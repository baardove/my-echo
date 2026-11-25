import Foundation
import AVFoundation
import Observation

public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off
    case all
    case one
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

    public var onSettingsChanged: (() -> Void)?
    /// Fired once per playback session when a track reaches its play threshold (min(30s, 50% duration)) or completes.
    public var onTrackPlayed: ((Track) -> Void)?

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
    }

    public func play(tracks: [Track], startingAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        let safeIdx = max(0, min(index, tracks.count - 1))
        originalQueue = tracks
        let chosen = tracks[safeIdx]

        if isShuffled {
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
    }

    public func playSingle(_ track: Track) {
        play(tracks: [track], startingAt: 0)
    }

    public func enqueueNext(_ track: Track) {
        if queue.isEmpty {
            playSingle(track)
            return
        }
        let insertIdx = min(currentIndex + 1, queue.count)
        queue.insert(track, at: insertIdx)
        originalQueue.append(track)
    }

    public func addToQueue(_ track: Track) {
        if queue.isEmpty {
            playSingle(track)
            return
        }
        queue.append(track)
        originalQueue.append(track)
    }

    public func jumpToQueueIndex(_ index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        loadAndPlayCurrent()
    }

    public func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
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
        guard let player else {
            if !queue.isEmpty { loadAndPlayCurrent() }
            return
        }
        if !player.isPlaying {
            player.play()
            if isCrossfading {
                fadingOutPlayer?.play()
            }
            isPlaying = true
            startTimer()
        }
    }

    public func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        fadingOutPlayer?.pause()
        isPlaying = false
        stopTimer()
        decayMeters()
    }

    public func stopPlaybackKeepTrack() {
        cancelActiveCrossfade()
        cancelAntiPopFade()
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
        spectrumBands = Array(repeating: 0, count: 16)
        peakHolds = Array(repeating: 0, count: 16)
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
            currentIndex += 1
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else {
            cancelActiveCrossfade()
            isPlaying = false
            stopTimer()
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
    }

    public func stop() {
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
        if isCrossfading, activeCrossfadeDuration > 0 {
            let progress = min(1.0, crossfadeElapsed / activeCrossfadeDuration)
            let gains = Self.equalPowerGains(progress: progress)
            fadingOutPlayer?.volume = master * Float(gains.outgoing)
            player?.volume = master * Float(gains.incoming)
        } else {
            player?.volume = master
        }
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

    private func loadAndPlayCurrent(crossfadeSeconds: TimeInterval? = nil) {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let track = queue[currentIndex]

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
                if useAntiPopFadeIn {
                    let fadeInDuration: TimeInterval = (antiPopFadingPlayer != nil) ? Self.antiPopFadeDuration : 0.04
                    newPlayer.setVolume(master, fadeDuration: fadeInDuration)
                } else {
                    applyCurrentVolumes()
                }
                startTimer()
            } else {
                cancelActiveCrossfade()
                isPlaying = false
                playbackError = "Unable to start playback for \(track.format.displayBadge)"
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
                guard let self, let player = self.player, player.isPlaying else { return }
                let now = Date()
                var delta: TimeInterval = 0
                if let last = self.lastTickWallTime {
                    delta = now.timeIntervalSince(last)
                    if delta > 0 && delta < 1.5 {
                        self.currentSessionListenedSeconds += delta
                        self.recordCurrentPlayIfNeeded()
                    } else {
                        delta = 0
                    }
                }
                self.lastTickWallTime = now

                // Step equal-power crossfade envelope if active
                if self.isCrossfading && delta > 0 {
                    self.crossfadeElapsed += delta
                    if self.crossfadeElapsed >= self.activeCrossfadeDuration || self.fadingOutPlayer == nil {
                        self.cancelActiveCrossfade()
                    } else {
                        self.applyCurrentVolumes()
                    }
                } else {
                    self.triggerAutoCrossfadeIfNeeded(currentPlayer: player)
                }

                if let active = self.player {
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
            // Ignore completion callbacks from stale or outgoing crossfade decks
            guard let active = self.player, ObjectIdentifier(active) == finishedID else { return }
            if flag {
                self.recordCurrentPlayIfNeeded(force: true)
            }
            self.nextTrack()
        }
    }
}
