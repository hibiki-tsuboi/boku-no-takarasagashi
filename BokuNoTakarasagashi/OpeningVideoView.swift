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
    @State private var skipInteractionIsEnabled = false
    @State private var skipPromptIsVisible = false
    @State private var skipPromptIsDimmed = false
    @AccessibilityFocusState private var skipIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.16, green: 0.09, blue: 0.04)

                if let player {
                    OpeningPlayerSurface(player: player)
                        .transition(.opacity)
                }

                Button(action: finish) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!skipInteractionIsEnabled)
                .accessibilityHidden(!skipInteractionIsEnabled)
                .accessibilityLabel("オープニングをスキップ")
                .accessibilityHint(
                    "画面をタップしてタイトル画面を表示します"
                )
                .accessibilityFocused($skipIsFocused)

                Text("TAP TO SKIP")
                    .font(
                        .system(
                            .title3,
                            design: .monospaced,
                            weight: .heavy
                        )
                    )
                    .tracking(2.8)
                    .foregroundStyle(.white)
                    .shadow(
                        color: .black.opacity(0.88),
                        radius: 4,
                        y: 2
                    )
                    .opacity(skipPromptIsDimmed ? 0.68 : 0.94)
                    .animation(
                        .easeInOut(duration: 1.6)
                            .repeatForever(autoreverses: true),
                        value: skipPromptIsDimmed
                    )
                    .opacity(skipPromptIsVisible ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.45),
                        value: skipPromptIsVisible
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height * 0.75
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
            if reduceMotion {
                finish()
            } else {
                startPlayback()
            }
        }
        .task {
            await prepareSkipInteraction()
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

    private func prepareSkipInteraction() async {
        guard !reduceMotion else { return }

        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }

        guard !didFinish else { return }
        skipInteractionIsEnabled = true
        await Task.yield()
        skipIsFocused = true

        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }

        guard !didFinish else { return }
        skipPromptIsVisible = true
        skipPromptIsDimmed = true
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
