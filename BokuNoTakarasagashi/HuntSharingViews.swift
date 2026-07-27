//
//  HuntSharingViews.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

enum HuntManagementAction: Equatable {
    case preview
    case duplicate
    case share
}

struct HuntActionRequest: Identifiable {
    let id = UUID()
    let hunt: TreasureHunt
    let action: HuntManagementAction
}

struct HuntImportCandidate: Identifiable {
    let id = UUID()
    let validatedPackage: ValidatedHuntTransferPackage
}

struct HuntActionView: View {
    let request: HuntActionRequest
    let onPrepare: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var duplicatedTitle: String?
    @State private var operationError: String?

    var body: some View {
        NavigationStack {
            TreasureBackground(style: backgroundStyle) {
                switch request.action {
                case .preview:
                    HuntPreviewView(
                        hunt: request.hunt,
                        onPrepare: onPrepare
                    )
                case .duplicate:
                    duplicateResult
                case .share:
                    HuntShareContent(hunt: request.hunt)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .tint(TreasureTheme.teal)
        .onAppear(perform: startRequestedActionIfNeeded)
    }

    private var navigationTitle: String {
        switch request.action {
        case .preview:
            "プレビュー"
        case .duplicate:
            "宝探しを複製"
        case .share:
            "宝探しを共有"
        }
    }

    private var backgroundStyle: TreasureBackgroundStyle {
        switch request.action {
        case .preview:
            .playing
        case .duplicate, .share:
            .home
        }
    }

    @ViewBuilder
    private var duplicateResult: some View {
        VStack(spacing: 22) {
            Spacer()

            if let duplicatedTitle {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(TreasureTheme.tealText)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("コピーしました")
                            .font(.title2.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text(duplicatedTitle)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.ink)
                    }
                }
                .treasureCompactCard()

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "QRコードとNFCタグの識別子は新しくなります。",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .font(.subheadline)
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .treasureCard()
            } else if let operationError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TreasureTheme.coralText)
                        .accessibilityHidden(true)

                    Text(operationError)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.ink)

                    Button("もう一度ためす", action: duplicateHunt)
                        .buttonStyle(.borderedProminent)
                }
                .treasureCompactCard()
            } else {
                ProgressView("コピーしています…")
                    .treasureCompactCard()
            }

            Spacer()
        }
        .padding(24)
    }

    private func startRequestedActionIfNeeded() {
        guard request.action == .duplicate,
              duplicatedTitle == nil,
              operationError == nil else {
            return
        }
        duplicateHunt()
    }

    private func duplicateHunt() {
        operationError = nil

        let unavailableVerification = request.hunt.stages
            .map(\.verification)
            .first { !deviceSupports($0) }
        if let unavailableVerification {
            operationError = "この端末では\(unavailableVerification.title)を利用できないため複製できません。先に発見方法を変更してください。"
            return
        }

        do {
            let copy = try HuntTransferService.duplicate(
                request.hunt,
                in: modelContext
            )
            duplicatedTitle = copy.title
        } catch {
            modelContext.rollback()
            operationError = error.localizedDescription
        }
    }
}

private struct HuntShareContent: View {
    let hunt: TreasureHunt

    @State private var shareFile: TemporaryHuntShareFile?
    @State private var preparationError: String?
    @State private var preparationTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(TreasureTheme.teal.opacity(0.14))

                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(TreasureTheme.tealText)
                }
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Text(hunt.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.ink)

                    Text("写真を含む宝探しを、AirDropやメッセージで家族へ送れます。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.secondaryText)
                }
                .treasureCompactCard()

                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        "宝 \(hunt.stages.count)こ",
                        systemImage: "gift.fill"
                    )

                    Label(
                        "写真 \(photoCount)まい",
                        systemImage: "photo.fill"
                    )

                    Label(
                        "冒険履歴は含みません",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .treasureCard()

                if let shareFile {
                    ShareLink(
                        item: shareFile.fileURL,
                        preview: SharePreview(
                            "\(hunt.title)・ぼくの宝探し",
                            image: Image(systemName: "map.fill")
                        )
                    ) {
                        Label(
                            "共有画面を開く",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(TreasurePrimaryButtonStyle())
                } else if let preparationError {
                    VStack(spacing: 12) {
                        Text(preparationError)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.coralText)

                        Button("もう一度ためす", action: prepareShareFile)
                            .buttonStyle(.bordered)
                    }
                    .treasureCompactCard()
                } else {
                    ProgressView("共有ファイルを準備しています…")
                }

                Label(
                    "共有ファイルには隠し場所や合言葉が入っています。信頼できる相手だけに送ってください。",
                    systemImage: "exclamationmark.shield.fill"
                )
                .font(.footnote)
                .foregroundStyle(TreasureTheme.coralText)
                .treasureCompactCard()
            }
            .padding(24)
        }
        .onAppear {
            prepareShareFile()
        }
        .onDisappear {
            preparationTask?.cancel()
            shareFile?.remove()
        }
    }

    private var photoCount: Int {
        hunt.stages.reduce(into: 0) { total, stage in
            total += stage.hintImageData == nil ? 0 : 1
            total += stage.availableExtraHintContents
                .compactMap(\.imageData)
                .count
        }
    }

    private func prepareShareFile() {
        preparationTask?.cancel()
        shareFile?.remove()
        shareFile = nil
        preparationError = nil

        let package = HuntTransferPackage(hunt: hunt)
        preparationTask = Task {
            var preparedFile: TemporaryHuntShareFile?

            do {
                preparedFile = try await Task.detached(priority: .userInitiated) {
                    try HuntTransferService.makeTemporaryShareFile(from: package)
                }.value
                try Task.checkCancellation()
                shareFile = preparedFile
                preparedFile = nil
            } catch is CancellationError {
                preparedFile?.remove()
            } catch {
                preparedFile?.remove()
                preparationError = error.localizedDescription
            }
        }
    }
}

