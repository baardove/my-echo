import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Observation

enum iOSRepeatMode: String, CaseIterable {
    case off, all, one
}

@MainActor
@Observable
final class iOSAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var currentItem: PlayableItem?
    private(set) var queue: [PlayableItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isCrossfading: Bool = false
    private(set) var playbackError: String?

    var isShuffled: Bool = false {
        didSet { applyShuffleState() }
    }
    var repeatMode: iOSRepeatMode = .off
    var crossfadeEnabled: Bool = true
    var crossfadeDuration: TimeInterval = 4.0

    var onNavidromeStreamPlayed: ((String) -> Void)?

    private var originalQueue: [PlayableItem] = []
    private var localPlayer: AVAudioPlayer?
    private var fadingOutLocalPlayer: AVAudioPlayer?
    private var crossfadeElapsed: TimeInterval = 0
    private var activeCrossfadeDuration: TimeInterval = 0

    private var streamPlayer: AVPlayer?
    private var streamEndObserver: NSObjectProtocol?

    private var timer: Timer?
    private var lastTickDate: Date?
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
        rc.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                let pos = posEvent.positionTime
                Task { @MainActor [weak self] in self?.seek(to: pos) }
                return .success
            }
            return .commandFailed
        }
    }

    // MARK: - Playback Controls

    func play(items: [PlayableItem], startingAt index: Int = 0) {
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

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        if let localPlayer {
            localPlayer.play()
            if isCrossfading { fadingOutLocalPlayer?.play() }
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        } else if let streamPlayer {
            streamPlayer.play()
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        } else if !queue.isEmpty {
            loadAndPlayCurrent()
        }
    }

    func pause() {
        antiPopCleanupTask?.cancel()
        antiPopCleanupTask = nil
        antiPopFadingPlayer?.delegate = nil
        antiPopFadingPlayer?.stop()
        antiPopFadingPlayer = nil
        localPlayer?.pause()
        fadingOutLocalPlayer?.pause()
        streamPlayer?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }
        let manualFade: TimeInterval? = (crossfadeEnabled && isPlaying) ? min(1.5, crossfadeDuration) : nil
        if repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent(crossfadeSeconds: manualFade)
        } else {
            cancelCrossfade()
            pause()
        }
    }

    func previousTrack() {
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

    func seek(to seconds: TimeInterval) {
        cancelCrossfade()
        let clamped = max(0, min(seconds, max(duration, 1)))
        if let localPlayer {
            localPlayer.currentTime = clamped
        } else if let streamPlayer {
            streamPlayer.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        }
        currentTime = clamped
        updateNowPlayingInfo()
    }

    // MARK: - Core Loader (Offline File or Navidrome Stream)

    private static let antiPopFadeDuration: TimeInterval = 0.20
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

    private func loadAndPlayCurrent(crossfadeSeconds: TimeInterval? = nil) {
        guard currentIndex >= 0 && currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        playbackError = nil
        scrobbledCurrentStream = false
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        switch item.source {
        case .localFile(let fileURL):
            stopStreamPlayer()
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: fileURL)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()

                var useAntiPopFadeIn = false
                if let fade = crossfadeSeconds, fade >= 0.4, let outgoing = localPlayer, outgoing.isPlaying {
                    antiPopCleanupTask?.cancel()
                    antiPopFadingPlayer?.stop()
                    antiPopFadingPlayer = nil
                    fadingOutLocalPlayer?.delegate = nil
                    fadingOutLocalPlayer?.stop()
                    outgoing.delegate = nil
                    fadingOutLocalPlayer = outgoing
                    crossfadeElapsed = 0
                    activeCrossfadeDuration = fade
                    isCrossfading = true
                    newPlayer.volume = 0
                } else {
                    cancelCrossfade()
                    if let outgoing = localPlayer, outgoing.isPlaying {
                        fadeOutAntiPop(outgoing)
                    } else {
                        localPlayer?.delegate = nil
                        localPlayer?.stop()
                    }
                    newPlayer.volume = 0
                    useAntiPopFadeIn = true
                }

                localPlayer = newPlayer
                currentItem = item
                duration = newPlayer.duration > 0 ? newPlayer.duration : item.duration
                currentTime = 0
                newPlayer.play()
                if useAntiPopFadeIn {
                    let fadeIn: TimeInterval = (antiPopFadingPlayer != nil) ? Self.antiPopFadeDuration : 0.04
                    newPlayer.setVolume(1.0, fadeDuration: fadeIn)
                }
                isPlaying = true
                startTimer()
                updateNowPlayingInfo()
            } catch {
                // Fallback to AVPlayer for local files (e.g. hi-res FLAC/containers where AVPlayer decodes cleanly)
                cancelCrossfade()
                localPlayer?.delegate = nil
                localPlayer?.stop()
                localPlayer = nil
                playWithAVPlayer(url: fileURL, item: item)
            }

        case .navidromeStream(_, let streamURL), .podcastStream(let streamURL):
            cancelCrossfade()
            localPlayer?.delegate = nil
            localPlayer?.stop()
            localPlayer = nil
            stopStreamPlayer()
            playWithAVPlayer(url: streamURL, item: item)
        }
    }

    private func playWithAVPlayer(url: URL, item: PlayableItem) {
        let playerItem = AVPlayerItem(url: url)
        let avp = AVPlayer(playerItem: playerItem)
        avp.automaticallyWaitsToMinimizeStalling = !url.isFileURL
        streamPlayer = avp
        streamEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextTrack() }
        }

        currentItem = item
        duration = item.duration
        currentTime = 0
        avp.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }

    private func stopStreamPlayer() {
        if let obs = streamEndObserver {
            NotificationCenter.default.removeObserver(obs)
            streamEndObserver = nil
        }
        streamPlayer?.pause()
        streamPlayer = nil
    }

    private func cancelCrossfade() {
        fadingOutLocalPlayer?.delegate = nil
        fadingOutLocalPlayer?.stop()
        fadingOutLocalPlayer = nil
        isCrossfading = false
        crossfadeElapsed = 0
        activeCrossfadeDuration = 0
        localPlayer?.volume = 1.0
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

    // MARK: - Progress, Equal-Power Crossfade & Now Playing

    private func startTimer() {
        stopTimer()
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastTickDate = nil
    }

    private func tick() {
        let now = Date()
        let delta = lastTickDate.map { min(0.5, max(0, now.timeIntervalSince($0))) } ?? 0
        lastTickDate = now

        if let lp = localPlayer, lp.isPlaying {
            if isCrossfading {
                crossfadeElapsed += delta
                let t = min(1.0, crossfadeElapsed / max(0.1, activeCrossfadeDuration))
                let angle = t * (.pi / 2.0)
                fadingOutLocalPlayer?.volume = Float(cos(angle))
                lp.volume = Float(sin(angle))
                if t >= 1.0 {
                    cancelCrossfade()
                }
            } else if crossfadeEnabled,
                      let nextIdx = nextIndexForAutoAdvance(),
                      case .localFile = queue[nextIdx].source {
                let effectiveFade = min(crossfadeDuration, lp.duration * 0.4)
                let remaining = lp.duration - lp.currentTime
                if effectiveFade >= 0.8 && remaining <= effectiveFade && remaining > 0.1 {
                    currentIndex = nextIdx
                    loadAndPlayCurrent(crossfadeSeconds: min(effectiveFade, remaining))
                    return
                }
            }
            currentTime = lp.currentTime
        } else if let sp = streamPlayer {
            let secs = sp.currentTime().seconds
            if secs.isFinite && secs >= 0 {
                currentTime = secs
            }
            if let itemDur = sp.currentItem?.duration.seconds, itemDur.isFinite && itemDur > 0 {
                duration = itemDur
            }
            if !scrobbledCurrentStream,
               let cur = currentItem,
               case .navidromeStream(let songID, _) = cur.source,
               currentTime >= min(30, max(10, duration * 0.5)) {
                scrobbledCurrentStream = true
                onNavidromeStreamPlayed?(songID)
            }
        }
    }

    private func nextIndexForAutoAdvance() -> Int? {
        guard !queue.isEmpty else { return nil }
        if repeatMode == .one { return currentIndex }
        if currentIndex + 1 < queue.count { return currentIndex + 1 }
        if repeatMode == .all { return 0 }
        return nil
    }

    nonisolated private static func makeNowPlayingArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPMediaItemPropertyAlbumTitle: item.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let artURL = item.localArtworkURL, let img = UIImage(contentsOfFile: artURL.path) {
            info[MPMediaItemPropertyArtwork] = Self.makeNowPlayingArtwork(from: img)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    nonisolated func audioPlayerDidFinishPlaying(_ finishedPlayer: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(finishedPlayer)
        Task { @MainActor [weak self] in
            guard let self, let active = self.localPlayer, ObjectIdentifier(active) == finishedID else { return }
            self.nextTrack()
        }
    }
}
