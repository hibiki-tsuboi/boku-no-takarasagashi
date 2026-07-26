//
//  HuntSharingViews.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

enum HuntParentAction: Equatable {
    case preview
    case duplicate
    case share
}

struct HuntActionRequest: Identifiable {
    let id = UUID()
    let hunt: TreasureHunt
    let action: HuntParentAction
}

struct HuntImportCandidate: Identifiable {
    let id = UUID()
    let package: HuntTransferPackage
}

struct ProtectedHuntActionView: View {
    let request: HuntActionRequest
    let onPrepare: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isUnlocked = false
    @State private var duplicatedTitle: String?
    @State private var operationError: String?

    var body: some View {
        if isUnlocked {
            NavigationStack {
                TreasureBackground {
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
        } else {
            ParentPINGateView(
                expectedDigest: request.hunt.parentPINDigest,
                onCancel: { dismiss() },
                onUnlock: unlock
            )
        }
    }

    private var navigationTitle: String {
        switch request.action {
        case .preview:
            "保護者プレビュー"
        case .duplicate:
            "宝探しを複製"
        case .share:
            "宝探しを共有"
        }
    }

    @ViewBuilder
    private var duplicateResult: some View {
        VStack(spacing: 22) {
            Spacer()

            if let duplicatedTitle {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(TreasureTheme.teal)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("コピーしました")
                        .font(.title2.bold())
                        .foregroundStyle(TreasureTheme.ink)

                    Text(duplicatedTitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.teal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "保護者PINは元の宝探しと同じです。",
                        systemImage: "lock.fill"
                    )
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(TreasureTheme.coral)
                    .accessibilityHidden(true)

                Text(operationError)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreasureTheme.ink)

                Button("もう一度ためす", action: duplicateHunt)
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView("コピーしています…")
            }

            Spacer()
        }
        .padding(24)
    }

    private func unlock() {
        isUnlocked = true
        if request.action == .duplicate {
            duplicateHunt()
        }
    }

    private func duplicateHunt() {
        operationError = nil

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

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(TreasureTheme.teal.opacity(0.14))

                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(TreasureTheme.teal)
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
                        .foregroundStyle(.secondary)
                }

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
                        "保護者PINと冒険履歴は含みません",
                        systemImage: "lock.shield.fill"
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
                    Text(preparationError)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.coral)

                    Button("もう一度ためす", action: prepareShareFile)
                        .buttonStyle(.bordered)
                } else {
                    ProgressView("共有ファイルを準備しています…")
                }

                Label(
                    "共有ファイルには隠し場所や合言葉が入っています。信頼できる相手だけに送ってください。",
                    systemImage: "exclamationmark.shield.fill"
                )
                .font(.footnote)
                .foregroundStyle(TreasureTheme.coral)
            }
            .padding(24)
        }
        .task {
            prepareShareFile()
        }
        .onDisappear {
            shareFile?.remove()
        }
    }

    private var photoCount: Int {
        hunt.stages.filter { $0.hintImageData != nil }.count
    }

    private func prepareShareFile() {
        shareFile?.remove()
        shareFile = nil
        preparationError = nil

        do {
            shareFile = try HuntTransferService.makeTemporaryShareFile(for: hunt)
        } catch {
            preparationError = error.localizedDescription
        }
    }
}

struct HuntImportView: View {
    let package: HuntTransferPackage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var parentPIN = ""
    @State private var importError: String?

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

                Section {
                    SecureField("4桁の数字", text: $parentPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: parentPIN) { _, newValue in
                            parentPIN = ParentPIN.digitsOnly(newValue)
                        }
                } header: {
                    Text("新しいおうちの人用PIN")
                } footer: {
                    Text("送った人のPINは共有されません。このiPhoneで使う4桁を設定してください。")
                }

                if requiresNewVerificationTools {
                    Section {
                        Label(
                            "QRコードとNFCタグの識別子は読み込み時に新しくなります。遊ぶ前に準備モードで用意してください。",
                            systemImage: "qrcode"
                        )
                        .font(.footnote)
                        .foregroundStyle(TreasureTheme.coral)
                    } header: {
                        Text("QR・NFCについて")
                    }
                }

                Section {
                    Label(
                        "道路・水辺・高い場所などがヒントに含まれていないか、読み込み後に必ず確認してください。",
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.coral)
                } header: {
                    Text("安全")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TreasureTheme.background)
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
                        .disabled(parentPIN.count != 4)
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
        package.stages.filter { $0.hintImageData != nil }.count
    }

    private var requiresNewVerificationTools: Bool {
        package.stages.contains { stage in
            stage.verificationRawValue == TreasureVerification.qrCode.rawValue
                || stage.verificationRawValue == TreasureVerification.nfc.rawValue
        }
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
        guard parentPIN.count == 4 else { return }

        do {
            _ = try HuntTransferService.importHunt(
                from: package,
                parentPIN: parentPIN,
                in: modelContext
            )
            dismiss()
        } catch {
            modelContext.rollback()
            importError = error.localizedDescription
        }
    }
}
