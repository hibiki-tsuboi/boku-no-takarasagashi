//
//  AppRootView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query(sort: \TreasureHunt.updatedAt, order: .reverse)
    private var hunts: [TreasureHunt]

    @State private var destination = AppDestination.title
    @State private var playingHunt: TreasureHunt?

    var body: some View {
        ZStack {
            switch destination {
            case .title:
                TitleScreenView(
                    resumableHunt: resumableHunt,
                    onStart: { show(.adventures) },
                    onResume: { playingHunt = $0 },
                    onOpenParent: { show(.parent) }
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
        .id(destination)
        .transition(.opacity)
        .fullScreenCover(item: $playingHunt) { hunt in
            PlaySessionView(hunt: hunt)
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
}

private enum AppDestination: Hashable {
    case title
    case adventures
    case parent
}

#Preview {
    AppRootView()
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
