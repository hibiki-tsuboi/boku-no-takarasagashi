//
//  OpeningVideoView.swift
//  BokuNoTakarasagashi
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct OpeningVideoView: View {
    let onFinished: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var audioSettings: AppAudioSettings

    @State private var player: AVPlayer?
    @State private var didFinish = false
    @AccessibilityFocusState private var skipIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color(red: 0.16, green: 0.09, blue: 0.04)

                if let player {
                    OpeningPlayerSurface(player: player)
                        .transition(.opacity)
                }

                Button("スキップ", action: finish)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        .black.opacity(0.54),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.45), lineWidth: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, proxy.safeAreaInsets.top + 12)
                    .padding(.trailing, 18)
                    .accessibilityHint(
                        "オープニングを終了してタイトル画面を表示します"
                    )
                    .accessibilityFocused($skipIsFocused)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            skipIsFocused = true
            if reduceMotion {
                finish()
            } else {
                startPlayback()
            }
        }
        .onDisappear(perform: stopPlayback)
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion {
                finish()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            updatePlayback(for: newPhase)
        }
        .onChange(of: audioSettings.backgroundMusicIsEnabled) {
            player?.isMuted = !audioSettings.backgroundMusicIsEnabled
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemDidPlayToEndTime
            )
        ) { notification in
            guard isCurrentPlayerItem(notification.object) else { return }
            finish()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemFailedToPlayToEndTime
            )
        ) { notification in
            guard isCurrentPlayerItem(notification.object) else { return }
            finish()
        }
    }

    private func startPlayback() {
        guard player == nil, !didFinish else { return }
        guard let url = Bundle.main.url(
            forResource: "opening",
            withExtension: "mp4"
        ) else {
            finish()
            return
        }

        configureAmbientAudio()

        let item = AVPlayerItem(url: url)
        let openingPlayer = AVPlayer(playerItem: item)
        openingPlayer.actionAtItemEnd = .pause
        openingPlayer.isMuted = !audioSettings.backgroundMusicIsEnabled
        player = openingPlayer
        openingPlayer.play()
    }

    private func updatePlayback(for phase: ScenePhase) {
        guard !didFinish else { return }

        if phase == .active {
            player?.play()
        } else {
            player?.pause()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        player?.pause()
        onFinished()
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
    }

    private func isCurrentPlayerItem(_ object: Any?) -> Bool {
        guard let item = object as? AVPlayerItem else { return false }
        return item === player?.currentItem
    }

    private func configureAmbientAudio() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // The video remains playable without sound if audio is unavailable.
        }
    }
}

private struct OpeningPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> OpeningPlayerView {
        let view = OpeningPlayerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: OpeningPlayerView, context: Context) {
        uiView.player = player
    }
}

private final class OpeningPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
    }
}
