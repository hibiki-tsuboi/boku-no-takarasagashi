//
//  HuntPreparationView.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct HuntPreparationView: View {
    let hunt: TreasureHunt
    let onClose: () -> Void
    let onContinue: () -> Void

    @State private var hiddenStageIDs: Set<UUID> = []
    @State private var testedStageIDs: Set<UUID> = []
    @State private var writtenNFCStageIDs: Set<UUID> = []
    @State private var displayedQRCodeStageIDs: Set<UUID> = []
    @State private var qrCodeStage: TreasureStage?
    @State private var qrCodeTestStage: TreasureStage?

    private var stages: [TreasureStage] {
        hunt.sortedStages
    }

    private var allTreasuresAreHidden: Bool {
        !stages.isEmpty && stages.allSatisfy { hiddenStageIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupHeader(title: "宝をしかける準備", onClose: onClose)

            ScrollView {
                VStack(spacing: 22) {
                    introduction
                    progress

                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        PreparationStageCard(
                            stage: stage,
                            number: index + 1,
                            isLast: index == stages.count - 1,
                            isHidden: hiddenStageIDs.contains(stage.id),
                            isTested: testedStageIDs.contains(stage.id),
                            isNFCWritten: writtenNFCStageIDs.contains(stage.id),
                            isQRCodeDisplayed: displayedQRCodeStageIDs.contains(stage.id),
                            onShowQRCode: {
                                displayedQRCodeStageIDs.insert(stage.id)
                                qrCodeStage = stage
                            },
                            onTestQRCode: {
                                qrCodeTestStage = stage
                            },
                            onNFCWritten: {
                                writtenNFCStageIDs.insert(stage.id)
                            },
                            onNFCTested: {
                                testedStageIDs.insert(stage.id)
                            },
                            onToggleHidden: {
                                toggleHidden(stage)
                            }
                        )
                    }

                    VStack(spacing: 9) {
                        Button("安全確認へ", action: onContinue)
                            .buttonStyle(TreasurePrimaryButtonStyle())
                            .disabled(!allTreasuresAreHidden)

                        if !allTreasuresAreHidden {
                            Text("すべての宝を隠したら次へ進めます")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .sheet(item: $qrCodeStage) { stage in
            NavigationStack {
                QRCodePreparationView(
                    payload: stage.verificationPayload,
                    treasureNumber: stage.orderIndex + 1
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") {
                            qrCodeStage = nil
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $qrCodeTestStage) { stage in
            QRCodeScannerView(
                expectedPayload: stage.verificationPayload,
                onMatch: {
                    testedStageIDs.insert(stage.id)
                    qrCodeTestStage = nil
                }
            )
        }
    }

    private var introduction: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 38))
                .foregroundStyle(TreasureTheme.coral)
                .accessibilityHidden(true)

            Text("順番に宝を準備しよう")
                .font(.title2.bold())
                .foregroundStyle(TreasureTheme.ink)

            Text("QRコードやNFCタグを用意して、\n実物の宝をヒントの場所へ隠してください。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var progress: some View {
        VStack(spacing: 8) {
            HStack {
                Text("準備の進み具合")
                Spacer()
                Text("\(hiddenStageIDs.count) / \(stages.count)")
            }
            .font(.caption.bold())
            .foregroundStyle(TreasureTheme.ink)

            ProgressView(
                value: Double(hiddenStageIDs.count),
                total: Double(max(stages.count, 1))
            )
            .tint(allTreasuresAreHidden ? TreasureTheme.gold : TreasureTheme.teal)
        }
        .padding(16)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
    }

    private func toggleHidden(_ stage: TreasureStage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if hiddenStageIDs.contains(stage.id) {
                hiddenStageIDs.remove(stage.id)
            } else {
                hiddenStageIDs.insert(stage.id)
            }
        }
    }
}

private struct PreparationStageCard: View {
    let stage: TreasureStage
    let number: Int
    let isLast: Bool
    let isHidden: Bool
    let isTested: Bool
    let isNFCWritten: Bool
    let isQRCodeDisplayed: Bool
    let onShowQRCode: () -> Void
    let onTestQRCode: () -> Void
    let onNFCWritten: () -> Void
    let onNFCTested: () -> Void
    let onToggleHidden: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isLast ? TreasureTheme.gold : TreasureTheme.teal.opacity(0.15))

                    Image(systemName: isLast ? "gift.fill" : "\(number).circle.fill")
                        .foregroundStyle(isLast ? .white : TreasureTheme.teal)
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isLast ? "宝 \(number)・ゴール" : "宝 \(number)")
                        .font(.headline)
                        .foregroundStyle(TreasureTheme.ink)

                    Label(stage.verification.title, systemImage: stage.verification.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TreasureTheme.teal)
                }

                Spacer()

                Image(systemName: isHidden ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isHidden ? TreasureTheme.teal : .secondary)
                    .accessibilityLabel(isHidden ? "隠しました" : "まだ隠していません")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("ヒント")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(stage.hint)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TreasureTheme.ink)
            }

            Divider()

            verificationPreparation

            Button(action: onToggleHidden) {
                Label(
                    isHidden ? "宝を隠しました" : "宝を隠したらチェック",
                    systemImage: isHidden ? "checkmark.circle.fill" : "shippingbox.fill"
                )
                .font(.headline)
                .foregroundStyle(isHidden ? TreasureTheme.teal : TreasureTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    isHidden
                        ? TreasureTheme.teal.opacity(0.14)
                        : TreasureTheme.gold.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
        }
        .treasureCard()
    }

    @ViewBuilder
    private var verificationPreparation: some View {
        switch stage.verification {
        case .honesty:
            PreparationNote(
                icon: "hand.thumbsup.fill",
                text: "追加の道具は必要ありません。実物の宝だけを隠してください。"
            )

        case .passphrase:
            VStack(alignment: .leading, spacing: 8) {
                Label("合言葉を書いた紙を用意", systemImage: "pencil")
                    .font(.subheadline.bold())
                    .foregroundStyle(TreasureTheme.ink)

                Text(stage.passphrase)
                    .font(.body.monospaced().weight(.semibold))
                    .foregroundStyle(TreasureTheme.coral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TreasureTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .textSelection(.enabled)
            }

        case .qrCode:
            VStack(alignment: .leading, spacing: 10) {
                Button(action: onShowQRCode) {
                    Label(
                        isQRCodeDisplayed ? "QRコードをもう一度表示" : "QRコードを表示・共有",
                        systemImage: "qrcode"
                    )
                }
                .buttonStyle(.bordered)

                Button(action: onTestQRCode) {
                    Label(
                        isTested ? "QRコードをもう一度テスト" : "QRコードを読み取りテスト",
                        systemImage: isTested ? "checkmark.circle.fill" : "qrcode.viewfinder"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isTested ? TreasureTheme.teal : TreasureTheme.ink)

                VerificationTestStatus(isTested: isTested)
            }

        case .nfc:
            VStack(alignment: .leading, spacing: 12) {
                NFCWriterControl(
                    payload: stage.verificationPayload,
                    onWriteSuccess: onNFCWritten
                )
                .buttonStyle(.bordered)

                if isNFCWritten {
                    Label("この宝のデータを書き込み済み", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TreasureTheme.teal)
                }

                NFCReaderControl(
                    expectedPayload: stage.verificationPayload,
                    buttonTitle: isTested
                        ? "NFCタグをもう一度テスト"
                        : "NFCタグを読み取りテスト",
                    instruction: "書き込んだタグがこの宝のものか確認できます",
                    successMessage: "正しい宝のNFCタグです！",
                    usesPrimaryButtonStyle: false,
                    onMatch: onNFCTested
                )

                VerificationTestStatus(isTested: isTested)
            }
        }
    }
}

private struct PreparationNote: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(TreasureTheme.ink)
    }
}

private struct VerificationTestStatus: View {
    let isTested: Bool

    var body: some View {
        Label(
            isTested ? "読み取り確認済み" : "読み取りテストは任意です",
            systemImage: isTested ? "checkmark.seal.fill" : "info.circle"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isTested ? TreasureTheme.teal : .secondary)
    }
}
