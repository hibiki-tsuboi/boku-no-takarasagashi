//
//  HuntTemplates.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct HuntTemplate: Identifiable {
    struct Stage {
        let hint: String
        let extraHint: String
        let discoveryMessage: String
    }

    let id: String
    let title: String
    let summary: String
    let systemImage: String
    let openingMessage: String
    let completionMessage: String
    let stages: [Stage]

    static let samples: [HuntTemplate] = [
        HuntTemplate(
            id: "home-adventure",
            title: "おうち探検",
            summary: "リビングや本棚をめぐる、3つの宝",
            systemImage: "house.fill",
            openingMessage: "おうちが冒険の島に変身！ヒントをたどって宝を見つけよう。",
            completionMessage: "おうち探検、大成功！ぜんぶの宝を見つけたね！",
            stages: [
                .init(
                    hint: "みんなが座って、ゆっくりする場所をさがしてみよう。",
                    extraHint: "ふかふかしたクッションの近くを見てみよう。",
                    discoveryMessage: "ひとつ目の宝を発見！次の場所へ進もう。"
                ),
                .init(
                    hint: "いろいろなお話が、ならんで待っている場所はどこかな？",
                    extraHint: "本の背中がたくさん見える場所だよ。",
                    discoveryMessage: "ふたつ目も見つけた！ゴールはもうすぐ。"
                ),
                .init(
                    hint: "毎日『いってきます』を言う場所をさがしてみよう。",
                    extraHint: "くつを置く場所の近くだよ。",
                    discoveryMessage: "さいごの宝を見つけた！"
                ),
            ]
        ),
        HuntTemplate(
            id: "rainy-day",
            title: "雨の日ミッション",
            summary: "家の中で体を動かして楽しむ、4つの宝",
            systemImage: "cloud.rain.fill",
            openingMessage: "雨雲から秘密のミッションが届いたよ。家の中の宝を救い出そう！",
            completionMessage: "すべてのミッション完了！雨の日の宝探し名人だね！",
            stages: [
                .init(
                    hint: "雨の日に外へ行くとき、頭の上でひらくものを見つけよう。",
                    extraHint: "かさをしまっている場所を見てみよう。",
                    discoveryMessage: "雨よけアイテムを発見！"
                ),
                .init(
                    hint: "ぬれた手を、ふわふわにしてくれるものはどこかな？",
                    extraHint: "手を洗う場所の近くにあるよ。",
                    discoveryMessage: "ふたつ目のミッション成功！"
                ),
                .init(
                    hint: "服がくるくる回って、きれいになる場所をさがそう。",
                    extraHint: "洗面所の大きな機械だよ。",
                    discoveryMessage: "みっつ目の宝も助け出した！"
                ),
                .init(
                    hint: "夜になると、からだを休ませる場所はどこかな？",
                    extraHint: "まくらの近くを見てみよう。",
                    discoveryMessage: "さいごのミッションも大成功！"
                ),
            ]
        ),
        HuntTemplate(
            id: "birthday-surprise",
            title: "おたんじょうび",
            summary: "特別な日に贈る、3つのサプライズ",
            systemImage: "birthday.cake.fill",
            openingMessage: "おたんじょうびの秘密の宝がかくされているよ。見つけられるかな？",
            completionMessage: "おたんじょうびおめでとう！さいごのプレゼントをどうぞ！",
            stages: [
                .init(
                    hint: "つめたい食べものや飲みものが入っている場所をさがそう。",
                    extraHint: "キッチンにある、大きな白い箱の近くだよ。",
                    discoveryMessage: "最初のサプライズを見つけたね！"
                ),
                .init(
                    hint: "今日の顔をうつしてくれる、ぴかぴかの場所はどこかな？",
                    extraHint: "鏡の近くを見てみよう。",
                    discoveryMessage: "ふたつ目のサプライズも発見！"
                ),
                .init(
                    hint: "家族みんなが集まる場所に、さいごの宝が待っているよ。",
                    extraHint: "いつもごはんを食べる机の近くだよ。",
                    discoveryMessage: "おたんじょうびの宝を見つけた！"
                ),
            ]
        ),
    ]
}

struct HuntCreationFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: HuntTemplate?
    @State private var isEditing = false

    var body: some View {
        if isEditing {
            HuntEditorView(hunt: nil, template: selectedTemplate)
        } else {
            NavigationStack {
                TreasureBackground(style: .editor) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("どんな冒険にする？")
                                    .font(.title2.bold())
                                    .foregroundStyle(TreasureTheme.ink)

                                Text("テンプレートのヒントは、家に合わせて自由に変えられます。")
                                    .font(.subheadline)
                                    .foregroundStyle(TreasureTheme.secondaryText)
                            }
                            .treasureCompactCard()

                            Button {
                                beginEditing(with: nil)
                            } label: {
                                TemplateCard(
                                    title: "はじめからつくる",
                                    summary: "宝の数やヒントを最初から決める",
                                    systemImage: "square.and.pencil"
                                )
                            }
                            .buttonStyle(.plain)

                            Text("おすすめテンプレート")
                                .font(.headline)
                                .foregroundStyle(TreasureTheme.ink)
                                .padding(.top, 4)

                            ForEach(HuntTemplate.samples) { template in
                                Button {
                                    beginEditing(with: template)
                                } label: {
                                    TemplateCard(
                                        title: template.title,
                                        summary: template.summary,
                                        systemImage: template.systemImage
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            Label(
                                "隠す前に、ヒントの場所が安全で使えるか確認してください。",
                                systemImage: "exclamationmark.shield.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(TreasureTheme.coralText)
                            .treasureCompactCard()
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("宝探しをつくる")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }
            .tint(TreasureTheme.teal)
        }
    }

    private func beginEditing(with template: HuntTemplate?) {
        selectedTemplate = template
        isEditing = true
    }
}

private struct TemplateCard: View {
    let title: String
    let summary: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(TreasureTheme.teal.opacity(0.14))

                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(TreasureTheme.tealText)
            }
            .frame(width: 54, height: 54)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(TreasureTheme.ink)

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.secondaryText)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(TreasureTheme.secondaryText)
        }
        .treasureCard()
        .contentShape(Rectangle())
    }
}
