import Foundation
import AppKit

public final class VolumeMonitor: @unchecked Sendable {
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
            let uuid = vals.volumeUUIDString
            let total = Int64(vals.volumeTotalCapacity ?? 0)
            let avail = Int64(vals.volumeAvailableCapacity ?? 0)
            let fs = vals.volumeLocalizedFormatDescription ?? "External"

            results.append(MountedVolumeInfo(
                name: name,
                mountPath: url.path,
                volumeUUID: uuid,
                totalBytes: total,
                availableBytes: avail,
                isRemovable: isRemovable,
                isExternal: !isInternal,
                fileSystemType: fs
            ))
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
        return MountedVolumeInfo(
            name: vals.volumeName ?? url.lastPathComponent,
            mountPath: path,
            volumeUUID: vals.volumeUUIDString,
            totalBytes: Int64(vals.volumeTotalCapacity ?? 0),
            availableBytes: Int64(vals.volumeAvailableCapacity ?? 0),
            isRemovable: vals.volumeIsRemovable ?? false,
            isExternal: !(vals.volumeIsInternal ?? true),
            fileSystemType: vals.volumeLocalizedFormatDescription ?? "Disk"
        )
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
