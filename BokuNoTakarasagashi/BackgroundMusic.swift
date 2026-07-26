//
//  BackgroundMusic.swift
//  BokuNoTakarasagashi
//

import AVFoundation
import Combine

enum BackgroundMusicTrack: String, Equatable {
    case title = "bgm-title"
    case discovery = "bgm-discovery"
    case exploration01 = "bgm-exploration-01"
    case exploration02 = "bgm-exploration-02"
    case exploration03 = "bgm-exploration-03"
    case exploration04 = "bgm-exploration-04"
    case exploration05 = "bgm-exploration-05"
    case exploration06 = "bgm-exploration-06"
    case exploration07 = "bgm-exploration-07"
    case exploration08 = "bgm-exploration-08"

    static let adventureMenu = BackgroundMusicTrack.exploration01
    static let parentMenu = BackgroundMusicTrack.exploration02

    private static let gameplayTracks: [BackgroundMusicTrack] = [
        .exploration03,
        .exploration04,
        .exploration05,
        .exploration06,
        .exploration07,
        .exploration08,
    ]

    static func gameplayTrack(for stageIndex: Int) -> BackgroundMusicTrack {
        let index = max(stageIndex, 0) % gameplayTracks.count
        return gameplayTracks[index]
    }

    var numberOfLoops: Int {
        -1
    }

    var volume: Float {
        switch self {
        case .title:
            0.24
        case .discovery:
            0.36
        case .exploration01,
             .exploration02,
             .exploration03,
             .exploration04,
             .exploration05,
             .exploration06,
             .exploration07,
             .exploration08:
            0.20
        }
    }
}

@MainActor
final class BackgroundMusicPlayer {
    private var player: AVAudioPlayer?
    private var currentTrack: BackgroundMusicTrack?
    private var isDucked = false

    func play(_ track: BackgroundMusicTrack) {
        if currentTrack == track, let player {
            if !player.isPlaying {
                player.play()
            }
            updateVolume(animated: true)
            return
        }

        stop()

        guard let url = Bundle.main.url(
            forResource: track.rawValue,
            withExtension: "mp3"
        ) else {
            return
        }

        do {
            try configureAudioSession()

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = track.numberOfLoops
            newPlayer.volume = 0
            newPlayer.prepareToPlay()

            player = newPlayer
            currentTrack = track
            newPlayer.play()
            updateVolume(animated: true)
        } catch {
            stop()
            // Music is supplementary; the app remains usable without audio.
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
    }

    func setDucked(_ isDucked: Bool) {
        guard self.isDucked != isDucked else { return }
        self.isDucked = isDucked
        updateVolume(animated: true)
    }

    private func updateVolume(animated: Bool) {
        guard let player, let currentTrack else { return }
        let volume = currentTrack.volume * (isDucked ? 0.28 : 1)

        if animated {
            player.setVolume(volume, fadeDuration: 0.35)
        } else {
            player.volume = volume
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)
    }
}

@MainActor
final class BackgroundMusicCoordinator: ObservableObject {
    private struct Request {
        let id: UUID
        var track: BackgroundMusicTrack
    }

    private let player = BackgroundMusicPlayer()
    private var baseTrack: BackgroundMusicTrack?
    private var requests: [Request] = []
    private var playbackIsEnabled = true
    private var sceneIsActive = false

    func setPlaybackEnabled(_ isEnabled: Bool) {
        guard playbackIsEnabled != isEnabled else { return }
        playbackIsEnabled = isEnabled
        refreshPlayback()
    }

    func setBaseTrack(_ track: BackgroundMusicTrack?) {
        guard baseTrack != track else { return }
        baseTrack = track
        refreshPlayback()
    }

    @discardableResult
    func begin(_ track: BackgroundMusicTrack) -> UUID {
        let id = UUID()
        requests.append(Request(id: id, track: track))
        refreshPlayback()
        return id
    }

    func update(_ id: UUID, track: BackgroundMusicTrack) {
        guard let index = requests.firstIndex(where: { $0.id == id }),
              requests[index].track != track else {
            return
        }
        requests[index].track = track
        refreshPlayback()
    }

    func end(_ id: UUID) {
        requests.removeAll { $0.id == id }
        refreshPlayback()
    }

    func setSceneActive(_ isActive: Bool) {
        guard sceneIsActive != isActive else { return }
        sceneIsActive = isActive
        refreshPlayback()
    }

    func setDucked(_ isDucked: Bool) {
        player.setDucked(isDucked)
    }

    private func refreshPlayback() {
        guard playbackIsEnabled else {
            player.stop()
            return
        }

        guard sceneIsActive else {
            player.pause()
            return
        }

        if let track = requests.last?.track ?? baseTrack {
            player.play(track)
        } else {
            player.stop()
        }
    }
}
