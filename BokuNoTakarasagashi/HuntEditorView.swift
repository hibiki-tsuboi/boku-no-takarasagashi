//
//  HuntEditorView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct HuntEditorView: View {
    let hunt: TreasureHunt?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: HuntDraft
    @State private var saveError: String?

    init(hunt: TreasureHunt?, template: HuntTemplate? = nil) {
        self.hunt = hunt
        _draft = State(initialValue: HuntDraft(hunt: hunt, template: template))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：おうちの大冒険", text: $draft.title)
                        .onChange(of: draft.title) { _, newValue in
                            draft.title = TreasureContentValidator.limited(
                                newValue,
                                maximumLength: TreasureContentLimits.maximumHuntTitleLength
                            )
                        }

                    CharacterLimitStatus(
                        count: draft.title.count,
                        maximum: TreasureContentLimits.maximumHuntTitleLength
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("はじまりのメッセージ")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $draft.openingMessage)
                            .frame(minHeight: 72)
                            .onChange(of: draft.openingMessage) { _, newValue in
                                draft.openingMessage = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumOpeningMessageLength
                                )
                            }

                        CharacterLimitStatus(
                            count: draft.openingMessage.count,
                            maximum: TreasureContentLimits.maximumOpeningMessageLength
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("クリアしたときのメッセージ")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $draft.completionMessage)
                            .frame(minHeight: 72)
                            .onChange(of: draft.completionMessage) { _, newValue in
                                draft.completionMessage = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumCompletionMessageLength
                                )
                            }

                        CharacterLimitStatus(
                            count: draft.completionMessage.count,
                            maximum: TreasureContentLimits.maximumCompletionMessageLength
                        )
                    }
                } header: {
                    Text("宝探し")
                } footer: {
                    Text("メッセージは、さがす人に表示されます。")
                }

                Section {
                    ForEach(Array(draft.stages.enumerated()), id: \.element.id) { index, stage in
                        NavigationLink {
                            StageEditorView(
                                stage: $draft.stages[index],
                                number: index + 1,
                                isLast: index == draft.stages.count - 1
                            )
                        } label: {
                            StageRow(
                                stage: stage,
                                number: index + 1,
                                isLast: index == draft.stages.count - 1
                            )
                        }
                    }
                    .onDelete(perform: deleteStages)
                    .onMove(perform: moveStages)

                    Button {
                        draft.stages.append(StageDraft())
                    } label: {
                        Label("宝を追加", systemImage: "plus.circle.fill")
                    }
                    .disabled(
                        draft.stages.count
                            >= TreasureContentLimits.maximumStageCount
                    )
                } header: {
                    HStack {
                        Text("宝の順番")
                        Spacer()
                        if draft.stages.count > 1 {
                            EditButton()
                                .font(.caption.weight(.semibold))
                                .textCase(nil)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            "上から順にヒントが開きます。最後の宝がゴールです"
                                + "（最大\(TreasureContentLimits.maximumStageCount)個）。"
                        )

                        if totalPhotoByteCount
                            > TreasureContentLimits.maximumTotalPhotoByteCount {
                            Label(
                                "写真の合計を20MB以内にしてください。",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(TreasureTheme.coralText)
                        }
                    }
                }

                Section {
                    SecureField(
                        hunt == nil ? "4桁の数字" : "変更するときだけ入力",
                        text: $draft.parentPIN
                    )
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: draft.parentPIN) { _, newValue in
                        draft.parentPIN = ParentPIN.digitsOnly(newValue)
                    }
                } header: {
                    Text("おうちの人用PIN")
                } footer: {
                    if hunt == nil {
                        Text("プレイ中に作成・編集画面へ戻るために使います。忘れない4桁を設定してください。")
                    } else {
                        Text("現在のPINを変えない場合は、空欄のまま保存してください。")
                    }
                }

                Section {
                    Label("道路・水辺・高い場所・立入禁止の場所には宝を隠さないでください。", systemImage: "exclamationmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(TreasureTheme.coralText)
                } header: {
                    Text("安全")
                }
            }
            .scrollContentBackground(.hidden)
            .treasureBackground(.editor)
            .navigationTitle(hunt == nil ? "宝探しをつくる" : "宝探しを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .alert("保存できませんでした", isPresented: saveErrorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "もう一度ためしてください。")
            }
        }
        .tint(TreasureTheme.teal)
    }

    private var canSave: Bool {
        let titleIsValid = TreasureContentValidator.isValidRequiredText(
            draft.title,
            maximumLength: TreasureContentLimits.maximumHuntTitleLength
        )
        let messagesAreValid = TreasureContentValidator.isWithinLimit(
            draft.openingMessage,
            maximumLength: TreasureContentLimits.maximumOpeningMessageLength
        ) && TreasureContentValidator.isWithinLimit(
            draft.completionMessage,
            maximumLength: TreasureContentLimits.maximumCompletionMessageLength
        )
        let pinIsValid = hunt == nil
            ? draft.parentPIN.count == 4
            : draft.parentPIN.isEmpty || draft.parentPIN.count == 4
        let stagesAreValid = !draft.stages.isEmpty
            && draft.stages.count <= TreasureContentLimits.maximumStageCount
            && draft.stages.allSatisfy { stage in
                TreasureContentValidator.isValidRequiredText(
                    stage.hint,
                    maximumLength: TreasureContentLimits.maximumHintLength
                )
                    && TreasureContentValidator.isWithinLimit(
                        stage.extraHint,
                        maximumLength: TreasureContentLimits.maximumExtraHintLength
                    )
                    && TreasureContentValidator.isWithinLimit(
                        stage.discoveryMessage,
                        maximumLength: TreasureContentLimits.maximumDiscoveryMessageLength
                    )
                    && TreasureContentValidator.isWithinLimit(
                        stage.passphrase,
                        maximumLength: TreasureContentLimits.maximumPassphraseLength
                    )
                    && (
                        stage.verification != .passphrase
                            || TreasureContentValidator.isValidRequiredText(
                                stage.passphrase,
                                maximumLength: TreasureContentLimits.maximumPassphraseLength
                            )
                    )
                    && (stage.verification != .qrCode || QRCodeScannerCapability.isSupported)
                    && (stage.verification != .nfc || NFCSessionController.isAvailable)
            }
        let photosAreValid = totalPhotoByteCount
            <= TreasureContentLimits.maximumTotalPhotoByteCount

        return titleIsValid
            && messagesAreValid
            && pinIsValid
            && stagesAreValid
            && photosAreValid
    }

    private var totalPhotoByteCount: Int {
        draft.stages.reduce(into: 0) { total, stage in
            total += stage.hintImageData?.count ?? 0
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isPresented in
                if !isPresented {
                    saveError = nil
                }
            }
        )
    }

    private func deleteStages(at offsets: IndexSet) {
        draft.stages.remove(atOffsets: offsets)
    }

    private func moveStages(from source: IndexSet, to destination: Int) {
        draft.stages.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        guard canSave else { return }

        let destination: TreasureHunt
        if let hunt {
            destination = hunt
        } else {
            destination = TreasureHunt(
                title: draft.title.trimmed,
                openingMessage: draft.openingMessage.trimmed,
                completionMessage: draft.completionMessage.trimmed,
                parentPIN: draft.parentPIN
            )
            modelContext.insert(destination)
        }

        destination.title = draft.title.trimmed
        destination.openingMessage = draft.openingMessage.trimmed
        destination.completionMessage = draft.completionMessage.trimmed
        destination.currentStageIndex = 0
        destination.playState = .ready
        destination.isChildModeLocked = false
        destination.revealedExtraHintStageID = nil
        destination.extraHintsUsedCount = 0
        destination.updatedAt = .now

        if !draft.parentPIN.isEmpty {
            destination.parentPINDigest = ParentPIN.digest(draft.parentPIN)
        }

        let previousStages = destination.stages
        destination.stages.removeAll()
        previousStages.forEach(modelContext.delete)

        for (index, stageDraft) in draft.stages.enumerated() {
            let stage = TreasureStage(
                orderIndex: index,
                hint: stageDraft.hint.trimmed,
                extraHint: stageDraft.extraHint.trimmed.isEmpty
                    ? nil
                    : stageDraft.extraHint.trimmed,
                hintImageData: stageDraft.hintImageData,
                discoveryMessage: stageDraft.discoveryMessage.trimmed,
                verification: stageDraft.verification,
                passphrase: stageDraft.passphrase.trimmed,
                verificationToken: stageDraft.verificationToken,
                hunt: destination
            )
            modelContext.insert(stage)
            destination.stages.append(stage)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

private struct HuntDraft {
    var title: String
    var openingMessage: String
    var completionMessage: String
    var parentPIN: String
    var stages: [StageDraft]

    init(hunt: TreasureHunt?, template: HuntTemplate? = nil) {
        title = hunt?.title ?? ""
        openingMessage = hunt?.openingMessage ?? "ヒントをたどって、さいごの宝を見つけよう！"
        completionMessage = hunt?.completionMessage ?? "ぜんぶの宝を見つけた！おめでとう！"
        parentPIN = ""

        if let hunt {
            stages = hunt.sortedStages.map { stage in
                StageDraft(stage: stage)
            }
        } else if let template {
            title = template.title
            openingMessage = template.openingMessage
            completionMessage = template.completionMessage
            stages = template.stages.map { stage in
                StageDraft(
                    hint: stage.hint,
                    extraHint: stage.extraHint,
                    discoveryMessage: stage.discoveryMessage
                )
            }
        } else {
            stages = [StageDraft()]
        }
    }
}

private struct StageDraft: Identifiable {
    let id: UUID
    var hint: String
    var extraHint: String
    var hintImageData: Data?
    var discoveryMessage: String
    var verification: TreasureVerification
    var passphrase: String
    var verificationToken: String

    init(
        id: UUID = UUID(),
        hint: String = "",
        extraHint: String = "",
        hintImageData: Data? = nil,
        discoveryMessage: String = "やったね！宝を見つけた！",
        verification: TreasureVerification = .honesty,
        passphrase: String = "",
        verificationToken: String = UUID().uuidString
    ) {
        self.id = id
        self.hint = hint
        self.extraHint = extraHint
        self.hintImageData = hintImageData
        self.discoveryMessage = discoveryMessage
        self.verification = verification
        self.passphrase = passphrase
        self.verificationToken = verificationToken
    }

    init(stage: TreasureStage) {
        id = stage.id
        hint = stage.hint
        extraHint = stage.extraHint ?? ""
        hintImageData = stage.hintImageData
        discoveryMessage = stage.discoveryMessage
        verification = stage.verification
        passphrase = stage.passphrase
        verificationToken = stage.verificationToken ?? stage.id.uuidString
    }

    var verificationPayload: String {
        TreasurePayload.make(token: verificationToken)
    }
}

private struct StageRow: View {
    let stage: StageDraft
    let number: Int
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isLast ? TreasureTheme.gold : TreasureTheme.teal.opacity(0.15))

                Image(systemName: isLast ? "gift.fill" : "\(number).circle.fill")
                    .foregroundStyle(isLast ? .white : TreasureTheme.teal)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("宝 \(number)")
                        .font(.headline)

                    if isLast {
                        Text("ゴール")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(TreasureTheme.gold.opacity(0.2), in: Capsule())
                    }
                }

                Text(stage.hint.trimmed.isEmpty ? "ヒントを入力してください" : stage.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if stage.hintImageData != nil {
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.coralText)
                    .accessibilityLabel("写真ヒントあり")
            }

            Image(systemName: stage.verification.systemImage)
                .font(.caption)
                .foregroundStyle(TreasureTheme.teal)
                .accessibilityLabel("発見方法、\(stage.verification.title)")
        }
        .padding(.vertical, 3)
    }
}

