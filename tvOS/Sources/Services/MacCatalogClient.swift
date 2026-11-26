import Foundation
import Network

struct TVDiscoveredMacServer: Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var host: String
    var port: UInt16

    var baseURLString: String { "http://\(host):\(port)" }
}

/// Zero-config Bonjour browser for My Echo on Mac (`_myecho-sync._tcp`) over LAN / Wi-Fi / Ethernet.
final class TVBonjourMacBrowser: @unchecked Sendable {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.myecho.tvos.bonjour")
    var onServersUpdated: (@Sendable ([TVDiscoveredMacServer]) -> Void)?

    private var resolvedByName: [String: TVDiscoveredMacServer] = [:]

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
                        let server = TVDiscoveredMacServer(name: name, host: lanIP, port: portVal)
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
                        hostStr = clean.lowercased().hasPrefix("fe80:") ? nil : "[\(clean)]"
                    case .name(let hostname, _):
                        hostStr = hostname
                    @unknown default:
                        hostStr = nil
                    }
                    if let hostStr, !hostStr.isEmpty {
                        let server = TVDiscoveredMacServer(name: serviceName, host: hostStr, port: port.rawValue)
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

/// HTTP client talking to My Echo Server (Unraid Docker) or My Echo on Mac for full library catalog, LAN lossless streaming, Mac remote control, and Party Mode TV display.
actor MacCatalogClient {
    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let frac = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let std = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let dt = try? frac.parse(s) { return dt }
            if let dt = try? std.parse(s) { return dt }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(s)")
        }
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 90
        self.session = URLSession(configuration: cfg)
    }

    static func normalizeBase(_ raw: String) -> String? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }

    static func artworkURL(serverURL: String, pin: String, hash: String?) -> URL? {
        guard let hash, !hash.isEmpty, let base = normalizeBase(serverURL) else { return nil }
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "\(base)/api/v1/artwork/\(hash)?token=\(cleanPin)")
    }

    static func partyArtworkURL(partyBaseURL: String, hash: String?) -> URL? {
        guard let hash, !hash.isEmpty, let base = normalizeBase(partyBaseURL) else { return nil }
        return URL(string: "\(base)/api/party/artwork/\(hash)")
    }

    static func partyStreamURL(partyBaseURL: String, trackID: String) -> URL? {
        guard !trackID.isEmpty, let base = normalizeBase(partyBaseURL) else { return nil }
        let encodedID = trackID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackID
        return URL(string: "\(base)/api/party/stream/\(encodedID)")
    }

    static func partyVoiceIntroURL(partyBaseURL: String, trackID: String) -> URL? {
        guard !trackID.isEmpty, let base = normalizeBase(partyBaseURL) else { return nil }
        let encodedID = trackID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackID
        return URL(string: "\(base)/api/party/intro/\(encodedID)")
    }

    static func catalogTrackStreamURL(serverURL: String, pin: String, trackID: String) -> URL? {
        guard let base = normalizeBase(serverURL) else { return nil }
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedID = trackID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackID
        return URL(string: "\(base)/api/v1/catalog/track/\(encodedID)?token=\(cleanPin)")
    }

    static func catalogEpisodeStreamURL(serverURL: String, pin: String, episodeID: String) -> URL? {
        guard let base = normalizeBase(serverURL) else { return nil }
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedID = episodeID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? episodeID
        return URL(string: "\(base)/api/v1/catalog/episode/\(encodedID)?token=\(cleanPin)")
    }

    // MARK: - Authenticated Mac Endpoints

    func ping(serverURL: String, pin: String) async throws -> TVPingPayload {
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/ping", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPingPayload.self, from: data)
    }

    func fetchFullCatalog(serverURL: String, pin: String) async throws -> TVFullCatalogPayload {
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/catalog/full", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVFullCatalogPayload.self, from: data)
    }

    func fetchRemoteState(serverURL: String, pin: String) async throws -> TVRemotePlaybackState {
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/remote/state", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVRemotePlaybackState.self, from: data)
    }

    func sendRemoteCommand(serverURL: String, pin: String, command: TVRemoteCommandRequest) async throws -> TVRemoteCommandResponse {
        var req = try buildRequest(serverURL: serverURL, path: "/api/v1/remote/command", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(command)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVRemoteCommandResponse.self, from: data)
    }

    func fetchPartyEnvelope(serverURL: String, pin: String) async throws -> TVPartyEnvelope {
        let req = try buildRequest(serverURL: serverURL, path: "/api/v1/party/state", pin: pin)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyEnvelope.self, from: data)
    }

    func startServerPartySession(serverURL: String, pin: String, rendererID: String, rendererName: String) async throws -> TVPartyEnvelope {
        var req = try buildRequest(serverURL: serverURL, path: "/api/party/session/start", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["rendererId": rendererID, "rendererName": rendererName])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyEnvelope.self, from: data)
    }

    func stopServerPartySession(serverURL: String, pin: String) async throws -> TVPartyEnvelope {
        var req = try buildRequest(serverURL: serverURL, path: "/api/party/session/stop", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyEnvelope.self, from: data)
    }

    func sendPartyHostCommand(serverURL: String, pin: String, action: String) async throws {
        var req = try buildRequest(serverURL: serverURL, path: "/api/party/host/command", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["action": action])
        let (_, resp) = try await session.data(for: req)
        try validateHTTP(resp)
    }

    func sendPartyRendererHeartbeat(
        serverURL: String,
        pin: String,
        rendererID: String,
        rendererName: String,
        trackID: String,
        currentTime: TimeInterval,
        isPlaying: Bool,
        isPlayingVoiceIntro: Bool
    ) async throws -> TVPartyPlaylistState {
        var req = try buildRequest(serverURL: serverURL, path: "/api/party/renderer/heartbeat", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "rendererId": rendererID,
            "rendererName": rendererName,
            "trackId": trackID,
            "currentTime": currentTime,
            "isPlaying": isPlaying,
            "isPlayingVoiceIntro": isPlayingVoiceIntro
        ])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyPlaylistState.self, from: data)
    }

    func notifyPartyRendererEnded(serverURL: String, pin: String, rendererID: String, trackID: String) async throws -> TVPartyPlaylistState {
        var req = try buildRequest(serverURL: serverURL, path: "/api/party/renderer/ended", pin: pin)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "rendererId": rendererID,
            "trackId": trackID
        ])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyPlaylistState.self, from: data)
    }

    /// Direct unauthenticated Party Mode polling when user enters a standalone Party Mode URL (e.g. `http://192.168.1.50:53333`).
    func fetchDirectPartyState(partyURL: String) async throws -> TVPartyPlaylistState {
        guard let base = Self.normalizeBase(partyURL),
              let url = URL(string: "\(base)/api/party/state") else {
            throw URLError(.badURL)
        }
        let (data, resp) = try await session.data(from: url)
        try validateHTTP(resp)
        return try decoder.decode(TVPartyPlaylistState.self, from: data)
    }

    // MARK: - Internals

    private func buildRequest(serverURL: String, path: String, pin: String) throws -> URLRequest {
        guard let base = Self.normalizeBase(serverURL),
              let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue(pin.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-Echo-Token")
        return req
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 {
            throw NSError(
                domain: "MyEchoTV.MacClient",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Invalid 6-digit Pairing PIN — check My Echo Settings on Mac."]
            )
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "MyEchoTV.MacClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "My Echo Mac server returned HTTP \(http.statusCode)"]
            )
        }
    }
}
