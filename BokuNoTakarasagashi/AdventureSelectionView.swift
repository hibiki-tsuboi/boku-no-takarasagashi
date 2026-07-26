//
//  AdventureSelectionView.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct AdventureSelectionView: View {
    let hunts: [TreasureHunt]
    let onPlay: (TreasureHunt) -> Void
    let onOpenParent: () -> Void
    let onShowTitle: () -> Void

    private var playableHunts: [TreasureHunt] {
        hunts.filter { !$0.sortedStages.isEmpty }
    }

    var body: some View {
        NavigationStack {
            TreasureBackground(style: .adventureSelection) {
                ScrollView {
                    VStack(spacing: 24) {
                        header

                        if playableHunts.isEmpty {
                            emptyState
                        } else {
                            huntList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onShowTitle) {
                        Label(
                            "タイトルへ戻る",
                            systemImage: "chevron.backward"
                        )
                    }
                    .tint(TreasureTheme.teal)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TreasureTheme.gold)
                    .frame(width: 72, height: 72)
                    .shadow(
                        color: TreasureTheme.gold.opacity(0.3),
                        radius: 12,
                        y: 6
                    )

                Image(systemName: "safari.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text("どの冒険にする？")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(TreasureTheme.ink)

            Text("遊びたい宝探しをえらんでね")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "map")
                .font(.system(size: 38))
                .foregroundStyle(TreasureTheme.gold)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("まだ冒険がありません")
                    .font(.title3.bold())
                    .foregroundStyle(TreasureTheme.ink)

                Text("おうちの人にiPhoneをわたして、\n宝探しをつくってもらおう。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button(action: onOpenParent) {
                Label(
                    "おうちの人にわたす",
                    systemImage: "person.crop.circle"
                )
            }
            .buttonStyle(TreasurePrimaryButtonStyle())
        }
        .treasureCard()
    }

    private var huntList: some View {
        LazyVStack(spacing: 16) {
            ForEach(playableHunts) { hunt in
                AdventureCard(
                    hunt: hunt,
                    onPlay: { onPlay(hunt) }
                )
            }
        }
    }
}

private struct AdventureCard: View {
    let hunt: TreasureHunt
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(0.16))

                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(hunt.title)
                        .font(.title3.bold())
                        .foregroundStyle(TreasureTheme.ink)
                        .lineLimit(2)

                    Text("\(statusTitle) ・ 宝 \(hunt.stages.count)こ")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer()
            }

            if hunt.playState == .inProgress {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("いまの場所")
                        Spacer()
                        Text(
                            "\(currentStageNumber) / \(hunt.stages.count)"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ProgressView(
                        value: Double(
                            min(
                                hunt.currentStageIndex,
                                hunt.stages.count
                            )
                        ),
                        total: Double(hunt.stages.count)
                    )
                    .tint(TreasureTheme.gold)
                }
            }

            Button(action: onPlay) {
                Label(playButtonTitle, systemImage: playButtonIcon)
            }
            .buttonStyle(TreasurePrimaryButtonStyle())
        }
        .treasureCard()
    }

    private var currentStageNumber: Int {
        min(hunt.currentStageIndex + 1, hunt.stages.count)
    }

    private var statusTitle: String {
        switch hunt.playState {
        case .ready:
            "準備できました"
        case .inProgress:
            "冒険の途中"
        case .completed:
            "クリア"
        }
    }

    private var statusIcon: String {
        switch hunt.playState {
        case .ready:
            "map.fill"
        case .inProgress:
            "figure.walk.motion"
        case .completed:
            "trophy.fill"
        }
    }

    private var statusColor: Color {
        switch hunt.playState {
        case .ready:
            TreasureTheme.teal
        case .inProgress:
            TreasureTheme.coral
        case .completed:
            TreasureTheme.gold
        }
    }

    private var playButtonTitle: String {
        switch hunt.playState {
        case .ready:
            "この冒険をはじめる"
        case .inProgress:
            "つづきから"
        case .completed:
            "もういちど遊ぶ"
        }
    }

    private var playButtonIcon: String {
        hunt.playState == .inProgress
            ? "arrow.right.circle.fill"
            : "play.fill"
    }
}

#Preview {
    AdventureSelectionView(
        hunts: [],
        onPlay: { _ in },
        onOpenParent: {},
        onShowTitle: {}
    )
}