private struct StageEditorView: View {
    @Binding var stage: StageDraft

    let number: Int
    let isLast: Bool

    var body: some View {
        Form {
            Section {
                TextEditor(text: $stage.hint)
                    .frame(minHeight: 110)
                    .onChange(of: stage.hint) { _, newValue in
                        stage.hint = TreasureContentValidator.limited(
                            newValue,
                            maximumLength: TreasureContentLimits.maximumHintLength
                        )
                    }
            } header: {
                Text("ヒント")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("隠し場所を直接言わず、子どもが考えられる言葉にします。")
                    CharacterLimitStatus(
                        count: stage.hint.count,
                        maximum: TreasureContentLimits.maximumHintLength
                    )
                }
            }

            Section {
                TextEditor(text: $stage.extraHint)
                    .frame(minHeight: 82)
                    .onChange(of: stage.extraHint) { _, newValue in
                        stage.extraHint = TreasureContentValidator.limited(
                            newValue,
                            maximumLength: TreasureContentLimits.maximumExtraHintLength
                        )
                    }
            } header: {
                Text("おたすけヒント（任意）")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("通常のヒントで難しいときだけ、さがす人が自分で開けます。空欄なら表示されません。")
                    CharacterLimitStatus(
                        count: stage.extraHint.count,
                        maximum: TreasureContentLimits.maximumExtraHintLength
                    )
                }
            }

