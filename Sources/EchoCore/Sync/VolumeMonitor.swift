import Foundation
import AppKit
import DiskArbitration
import IOKit

public struct VolumeHardwareProbe: Sendable, Hashable {
    public var connectionKind: VolumeConnectionKind
    public var vendorName: String?
    public var productName: String?
    public var usbVendorID: Int?
    public var usbProductID: Int?
    public var usbLocationID: Int?

    public init(
        connectionKind: VolumeConnectionKind,
        vendorName: String? = nil,
        productName: String? = nil,
        usbVendorID: Int? = nil,
        usbProductID: Int? = nil,
        usbLocationID: Int? = nil
    ) {
        self.connectionKind = connectionKind
        self.vendorName = vendorName
        self.productName = productName
        self.usbVendorID = usbVendorID
        self.usbProductID = usbProductID
        self.usbLocationID = usbLocationID
    }
}

public final class VolumeMonitor: @unchecked Sendable {
    /// Normalizes macOS volume UUIDs, rejecting all-zero FAT32 placeholder UUIDs (common on DAP-formatted microSD cards).
    public static func sanitizedVolumeUUID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "0", with: "")
        return stripped.isEmpty ? nil : trimmed
    }

    public static func scanMountedExternalVolumes() -> [MountedVolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey,
            .volumeLocalizedFormatDescriptionKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        var results: [MountedVolumeInfo] = []
        for url in urls {
            guard url.path != "/" else { continue }
            guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let isLocal = vals.volumeIsLocal ?? true
            let isInternal = vals.volumeIsInternal ?? false
            let isRemovable = vals.volumeIsRemovable ?? false

            // Include removable media (SD cards, FiiO USB Mass Storage, USB sticks) and external local drives
            guard isLocal && (isRemovable || !isInternal) else { continue }

            let name = vals.volumeName ?? url.lastPathComponent
            let uuid = sanitizedVolumeUUID(vals.volumeUUIDString)
            let total = Int64(vals.volumeTotalCapacity ?? 0)
            let avail = Int64(vals.volumeAvailableCapacity ?? 0)
            let fs = vals.volumeLocalizedFormatDescription ?? "External"
            let hw = inspectHardware(forMountPath: url.path)

            results.append(MountedVolumeInfo(
                name: name,
                mountPath: url.path,
                volumeUUID: uuid,
                totalBytes: total,
                availableBytes: avail,
                isRemovable: isRemovable,
                isExternal: !isInternal,
                fileSystemType: fs,
                connectionKind: hw.connectionKind,
                hardwareVendor: hw.vendorName,
                hardwareProduct: hw.productName,
                usbVendorID: hw.usbVendorID,
                usbProductID: hw.usbProductID,
                usbLocationID: hw.usbLocationID
            ))
        }

        // Multi-LUN sibling check: e.g. FiiO Echo Mini plugged in via USB mounts BOTH internal "ECHO" + microSD "ECHO SD"
        // under the same USB device locationID. If any sibling is identified as a player (or carries a DAP name), elevate siblings too.
        let byLocation = Dictionary(grouping: results.indices.filter { results[$0].usbLocationID != nil }) {
            results[$0].usbLocationID!
        }
        for (_, indices) in byLocation where indices.count >= 2 {
            let names = indices.map { results[$0].name.lowercased() }
            let hasPlayerHint = indices.contains { results[$0].connectionKind == .inPlayer }
                || names.contains(where: { $0 == "echo" || $0.contains("fiio") || $0.contains("snowsky") || $0.contains("walkman") || $0.contains("hiby") || $0.contains("shanling") })
            if hasPlayerHint {
                for idx in indices where results[idx].connectionKind != .builtInCardReader {
                    results[idx].connectionKind = .inPlayer
                }
            }
        }

        return results
    }

    public static func volumeInfo(atPath path: String) -> MountedVolumeInfo? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeLocalizedFormatDescriptionKey
        ]
        guard let vals = try? url.resourceValues(forKeys: keys) else { return nil }
        let hw = inspectHardware(forMountPath: path)
        return MountedVolumeInfo(
            name: vals.volumeName ?? url.lastPathComponent,
            mountPath: path,
            volumeUUID: sanitizedVolumeUUID(vals.volumeUUIDString),
            totalBytes: Int64(vals.volumeTotalCapacity ?? 0),
            availableBytes: Int64(vals.volumeAvailableCapacity ?? 0),
            isRemovable: vals.volumeIsRemovable ?? false,
            isExternal: !(vals.volumeIsInternal ?? true),
            fileSystemType: vals.volumeLocalizedFormatDescription ?? "Disk",
            connectionKind: hw.connectionKind,
            hardwareVendor: hw.vendorName,
            hardwareProduct: hw.productName,
            usbVendorID: hw.usbVendorID,
            usbProductID: hw.usbProductID,
            usbLocationID: hw.usbLocationID
        )
    }

    // MARK: - Native DiskArbitration + IOKit Hardware Detection (In Player vs Card Reader)

    public static func inspectHardware(forMountPath mountPath: String) -> VolumeHardwareProbe {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            return VolumeHardwareProbe(connectionKind: .unknown)
        }
        let url = URL(fileURLWithPath: mountPath) as CFURL
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url) else {
            return VolumeHardwareProbe(connectionKind: .unknown)
        }
        let media = DADiskCopyIOMedia(disk)
        guard media != 0 else {
            return VolumeHardwareProbe(connectionKind: .unknown)
        }
        defer { IOObjectRelease(media) }

        var classNames: [String] = []
        var usbVendorID: Int?
        var usbProductID: Int?
        var usbLocationID: Int?
        var usbVendorName: String?
        var usbProductName: String?
        var scsiVendor: String?
        var scsiProduct: String?
        var interconnect: String?
        var interconnectLocation: String?

        var current: io_registry_entry_t = media
        IOObjectRetain(current)

        for _ in 0..<24 {
            var cname = [CChar](repeating: 0, count: 128)
            if IOObjectGetClass(current, &cname) == KERN_SUCCESS {
                let bytes = cname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                let s = String(decoding: bytes, as: UTF8.self)
                classNames.append(s)
            }

            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(current, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = propsRef?.takeRetainedValue() as? [String: Any] {
                if usbVendorID == nil, let v = dict["idVendor"] as? NSNumber {
                    usbVendorID = v.intValue
                }
                if usbProductID == nil, let p = dict["idProduct"] as? NSNumber {
                    usbProductID = p.intValue
                }
                if usbLocationID == nil, let loc = dict["locationID"] as? NSNumber {
                    usbLocationID = loc.intValue
                }
                if usbVendorName == nil, let vn = (dict["USB Vendor Name"] as? String) ?? (dict["kUSBVendorString"] as? String) {
                    let trimmed = vn.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { usbVendorName = trimmed }
                }
                if usbProductName == nil, let pn = (dict["USB Product Name"] as? String) ?? (dict["kUSBProductString"] as? String) {
                    let trimmed = pn.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { usbProductName = trimmed }
                }
                if scsiVendor == nil, let sv = dict["Vendor Identification"] as? String {
                    let trimmed = sv.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { scsiVendor = trimmed }
                }
                if scsiProduct == nil, let sp = dict["Product Identification"] as? String {
                    let trimmed = sp.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { scsiProduct = trimmed }
                }
                if let devChars = dict["Device Characteristics"] as? [String: Any] {
                    if scsiVendor == nil, let sv = devChars["Vendor Name"] as? String {
                        let trimmed = sv.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { scsiVendor = trimmed }
                    }
                    if scsiProduct == nil, let sp = devChars["Product Name"] as? String {
                        let trimmed = sp.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { scsiProduct = trimmed }
                    }
                }
                if let protoChars = dict["Protocol Characteristics"] as? [String: Any] {
                    if interconnect == nil, let ic = protoChars["Physical Interconnect"] as? String {
                        interconnect = ic
                    }
                    if interconnectLocation == nil, let icl = protoChars["Physical Interconnect Location"] as? String {
                        interconnectLocation = icl
                    }
                }
                if interconnect == nil, let ic = dict["Physical Interconnect"] as? String {
                    interconnect = ic
                }
                if interconnectLocation == nil, let icl = dict["Physical Interconnect Location"] as? String {
                    interconnectLocation = icl
                }
                if let usbInfo = dict["USB Device Info"] as? [String: Any] {
                    if usbVendorID == nil, let v = usbInfo["idVendor"] as? NSNumber { usbVendorID = v.intValue }
                    if usbProductID == nil, let p = usbInfo["idProduct"] as? NSNumber { usbProductID = p.intValue }
                    if usbLocationID == nil, let loc = usbInfo["locationID"] as? NSNumber { usbLocationID = loc.intValue }
                }
            }

            var parent: io_registry_entry_t = 0
            let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            IOObjectRelease(current)
            if kr != KERN_SUCCESS || parent == 0 {
                break
            }
            current = parent
        }

        return classifyHardware(
            classNames: classNames,
            interconnect: interconnect,
            interconnectLocation: interconnectLocation,
            usbVendorID: usbVendorID,
            usbProductID: usbProductID,
            usbLocationID: usbLocationID,
            usbVendorName: usbVendorName,
            usbProductName: usbProductName,
            scsiVendor: scsiVendor,
            scsiProduct: scsiProduct
        )
    }

    /// Pure deterministic hardware classifier (unit-tested in EchoCoreTests).
    public static func classifyHardware(
        classNames: [String],
        interconnect: String?,
        interconnectLocation: String?,
        usbVendorID: Int?,
        usbProductID: Int?,
        usbLocationID: Int? = nil,
        usbVendorName: String?,
        usbProductName: String?,
        scsiVendor: String?,
        scsiProduct: String?
    ) -> VolumeHardwareProbe {
        let joinedClasses = classNames.joined(separator: " ").lowercased()
        let ic = (interconnect ?? "").lowercased()
        let icLoc = (interconnectLocation ?? "").lowercased()
        let combinedText = [usbVendorName, usbProductName, scsiVendor, scsiProduct]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        let knownVendorName = Self.knownVendorLabel(for: usbVendorID)
        let displayVendor = knownVendorName
            ?? nonGenericString(usbVendorName)
            ?? nonGenericString(scsiVendor)
        let displayProduct = nonGenericString(usbProductName) ?? nonGenericString(scsiProduct)

        // 1. Built-in Mac SD Card Reader (AppleSDXC, O2 Micro PCIe 0x17A0, Apple internal USB Card Reader 0x05AC)
        if ic.contains("secure digital")
            || joinedClasses.contains("applesdxc")
            || joinedClasses.contains("appleusbcardreader")
            || usbVendorID == 0x17A0
            || (usbVendorID == 0x05AC && (combinedText.contains("card reader") || combinedText.contains("sd") || icLoc == "internal"))
            || (icLoc == "internal" && (combinedText.contains("card reader") || combinedText.contains("sdxc"))) {
            return VolumeHardwareProbe(
                connectionKind: .builtInCardReader,
                vendorName: "Apple",
                productName: displayProduct ?? "Built-in SDXC Slot",
                usbVendorID: usbVendorID,
                usbProductID: usbProductID,
                usbLocationID: usbLocationID
            )
        }

        // 2. Digital Audio Player (DAP) over USB Mass Storage
        let dapVendorIDs: Set<Int> = [
            0x2972, // FiiO Electronics Technology Co., Ltd. (Snowsky / FiiO)
            0x2207, // Rockchip (FiiO Echo / Nano / HiBy / Shanling DAPs)
            0x10D6, // Actions Semiconductor (Snowsky Echo Mini / classic DAPs)
            0x601A, // Ingenic (FiiO Disc / HiBy R-series / Shanling M0)
            0xA108, // Ingenic / Actions DAP mass storage
            0x4102, // iRiver / Astell&Kern
            0x2F0E, // Shanling
            0x301A, // HiBy
            0x1F3A  // Allwinner DAPs
        ]
        let dapKeywords = [
            "fiio", "snowsky", "echo mini", "walkman", "shanling", "hiby",
            "astell", "ibasso", "cayin", "tempotec", "hidizs", "surfans",
            "innioasis", "agptek", "sansa", "clip jam", "clip sport",
            "audio player", "mp3 player", "digital audio"
        ]
        let androidDAPVendorIDs: Set<Int> = [0x18D1, 0x0E8D, 0x05C6, 0x054C]

        if (usbVendorID.map { dapVendorIDs.contains($0) } ?? false)
            || dapKeywords.contains(where: { combinedText.contains($0) })
            || ((usbVendorID.map { androidDAPVendorIDs.contains($0) } ?? false)
                && (combinedText.contains("walkman") || combinedText.contains("nw-") || combinedText.contains("fiio") || combinedText.contains("dap") || combinedText.contains("player"))) {
            return VolumeHardwareProbe(
                connectionKind: .inPlayer,
                vendorName: displayVendor ?? "Audio Player",
                productName: displayProduct,
                usbVendorID: usbVendorID,
                usbProductID: usbProductID,
                usbLocationID: usbLocationID
            )
        }

        // 3. External USB Card Readers (Genesys Logic 0x05E3, Realtek 0x0BDA, Alcor 0x058F, Super Top 0x14CD, etc.)
        let cardReaderVendorIDs: Set<Int> = [
            0x05E3, // Genesys Logic (GL3224 / GL3232 / GL827L USB SD/microSD Readers)
            0x0BDA, // Realtek USB Card Readers (RTS5129 / RTS5169 / RTS5309 / RTS5329)
            0x058F, // Alcor Micro USB Card Readers
            0x14CD, // Super Top Generic USB SD Readers
            0x1908, // GEMBIRD / Generic USB Card Readers
            0x0CF2, // ENE Technology Card Readers
            0x0AEC, // Neodio Card Readers
            0x0424  // Microchip / SMSC Card Readers
        ]
        let cardReaderKeywords = [
            "card reader", "sd reader", "microsd", "sd/mmc", "tf reader",
            "multi-card", "imagemate", "sddr", "storage device"
        ]
        let isGenericUSBStorage = (combinedText.contains("generic") && combinedText.contains("storage"))
            || combinedText.contains("usb storage")

        if (usbVendorID.map { cardReaderVendorIDs.contains($0) } ?? false)
            || cardReaderKeywords.contains(where: { combinedText.contains($0) })
            || isGenericUSBStorage {
            return VolumeHardwareProbe(
                connectionKind: .usbCardReader,
                vendorName: displayVendor ?? "Generic USB",
                productName: displayProduct ?? "Card Reader",
                usbVendorID: usbVendorID,
                usbProductID: usbProductID,
                usbLocationID: usbLocationID
            )
        }

        // 4. Other External USB / Thunderbolt Drive
        if ic.contains("usb") || ic.contains("thunderbolt") || icLoc == "external" {
            return VolumeHardwareProbe(
                connectionKind: .externalDrive,
                vendorName: displayVendor,
                productName: displayProduct,
                usbVendorID: usbVendorID,
                usbProductID: usbProductID,
                usbLocationID: usbLocationID
            )
        }

        return VolumeHardwareProbe(
            connectionKind: .unknown,
            vendorName: displayVendor,
            productName: displayProduct,
            usbVendorID: usbVendorID,
            usbProductID: usbProductID,
            usbLocationID: usbLocationID
        )
    }

    private static func knownVendorLabel(for vendorID: Int?) -> String? {
        guard let vendorID else { return nil }
        switch vendorID {
        case 0x2972: return "FiiO / Snowsky"
        case 0x2207: return "Rockchip DAP"
        case 0x10D6: return "Actions DAP"
        case 0x601A, 0xA108: return "Ingenic DAP"
        case 0x4102: return "Astell&Kern"
        case 0x2F0E: return "Shanling"
        case 0x301A: return "HiBy"
        case 0x054C: return "Sony"
        case 0x05E3: return "Genesys Logic"
        case 0x0BDA: return "Realtek"
        case 0x058F: return "Alcor Micro"
        case 0x14CD: return "Super Top"
        case 0x0781: return "SanDisk"
        case 0x17A0: return "O2 Micro"
        case 0x05AC: return "Apple"
        default: return nil
        }
    }

    private static func nonGenericString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let low = trimmed.lowercased()
        if low == "generic" || low == "usb storage" || low == "storage device" || low == "mass storage" {
            return nil
        }
        return trimmed
    }

    public static func cleanAndEject(mountPath: String, force: Bool = false) async throws -> Int {
        try await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: mountPath)
            let cleaned = SyncEngine.cleanMacOSJunkFiles(at: url)
            // Flush pending FAT32/exFAT writes before unmounting
            sync()
            try? await Task.sleep(for: .milliseconds(250))

            if force {
                let res = runDiskutil(["unmount", "force", mountPath])
                if res.exitCode == 0 {
                    _ = runDiskutil(["eject", mountPath])
                    return cleaned
                }
                let ejectRes = runDiskutil(["eject", mountPath])
                if ejectRes.exitCode == 0 { return cleaned }
                throw NSError(domain: "Echo.Eject", code: Int(res.exitCode), userInfo: [
                    NSLocalizedDescriptionKey: res.output.isEmpty ? "Could not force-eject volume." : res.output
                ])
            }

            // 1. Try standard safe `diskutil eject`
            var ejectRes = runDiskutil(["eject", mountPath])
            if ejectRes.exitCode == 0 { return cleaned }

            // 2. Brief retry in case Spotlight / fseventsd just released the FAT32 lock
            try? await Task.sleep(for: .milliseconds(700))
            ejectRes = runDiskutil(["eject", mountPath])
            if ejectRes.exitCode == 0 { return cleaned }

            // 3. Fallback to `diskutil unmount` (often succeeds on multi-LUN USB DAPs like FiiO Echo + Echo SD)
            let unmountRes = runDiskutil(["unmount", mountPath])
            if unmountRes.exitCode == 0 { return cleaned }

            let detail = !ejectRes.output.isEmpty ? ejectRes.output : unmountRes.output
            throw NSError(domain: "Echo.Eject", code: Int(ejectRes.exitCode), userInfo: [
                NSLocalizedDescriptionKey: detail.isEmpty
                    ? "Volume is busy (another app like Finder or Spotlight is using it). Try right-click → Force Eject."
                    : "\(detail) — Try Force Eject if no files are open."
            ])
        }.value
    }

    private static func runDiskutil(_ args: [String]) -> (exitCode: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (proc.terminationStatus, text)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
