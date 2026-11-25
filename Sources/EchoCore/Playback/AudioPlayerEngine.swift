import Foundation
import AVFoundation
import CoreAudio
import Observation
#if os(macOS)
import AppKit
import MediaPlayer
#endif

public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off
    case all
    case one
}

/// Represents a macOS CoreAudio output device (Built-in speakers, USB DAC, Bluetooth/AirPods, AirPlay, HDMI, etc.).
public struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    public enum TransportKind: String, Sendable, Hashable {
        case builtIn
        case usb
        case bluetooth
        case airPlay
        case hdmi
        case virtual
        case other

        public var label: String {
            switch self {
            case .builtIn: return "BUILT-IN"
            case .usb: return "USB DAC"
            case .bluetooth: return "BLUETOOTH"
            case .airPlay: return "AIRPLAY"
            case .hdmi: return "HDMI / DP"
            case .virtual: return "VIRTUAL"
            case .other: return "AUDIO"
            }
        }

        public var iconName: String {
            switch self {
            case .builtIn: return "laptopcomputer"
            case .usb: return "cable.connector"
            case .bluetooth: return "headphones"
            case .airPlay: return "airplayaudio"
            case .hdmi: return "tv"
            case .virtual: return "waveform.circle"
            case .other: return "hifispeaker.fill"
            }
        }
    }

    public let id: String            // CoreAudio UID (passed to AVAudioPlayer.currentDevice)
    public let audioDeviceID: UInt32
    public let name: String
    public let transportKind: TransportKind
    public let sampleRateHz: Double
    public let isSystemDefault: Bool

    public var formattedSampleRate: String? {
        guard sampleRateHz > 0 else { return nil }
        let khz = sampleRateHz / 1000.0
        return khz.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kHz", khz)
            : String(format: "%.1f kHz", khz)
    }

    /// Enumerates all live CoreAudio output-capable devices on macOS.
    public static func listAllOutputDevices() -> [AudioOutputDevice] {
        var defaultDeviceID: AudioDeviceID = 0
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddr,
            0,
            nil,
            &defaultSize,
            &defaultDeviceID
        )

        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            0,
            nil,
            &dataSize
        ) == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return []
        }

        var result: [AudioOutputDevice] = []
        for devID in deviceIDs {
            guard outputChannelCount(for: devID) > 0,
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, deviceID: devID),
                  !uid.isEmpty,
                  let name = stringProperty(kAudioObjectPropertyName, deviceID: devID),
                  !name.isEmpty else {
                continue
            }

            let transport = classifyTransport(for: devID)
            let rate = sampleRate(for: devID)
            result.append(AudioOutputDevice(
                id: uid,
                audioDeviceID: devID,
                name: name,
                transportKind: transport,
                sampleRateHz: rate,
                isSystemDefault: devID == defaultDeviceID
            ))
        }

        return result.sorted { a, b in
            if a.isSystemDefault != b.isSystemDefault { return a.isSystemDefault }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    public static func listAllInputDeviceIDs() -> [AudioDeviceID] {
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            0,
            nil,
            &dataSize
        ) == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return []
        }

        return deviceIDs.filter { inputChannelCount(for: $0) > 0 }
    }

    public static func isDeviceRunningSomewhere(_ deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &running) == noErr else {
            return false
        }
        return running != 0
    }

    private static func inputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, raw) == noErr else {
            return 0
        }
        let listPtr = raw.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(listPtr)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func outputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, raw) == noErr else {
            return 0
        }
        let listPtr = raw.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(listPtr)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfStr: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &cfStr) == noErr,
              let value = cfStr?.takeRetainedValue() else {
            return nil
        }
        return value as String
    }

    private static func classifyTransport(for deviceID: AudioDeviceID) -> TransportKind {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport) == noErr else {
            return .other
        }
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .hdmi
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return .virtual
        default:
            return .other
        }
    }

    private static func sampleRate(for deviceID: AudioDeviceID) -> Double {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &rate) == noErr else {
            return 0
        }
        return rate
    }
}

@MainActor
@Observable
public final class AudioPlayerEngine: NSObject, AVAudioPlayerDelegate {
    public private(set) var currentTrack: Track?
    public private(set) var queue: [Track] = []
    public private(set) var currentIndex: Int = 0
    public private(set) var isPlaying: Bool = false
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var playbackError: String?
    public private(set) var spectrumBands: [Double] = Array(repeating: 0, count: 16)
    public private(set) var peakHolds: [Double] = Array(repeating: 0, count: 16)
    public private(set) var isCrossfading: Bool = false
    public private(set) var availableOutputDevices: [AudioOutputDevice] = []
    /// CoreAudio device UID for dedicated My Echo playback output; `nil` follows macOS System Default.
    public var selectedOutputDeviceUID: String? = nil {
        didSet {
            if selectedOutputDeviceUID != oldValue {
                onSettingsChanged?()
            }
        }
    }

    public var activeOutputDevice: AudioOutputDevice? {
        if let uid = selectedOutputDeviceUID,
           let match = availableOutputDevices.first(where: { $0.id == uid }) {
            return match
        }
        return availableOutputDevices.first(where: \.isSystemDefault) ?? availableOutputDevices.first
    }

    /// True when the user picked a dedicated output device that is currently connected.
    public var isUsingDedicatedOutputDevice: Bool {
        guard let uid = selectedOutputDeviceUID else { return false }
        return availableOutputDevices.contains(where: { $0.id == uid })
    }

    private var resolvedOutputDeviceUID: String? {
        guard let uid = selectedOutputDeviceUID,
              availableOutputDevices.contains(where: { $0.id == uid }) else {
            return nil
        }
        return uid
    }

    public var volume: Double = 0.85 {
        didSet {
            let clamped = max(0, min(1, volume))
            if clamped != volume { volume = clamped; return }
            applyCurrentVolumes()
            onSettingsChanged?()
        }
    }

    public var isMuted: Bool = false {
        didSet {
            applyCurrentVolumes()
        }
    }

    public var isShuffled: Bool = false {
        didSet {
            applyShuffleState()
            onSettingsChanged?()
        }
    }

    public var repeatMode: RepeatMode = .off {
        didSet {
            onSettingsChanged?()
        }
    }

    public var crossfadeEnabled: Bool = false {
        didSet {
            if !crossfadeEnabled && isCrossfading {
                cancelActiveCrossfade()
            }
            onSettingsChanged?()
        }
    }

    public var crossfadeDuration: TimeInterval = 5.0 {
        didSet {
            let clamped = max(1.0, min(12.0, crossfadeDuration))
            if abs(clamped - crossfadeDuration) > 0.001 {
                crossfadeDuration = clamped
                return
            }
            onSettingsChanged?()
        }
    }

    /// Automatically pause when a FaceTime/Teams/Zoom/phone call activates an audio input, or when the dedicated output disconnects.
    public var autoPauseOnCall: Bool = true {
        didSet {
            if !autoPauseOnCall {
                pausedByCall = false
                callResumeTask?.cancel()
                callResumeTask = nil
            }
            onSettingsChanged?()
        }
    }

    /// Automatically resume playback shortly after the call/meeting finishes (only if My Echo paused it).
    public var autoResumeAfterCall: Bool = true {
        didSet {
            onSettingsChanged?()
        }
    }

    public private(set) var isPausedForCall: Bool = false
    /// When true (e.g., Party Mode active), Mac microphone input does not pause or duck playback.
    public var ignoreMicInputAutoPause: Bool = false
    /// True when playback naturally finished the last track of the queue without repeating.
    public private(set) var didReachQueueEnd: Bool = false
    /// True while a guest-recorded Party Mode voice intro is playing over ducked music (40%).
    public private(set) var isPlayingVoiceIntro: Bool = false
    public private(set) var activeVoiceIntroTrackID: String? = nil

