//
//  AppRootView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query(sort: \TreasureHunt.updatedAt, order: .reverse)
    private var hunts: [TreasureHunt]

    @AppStorage(OpeningVideoPreference.hasPlayedKey)
    private var hasPlayedOpeningVideo = false

    @State private var destination = AppDestination.title
    @State private var playingHunt: TreasureHunt?
    @State private var isShowingOpeningVideo: Bool

    init(automaticallyShowsOpening: Bool = true) {
        let hasPlayed = UserDefaults.standard.bool(
            forKey: OpeningVideoPreference.hasPlayedKey
        )
        _isShowingOpeningVideo = State(
            initialValue: automaticallyShowsOpening && !hasPlayed
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
        .fullScreenCover(item: $playingHunt) { hunt in
            PlaySessionView(hunt: hunt)
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
        hasPlayedOpeningVideo = true

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

private enum OpeningVideoPreference {
    static let hasPlayedKey = "hasPlayedOpeningVideo.v1"
}

#Preview {
    AppRootView(automaticallyShowsOpening: false)
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
