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
    private(set) var hasCurrentItem: Bool = false
    private(set) var currentItem: TVPlayableItem?
    private(set) var queue: [TVPlayableItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isCustomQueue: Bool = false
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var playbackError: String?

    var isShuffled: Bool = UserDefaults.standard.bool(forKey: "tv.player.isShuffled") {
        didSet {
            UserDefaults.standard.set(isShuffled, forKey: "tv.player.isShuffled")
            applyShuffleState()
        }
    }
    var repeatMode: TVRepeatMode = TVRepeatMode(rawValue: UserDefaults.standard.string(forKey: "tv.player.repeatMode") ?? "") ?? .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "tv.player.repeatMode")
        }
    }
    var onNavidromeStreamPlayed: ((String) -> Void)?

    private var originalQueue: [TVPlayableItem] = []
    private let avPlayer: AVPlayer = {
        let p = AVPlayer()
        p.automaticallyWaitsToMinimizeStalling = true
        return p
    }()
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var timer: Timer?
    private var scrobbledCurrentStream: Bool = false

    // Live synced Party Mode audio stream (for TV / Both output modes & standalone Echo Server Party renderer)
    private var partyPlayer: AVPlayer?
    private var partyIntroPlayer: AVPlayer?
    private var partyEndObserver: NSObjectProtocol?
    private var partyIntroEndObserver: NSObjectProtocol?
    private var partyTrackID: String?
    private var playedIntroTrackIDs: Set<String> = []
    private(set) var isPartyStreamActive: Bool = false
    private(set) var isPlayingPartyVoiceIntro: Bool = false
    var onPartyTrackEnded: ((String) -> Void)?

    var partyPlaybackCurrentTime: TimeInterval {
        let s = partyPlayer?.currentTime().seconds ?? 0
        return (s.isFinite && s >= 0) ? s : 0
    }

    var partyPlaybackIsPlaying: Bool {
        guard let p = partyPlayer else { return false }
        return p.rate > 0 || p.timeControlStatus == .playing || p.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

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
        stopPartyStream()
        if isCustomQueue { isCustomQueue = false }
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
        stopPartyStream()
        if queue.isEmpty || currentItem == nil {
            originalQueue = [item]
            queue = [item]
            currentIndex = 0
            if !isCustomQueue { isCustomQueue = true }
            loadAndPlayCurrent()
        } else if !isCustomQueue {
            let current = currentItem ?? queue[min(currentIndex, queue.count - 1)]
            let newQueue = [current, item]
            originalQueue = newQueue
            queue = newQueue
            if currentIndex != 0 { currentIndex = 0 }
            isCustomQueue = true
        } else {
            queue.append(item)
            originalQueue.append(item)
        }
    }

    func enqueueAll(_ items: [TVPlayableItem]) {
        guard !items.isEmpty else { return }
        for item in items {
            enqueue(item)
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func resume() {
        if avPlayer.currentItem != nil {
            avPlayer.play()
            if !isPlaying { isPlaying = true }
            startTimer()
            updateNowPlayingInfo()
        } else if !queue.isEmpty {
            loadAndPlayCurrent()
        }
    }

    func pause() {
        avPlayer.pause()
        if isPlaying { isPlaying = false }
        stopTimer()
        updateNowPlayingInfo()
    }

    func stop() {
        cleanupPlayer(clearItem: true)
        if isPlaying { isPlaying = false }
        if isBuffering { isBuffering = false }
        if currentItem != nil { currentItem = nil }
        if hasCurrentItem { hasCurrentItem = false }
        if currentTime != 0 { currentTime = 0 }
        if duration != 0 { duration = 0 }
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
        if currentIndex != index {
            currentIndex = index
        }
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
        avPlayer.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        if currentTime != clamped {
            currentTime = clamped
        }
        updateNowPlayingInfo()
    }

    // MARK: - Synced Party Mode Live Stream & Authoritative Standalone Renderer (TV / Both Output)

    func syncPartyStream(
        url: URL?,
        trackID: String?,
        isPlaying: Bool,
        targetTime: TimeInterval,
        voiceIntroURL: URL? = nil,
        isAuthoritativeRenderer: Bool = false
    ) {
        guard let url, let trackID, !trackID.isEmpty else {
            stopPartyStream()
            return
        }

        // Pause standalone Apple TV music queue so it never overlaps Party audio
        if self.isPlaying {
            pause()
        }

        if partyTrackID != trackID || partyPlayer == nil {
            if let obs = partyEndObserver {
                NotificationCenter.default.removeObserver(obs)
                partyEndObserver = nil
            }
            stopPartyVoiceIntro()
            partyPlayer?.pause()

            let item = AVPlayerItem(url: url)
            let p = AVPlayer(playerItem: item)
            p.automaticallyWaitsToMinimizeStalling = true
            partyPlayer = p
            partyTrackID = trackID
            isPartyStreamActive = true

            partyEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onPartyTrackEnded?(trackID)
                }
            }

            if targetTime > 0.5 && !isAuthoritativeRenderer {
                p.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
            if isPlaying {
                if let voiceIntroURL, !playedIntroTrackIDs.contains(trackID) {
                    playedIntroTrackIDs.insert(trackID)
                    playPartyVoiceIntro(url: voiceIntroURL, musicPlayer: p)
                } else {
                    p.volume = 1.0
                }
                p.play()
            } else {
                p.pause()
            }
            return
        }

        guard let p = partyPlayer else { return }
        isPartyStreamActive = true
        if isPlaying {
            if p.timeControlStatus != .playing && p.timeControlStatus != .waitingToPlayAtSpecifiedRate {
                p.play()
            }
            if !isAuthoritativeRenderer {
                let curSecs = p.currentTime().seconds
                if curSecs.isFinite && abs(curSecs - targetTime) > 1.8 {
                    p.seek(to: CMTime(seconds: max(0, targetTime), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
        } else {
            p.pause()
            partyIntroPlayer?.pause()
        }
    }

    private func playPartyVoiceIntro(url: URL, musicPlayer: AVPlayer) {
        stopPartyVoiceIntro()
        // Duck incoming song to 40% while DJ voice intro plays over the start (matching macOS AudioPlayerEngine)
        musicPlayer.volume = 0.40
        let introItem = AVPlayerItem(url: url)
        let ip = AVPlayer(playerItem: introItem)
        ip.volume = 1.0
        partyIntroPlayer = ip
        isPlayingPartyVoiceIntro = true
        partyIntroEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: introItem,
            queue: .main
        ) { [weak self, weak musicPlayer] _ in
            Task { @MainActor [weak self, weak musicPlayer] in
                musicPlayer?.volume = 1.0
                self?.stopPartyVoiceIntro()
            }
        }
        ip.play()
    }

    private func stopPartyVoiceIntro() {
        if let obs = partyIntroEndObserver {
            NotificationCenter.default.removeObserver(obs)
            partyIntroEndObserver = nil
        }
        partyIntroPlayer?.pause()
        partyIntroPlayer = nil
        isPlayingPartyVoiceIntro = false
        partyPlayer?.volume = 1.0
    }

    func stopPartyStream() {
        if let obs = partyEndObserver {
            NotificationCenter.default.removeObserver(obs)
            partyEndObserver = nil
        }
        stopPartyVoiceIntro()
        partyPlayer?.pause()
        partyPlayer = nil
        partyTrackID = nil
        isPartyStreamActive = false
    }

    // MARK: - Internals

    private func loadAndPlayCurrent() {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        if playbackError != nil { playbackError = nil }
        scrobbledCurrentStream = false
        cleanupPlayer(clearItem: false)

        let streamURL: URL
        switch item.source {
        case .macStream(_, let u), .navidromeStream(_, let u), .podcastStream(_, let u):
            streamURL = u
        }

        let playerItem = AVPlayerItem(url: streamURL)

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
                guard let self else { return }
                self.playbackError = errText
                if self.isPlaying { self.isPlaying = false }
                if self.isBuffering { self.isBuffering = false }
            }
        }

        avPlayer.replaceCurrentItem(with: playerItem)
        if !hasCurrentItem { hasCurrentItem = true }
        if currentItem != item { currentItem = item }
        if duration != item.duration { duration = item.duration }
        if currentTime != 0 { currentTime = 0 }
        if !isBuffering { isBuffering = true }
        if !isPlaying { isPlaying = true }
        avPlayer.play()
        startTimer()
        updateNowPlayingInfo()
    }

    private func cleanupPlayer(clearItem: Bool = false) {
        stopTimer()
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        if let obs = failObserver {
            NotificationCenter.default.removeObserver(obs)
            failObserver = nil
        }
        if clearItem {
            avPlayer.pause()
            avPlayer.replaceCurrentItem(with: nil)
        }
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
        guard avPlayer.currentItem != nil else { return }
        let secs = avPlayer.currentTime().seconds
        if secs.isFinite && secs >= 0 && abs(currentTime - secs) >= 0.05 {
            currentTime = secs
        }
        if let itemDur = avPlayer.currentItem?.duration.seconds,
           itemDur.isFinite && itemDur > 0 && abs(duration - itemDur) >= 0.1 {
            duration = itemDur
        }
        let buffering = (avPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate)
        if isBuffering != buffering {
            isBuffering = buffering
        }
        if let itemErr = avPlayer.currentItem?.error {
            let msg = itemErr.localizedDescription
            if playbackError != msg { playbackError = msg }
            if isPlaying { isPlaying = false }
            if isBuffering { isBuffering = false }
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