    /// When true (e.g., Party Mode locked to "Partymode"), external queue-replacing calls are routed to lock interceptors.
    public var isQueueLocked: Bool = false
    public var onLockedQueuePlayRequest: ((_ tracks: [Track], _ startingAt: Int) -> Void)?
    public var onLockedQueueAppendRequest: ((_ track: Track, _ playNext: Bool) -> Void)?
    public var onLockedQueueRemoveRequest: ((_ index: Int) -> Void)?
    /// Optional lookup returning a local audio file URL for a recorded voice intro attached to `trackID`.
    public var onVoiceIntroURLForTrack: ((_ trackID: String) -> URL?)?
    /// Fired when a recorded voice intro begins playing for `trackID`.
    public var onVoiceIntroStarted: ((_ trackID: String) -> Void)?

    public var onSettingsChanged: (() -> Void)?
    /// Fired whenever the active queue, current track, pause/seek position, or playback state changes so callers can persist the playing queue across restarts.
    public var onQueueChanged: (() -> Void)?
    /// Fired once per playback session when a track reaches its play threshold (min(30s, 50% duration)) or completes.
    public var onTrackPlayed: ((Track) -> Void)?
    /// Optional lookup returning thumbnail JPEG/PNG bytes for a track's `artworkHash` (shown in macOS Control Center Now Playing).
    public var onArtworkDataForNowPlaying: ((String?) -> Data?)?

    private var originalQueue: [Track] = []
    private var player: AVAudioPlayer?
    private var fadingOutPlayer: AVAudioPlayer?
    private var crossfadeElapsed: TimeInterval = 0
    private var activeCrossfadeDuration: TimeInterval = 0
    private var progressTimer: Timer?
    private var currentSessionTrackID: String?
    private var currentSessionListenedSeconds: TimeInterval = 0
    private var currentSessionRecordedPlay: Bool = false
    private var lastTickWallTime: Date?
    private var pausedByCall: Bool = false {
        didSet { isPausedForCall = pausedByCall }
    }
    private var watchedInputDeviceIDs: Set<AudioDeviceID> = []
    private var wasAnyInputRunning: Bool = false
    private var callResumeTask: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?

    // Party Mode Voice Intro DJ Ducking Deck
    public static let voiceIntroDuckGain: Float = 0.40
    public static let voiceIntroOverlapSeconds: TimeInterval = 5.0

    private var introPlayer: AVAudioPlayer?
    private var introTargetQueueIndex: Int?
    private var introTargetTrackID: String?
    private var introOverlapTail: TimeInterval = 5.0
    private var introHasStartedTargetTrack: Bool = false
    private var introTriggeredKey: String?
    private var cachedNextIntroProbe: (trackID: String, url: URL, duration: TimeInterval)?

    /// Computes DJ talk-over timing: `preRoll` plays over the faded outgoing song, and the final `overlap`
    /// seconds (default 5s) play over the incoming song while both songs are ducked to 40%.
    public static func voiceIntroTimeline(
        introDuration: TimeInterval,
        overlapTailSeconds: TimeInterval = voiceIntroOverlapSeconds
    ) -> (preRoll: TimeInterval, overlap: TimeInterval, duckGain: Float) {
        let clampedDur = max(0, introDuration)
        let overlap = min(max(0, overlapTailSeconds), clampedDur)
        let preRoll = max(0, clampedDur - overlap)
        return (preRoll, overlap, voiceIntroDuckGain)
    }

    /// Equal-power crossfade gains (constant acoustic energy: out^2 + in^2 = 1.0)
    public static func equalPowerGains(progress: Double) -> (outgoing: Double, incoming: Double) {
        let t = max(0.0, min(1.0, progress))
        let angle = t * (.pi / 2.0)
        return (cos(angle), sin(angle))
    }

    /// Computes effective crossfade window for a track duration so very short tracks don't prematurely fade out
    public static func effectiveCrossfadeDuration(configured: TimeInterval, trackDuration: TimeInterval) -> TimeInterval {
        guard configured > 0, trackDuration > 2.5 else { return 0 }
        return min(configured, trackDuration * 0.4)
    }

    public override init() {
        super.init()
        refreshOutputDevices()
        installCoreAudioListeners()
        installCallAndSleepWatchers()
        setupRemoteMediaCommands()
    }

    // MARK: - macOS Media Keys & Control Center Now Playing

