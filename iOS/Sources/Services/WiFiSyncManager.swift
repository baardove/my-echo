import Foundation
import Network
import UIKit

struct DiscoveredMacServer: Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var host: String
    var port: UInt16

    var baseURLString: String { "http://\(host):\(port)" }
}

/// Bonjour NWBrowser for zero-config discovery of My Echo on Mac over local Wi-Fi (`_myecho-sync._tcp`)
final class BonjourMacBrowser: @unchecked Sendable {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.myecho.ios.bonjour")
    var onServersUpdated: (@Sendable ([DiscoveredMacServer]) -> Void)?

    private var resolvedByName: [String: DiscoveredMacServer] = [:]

    func start() {
        stop()
        let desc = NWBrowser.Descriptor.bonjour(type: "_myecho-sync._tcp", domain: nil)
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: desc, using: params)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint {
                    if case .bonjour(let txt) = result.metadata,
                       let lanIP = txt["lanIP"], !lanIP.isEmpty {
                        let portVal = txt["port"].flatMap(UInt16.init) ?? 48721
                        let server = DiscoveredMacServer(name: name, host: lanIP, port: portVal)
                        self.resolvedByName[name] = server
                        let list = Array(self.resolvedByName.values).sorted { $0.name < $1.name }
                        self.onServersUpdated?(list)
                    } else {
                        self.resolveEndpoint(result.endpoint, serviceName: name)
                    }
                }
            }
        }
        browser = b
        b.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint, serviceName: String) {
        let params = NWParameters.tcp
        if let ipOpts = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOpts.version = .v4
        }
        let conn = NWConnection(to: endpoint, using: params)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                if let remote = conn.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = remote {
                    let hostStr: String?
                    switch host {
                    case .ipv4(let addr):
                        hostStr = "\(addr)".components(separatedBy: "%").first ?? "\(addr)"
                    case .ipv6(let addr):
                        let clean = "\(addr)".components(separatedBy: "%").first ?? "\(addr)"
                        // Skip link-local fe80:: addresses which fail in URLSession without a scope ID
                        hostStr = clean.lowercased().hasPrefix("fe80:") ? nil : "[\(clean)]"
                    case .name(let hostname, _):
                        hostStr = hostname
                    @unknown default:
                        hostStr = nil
                    }
                    if let hostStr, !hostStr.isEmpty {
                        let server = DiscoveredMacServer(name: serviceName, host: hostStr, port: port.rawValue)
                        self.resolvedByName[serviceName] = server
                        let list = Array(self.resolvedByName.values).sorted { $0.name < $1.name }
                        self.onServersUpdated?(list)
                    }
                }
                conn.cancel()
            } else if case .failed = state {
                conn.cancel()
            }
        }
        conn.start(queue: queue)
    }
}

