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

    public var volume: Double = 0.85 {
        didSet {
            let clamped = max(0, min(1, volume))
            if clamped != volume { volume = clamped; return }
            player?.volume = isMuted ? 0 : Float(clamped)
            onSettingsChanged?()
        }
    }

    public var isMuted: Bool = false {
        didSet {
            player?.volume = isMuted ? 0 : Float(volume)
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

    public var onSettingsChanged: (() -> Void)?

    private var originalQueue: [Track] = []
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

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
            isPlaying = true
            startTimer()
        }
    }

    public func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        isPlaying = false
        stopTimer()
        decayMeters()
    }

    public func stopPlaybackKeepTrack() {
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
        if repeatMode == .one {
            seek(to: 0)
            player?.play()
            isPlaying = true
            startTimer()
            return
        }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadAndPlayCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent()
        } else {
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
        if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlayCurrent()
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
            loadAndPlayCurrent()
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
        let clamped = max(0, min(seconds, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentTrack = nil
        stopTimer()
    }

    private func loadAndPlayCurrent() {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let track = queue[currentIndex]
        currentTrack = track
        playbackError = nil

        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            isPlaying = false
            playbackError = "File offline (source disconnected): \(track.fileName)"
            return
        }

        do {
            player?.stop()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.isMeteringEnabled = true
            newPlayer.volume = isMuted ? 0 : Float(volume)
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration > 0 ? newPlayer.duration : track.duration
            currentTime = 0
            if newPlayer.play() {
                isPlaying = true
                startTimer()
            } else {
                isPlaying = false
                playbackError = "Unable to start playback for \(track.format.displayBadge)"
            }
        } catch {
            player = nil
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
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, player.isPlaying else { return }
                self.currentTime = player.currentTime
                self.sampleMeters(from: player)
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
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.nextTrack()
        }
    }
}