    private func setupRemoteMediaCommands() {
        #if os(macOS)
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeOrPlay()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextTrack()
            }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previousTrack()
            }
            return .success
        }

        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopPlaybackKeepTrack()
            }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetTime = posEvent.positionTime
            Task { @MainActor [weak self] in
                self?.seek(to: targetTime)
            }
            return .success
        }
        #endif
    }

    private func updateNowPlayingInfo() {
        #if os(macOS)
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let track = currentTrack else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.effectiveAlbum,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let artData = onArtworkDataForNowPlaying?(track.artworkHash),
           let probe = NSImage(data: artData) {
            let bounds = probe.size.width > 0 ? probe.size : NSSize(width: 512, height: 512)
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: bounds) { _ in
                NSImage(data: artData) ?? NSImage(size: bounds)
            }
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
        #endif
    }

    public func refreshOutputDevices() {
        availableOutputDevices = AudioOutputDevice.listAllOutputDevices()
    }

    /// Switches My Echo's playback output device live (pass `nil` for macOS System Default).
    public func selectOutputDevice(uid: String?) {
        let normalized = (uid?.isEmpty == false) ? uid : nil
        refreshOutputDevices()
        selectedOutputDeviceUID = normalized
        rerouteActivePlaybackToCurrentOutputDevice()
    }

    private func installCoreAudioListeners() {
        let queue = DispatchQueue.main
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            queue
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hadDedicated = self.isUsingDedicatedOutputDevice
                self.refreshOutputDevices()
                let stillHasDedicated = self.isUsingDedicatedOutputDevice
                if hadDedicated && !stillHasDedicated && self.autoPauseOnCall && self.isPlaying {
                    self.pause()
                }
                self.refreshInputDeviceListeners()
            }
        }

        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddr,
            queue
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshOutputDevices()
            }
        }
    }

    // MARK: - Auto-Pause on Incoming Calls / Meetings / Mac Sleep

    private func installCallAndSleepWatchers() {
        refreshInputDeviceListeners()
        #if os(macOS)
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.autoPauseOnCall, self.isPlaying else { return }
                self.pause()
            }
        }
        #endif
    }

    private func refreshInputDeviceListeners() {
        let currentInputs = AudioOutputDevice.listAllInputDeviceIDs()
        let queue = DispatchQueue.main
        var runningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        for devID in currentInputs where !watchedInputDeviceIDs.contains(devID) {
            watchedInputDeviceIDs.insert(devID)
            _ = AudioObjectAddPropertyListenerBlock(devID, &runningAddr, queue) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.handleInputActivityChanged()
                }
            }
        }
        wasAnyInputRunning = currentInputs.contains(where: { AudioOutputDevice.isDeviceRunningSomewhere($0) })
    }

    private func handleInputActivityChanged() {
        let inputIDs = AudioOutputDevice.listAllInputDeviceIDs()
        let anyRunning = inputIDs.contains(where: { AudioOutputDevice.isDeviceRunningSomewhere($0) })
        guard anyRunning != wasAnyInputRunning else { return }
        wasAnyInputRunning = anyRunning

        // In Party Mode, leave playback completely untouched when the Mac mic activates
        guard !ignoreMicInputAutoPause, autoPauseOnCall else { return }

        if anyRunning {
            callResumeTask?.cancel()
            callResumeTask = nil
            if isPlaying {
                pause()
                pausedByCall = true
            }
        } else if pausedByCall && autoResumeAfterCall && !isPlaying && currentTrack != nil {
            callResumeTask?.cancel()
            callResumeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled, let self else { return }
                let stillIdle = !AudioOutputDevice.listAllInputDeviceIDs().contains(where: { AudioOutputDevice.isDeviceRunningSomewhere($0) })
                if stillIdle && self.pausedByCall && self.autoPauseOnCall && self.autoResumeAfterCall && !self.isPlaying {
                    self.pausedByCall = false
                    self.resumeOrPlay()
                }
            }
        }
    }

    private func rerouteActivePlaybackToCurrentOutputDevice() {
        guard let track = currentTrack, let outgoing = player else { return }
        let wasPlaying = outgoing.isPlaying
        let resumeTime = outgoing.currentTime
        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.isMeteringEnabled = true
            newPlayer.currentDevice = resolvedOutputDeviceUID
            newPlayer.currentTime = max(0, min(resumeTime, max(0, newPlayer.duration - 0.1)))
            newPlayer.prepareToPlay()

            cancelActiveCrossfade()
            let master: Float = isMuted ? 0 : Float(volume)

            if wasPlaying {
                fadeOutAntiPop(outgoing)
                newPlayer.volume = 0
                player = newPlayer
                if newPlayer.play() {
                    newPlayer.setVolume(master, fadeDuration: Self.antiPopFadeDuration)
                    isPlaying = true
                    startTimer()
                }
            } else {
                outgoing.delegate = nil
                outgoing.stop()
                newPlayer.volume = master
                player = newPlayer
            }
        } catch {
            // Fall back to setting currentDevice in place if re-opening failed
            outgoing.currentDevice = resolvedOutputDeviceUID
        }
    }

    public func play(tracks: [Track], startingAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        let safeIdx = max(0, min(index, tracks.count - 1))
        if isQueueLocked, let handler = onLockedQueuePlayRequest {
            handler(tracks, safeIdx)
            return
        }
        playInternal(tracks: tracks, startingAt: safeIdx, respectShuffle: true)
    }

    /// Plays directly inside the locked dynamic queue (used by Party Mode host controls).
    public func playLockedQueue(tracks: [Track], startingAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        let safeIdx = max(0, min(index, tracks.count - 1))
        playInternal(tracks: tracks, startingAt: safeIdx, respectShuffle: false)
    }

    /// Dynamically synchronizes the locked playback queue (e.g. "Partymode") without interrupting the currently playing track.
    public func syncLockedQueue(tracks: [Track], autoStartIfIdle: Bool = false) {
        let previousQueue = queue
        let previousIndex = currentIndex
        let previousCurrentID = currentTrack?.id
        let hadFinishedQueue = didReachQueueEnd

        guard !tracks.isEmpty else {
            originalQueue = []
            queue = []
            currentIndex = 0
            didReachQueueEnd = false
            stop()
            return
        }

        // Case 1: Nothing loaded yet -> prime queue and optionally start playback
        guard let activeID = previousCurrentID else {
            originalQueue = tracks
            queue = tracks
            currentIndex = 0
            didReachQueueEnd = false
            if autoStartIfIdle {
                loadAndPlayCurrent()
            } else {
                currentTrack = tracks[0]
                duration = tracks[0].duration
                currentTime = 0
                updateNowPlayingInfo()
                onQueueChanged?()
            }
            return
        }

        // Case 2: Locate the currently active track in the updated dynamic playlist
        var matchedIndex: Int?
        if previousIndex >= 0 && previousIndex < tracks.count && tracks[previousIndex].id == activeID {
            matchedIndex = previousIndex
        } else if let idx = tracks.firstIndex(where: { $0.id == activeID }) {
            matchedIndex = idx
        }

        originalQueue = tracks
        queue = tracks

        if let keptIndex = matchedIndex {
            currentIndex = keptIndex
            // If playback had reached the end of the previous queue and new tracks arrived after the last track, auto-advance!
            if hadFinishedQueue && autoStartIfIdle && !isPlaying && keptIndex + 1 < tracks.count && tracks.count > previousQueue.count {
                didReachQueueEnd = false
                currentIndex = keptIndex + 1
                loadAndPlayCurrent()
            } else {
                onQueueChanged?()
            }
        } else {
            // Host removed the currently playing track from Partymode -> smoothly move to the next valid position
            let nextIdx = min(max(0, previousIndex), tracks.count - 1)
            currentIndex = nextIdx
            didReachQueueEnd = false
            if isPlaying || autoStartIfIdle {
                loadAndPlayCurrent()
            } else {
                currentTrack = tracks[nextIdx]
                duration = tracks[nextIdx].duration
                currentTime = 0
                updateNowPlayingInfo()
                onQueueChanged?()
            }
        }
    }

    private func playInternal(tracks: [Track], startingAt safeIdx: Int, respectShuffle: Bool) {
        didReachQueueEnd = false
        originalQueue = tracks
        let chosen = tracks[safeIdx]

        if respectShuffle && isShuffled {
            var rest = tracks
            rest.remove(at: safeIdx)
            rest.shuffle()
            queue = [chosen] + rest
            currentIndex = 0
        } else {
            queue = tracks
            currentIndex = safeIdx
        }

        loadAndPlayCurrent()
        onQueueChanged?()
    }

    /// Restores a previously persisted playing queue on app launch (paused at `resumeTime` so playback doesn't start unexpectedly).
    public func restoreQueue(tracks: [Track], currentIndex index: Int, resumeTime: TimeInterval = 0) {
        guard !tracks.isEmpty else { return }
        let safeIdx = max(0, min(index, tracks.count - 1))
        originalQueue = tracks
        queue = tracks
        currentIndex = safeIdx
        let track = tracks[safeIdx]
        currentTrack = track
        duration = track.duration
        let clampedResume = max(0, min(resumeTime, max(0, track.duration - 1)))
        currentTime = clampedResume
        isPlaying = false
        playbackError = nil
        resetPlaySession(for: track)

        let url = URL(fileURLWithPath: track.filePath)
        if FileManager.default.fileExists(atPath: url.path),
           let restoredPlayer = try? AVAudioPlayer(contentsOf: url) {
            restoredPlayer.delegate = self
            restoredPlayer.isMeteringEnabled = true
            restoredPlayer.currentDevice = resolvedOutputDeviceUID
            let actualDur = restoredPlayer.duration > 0 ? restoredPlayer.duration : track.duration
            duration = actualDur
            let clamped = max(0, min(resumeTime, max(0, actualDur - 0.5)))
            restoredPlayer.currentTime = clamped
            currentTime = clamped
            restoredPlayer.volume = isMuted ? 0 : Float(volume)
            restoredPlayer.prepareToPlay()
            player = restoredPlayer
        }
        updateNowPlayingInfo()
    }

    public func playSingle(_ track: Track) {
        play(tracks: [track], startingAt: 0)
    }

    public func enqueueNext(_ track: Track) {
        if isQueueLocked, let handler = onLockedQueueAppendRequest {
            handler(track, true)
            return
        }
        if queue.isEmpty {
            playSingle(track)
            return
        }
        let insertIdx = min(currentIndex + 1, queue.count)
        queue.insert(track, at: insertIdx)
        originalQueue.append(track)
        onQueueChanged?()
    }

    public func addToQueue(_ track: Track) {
        if isQueueLocked, let handler = onLockedQueueAppendRequest {
            handler(track, false)
            return
        }
        if queue.isEmpty {
            playSingle(track)
            return
        }
        queue.append(track)
        originalQueue.append(track)
        onQueueChanged?()
    }

    public func jumpToQueueIndex(_ index: Int) {
        guard index >= 0 && index < queue.count else { return }
        didReachQueueEnd = false
        currentIndex = index
        loadAndPlayCurrent()
        onQueueChanged?()
    }

    public func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        if isQueueLocked, let handler = onLockedQueueRemoveRequest {
            handler(index)
            return
        }
        if index == currentIndex {
            queue.remove(at: index)
            if queue.isEmpty {
                stop()
            } else {
                currentIndex = min(index, queue.count - 1)
                loadAndPlayCurrent()
            }
        } else {
            queue.remove(at: index)
            if index < currentIndex {
                currentIndex -= 1
            }
        }
        onQueueChanged?()
    }

    public func togglePlayPause() {
        guard let player else {
            if !queue.isEmpty { loadAndPlayCurrent() }
            return
        }
        if player.isPlaying {
            pause()
        } else {
            resumeOrPlay()
        }
    }

    public func resumeOrPlay() {
        pausedByCall = false
        callResumeTask?.cancel()
        callResumeTask = nil
        guard let player else {
            if !queue.isEmpty { loadAndPlayCurrent() }
            return
        }
        if !player.isPlaying {
            player.play()
            if isCrossfading {
                fadingOutPlayer?.play()
            }
            if isPlayingVoiceIntro {
                introPlayer?.play()
            }
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        } else if isPlayingVoiceIntro, let intro = introPlayer, !intro.isPlaying {
            intro.play()
            isPlaying = true
            startTimer()
        }
    }

    public func pause() {
        let wasActive = (player?.isPlaying == true) || (introPlayer?.isPlaying == true)
        guard wasActive else { return }
        player?.pause()
        fadingOutPlayer?.pause()
        introPlayer?.pause()
        isPlaying = false
        stopTimer()
        decayMeters()
        updateNowPlayingInfo()
        onQueueChanged?()
    }

    public func stopPlaybackKeepTrack() {
        pausedByCall = false
        callResumeTask?.cancel()
        callResumeTask = nil
        cancelActiveVoiceIntro()
        cancelActiveCrossfade()
        cancelAntiPopFade()
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
        spectrumBands = Array(repeating: 0, count: 16)
        peakHolds = Array(repeating: 0, count: 16)
        updateNowPlayingInfo()
        onQueueChanged?()
    }

    public func nextTrack() {
        guard !queue.isEmpty else { return }
        let manualFade: TimeInterval? = (crossfadeEnabled && isPlaying) ? min(1.5, crossfadeDuration) : nil
        if repeatMode == .one {
            if let fade = manualFade {
                loadAndPlayCurrent(crossfadeSeconds: fade)
            } else {
                seek(to: 0)
                resetPlaySession(for: currentTrack)
                player?.play()
                isPlaying = true
                startTimer()
            }
            return
        }
        if currentIndex + 1 < queue.count {
            didReachQueueEnd = false
            currentIndex += 1
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else if repeatMode == .all {
            didReachQueueEnd = false
            currentIndex = 0
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else {
            cancelActiveCrossfade()
            isPlaying = false
            didReachQueueEnd = true
            stopTimer()
            updateNowPlayingInfo()
            onQueueChanged?()
        }
    }

    public func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        let manualFade: TimeInterval? = (crossfadeEnabled && isPlaying) ? min(1.5, crossfadeDuration) : nil
        if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else {
            seek(to: 0)
        }
    }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    public func seek(to seconds: TimeInterval) {
        guard let player else { return }
        if isCrossfading {
            cancelActiveCrossfade()
        }
        let clamped = max(0, min(seconds, player.duration))
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingInfo()
        onQueueChanged?()
    }

    public func stop() {
        pausedByCall = false
        callResumeTask?.cancel()
        callResumeTask = nil
        cancelActiveVoiceIntro()
        cancelActiveCrossfade()
        cancelAntiPopFade()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentTrack = nil
        resetPlaySession(for: nil)
        stopTimer()
        updateNowPlayingInfo()
        onQueueChanged?()
    }

    private func resetPlaySession(for track: Track?) {
        currentSessionTrackID = track?.id
        currentSessionListenedSeconds = 0
        currentSessionRecordedPlay = false
        lastTickWallTime = nil
    }

    private func recordCurrentPlayIfNeeded(force: Bool = false) {
        guard !currentSessionRecordedPlay,
              let track = currentTrack,
              track.id == currentSessionTrackID else { return }

        let effectiveDuration = duration > 0 ? duration : track.duration
        let threshold: TimeInterval = effectiveDuration > 0
            ? min(30.0, max(5.0, effectiveDuration * 0.5))
            : 15.0

        if force || currentSessionListenedSeconds >= threshold {
            currentSessionRecordedPlay = true
            onTrackPlayed?(track)
        }
    }

    private func nextQueueIndexForAutoAdvance() -> Int? {
        guard !queue.isEmpty else { return nil }
        if repeatMode == .one {
            return currentIndex
        }
        if currentIndex + 1 < queue.count {
            return currentIndex + 1
        }
        if repeatMode == .all {
            return 0
        }
        return nil
    }

    private func applyCurrentVolumes() {
        let master: Float = isMuted ? 0 : Float(volume)
        if isPlayingVoiceIntro {
            introPlayer?.volume = master
            player?.volume = master * Self.voiceIntroDuckGain
            return
        }
        if isCrossfading, activeCrossfadeDuration > 0 {
            let progress = min(1.0, crossfadeElapsed / activeCrossfadeDuration)
            let gains = Self.equalPowerGains(progress: progress)
            fadingOutPlayer?.volume = master * Float(gains.outgoing)
            player?.volume = master * Float(gains.incoming)
        } else {
            player?.volume = master
        }
    }

    private func cancelActiveVoiceIntro() {
        introPlayer?.delegate = nil
        introPlayer?.stop()
        introPlayer = nil
        isPlayingVoiceIntro = false
        activeVoiceIntroTrackID = nil
        introTargetQueueIndex = nil
        introTargetTrackID = nil
        introHasStartedTargetTrack = false
        introOverlapTail = Self.voiceIntroOverlapSeconds
        player?.volume = isMuted ? 0 : Float(volume)
    }

    private func probeVoiceIntro(for trackID: String) -> (url: URL, duration: TimeInterval)? {
        guard let url = onVoiceIntroURLForTrack?(trackID),
              FileManager.default.fileExists(atPath: url.path) else {
            if cachedNextIntroProbe?.trackID == trackID {
                cachedNextIntroProbe = nil
            }
            return nil
        }
        if let cached = cachedNextIntroProbe,
           cached.trackID == trackID,
           cached.url == url {
            return (cached.url, cached.duration)
        }
        guard let probe = try? AVAudioPlayer(contentsOf: url), probe.duration > 0.1 else {
            return nil
        }
        let result = (url, probe.duration)
        cachedNextIntroProbe = (trackID, url, probe.duration)
        return result
    }

    private func startTargetTrackUnderActiveIntro() {
        guard isPlayingVoiceIntro, !introHasStartedTargetTrack else { return }
        introHasStartedTargetTrack = true

        // Re-resolve target index in case the queue was reordered while the intro pre-roll was playing
        let resolvedIdx: Int? = {
            if let tid = introTargetTrackID,
               let idx = queue.firstIndex(where: { $0.id == tid }) {
                return idx
            }
            if let idx = introTargetQueueIndex, idx >= 0 && idx < queue.count {
                return idx
            }
            return nil
        }()
        guard let nextIdx = resolvedIdx else { return }
        currentIndex = nextIdx
        loadAndPlayCurrent(crossfadeSeconds: nil, startDuckedForIntro: true, allowStandaloneIntro: false)
    }

    private func finishVoiceIntroAndRestoreVolume() {
        let targetMaster: Float = isMuted ? 0 : Float(volume)
        let hadStartedTarget = introHasStartedTargetTrack
        let pendingTargetIdx = introTargetQueueIndex
        let pendingTargetID = introTargetTrackID

        introPlayer?.delegate = nil
        introPlayer?.stop()
        introPlayer = nil
        isPlayingVoiceIntro = false
        activeVoiceIntroTrackID = nil
        introTargetQueueIndex = nil
        introTargetTrackID = nil
        introHasStartedTargetTrack = false
        introOverlapTail = Self.voiceIntroOverlapSeconds

        if !hadStartedTarget {
            if let tid = pendingTargetID, let idx = queue.firstIndex(where: { $0.id == tid }) {
                currentIndex = idx
                loadAndPlayCurrent(crossfadeSeconds: nil, startDuckedForIntro: false, allowStandaloneIntro: false)
            } else if let idx = pendingTargetIdx, idx >= 0 && idx < queue.count {
                currentIndex = idx
                loadAndPlayCurrent(crossfadeSeconds: nil, startDuckedForIntro: false, allowStandaloneIntro: false)
            }
        } else {
            // Smoothly ramp incoming song back up from 40% to 100%
            player?.setVolume(targetMaster, fadeDuration: 0.75)
        }
        onQueueChanged?()
    }

    /// Handles DJ voice-intro pre-roll ducking (40% on outgoing song), overlapping the last 5s over the incoming song (40%),
    /// and ramping the new song back to 100% when the intro finishes. Returns `true` if a voice intro is handling transition.
    private func stepOrTriggerVoiceIntro(currentPlayer: AVAudioPlayer?) -> Bool {
        if isPlayingVoiceIntro {
            guard let intro = introPlayer else {
                finishVoiceIntroAndRestoreVolume()
                return false
            }
            let introRem = max(0, intro.duration - intro.currentTime)
            if !introHasStartedTargetTrack {
                let outgoingRem = currentPlayer.map { max(0, $0.duration - $0.currentTime) } ?? 999
                if introRem <= introOverlapTail + 0.08 || (currentPlayer != nil && outgoingRem <= 0.45) {
                    startTargetTrackUnderActiveIntro()
                }
            }
            return true
        }

        guard let currentPlayer, !isCrossfading else { return false }
        guard let nextIdx = nextQueueIndexForAutoAdvance(), nextIdx >= 0 && nextIdx < queue.count else { return false }
        let nextTrack = queue[nextIdx]
        let triggerKey = "\(currentSessionTrackID ?? "")->\(nextTrack.id)"
        guard introTriggeredKey != triggerKey else { return false }

        guard let probed = probeVoiceIntro(for: nextTrack.id) else { return false }
        let timeline = Self.voiceIntroTimeline(introDuration: probed.duration)
        let total = currentPlayer.duration
        guard total > 1.0 else { return false }

        let remaining = max(0, total - currentPlayer.currentTime)
        let triggerWindow = max(0.65, min(total * 0.85, timeline.preRoll + 0.35))
        guard remaining <= triggerWindow && remaining > 0.05 else { return false }

        introTriggeredKey = triggerKey
        guard let newIntro = try? AVAudioPlayer(contentsOf: probed.url) else { return false }
        newIntro.delegate = self
        newIntro.currentDevice = resolvedOutputDeviceUID
        newIntro.prepareToPlay()

        let master: Float = isMuted ? 0 : Float(volume)
        // Fade outgoing song smoothly down to 40% while intro plays
        currentPlayer.setVolume(master * Self.voiceIntroDuckGain, fadeDuration: 0.45)
        newIntro.volume = master

        guard newIntro.play() else { return false }
        introPlayer = newIntro
        isPlayingVoiceIntro = true
        activeVoiceIntroTrackID = nextTrack.id
        introTargetQueueIndex = nextIdx
        introTargetTrackID = nextTrack.id
        introOverlapTail = timeline.overlap
        introHasStartedTargetTrack = false
        recordCurrentPlayIfNeeded(force: true)
        onVoiceIntroStarted?(nextTrack.id)
        onQueueChanged?()

        // Short intro (<= 5s) near end of outgoing song -> immediately transition incoming song under intro
        if timeline.preRoll <= 0.12 && remaining <= 0.65 {
            startTargetTrackUnderActiveIntro()
        }
        return true
    }

    /// Short sample-accurate fade applied on manual/non-crossfade track switches to prevent DAC click/pop artifacts.
    public static let antiPopFadeDuration: TimeInterval = 0.20

    private var antiPopFadingPlayer: AVAudioPlayer?
    private var antiPopCleanupTask: Task<Void, Never>?

    private func fadeOutAntiPop(_ outgoing: AVAudioPlayer) {
        antiPopCleanupTask?.cancel()
        antiPopFadingPlayer?.delegate = nil
        antiPopFadingPlayer?.stop()

        outgoing.delegate = nil
        antiPopFadingPlayer = outgoing
        outgoing.setVolume(0, fadeDuration: Self.antiPopFadeDuration)
        antiPopCleanupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(230))
            guard !Task.isCancelled, let self else { return }
            self.antiPopFadingPlayer?.stop()
            self.antiPopFadingPlayer = nil
        }
    }

    private func cancelAntiPopFade() {
        antiPopCleanupTask?.cancel()
        antiPopCleanupTask = nil
        antiPopFadingPlayer?.delegate = nil
        antiPopFadingPlayer?.stop()
        antiPopFadingPlayer = nil
    }

    private func cancelActiveCrossfade() {
        fadingOutPlayer?.delegate = nil
        fadingOutPlayer?.stop()
        fadingOutPlayer = nil
        isCrossfading = false
        crossfadeElapsed = 0
        activeCrossfadeDuration = 0
        player?.volume = isMuted ? 0 : Float(volume)
    }

    private func loadAndPlayCurrent(
        crossfadeSeconds: TimeInterval? = nil,
        startDuckedForIntro: Bool = false,
        allowStandaloneIntro: Bool = true
    ) {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let track = queue[currentIndex]

        if !startDuckedForIntro && isPlayingVoiceIntro {
            cancelActiveVoiceIntro()
        }

        // If starting directly on a track that has a recorded intro (e.g. first song in Partymode or manual play),
        // play the pre-roll intro first, then launch the song at 40% for the final 5 seconds of the intro!
        if allowStandaloneIntro && !startDuckedForIntro,
           let probed = probeVoiceIntro(for: track.id),
           let newIntro = try? AVAudioPlayer(contentsOf: probed.url) {
            let timeline = Self.voiceIntroTimeline(introDuration: probed.duration)
            newIntro.delegate = self
            newIntro.currentDevice = resolvedOutputDeviceUID
            let master: Float = isMuted ? 0 : Float(volume)
            newIntro.volume = master
            newIntro.prepareToPlay()

            if newIntro.play() {
                cancelActiveCrossfade()
                if let outgoing = self.player, outgoing.isPlaying {
                    if timeline.preRoll > 0.15 {
                        outgoing.setVolume(master * Self.voiceIntroDuckGain, fadeDuration: 0.40)
                    } else {
                        fadeOutAntiPop(outgoing)
                    }
                }
                introPlayer = newIntro
                isPlayingVoiceIntro = true
                activeVoiceIntroTrackID = track.id
                introTargetQueueIndex = currentIndex
                introTargetTrackID = track.id
                introOverlapTail = timeline.overlap
                introHasStartedTargetTrack = false
                introTriggeredKey = "standalone->\(track.id)"
                currentTrack = track
                playbackError = nil
                duration = track.duration
                currentTime = 0
                isPlaying = true
                onVoiceIntroStarted?(track.id)
                startTimer()
                updateNowPlayingInfo()
                onQueueChanged?()

                if timeline.preRoll <= 0.12 {
                    startTargetTrackUnderActiveIntro()
                }
                return
            }
        }

        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            cancelActiveCrossfade()
            if let outgoing = player, outgoing.isPlaying {
                fadeOutAntiPop(outgoing)
            } else {
                player?.stop()
            }
            player = nil
            currentTrack = track
            isPlaying = false
            playbackError = "File offline (source disconnected): \(track.fileName)"
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.isMeteringEnabled = true
            newPlayer.currentDevice = resolvedOutputDeviceUID
            newPlayer.prepareToPlay()

            let canCrossfade: Bool = {
                guard let fade = crossfadeSeconds, fade >= 0.4,
                      let outgoing = self.player, outgoing.isPlaying else { return false }
                return true
            }()

            let master: Float = isMuted ? 0 : Float(volume)
            var useAntiPopFadeIn = false

            if canCrossfade, let fade = crossfadeSeconds, let outgoing = self.player {
                // Stop any older lingering fade-out deck before promoting current deck to outgoing
                cancelAntiPopFade()
                fadingOutPlayer?.delegate = nil
                fadingOutPlayer?.stop()

                outgoing.delegate = nil
                fadingOutPlayer = outgoing
                crossfadeElapsed = 0
                activeCrossfadeDuration = fade
                isCrossfading = true

                newPlayer.volume = 0
                player = newPlayer
            } else {
                cancelActiveCrossfade()
                if let outgoing = self.player, outgoing.isPlaying {
                    // Quick 0.20s anti-pop fade-out on outgoing track + 0.20s fade-in on incoming track
                    fadeOutAntiPop(outgoing)
                    newPlayer.volume = 0
                    useAntiPopFadeIn = true
                } else {
                    player?.delegate = nil
                    player?.stop()
                    newPlayer.volume = 0
                    useAntiPopFadeIn = true
                }
                player = newPlayer
            }

            currentTrack = track
            playbackError = nil
            duration = newPlayer.duration > 0 ? newPlayer.duration : track.duration
            currentTime = 0
            resetPlaySession(for: track)
            if newPlayer.play() {
                isPlaying = true
                let effectiveTargetVol: Float = startDuckedForIntro ? (master * Self.voiceIntroDuckGain) : master
                if useAntiPopFadeIn {
                    let fadeInDuration: TimeInterval = (antiPopFadingPlayer != nil) ? Self.antiPopFadeDuration : 0.04
                    newPlayer.setVolume(effectiveTargetVol, fadeDuration: fadeInDuration)
                } else {
                    applyCurrentVolumes()
                }
                startTimer()
                updateNowPlayingInfo()
                onQueueChanged?()
            } else {
                cancelActiveCrossfade()
                isPlaying = false
                playbackError = "Unable to start playback for \(track.format.displayBadge)"
                updateNowPlayingInfo()
            }
        } catch {
            cancelActiveCrossfade()
            player?.stop()
            player = nil
            currentTrack = track
            isPlaying = false
            duration = track.duration
            currentTime = 0
            if track.format == .dsf || track.format == .dff || track.format == .ape || track.format == .ogg {
                playbackError = "macOS preview doesn't decode \(track.format.displayBadge) natively — it will still sync & play on FiiO."
            } else {
                playbackError = "Playback error: \(error.localizedDescription)"
            }
        }
    }

    private func triggerAutoCrossfadeIfNeeded(currentPlayer: AVAudioPlayer) {
        guard crossfadeEnabled, !isCrossfading else { return }
        guard let nextIdx = nextQueueIndexForAutoAdvance() else { return }
        let total = currentPlayer.duration
        let effectiveFade = Self.effectiveCrossfadeDuration(configured: crossfadeDuration, trackDuration: total)
        guard effectiveFade >= 0.8 else { return }

        let remaining = total - currentPlayer.currentTime
        if remaining <= effectiveFade && remaining > 0.08 {
            // Ensure outgoing track counts as played since it reached the crossfade tail
            recordCurrentPlayIfNeeded(force: true)
            let actualFade = max(0.5, min(effectiveFade, remaining))
            currentIndex = nextIdx
            loadAndPlayCurrent(crossfadeSeconds: actualFade)
        }
    }

    private func applyShuffleState() {
        guard !queue.isEmpty, let current = currentTrack else { return }
        if isShuffled {
            var rest = originalQueue.filter { $0.id != current.id }
            rest.shuffle()
            queue = [current] + rest
            currentIndex = 0
        } else {
            queue = originalQueue
            currentIndex = originalQueue.firstIndex(where: { $0.id == current.id }) ?? 0
        }
    }

    private var meterTick: Double = 0

    private func startTimer() {
        stopTimer()
        lastTickWallTime = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let activePlayer = self.player
                let introRunning = self.isPlayingVoiceIntro && (self.introPlayer?.isPlaying == true)
                guard (activePlayer?.isPlaying == true) || introRunning else { return }

                let now = Date()
                var delta: TimeInterval = 0
                if let last = self.lastTickWallTime {
                    delta = now.timeIntervalSince(last)
                    if delta > 0 && delta < 1.5 {
                        if activePlayer?.isPlaying == true {
                            self.currentSessionListenedSeconds += delta
                            self.recordCurrentPlayIfNeeded()
                        }
                    } else {
                        delta = 0
                    }
                }
                self.lastTickWallTime = now

                // Step or trigger Party Mode voice intro (takes priority over regular crossfade)
                let introActive = self.stepOrTriggerVoiceIntro(currentPlayer: activePlayer)

                // Step equal-power crossfade envelope if active
                if !introActive {
                    if self.isCrossfading && delta > 0 {
                        self.crossfadeElapsed += delta
                        if self.crossfadeElapsed >= self.activeCrossfadeDuration || self.fadingOutPlayer == nil {
                            self.cancelActiveCrossfade()
                        } else {
                            self.applyCurrentVolumes()
                        }
                    } else if let player = activePlayer, player.isPlaying {
                        self.triggerAutoCrossfadeIfNeeded(currentPlayer: player)
                    }
                }

                if let active = self.player, active.isPlaying {
                    self.currentTime = active.currentTime
                    self.sampleMeters(from: active)
                }
            }
        }
    }

    private func sampleMeters(from player: AVAudioPlayer) {
        player.updateMeters()
        let leftAvg = normalizeDecibels(player.averagePower(forChannel: 0))
        let rightAvg = player.numberOfChannels > 1 ? normalizeDecibels(player.averagePower(forChannel: 1)) : leftAvg
        let leftPeak = normalizeDecibels(player.peakPower(forChannel: 0))
        let rightPeak = player.numberOfChannels > 1 ? normalizeDecibels(player.peakPower(forChannel: 1)) : leftPeak

        let energy = (leftAvg + rightAvg) * 0.5
        let peak = max(leftPeak, rightPeak)
        meterTick += 0.35

        var nextBands = spectrumBands
        var nextPeaks = peakHolds

        for i in 0..<16 {
            let normIdx = Double(i) / 15.0
            // Classic Winamp bass-weighted curve modulated smoothly by live audio energy + channel stereo spread
            let channelMix = i < 8 ? leftAvg : rightAvg
            let wave = 0.5 + 0.5 * sin(meterTick * (1.1 + normIdx * 2.4) + Double(i) * 0.85)
            let bassBoost = 1.0 - normIdx * 0.32
            let target = min(1.0, max(0.0, (channelMix * 0.65 + peak * 0.35) * (0.45 + wave * 0.72) * bassBoost))
            let smoothed = target > nextBands[i] ? (nextBands[i] * 0.3 + target * 0.7) : (nextBands[i] * 0.78 + target * 0.22)
            nextBands[i] = energy < 0.01 ? smoothed * 0.7 : smoothed

            if nextBands[i] >= nextPeaks[i] {
                nextPeaks[i] = nextBands[i]
            } else {
                nextPeaks[i] = max(nextBands[i], nextPeaks[i] - 0.035)
            }
        }

        spectrumBands = nextBands
        peakHolds = nextPeaks
    }

    private func decayMeters() {
        spectrumBands = Array(repeating: 0, count: 16)
        peakHolds = Array(repeating: 0, count: 16)
    }

    private func normalizeDecibels(_ db: Float) -> Double {
        if db <= -55 { return 0 }
        if db >= 0 { return 1 }
        return Double((db + 55) / 55)
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        lastTickWallTime = nil
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ finishedPlayer: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(finishedPlayer)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let intro = self.introPlayer, ObjectIdentifier(intro) == finishedID {
                self.finishVoiceIntroAndRestoreVolume()
                return
            }
            // Ignore completion callbacks from stale or outgoing crossfade decks
            guard let active = self.player, ObjectIdentifier(active) == finishedID else { return }
            if flag {
                self.recordCurrentPlayIfNeeded(force: true)
            }
            if self.isPlayingVoiceIntro && !self.introHasStartedTargetTrack {
                self.startTargetTrackUnderActiveIntro()
                return
            }
            self.nextTrack()
        }
    }
}