struct HuntImportView: View {
    let validatedPackage: ValidatedHuntTransferPackage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var importError: String?

    private var package: HuntTransferPackage {
        validatedPackage.package
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(package.title)
                            .font(.title3.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Label(
                            "宝 \(package.stages.count)こ",
                            systemImage: "gift.fill"
                        )

                        if photoCount > 0 {
                            Label(
                                "写真 \(photoCount)まい",
                                systemImage: "photo.fill"
                            )
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("読み込む宝探し")
                }

                if requiresNewVerificationTools {
                    Section {
                        Label(
                            "QRコードとNFCタグの識別子は読み込み時に新しくなります。遊ぶ前に準備モードで用意してください。",
                            systemImage: "qrcode"
                        )
                        .font(.footnote)
                        .foregroundStyle(TreasureTheme.coralText)
                    } header: {
                        Text("QR・NFCについて")
                    }
                }

                if let unavailableVerification {
                    Section {
                        Label(
                            "この端末では\(unavailableVerification.title)を利用できないため、この宝探しは読み込めません。対応するiPhoneで読み込むか、送信元で発見方法を変更してください。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(TreasureTheme.coralText)
                    } header: {
                        Text("利用できない発見方法")
                    }
                }

                Section {
                    Label(
                        "道路・水辺・高い場所などがヒントに含まれていないか、読み込み後に必ず確認してください。",
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.coralText)
                } header: {
                    Text("安全")
                }
            }
            .scrollContentBackground(.hidden)
            .treasureBackground(.home)
            .navigationTitle("宝探しを読み込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("読み込む", action: importHunt)
                        .fontWeight(.semibold)
                        .disabled(unavailableVerification != nil)
                }
            }
            .alert("読み込めませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "もう一度ためしてください。")
            }
        }
        .tint(TreasureTheme.teal)
    }

    private var photoCount: Int {
        package.stages.reduce(into: 0) { total, stage in
            total += stage.allPhotoData.count
        }
    }

    private var requiresNewVerificationTools: Bool {
        package.stages.contains { stage in
            stage.verificationRawValue == TreasureVerification.qrCode.rawValue
                || stage.verificationRawValue == TreasureVerification.nfc.rawValue
        }
    }

    private var unavailableVerification: TreasureVerification? {
        package.stages
            .compactMap {
                TreasureVerification(rawValue: $0.verificationRawValue)
            }
            .first { !deviceSupports($0) }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { isPresented in
                if !isPresented {
                    importError = nil
                }
            }
        )
    }

    private func importHunt() {
        guard unavailableVerification == nil else {
            importError = "この端末で使えない発見方法が含まれています。変更してから読み込んでください。"
            return
        }

        do {
            _ = try HuntTransferService.importHunt(
                from: validatedPackage,
                in: modelContext
            )
            dismiss()
        } catch {
            modelContext.rollback()
            importError = error.localizedDescription
        }
    }
}

private func deviceSupports(
    _ verification: TreasureVerification
) -> Bool {
    switch verification {
    case .qrCode:
        QRCodeScannerCapability.isSupported
    case .nfc:
        NFCSessionController.isAvailable
    case .honesty, .passphrase:
        true
    }
}
