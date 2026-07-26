//
//  AppRootView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query(sort: \TreasureHunt.updatedAt, order: .reverse)
    private var hunts: [TreasureHunt]

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var destination = AppDestination.title
    @State private var playingHunt: TreasureHunt?
    @State private var isShowingOpeningVideo: Bool
    @State private var hasResolvedInitialSession = false
    @StateObject private var audioSettings = AppAudioSettings()
    @StateObject private var musicCoordinator = BackgroundMusicCoordinator()
    @StateObject private var privacyShieldController =
        AppPrivacyShieldWindowController()

    init(automaticallyShowsOpening: Bool = true) {
        _isShowingOpeningVideo = State(
            initialValue: automaticallyShowsOpening
        )
    }

    var body: some View {
        ZStack {
            if hasResolvedInitialSession {
                destinationContent
                    .id(destination)
                    .transition(.opacity)
                    .allowsHitTesting(!isShowingOpeningVideo)
                    .accessibilityHidden(isShowingOpeningVideo)

                if isShowingOpeningVideo {
                    OpeningVideoView(onFinished: finishOpeningVideo)
                        .transition(.opacity)
                        .zIndex(10)
                }
            } else {
                TreasureBackgroundArtwork(style: .home)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.32),
            value: destination
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.32),
            value: isShowingOpeningVideo
        )
        .environmentObject(musicCoordinator)
        .environmentObject(audioSettings)
        .onAppear {
            resumeLockedSessionIfNeeded()
            hasResolvedInitialSession = true
            musicCoordinator.setPlaybackEnabled(
                audioSettings.backgroundMusicIsEnabled
            )
            updateMusic()
            updatePrivacyShield()
        }
        .onChange(of: audioSettings.backgroundMusicIsEnabled) {
            musicCoordinator.setPlaybackEnabled(
                audioSettings.backgroundMusicIsEnabled
            )
        }
        .onChange(of: backgroundMusicTrack) {
            updateMusic()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                resumeLockedSessionIfNeeded()
            }
            updatePrivacyShield()
            updateMusic()
        }
        .onChange(of: destination) {
            updatePrivacyShield()
        }
        .onChange(of: playingHunt?.id) {
            updateMusic()
        }
        .onChange(of: lockedHunt?.id) { _, lockedHuntID in
            if lockedHuntID != nil {
                resumeLockedSessionIfNeeded()
            }
        }
        .fullScreenCover(
            item: $playingHunt,
            onDismiss: {
                show(.home)
                resumeLockedSessionIfNeeded()
            }
        ) { hunt in
            PlaySessionView(hunt: hunt)
                .environmentObject(musicCoordinator)
                .environmentObject(audioSettings)
        }
        .onDisappear {
            privacyShieldController.hide()
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .title:
            TitleScreenView(
                resumableHunt: resumableHunt,
                onStart: { show(.home) },
                onResume: { playingHunt = $0 }
            )

        case .home:
            ContentView(onShowTitle: { show(.title) })
        }
    }

    private var resumableHunt: TreasureHunt? {
        lockedHunt ?? hunts.first { $0.playState == .inProgress }
    }

    private var lockedHunt: TreasureHunt? {
        hunts.first(where: \.isChildModeLocked)
    }

    private var backgroundMusicTrack: BackgroundMusicTrack? {
        guard hasResolvedInitialSession,
              !isShowingOpeningVideo,
              playingHunt == nil else {
            return nil
        }

        switch destination {
        case .title:
            return .title
        case .home:
            return .homeMenu
        }
    }

    private func updateMusic() {
        musicCoordinator.setBaseTrack(backgroundMusicTrack)
        musicCoordinator.setSceneActive(scenePhase == .active)
    }

    private func resumeLockedSessionIfNeeded() {
        guard destination == .title,
              playingHunt == nil,
              let lockedHunt else {
            return
        }
        isShowingOpeningVideo = false
        playingHunt = lockedHunt
    }

    private var privacyShieldMode: AppPrivacyShieldMode? {
        if scenePhase != .active {
            return .background
        }
        return nil
    }

    private func updatePrivacyShield() {
        privacyShieldController.update(
            mode: privacyShieldMode
        )
    }

    private func show(_ newDestination: AppDestination) {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.28)
        ) {
            destination = newDestination
        }
    }

    private func finishOpeningVideo() {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.32)
        ) {
            isShowingOpeningVideo = false
        }
    }
}

private enum AppDestination: Hashable {
    case title
    case home
}

#Preview {
    AppRootView(automaticallyShowsOpening: false)
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
