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
    @State private var preparedQRCodeStageIDs: Set<UUID> = []
    @State private var qrCodeStage: TreasureStage?
    @State private var qrCodeTestStage: TreasureStage?

    private var stages: [TreasureStage] {
        hunt.sortedStages
    }

    private var allTreasuresAreHidden: Bool {
        !stages.isEmpty && stages.allSatisfy { hiddenStageIDs.contains($0.id) }
    }

    private var hasUnavailableVerificationStage: Bool {
        stages.contains { !verificationIsAvailable($0.verification) }
    }

    private var allVerificationToolsArePrepared: Bool {
        stages.allSatisfy(verificationToolIsPrepared)
    }

    private var canContinue: Bool {
        allTreasuresAreHidden
            && allVerificationToolsArePrepared
            && !hasUnavailableVerificationStage
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupHeader(title: "宝をしかける準備", onClose: onClose)

            ScrollView {
                VStack(spacing: 22) {
                    introduction
                    progress

                    if hasUnavailableVerificationStage {
                        Label(
                            "この端末で使えない発見方法があります。いったん閉じて、合言葉などへ変更してください。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TreasureTheme.coralText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .treasureCard()
                    }

                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        PreparationStageCard(
                            stage: stage,
                            number: index + 1,
                            isLast: index == stages.count - 1,
                            isHidden: hiddenStageIDs.contains(stage.id),
                            isTested: testedStageIDs.contains(stage.id),
                            isNFCWritten: writtenNFCStageIDs.contains(stage.id),
                            isQRCodePrepared: preparedQRCodeStageIDs.contains(stage.id),
                            onShowQRCode: {
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
                            .disabled(!canContinue)

                        if hasUnavailableVerificationStage {
                            Text("使えない発見方法を、この端末で利用できる方法へ変更してください")
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.coralText)
                                .treasureCompactCard()
                        } else if !allVerificationToolsArePrepared {
                            Text("QRコードの表示・共有とNFCタグへの書き込みを完了してください")
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.coralText)
                                .treasureCompactCard()
                        } else if !allTreasuresAreHidden {
                            Text("すべての宝を隠したら次へ進めます")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TreasureTheme.secondaryText)
                                .treasureCompactCard()
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
                    treasureNumber: stage.orderIndex + 1,
                    isPrepared: preparedQRCodeStageIDs.contains(stage.id),
                    onPrepared: {
                        preparedQRCodeStageIDs.insert(stage.id)
                    }
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
                .foregroundStyle(TreasureTheme.tealText)
                .accessibilityHidden(true)

            Text("順番に宝を準備しよう")
                .font(.title2.bold())
                .foregroundStyle(TreasureTheme.ink)

            Text("QRコードやNFCタグを用意して、\n実物の宝をヒントの場所へ隠してください。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreasureTheme.secondaryText)
        }
        .treasureCompactCard()
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
        .background(
            TreasureTheme.cardSurface,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func toggleHidden(_ stage: TreasureStage) {
        guard verificationToolIsPrepared(stage) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            if hiddenStageIDs.contains(stage.id) {
                hiddenStageIDs.remove(stage.id)
            } else {
                hiddenStageIDs.insert(stage.id)
            }
        }
    }

    private func verificationToolIsPrepared(_ stage: TreasureStage) -> Bool {
        TreasurePreparationRequirement.isToolPrepared(
            verification: stage.verification,
            qrCodeIsPrepared: preparedQRCodeStageIDs.contains(stage.id),
            qrCodeIsAvailable: QRCodeScannerCapability.isCurrentlyAvailable,
            nfcWasWritten: writtenNFCStageIDs.contains(stage.id),
            nfcIsAvailable: NFCSessionController.isAvailable
        )
    }

    private func verificationIsAvailable(
        _ verification: TreasureVerification
    ) -> Bool {
        switch verification {
        case .qrCode:
            QRCodeScannerCapability.isCurrentlyAvailable
        case .nfc:
            NFCSessionController.isAvailable
        case .honesty, .passphrase:
            true
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
    let isQRCodePrepared: Bool
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
                        .foregroundStyle(
                            isLast ? .white : TreasureTheme.tealText
                        )
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isLast ? "宝 \(number)・ゴール" : "宝 \(number)")
                        .font(.headline)
                        .foregroundStyle(TreasureTheme.ink)

                    Label(stage.verification.title, systemImage: stage.verification.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TreasureTheme.tealText)
                }

                Spacer()

                Image(systemName: isHidden ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        isHidden
                            ? TreasureTheme.tealText
                            : TreasureTheme.secondaryText
                    )
                    .accessibilityLabel(isHidden ? "隠しました" : "まだ隠していません")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("ヒント")
                    .font(.caption.bold())
                    .foregroundStyle(TreasureTheme.secondaryText)

                Text(stage.hint)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TreasureTheme.ink)

                if let hintImageData = stage.hintImageData {
                    HintPhotoView(data: hintImageData, maxHeight: 160)
                        .padding(.top, 5)
                }

                if let extraHint = stage.availableExtraHint {
                    Text("おたすけヒント")
                        .font(.caption.bold())
                        .foregroundStyle(TreasureTheme.goldText)
                        .padding(.top, 5)

                    Text(extraHint)
                        .font(.caption)
                        .foregroundStyle(TreasureTheme.ink)
                }
            }

            Divider()

            verificationPreparation

            Button(action: onToggleHidden) {
                Label(
                    hiddenButtonTitle,
                    systemImage: isHidden ? "checkmark.circle.fill" : "shippingbox.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    isHidden ? TreasureTheme.tealText : TreasureTheme.ink
                )
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
            .disabled(!verificationToolIsPrepared)
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
                    .foregroundStyle(TreasureTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TreasureTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .textSelection(.enabled)
            }

        case .qrCode:
            if QRCodeScannerCapability.isCurrentlyAvailable {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onShowQRCode) {
                        Label(
                            isQRCodePrepared
                                ? "QRコードをもう一度表示"
                                : "QRコードを表示・共有",
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
            } else {
                PreparationNote(
                    icon: "exclamationmark.triangle.fill",
                    text: "この端末ではQRコードを読み取れません。発見方法を変更してください。"
                )
                .foregroundStyle(TreasureTheme.coralText)
            }

        case .nfc:
            if NFCSessionController.isAvailable {
                VStack(alignment: .leading, spacing: 12) {
                    NFCWriterControl(
                        payload: stage.verificationPayload,
                        onWriteSuccess: onNFCWritten
                    )
                    .buttonStyle(.bordered)

                    if isNFCWritten {
                        Label("この宝のデータを書き込み済み", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TreasureTheme.tealText)
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
            } else {
                PreparationNote(
                    icon: "exclamationmark.triangle.fill",
                    text: "この端末ではNFCを利用できません。発見方法を変更してください。"
                )
                .foregroundStyle(TreasureTheme.coralText)
            }
        }
    }

    private var verificationIsAvailable: Bool {
        switch stage.verification {
        case .qrCode:
            QRCodeScannerCapability.isCurrentlyAvailable
        case .nfc:
            NFCSessionController.isAvailable
        case .honesty, .passphrase:
            true
        }
    }

    private var verificationToolIsPrepared: Bool {
        TreasurePreparationRequirement.isToolPrepared(
            verification: stage.verification,
            qrCodeIsPrepared: isQRCodePrepared,
            qrCodeIsAvailable: QRCodeScannerCapability.isCurrentlyAvailable,
            nfcWasWritten: isNFCWritten,
            nfcIsAvailable: NFCSessionController.isAvailable
        )
    }

    private var hiddenButtonTitle: String {
        if !verificationIsAvailable {
            return "先に発見方法を変更してください"
        }
        if !verificationToolIsPrepared {
            switch stage.verification {
            case .qrCode:
                return "先にQRコードを表示・共有してください"
            case .nfc:
                return "先にNFCタグへ書き込んでください"
            case .honesty, .passphrase:
                break
            }
        }
        return isHidden ? "宝を隠しました" : "宝を隠したらチェック"
    }
}

enum TreasurePreparationRequirement {
    nonisolated static func isToolPrepared(
        verification: TreasureVerification,
        qrCodeIsPrepared: Bool,
        qrCodeIsAvailable: Bool,
        nfcWasWritten: Bool,
        nfcIsAvailable: Bool
    ) -> Bool {
        switch verification {
        case .honesty, .passphrase:
            return true
        case .qrCode:
            return qrCodeIsAvailable && qrCodeIsPrepared
        case .nfc:
            return nfcIsAvailable && nfcWasWritten
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
        .foregroundStyle(
            isTested
                ? TreasureTheme.tealText
                : TreasureTheme.secondaryText
        )
    }
}
