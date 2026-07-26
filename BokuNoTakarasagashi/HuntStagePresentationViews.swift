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
                    .foregroundStyle(isLast ? .white : TreasureTheme.coral)
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

    @ObservedObject var speechController: HintSpeechController

    var body: some View {
        VStack(spacing: 12) {
            Label("おたすけヒント", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(TreasureTheme.coral)

            Text(extraHint)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("おたすけヒント、\(extraHint)")

            HintSpeechButton(
                controller: speechController,
                text: extraHint
            )
        }
        .padding(18)
        .background(
            TreasureTheme.gold.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(TreasureTheme.gold.opacity(0.45), lineWidth: 1.5)
        }
    }
}