// MARK: - Voice Intro Broadcast Vocal Chain (EQ, De-Mud, Compression, Normalization & Limiting)

public enum VoiceIntroAudioNormalizer {
    /// Target active-speech RMS (~ -13.2 dBFS) so spoken DJ intros sit clear and punchy over 40%-ducked music.
    public static let targetActiveRMS: Float = 0.22
    /// Soft-knee peak ceiling (~ -1.0 dBFS) to prevent digital clipping on plosives or loud laughs.
    public static let peakCeiling: Float = 0.891
    /// Linear knee onset below ceiling.
    private static let limiterKneeStart: Float = 0.70

    private struct BiquadFilter {
        let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
        var z1: Double = 0
        var z2: Double = 0

        mutating func process(_ samples: inout [Float]) {
            for i in samples.indices {
                let x = Double(samples[i])
                let y = b0 * x + z1
                z1 = b1 * x - a1 * y + z2
                z2 = b2 * x - a2 * y
                samples[i] = Float(y)
            }
        }

        static func highPass(frequency: Double, q: Double = 0.7071, sampleRate: Double) -> BiquadFilter {
            let w0 = 2.0 * Double.pi * frequency / sampleRate
            let cosW0 = cos(w0)
            let alpha = sin(w0) / (2.0 * q)
            let a0 = 1.0 + alpha
            return BiquadFilter(
                b0: ((1.0 + cosW0) * 0.5) / a0,
                b1: -(1.0 + cosW0) / a0,
                b2: ((1.0 + cosW0) * 0.5) / a0,
                a1: (-2.0 * cosW0) / a0,
                a2: (1.0 - alpha) / a0
            )
        }