/// Handles incremental differential Wi-Fi sync with My Echo on Mac (tracks, playlists, podcasts, artwork + Mirror deletion).
actor WiFiSyncEngine {
    let libraryRootURL: URL
    let tracksDir: URL
    let episodesDir: URL
    let artworkDir: URL
    let manifestFileURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.libraryRootURL = docs.appendingPathComponent("MyEchoLibrary", isDirectory: true)
        self.tracksDir = libraryRootURL.appendingPathComponent("Tracks", isDirectory: true)
        self.episodesDir = libraryRootURL.appendingPathComponent("Episodes", isDirectory: true)
        self.artworkDir = libraryRootURL.appendingPathComponent("Artwork", isDirectory: true)
        self.manifestFileURL = libraryRootURL.appendingPathComponent("manifest.json")

        let fm = FileManager.default
        try? fm.createDirectory(at: tracksDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: episodesDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: artworkDir, withIntermediateDirectories: true)

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: cfg)
    }

    func loadLocalManifest() -> SyncManifestPayload? {
        guard let data = try? Data(contentsOf: manifestFileURL) else { return nil }
        return try? decoder.decode(SyncManifestPayload.self, from: data)
    }

    func localTrackURL(for track: SyncedTrack) -> URL {
        tracksDir.appendingPathComponent("\(track.id).\(track.fileExtension)")
    }

    func localEpisodeURL(for episode: SyncedEpisode) -> URL {
        episodesDir.appendingPathComponent("\(episode.id).\(episode.fileExtension)")
    }

    func localArtworkURL(for hash: String?) -> URL? {
        guard let hash, !hash.isEmpty else { return nil }
        let url = artworkDir.appendingPathComponent("\(hash).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func localStorageBytes() -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for dir in [tracksDir, episodesDir, artworkDir] {
            if let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for u in urls {
                    if let sz = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        total += Int64(sz)
                    }
                }
            }
        }
        return total
    }

    func ping(serverURL: String, pin: String) async throws -> SyncPingPayload {
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/ping", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(SyncPingPayload.self, from: data)
    }

    func searchMacLibrary(serverURL: String, pin: String, query: String) async throws -> MacLibrarySearchResponse {
        let encodedQ = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/library/search?q=\(encodedQ)&limit=30", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(MacLibrarySearchResponse.self, from: data)
    }

    func setMacSyncSelection(serverURL: String, pin: String, request: MacRemoteSyncSelectRequest) async throws -> MacRemoteSyncSelectResponse {
        var req = try buildRequest(serverURL: serverURL, path: "/api/v1/sync/select", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(request)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(MacRemoteSyncSelectResponse.self, from: data)
    }

    func searchLidarrViaMac(serverURL: String, pin: String, query: String) async throws -> MacLidarrSearchResponse {
        let encodedQ = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/lidarr/search?q=\(encodedQ)", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(MacLidarrSearchResponse.self, from: data)
    }

    func orderLidarrViaMac(serverURL: String, pin: String, request: MacLidarrOrderRequest) async throws -> MacLidarrOrderResponse {
        var req = try buildRequest(serverURL: serverURL, path: "/api/v1/lidarr/order", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(request)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(MacLidarrOrderResponse.self, from: data)
    }

    func subscribePodcastOnMac(serverURL: String, pin: String, request: MacPodcastSubscribeRequest) async throws -> MacPodcastSubscribeResponse {
        var req = try buildRequest(serverURL: serverURL, path: "/api/v1/podcasts/subscribe", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(request)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(MacPodcastSubscribeResponse.self, from: data)
    }

    func macArtworkURL(serverURL: String, pin: String, hash: String?) -> URL? {
        guard let hash, !hash.isEmpty else { return nil }
        var trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "\(trimmed)/api/v1/artwork/\(hash)?token=\(cleanPin)")
    }

    struct SyncProgressUpdate: Sendable {
        var phase: String
        var completed: Int
        var total: Int
        var currentTitle: String
    }

    func performSync(
        serverURL: String,
        pin: String,
        clientName: String,
        localPodcastIndex: LocalPodcastDownloadIndex = LocalPodcastDownloadIndex(downloadedIDs: [], downloadedGUIDs: [], downloadedAudioURLs: [], selfDownloadedFileNames: []),
        onProgress: @escaping @Sendable (SyncProgressUpdate) -> Void
    ) async throws -> SyncManifestPayload {
        onProgress(SyncProgressUpdate(phase: "Fetching manifest from Mac...", completed: 0, total: 1, currentTitle: ""))
        let manifestReq = try buildRequest(serverURL: serverURL, path: "/api/v1/manifest", pin: pin)
        let (mData, mResp) = try await session.data(for: manifestReq)
        try validateHTTP(mResp)
        let remoteManifest = try decoder.decode(SyncManifestPayload.self, from: mData)

        let tracksToDownload = remoteManifest.tracks.filter { !FileManager.default.fileExists(atPath: localTrackURL(for: $0).path) }
        // Avoid syncing podcast episodes that the iOS app has already downloaded locally (matched by ID, GUID, or audio URL)
        let episodesToDownload = remoteManifest.episodes.filter { ep in
            !FileManager.default.fileExists(atPath: localEpisodeURL(for: ep).path)
                && !localPodcastIndex.contains(id: ep.id, guid: ep.guid, audioURL: ep.audioURL)
        }
        let neededArtworkHashes = Set(
            remoteManifest.tracks.compactMap(\.artworkHash)
                + remoteManifest.episodes.compactMap(\.artworkHash)
                + remoteManifest.podcastFeeds.compactMap(\.artworkHash)
        ).filter { !FileManager.default.fileExists(atPath: artworkDir.appendingPathComponent("\($0).jpg").path) }

        let totalWork = max(1, tracksToDownload.count + episodesToDownload.count + neededArtworkHashes.count)
        var done = 0

        // 1. Download missing artwork
        for hash in neededArtworkHashes {
            if let req = try? buildRequest(serverURL: serverURL, path: "/api/v1/artwork/\(hash)", pin: pin),
               let (artData, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                try? artData.write(to: artworkDir.appendingPathComponent("\(hash).jpg"), options: .atomic)
            }
            done += 1
            onProgress(SyncProgressUpdate(phase: "Syncing artwork", completed: done, total: totalWork, currentTitle: ""))
        }

        // 2. Download missing audio tracks (lossless FLAC/ALAC/MP3/M4A/WAV)
        for track in tracksToDownload {
            onProgress(SyncProgressUpdate(phase: "Downloading music", completed: done, total: totalWork, currentTitle: "\(track.artist) — \(track.title)"))
            let req = try buildRequest(serverURL: serverURL, path: "/api/v1/track/\(track.id)", pin: pin)
            let (tempURL, resp) = try await session.download(for: req)
            try validateHTTP(resp)
            let dest = localTrackURL(for: track)
            if FileManager.default.fileExists(atPath: dest.path) { try? FileManager.default.removeItem(at: dest) }
            try FileManager.default.moveItem(at: tempURL, to: dest)
            done += 1
            onProgress(SyncProgressUpdate(phase: "Downloading music", completed: done, total: totalWork, currentTitle: track.title))
        }

        // 3. Download missing podcast episodes
        for ep in episodesToDownload {
            onProgress(SyncProgressUpdate(phase: "Downloading podcasts", completed: done, total: totalWork, currentTitle: ep.title))
            let req = try buildRequest(serverURL: serverURL, path: "/api/v1/episode/\(ep.id)", pin: pin)
            let (tempURL, resp) = try await session.download(for: req)
            try validateHTTP(resp)
            let dest = localEpisodeURL(for: ep)
            if FileManager.default.fileExists(atPath: dest.path) { try? FileManager.default.removeItem(at: dest) }
            try FileManager.default.moveItem(at: tempURL, to: dest)
            done += 1
        }

        // 4. Mirror cleanup: remove unselected Mac-synced files while preserving device-downloaded podcast episodes
        if remoteManifest.syncMode == "mirror" {
            let keepTracks = Set(remoteManifest.tracks.map { "\($0.id).\($0.fileExtension)" })
            if let existing = try? FileManager.default.contentsOfDirectory(at: tracksDir, includingPropertiesForKeys: nil) {
                for file in existing where !keepTracks.contains(file.lastPathComponent) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            let keepEps = Set(remoteManifest.episodes.map { "\($0.id).\($0.fileExtension)" })
                .union(localPodcastIndex.selfDownloadedFileNames)
            if let existing = try? FileManager.default.contentsOfDirectory(at: episodesDir, includingPropertiesForKeys: nil) {
                for file in existing where !keepEps.contains(file.lastPathComponent) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // 5. Save local manifest
        let savedData = try encoder.encode(remoteManifest)
        try savedData.write(to: manifestFileURL, options: .atomic)

        // 6. Report confirmed synced IDs back to My Echo on Mac (including episodes already downloaded on iPhone)
        let confirmedTracks = remoteManifest.tracks.filter { FileManager.default.fileExists(atPath: localTrackURL(for: $0).path) }.map(\.id)
        let confirmedEps = remoteManifest.episodes.filter { ep in
            FileManager.default.fileExists(atPath: localEpisodeURL(for: ep).path)
                || localPodcastIndex.contains(id: ep.id, guid: ep.guid, audioURL: ep.audioURL)
        }.map(\.id)
        let report = SyncReportPayload(
            deviceID: remoteManifest.deviceID,
            clientName: clientName,
            syncedTrackIDs: confirmedTracks,
            syncedEpisodeIDs: confirmedEps,
            completedAt: Date()
        )
        if var repReq = try? buildRequest(serverURL: serverURL, path: "/api/v1/sync-report", pin: pin) {
            repReq.httpMethod = "POST"
            repReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            repReq.httpBody = try? encoder.encode(report)
            _ = try? await session.data(for: repReq)
        }

        onProgress(SyncProgressUpdate(phase: "Up to date", completed: totalWork, total: totalWork, currentTitle: ""))
        return remoteManifest
    }

    private func buildRequest(serverURL: String, path: String, pin: String) throws -> URLRequest {
        var trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue(pin.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-Echo-Token")
        return req
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 {
            throw NSError(domain: "MyEchoiOS.Sync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid 6-digit Pairing PIN — check My Echo on Mac."])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "MyEchoiOS.Sync", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Mac Sync Server returned HTTP \(http.statusCode)"])
        }
    }
}
