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

    @State private var destination = AppDestination.title
    @State private var playingHunt: TreasureHunt?
    @State private var isShowingOpeningVideo: Bool
    @StateObject private var musicCoordinator = BackgroundMusicCoordinator()

    init(automaticallyShowsOpening: Bool = true) {
        _isShowingOpeningVideo = State(
            initialValue: automaticallyShowsOpening
        )
    }

    var body: some View {
        ZStack {
            destinationContent
                .id(destination)
                .transition(.opacity)

            if isShowingOpeningVideo {
                OpeningVideoView(onFinished: finishOpeningVideo)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.32), value: destination)
        .animation(.easeInOut(duration: 0.32), value: isShowingOpeningVideo)
        .environmentObject(musicCoordinator)
        .onAppear {
            updateMusic()
        }
        .onChange(of: backgroundMusicTrack) {
            updateMusic()
        }
        .onChange(of: scenePhase) {
            updateMusic()
        }
        .fullScreenCover(item: $playingHunt) { hunt in
            PlaySessionView(hunt: hunt)
                .environmentObject(musicCoordinator)
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .title:
            TitleScreenView(
                resumableHunt: resumableHunt,
                onStart: { show(.adventures) },
                onResume: { playingHunt = $0 },
                onOpenParent: { show(.parent) },
                onPlayOpening: showOpeningVideo
            )

        case .adventures:
            AdventureSelectionView(
                hunts: hunts,
                onPlay: { playingHunt = $0 },
                onOpenParent: { show(.parent) },
                onShowTitle: { show(.title) }
            )

        case .parent:
            ContentView(
                onShowTitle: { show(.title) }
            )
        }
    }

    private var resumableHunt: TreasureHunt? {
        hunts.first(where: \.isChildModeLocked)
            ?? hunts.first { $0.playState == .inProgress }
    }

    private var backgroundMusicTrack: BackgroundMusicTrack? {
        guard !isShowingOpeningVideo else { return nil }

        switch destination {
        case .title:
            return .title
        case .adventures:
            return .adventureMenu
        case .parent:
            return .parentMenu
        }
    }

    private func updateMusic() {
        musicCoordinator.setBaseTrack(backgroundMusicTrack)
        musicCoordinator.setSceneActive(scenePhase == .active)
    }

    private func show(_ newDestination: AppDestination) {
        withAnimation(.easeInOut(duration: 0.28)) {
            destination = newDestination
        }
    }

    private func showOpeningVideo() {
        withAnimation(.easeInOut(duration: 0.32)) {
            isShowingOpeningVideo = true
        }
    }

    private func finishOpeningVideo() {
        withAnimation(.easeInOut(duration: 0.32)) {
            isShowingOpeningVideo = false
        }
    }
}

private enum AppDestination: Hashable {
    case title
    case adventures
    case parent
}

#Preview {
    AppRootView(automaticallyShowsOpening: false)
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