        static func peakingEQ(frequency: Double, gainDB: Double, q: Double, sampleRate: Double) -> BiquadFilter {
            let a = pow(10.0, gainDB / 40.0)
            let w0 = 2.0 * Double.pi * frequency / sampleRate
            let cosW0 = cos(w0)
            let alpha = sin(w0) / (2.0 * q)
            let a0 = 1.0 + alpha / a
            return BiquadFilter(
                b0: (1.0 + alpha * a) / a0,
                b1: (-2.0 * cosW0) / a0,
                b2: (1.0 - alpha * a) / a0,
                a1: (-2.0 * cosW0) / a0,
                a2: (1.0 - alpha / a) / a0
            )
        }

        static func highShelf(frequency: Double, gainDB: Double, slope: Double = 0.8, sampleRate: Double) -> BiquadFilter {
            let a = pow(10.0, gainDB / 40.0)
            let w0 = 2.0 * Double.pi * frequency / sampleRate
            let cosW0 = cos(w0)
            let sinW0 = sin(w0)
            let alpha = (sinW0 / 2.0) * sqrt((a + 1.0 / a) * (1.0 / slope - 1.0) + 2.0)
            let twoSqrtAAlpha = 2.0 * sqrt(a) * alpha
            let a0 = (a + 1.0) - (a - 1.0) * cosW0 + twoSqrtAAlpha
            return BiquadFilter(
                b0: (a * ((a + 1.0) + (a - 1.0) * cosW0 + twoSqrtAAlpha)) / a0,
                b1: (-2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0)) / a0,
                b2: (a * ((a + 1.0) + (a - 1.0) * cosW0 - twoSqrtAAlpha)) / a0,
                a1: (2.0 * ((a - 1.0) - (a + 1.0) * cosW0)) / a0,
                a2: ((a + 1.0) - (a - 1.0) * cosW0 - twoSqrtAAlpha) / a0
            )
        }
    }

    /// Processes a mono Float32 voice recording through a studio/radio DJ broadcast chain:
    /// 1) DC offset removal + 2nd-order 95 Hz Butterworth high-pass (rumble & mic bump cleanup)
    /// 2) 3-band broadcast vocal EQ (-2.2 dB @ 280 Hz de-mud, +3.0 dB @ 3.2 kHz presence, +1.8 dB @ 7.5 kHz air)
    /// 3) Pre-leveling into an adaptive soft noise-floor softener + 3.2:1 radio vocal compressor
    /// 4) Final active-speech gated RMS loudness normalization (-13.2 dBFS)
    /// 5) Soft-knee peak limiter (-1.0 dBFS ceiling) + 15 ms / 25 ms anti-click edge fades
    @discardableResult
    public static func normalizeSamples(_ samples: inout [Float], sampleRate: Double) -> Float {
        guard !samples.isEmpty else { return 1.0 }
        let sr = max(8_000.0, sampleRate)
        let nyquist = sr * 0.5

        // 1. Remove DC offset
        var mean: Double = 0
        for s in samples { mean += Double(s) }
        mean /= Double(samples.count)
        let meanF = Float(mean)
        for i in samples.indices { samples[i] -= meanF }

        // 2. 2nd-order Butterworth 95 Hz high-pass filter (removes mic bumps, wind & sub-bass rumble)
        var hpf = BiquadFilter.highPass(frequency: min(95.0, nyquist * 0.4), q: 0.7071, sampleRate: sr)
        hpf.process(&samples)

        // Bail early on dead silence (< -60 dBFS) so silent recordings never turn into amplified hiss
        let initialRMS = activeSpeechRMS(samples, sampleRate: sr)
        guard initialRMS >= 0.001 else {
            return 1.0
        }

        // 3. Radio DJ 3-band vocal EQ (de-mud + clarity presence + studio air)
        if nyquist > 600 {
            var deMud = BiquadFilter.peakingEQ(frequency: 280.0, gainDB: -2.2, q: 1.1, sampleRate: sr)
            deMud.process(&samples)
        }
        if nyquist > 4_000 {
            var presence = BiquadFilter.peakingEQ(frequency: 3_200.0, gainDB: 3.0, q: 1.0, sampleRate: sr)
            presence.process(&samples)
        }
        if nyquist > 9_000 {
            var air = BiquadFilter.highShelf(frequency: 7_500.0, gainDB: 1.8, slope: 0.8, sampleRate: sr)
            air.process(&samples)
        }

        // 4. Pre-level into the dynamics stage so gate & compressor thresholds track consistently across quiet/loud mics
        let postEQRMS = activeSpeechRMS(samples, sampleRate: sr)
        guard postEQRMS >= 0.0008 else { return 1.0 }
        let preGain = min(16.0, max(0.25, targetActiveRMS / postEQRMS))
        for i in samples.indices {
            samples[i] *= preGain
        }

        // 5. Smooth soft noise-floor softener (-10 dB gentle downward expansion below -40 dBFS)
        //    + Broadcast vocal compressor (3.2:1 ratio above -18 dBFS, 6 ms attack / 110 ms release)
        let envAttack = Float(exp(-1.0 / (sr * 0.006)))
        let envRelease = Float(exp(-1.0 / (sr * 0.110)))
        let gateAttack = Float(exp(-1.0 / (sr * 0.008)))
        let gateRelease = Float(exp(-1.0 / (sr * 0.120)))

        let compThresholdDB: Float = -18.0
        let compRatio: Float = 3.2
        let compKneeDB: Float = 6.0
        let gateThreshold: Float = 0.010 // ~ -40 dBFS after pre-leveling
        let gateFloorGain: Float = 0.316 // -10 dB gentle reduction (natural room feel, no choppy cutoff)

        var env: Float = 0
        var gateGain: Float = 1.0
        for i in samples.indices {
            let x = samples[i]
            let mag = abs(x)
            let coeff = mag > env ? envAttack : envRelease
            env = coeff * env + (1.0 - coeff) * mag

            // Soft downward expander for pauses between words
            let targetGate: Float
            if env >= gateThreshold {
                targetGate = 1.0
            } else {
                let ratio = max(0, env / gateThreshold)
                targetGate = gateFloorGain + (1.0 - gateFloorGain) * (ratio * ratio)
            }
            let gCoeff = targetGate > gateGain ? gateAttack : gateRelease
            gateGain = gCoeff * gateGain + (1.0 - gCoeff) * targetGate

            // Soft-knee RMS/envelope compressor
            let envDB: Float = 20.0 * log10(max(env, 1e-6))
            let overshoot = envDB - compThresholdDB
            let reductionDB: Float
            if overshoot <= -compKneeDB * 0.5 {
                reductionDB = 0
            } else if overshoot >= compKneeDB * 0.5 {
                reductionDB = overshoot * (1.0 - 1.0 / compRatio)
            } else {
                let k = overshoot + compKneeDB * 0.5
                reductionDB = (1.0 - 1.0 / compRatio) * (k * k) / (2.0 * compKneeDB)
            }
            let compGain = pow(10.0, -reductionDB / 20.0)
            samples[i] = x * gateGain * compGain
        }

        // 6. Final active-speech loudness makeup to -13.2 dBFS
        let postCompRMS = activeSpeechRMS(samples, sampleRate: sr)
        let makeupGain: Float = postCompRMS >= 0.001
            ? min(4.0, max(0.4, targetActiveRMS / postCompRMS))
            : 1.0

        // 7. Apply makeup gain + soft-knee peak limiter (ceiling -1.0 dBFS)
        let kneeSpan = peakCeiling - limiterKneeStart
        for i in samples.indices {
            let v = samples[i] * makeupGain
            let mag = abs(v)
            if mag <= limiterKneeStart {
                samples[i] = v
            } else {
                let excess = (mag - limiterKneeStart) / kneeSpan
                let limited = limiterKneeStart + kneeSpan * tanh(excess)
                samples[i] = v >= 0 ? limited : -limited
            }
        }

        // 8. Short anti-click fade-in (15 ms) and fade-out (25 ms)
        let fadeInSamples = min(samples.count / 4, Int(sr * 0.015))
        if fadeInSamples > 1 {
            for i in 0..<fadeInSamples {
                samples[i] *= Float(i) / Float(fadeInSamples)
            }
        }
        let fadeOutSamples = min(samples.count / 4, Int(sr * 0.025))
        if fadeOutSamples > 1 {
            let start = samples.count - fadeOutSamples
            for i in 0..<fadeOutSamples {
                samples[start + i] *= Float(fadeOutSamples - 1 - i) / Float(fadeOutSamples)
            }
        }

        return preGain * makeupGain
    }

    private static func activeSpeechRMS(_ samples: [Float], sampleRate: Double) -> Float {
        let frameSize = max(128, Int(sampleRate * 0.05))
        let silenceGate: Float = 0.0056 // ~ -45 dBFS
        var activeFrameRMS: [Float] = []
        var overallSqSum: Double = 0

        var idx = 0
        while idx < samples.count {
            let end = min(samples.count, idx + frameSize)
            var sq: Double = 0
            for j in idx..<end {
                let v = Double(samples[j])
                sq += v * v
            }
            overallSqSum += sq
            let rms = Float(sqrt(sq / Double(max(1, end - idx))))
            if rms >= silenceGate {
                activeFrameRMS.append(rms)
            }
            idx = end
        }

        if !activeFrameRMS.isEmpty {
            activeFrameRMS.sort()
            let p75Index = min(activeFrameRMS.count - 1, Int(Double(activeFrameRMS.count - 1) * 0.75))
            return activeFrameRMS[p75Index]
        }
        return Float(sqrt(overallSqSum / Double(max(1, samples.count))))
    }

    /// Reads any AVAudioFile-supported intro recording, mixes to normalized mono 16-bit PCM WAV, and returns duration.
    public static func normalizeAudioFile(inputURL: URL, outputURL: URL) throws -> TimeInterval {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 22_050
        let totalFrames = AVAudioFrameCount(min(inputFile.length, AVAudioFramePosition(sampleRate * 70.0)))
        guard totalFrames > 0,
              let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw NSError(domain: "VoiceIntroAudioNormalizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty audio file"])
        }
        try inputFile.read(into: readBuffer, frameCount: totalFrames)
        let frameCount = Int(readBuffer.frameLength)
        let channelCount = Int(format.channelCount)
        guard frameCount > 0, channelCount > 0, let floatData = readBuffer.floatChannelData else {
            throw NSError(domain: "VoiceIntroAudioNormalizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported PCM buffer"])
        }

        // Mix down to mono Float32 for consistent centered DJ voice playback
        var mono = [Float](repeating: 0, count: frameCount)
        if channelCount == 1 {
            let ch0 = floatData[0]
            for i in 0..<frameCount { mono[i] = ch0[i] }
        } else {
            let scale = 1.0 / Float(channelCount)
            for ch in 0..<channelCount {
                let ptr = floatData[ch]
                for i in 0..<frameCount { mono[i] += ptr[i] * scale }
            }
        }

        normalizeSamples(&mono, sampleRate: sampleRate)

        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ), let outBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let outPtr = outBuffer.floatChannelData?[0] else {
            throw NSError(domain: "VoiceIntroAudioNormalizer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not allocate output buffer"])
        }
        outBuffer.frameLength = AVAudioFrameCount(frameCount)
        for i in 0..<frameCount { outPtr[i] = mono[i] }

        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: wavSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outputFile.write(from: outBuffer)
        return Double(frameCount) / sampleRate
    }
}
