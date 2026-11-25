import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Observation

enum TVRepeatMode: String, CaseIterable {
    case off, all, one
}

@MainActor
@Observable
final class TVAudioPlayer: NSObject {
    private(set) var currentItem: TVPlayableItem?
    private(set) var queue: [TVPlayableItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var playbackError: String?

    var isShuffled: Bool = false {
        didSet { applyShuffleState() }
    }
    var repeatMode: TVRepeatMode = .off
    var onNavidromeStreamPlayed: ((String) -> Void)?

    private var originalQueue: [TVPlayableItem] = []
    private var avPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var timer: Timer?
    private var scrobbledCurrentStream: Bool = false

    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
    }

    nonisolated private func configureAudioSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                let msg = error.localizedDescription
                Task { @MainActor [weak self] in
                    self?.playbackError = "Audio session error: \(msg)"
                }
            }
        }
    }

    nonisolated private func configureRemoteCommands() {
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        rc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        rc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextTrack() }
            return .success
        }
        rc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previousTrack() }
            return .success
        }
        rc.skipForwardCommand.preferredIntervals = [15]
        rc.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skip(by: 15) }
            return .success
        }
        rc.skipBackwardCommand.preferredIntervals = [15]
        rc.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skip(by: -15) }
            return .success
        }
    }

    func play(items: [TVPlayableItem], startingAt index: Int = 0) {
        guard !items.isEmpty else { return }
        let safeIdx = max(0, min(index, items.count - 1))
        originalQueue = items
        let chosen = items[safeIdx]
        if isShuffled {
            var rest = items
            rest.remove(at: safeIdx)
            rest.shuffle()
            queue = [chosen] + rest
            currentIndex = 0
        } else {
            queue = items
            currentIndex = safeIdx
        }
        loadAndPlayCurrent()
    }

    func enqueue(_ item: TVPlayableItem) {
        if queue.isEmpty {
            play(items: [item], startingAt: 0)
        } else {
            queue.append(item)
            originalQueue.append(item)
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func resume() {
        if let avPlayer {
            avPlayer.play()
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        } else if !queue.isEmpty {
            loadAndPlayCurrent()
        }
    }

    func pause() {
        avPlayer?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }

    func stop() {
        cleanupPlayer()
        isPlaying = false
        isBuffering = false
        currentItem = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }
        if repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadAndPlayCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent()
        } else {
            pause()
        }
    }

    func previousTrack() {
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

    func jumpToQueueIndex(_ index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        loadAndPlayCurrent()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func skip(by delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(seconds, max(duration, 1)))
        avPlayer?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        updateNowPlayingInfo()
    }

    // MARK: - Internals

    private func loadAndPlayCurrent() {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        playbackError = nil
        scrobbledCurrentStream = false
        cleanupPlayer()

        let streamURL: URL
        switch item.source {
        case .macStream(_, let u), .navidromeStream(_, let u), .podcastStream(_, let u):
            streamURL = u
        }

        let playerItem = AVPlayerItem(url: streamURL)
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        avPlayer = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextTrack() }
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] note in
            let errText = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "Stream interrupted"
            Task { @MainActor [weak self] in
                self?.playbackError = errText
                self?.isPlaying = false
                self?.isBuffering = false
            }
        }

        currentItem = item
        duration = item.duration
        currentTime = 0
        isBuffering = true
        isPlaying = true
        player.play()
        startTimer()
        updateNowPlayingInfo()
    }

    private func cleanupPlayer() {
        stopTimer()
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        if let obs = failObserver {
            NotificationCenter.default.removeObserver(obs)
            failObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
    }

    private func applyShuffleState() {
        guard !queue.isEmpty, let current = currentItem else { return }
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

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let avPlayer else { return }
        let secs = avPlayer.currentTime().seconds
        if secs.isFinite && secs >= 0 {
            currentTime = secs
        }
        if let itemDur = avPlayer.currentItem?.duration.seconds, itemDur.isFinite && itemDur > 0 {
            duration = itemDur
        }
        isBuffering = (avPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate)
        if let itemErr = avPlayer.currentItem?.error {
            playbackError = itemErr.localizedDescription
            isPlaying = false
            isBuffering = false
        }

        if !scrobbledCurrentStream,
           let cur = currentItem,
           case .navidromeStream(let songID, _) = cur.source,
           currentTime >= min(30, max(10, duration * 0.5)) {
            scrobbledCurrentStream = true
            onNavidromeStreamPlayed?(songID)
        }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPMediaItemPropertyAlbumTitle: item.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
