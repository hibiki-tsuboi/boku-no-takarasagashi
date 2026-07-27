//
//  HuntStagePresentationViews.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct HuntHintCard: View {
    let stage: TreasureStage
    let number: Int
    let isLast: Bool

    @ObservedObject var speechController: HintSpeechController

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        isLast
                            ? TreasureTheme.gold
                            : TreasureTheme.coral.opacity(0.15)
                    )

                Image(systemName: isLast ? "gift.fill" : "magnifyingglass")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        isLast ? .white : TreasureTheme.coralText
                    )
            }
            .frame(width: 82, height: 82)
            .accessibilityHidden(true)

            Text(isLast ? "さいごのヒント" : "ヒント \(number)")
                .font(.title2.bold())
                .foregroundStyle(TreasureTheme.ink)

            if let hintImageData = stage.hintImageData {
                HintPhotoView(data: hintImageData)
            }

            Text(stage.hint)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityLabel("ヒント、\(stage.hint)")

            HintSpeechButton(
                controller: speechController,
                text: stage.hint
            )
        }
        .treasureCard()
    }
}

struct HuntExtraHintCard: View {
    let extraHint: String
    let imageData: Data?
    let number: Int
    let totalCount: Int

    @ObservedObject var speechController: HintSpeechController

    var body: some View {
        VStack(spacing: 12) {
            Label(title, systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(TreasureTheme.goldText)

            if let imageData {
                HintPhotoView(
                    data: imageData,
                    accessibilityLabel: "\(title)の写真"
                )
            }

            Text(extraHint)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(title)、\(extraHint)")

            HintSpeechButton(
                controller: speechController,
                text: extraHint
            )
        }
        .padding(18)
        .background(
            TreasureTheme.cardSurface,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(TreasureTheme.gold.opacity(0.45), lineWidth: 1.5)
        }
    }

    private var title: String {
        guard totalCount > 1 else { return "おたすけヒント" }
        return "おたすけヒント \(number) / \(totalCount)"
    }
}