            Section {
                HintPhotoEditor(imageData: $stage.hintImageData)
            } header: {
                Text("写真ヒント（任意）")
            } footer: {
                Text("隠し場所の一部分など、答えがすぐ分からない写真がおすすめです。")
            }

            Section {
                if verificationIsUnavailable {
                    LabeledContent("発見方法") {
                        Label(
                            "\(stage.verification.title)（利用不可）",
                            systemImage: stage.verification.systemImage
                        )
                        .foregroundStyle(TreasureTheme.coralText)
                    }

                    Label(
                        "この端末では\(stage.verification.title)を使えません。保存するには発見方法を変更してください。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.coralText)

                    if QRCodeScannerCapability.isSupported,
                       stage.verification != .qrCode {
                        Button {
                            stage.verification = .qrCode
                        } label: {
                            Label("QRコードに変更", systemImage: "qrcode")
                        }
                    }

                    Button {
                        stage.verification = .honesty
                    } label: {
                        Label("「みつけた！」に変更", systemImage: "hand.thumbsup.fill")
                    }
                } else {
                    Picker("発見方法", selection: $stage.verification) {
                        ForEach(availableVerifications) { verification in
                            Label(verification.title, systemImage: verification.systemImage)
                                .tag(verification)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if stage.verification == .passphrase {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("宝と一緒に置く合言葉", text: $stage.passphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: stage.passphrase) { _, newValue in
                                stage.passphrase = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumPassphraseLength
                                )
                            }

                        CharacterLimitStatus(
                            count: stage.passphrase.count,
                            maximum: TreasureContentLimits.maximumPassphraseLength
                        )
                    }
                }

                if stage.verification == .qrCode && QRCodeScannerCapability.isSupported {
                    NavigationLink {
                        QRCodePreparationView(
                            payload: stage.verificationPayload,
                            treasureNumber: number
                        )
                    } label: {
                        Label("QRコードを表示・共有", systemImage: "qrcode")
                    }
                }

                if stage.verification == .nfc && NFCSessionController.isAvailable {
                    NFCWriterControl(payload: stage.verificationPayload)
                }
            } header: {
                Text("見つけたことの確認")
            } footer: {
                Text(verificationHelp)
            }

            Section {
                TextEditor(text: $stage.discoveryMessage)
                    .frame(minHeight: 82)
                    .onChange(of: stage.discoveryMessage) { _, newValue in
                        stage.discoveryMessage = TreasureContentValidator.limited(
                            newValue,
                            maximumLength: TreasureContentLimits
                                .maximumDiscoveryMessageLength
                        )
                    }
            } header: {
                Text("見つけたときのひとこと")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isLast
                        ? "このあと、宝探し全体のクリアメッセージを表示します。"
                        : "このメッセージのあとに、次のヒントが開きます。"
                    )

                    CharacterLimitStatus(
                        count: stage.discoveryMessage.count,
                        maximum: TreasureContentLimits.maximumDiscoveryMessageLength
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .treasureBackground(.editor)
        .navigationTitle(isLast ? "宝 \(number)・ゴール" : "宝 \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .tint(TreasureTheme.teal)
    }

    private var verificationHelp: String {
        switch stage.verification {
        case .honesty:
            "準備は不要です。見つけたら「みつけた！」ボタンを押します。"
        case .passphrase:
            "紙に合言葉を書いて宝と一緒に置いてください。大文字・小文字や全角・半角の違いは無視します。"
        case .qrCode:
            if QRCodeScannerCapability.isSupported {
                "QRコード画像を印刷するか別の端末に表示して、宝と一緒に置いてください。"
            } else {
                "この端末ではQRコードを読み取れません。合言葉など別の発見方法へ変更してください。"
            }
        case .nfc:
            if NFCSessionController.isAvailable {
                "書き込み可能なNDEF対応NFCタグを使います。書き込み後、そのタグを宝と一緒に置いてください。"
            } else {
                "この端末ではNFCを利用できません。QRコードなど別の発見方法へ変更してください。"
            }
        }
    }

    private var verificationIsUnavailable: Bool {
        switch stage.verification {
        case .qrCode:
            !QRCodeScannerCapability.isSupported
        case .nfc:
            !NFCSessionController.isAvailable
        case .honesty, .passphrase:
            false
        }
    }

    private var availableVerifications: [TreasureVerification] {
        TreasureVerification.allCases.filter {
            switch $0 {
            case .qrCode:
                QRCodeScannerCapability.isSupported
            case .nfc:
                NFCSessionController.isAvailable
            case .honesty, .passphrase:
                true
            }
        }
    }
}

private extension String {
    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CharacterLimitStatus: View {
    let count: Int
    let maximum: Int

    var body: some View {
        Text("\(count) / \(maximum)文字")
            .font(.caption)
            .foregroundStyle(
                count <= maximum
                    ? Color.secondary
                    : TreasureTheme.coralText
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(maximum)文字中\(count)文字")
    }
}
