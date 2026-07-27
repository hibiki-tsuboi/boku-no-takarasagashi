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
    @State private var isShowingDiscardConfirmation = false

    private let initialDraft: HuntDraft

    init(hunt: TreasureHunt?, template: HuntTemplate? = nil) {
        self.hunt = hunt
        let initialDraft = HuntDraft(hunt: hunt, template: template)
        self.initialDraft = initialDraft
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("例：おうちの大冒険", text: $draft.title)
                            .onChange(of: draft.title) { _, newValue in
                                draft.title = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumHuntTitleLength
                                )
                            }

                        CharacterLimitStatus(
                            count: draft.title.count,
                            maximum: TreasureContentLimits.maximumHuntTitleLength
                        )
                    }
                    .listRowSeparator(.hidden)

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
                    .foregroundStyle(TreasureTheme.secondaryText)
                    .treasureCompactCard()
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
                        close()
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
            .confirmationDialog(
                "変更を破棄しますか？",
                isPresented: $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("変更を破棄", role: .destructive) {
                    dismiss()
                }
                Button("編集を続ける", role: .cancel) {}
            } message: {
                Text("まだ保存されていない変更があります。")
            }
        }
        .tint(TreasureTheme.teal)
        .interactiveDismissDisabled(hasUnsavedChanges)
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
        let stagesAreValid = !draft.stages.isEmpty
            && draft.stages.count <= TreasureContentLimits.maximumStageCount
            && draft.stages.allSatisfy { stage in
                TreasureContentValidator.isValidRequiredText(
                    stage.hint,
                    maximumLength: TreasureContentLimits.maximumHintLength
                )
                    && stage.extraHints.count
                        <= TreasureContentLimits.maximumExtraHintCount
                    && stage.extraHints.allSatisfy { extraHint in
                        TreasureContentValidator.isValidRequiredText(
                            extraHint.text,
                            maximumLength: TreasureContentLimits
                                .maximumExtraHintLength
                        )
                    }
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
            && stagesAreValid
            && photosAreValid
    }

    private var totalPhotoByteCount: Int {
        draft.stages.reduce(into: 0) { total, stage in
            total += stage.hintImageData?.count ?? 0
            total += stage.extraHints.reduce(into: 0) { hintTotal, extraHint in
                hintTotal += extraHint.imageData?.count ?? 0
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        draft != initialDraft
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

    private func close() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }

        isShowingDiscardConfirmation = true
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
                completionMessage: draft.completionMessage.trimmed
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
        destination.revealedExtraHintCount = nil
        destination.extraHintsUsedCount = 0
        destination.updatedAt = .now

        let previousStages = destination.stages
        destination.stages.removeAll()
        previousStages.forEach(modelContext.delete)

        for (index, stageDraft) in draft.stages.enumerated() {
            let extraHints = stageDraft.availableExtraHints
            let firstExtraHint = extraHints.first
            let secondExtraHint = extraHints.dropFirst().first
            let thirdExtraHint = extraHints.dropFirst(2).first
            let stage = TreasureStage(
                orderIndex: index,
                hint: stageDraft.hint.trimmed,
                extraHint: firstExtraHint?.text,
                extraHint2: secondExtraHint?.text,
                extraHint3: thirdExtraHint?.text,
                hintImageData: stageDraft.hintImageData,
                extraHintImageData: firstExtraHint?.imageData,
                extraHint2ImageData: secondExtraHint?.imageData,
                extraHint3ImageData: thirdExtraHint?.imageData,
                discoveryMessage: stageDraft.discoveryMessage.trimmed,
                verification: stageDraft.verification,
                passphrase: stageDraft.passphrase.trimmed,
                verificationToken: stageDraft.verificationToken,
                nfcWrittenVerificationToken:
                    stageDraft.nfcWrittenVerificationToken,
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

private struct HuntDraft: Equatable {
    var title: String
    var openingMessage: String
    var completionMessage: String
    var stages: [StageDraft]

    init(hunt: TreasureHunt?, template: HuntTemplate? = nil) {
        title = hunt?.title ?? "おうちの宝探し"
        openingMessage = hunt?.openingMessage ?? "ヒントをたどって、さいごの宝を見つけよう！"
        completionMessage = hunt?.completionMessage ?? "ぜんぶの宝を見つけた！おめでとう！"

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
                    extraHints: [stage.extraHint],
                    discoveryMessage: stage.discoveryMessage
                )
            }
        } else {
            stages = [StageDraft()]
        }
    }
}

private struct StageDraft: Identifiable, Equatable {
    let id: UUID
    var hint: String
    var extraHints: [ExtraHintDraft]
    var hintImageData: Data?
    var discoveryMessage: String
    var verification: TreasureVerification
    var passphrase: String
    var verificationToken: String
    var nfcWrittenVerificationToken: String?

    init(
        id: UUID = UUID(),
        hint: String = "",
        extraHints: [String] = [],
        hintImageData: Data? = nil,
        discoveryMessage: String = "やったね！宝を見つけた！",
        verification: TreasureVerification = .honesty,
        passphrase: String = "",
        verificationToken: String = UUID().uuidString,
        nfcWrittenVerificationToken: String? = nil
    ) {
        self.id = id
        self.hint = hint
        self.extraHints = extraHints.map { hint in
            ExtraHintDraft(text: hint)
        }
        self.hintImageData = hintImageData
        self.discoveryMessage = discoveryMessage
        self.verification = verification
        self.passphrase = passphrase
        self.verificationToken = verificationToken
        self.nfcWrittenVerificationToken = nfcWrittenVerificationToken
    }

    init(stage: TreasureStage) {
        id = stage.id
        hint = stage.hint
        extraHints = stage.availableExtraHintContents.map { content in
            ExtraHintDraft(
                text: content.text,
                imageData: content.imageData
            )
        }
        hintImageData = stage.hintImageData
        discoveryMessage = stage.discoveryMessage
        verification = stage.verification
        passphrase = stage.passphrase
        verificationToken = stage.verificationToken ?? stage.id.uuidString
        nfcWrittenVerificationToken = stage.nfcWrittenVerificationToken
    }

    var verificationPayload: String {
        TreasurePayload.make(token: verificationToken)
    }

    var nfcTagWasWritten: Bool {
        nfcWrittenVerificationToken == verificationToken
    }

    var availableExtraHints: [ExtraHintDraft] {
        extraHints
            .compactMap { extraHint in
                let text = extraHint.text.trimmed
                guard !text.isEmpty else { return nil }
                return ExtraHintDraft(
                    id: extraHint.id,
                    text: text,
                    imageData: extraHint.imageData
                )
            }
    }

    var hasPhotos: Bool {
        hintImageData != nil
            || extraHints.contains { $0.imageData != nil }
    }
}

private struct ExtraHintDraft: Identifiable, Equatable {
    let id: UUID
    var text: String
    var imageData: Data?

    init(
        id: UUID = UUID(),
        text: String = "",
        imageData: Data? = nil
    ) {
        self.id = id
        self.text = text
        self.imageData = imageData
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
                    .foregroundStyle(
                        isLast ? .white : TreasureTheme.tealText
                    )
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
                    .foregroundStyle(TreasureTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if stage.hasPhotos {
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.coralText)
                    .accessibilityLabel("写真つきヒントあり")
            }

            Image(systemName: stage.verification.systemImage)
                .font(.caption)
                .foregroundStyle(TreasureTheme.tealText)
                .accessibilityLabel("発見方法、\(stage.verification.title)")
        }
        .padding(.vertical, 3)
    }
}

enum StageEditorValidationField: Hashable {
    case hint
    case extraHint(UUID)
    case passphrase
}

enum StageEditorValidator {
    static func firstInvalidField(
        hint: String,
        extraHints: [(id: UUID, text: String)],
        verification: TreasureVerification,
        passphrase: String
    ) -> StageEditorValidationField? {
        if !TreasureContentValidator.isValidRequiredText(
            hint,
            maximumLength: TreasureContentLimits.maximumHintLength
        ) {
            return .hint
        }

        if let invalidExtraHint = extraHints.first(where: {
            !TreasureContentValidator.isValidRequiredText(
                $0.text,
                maximumLength: TreasureContentLimits.maximumExtraHintLength
            )
        }) {
            return .extraHint(invalidExtraHint.id)
        }

        if verification == .passphrase,
           !TreasureContentValidator.isValidRequiredText(
               passphrase,
               maximumLength: TreasureContentLimits.maximumPassphraseLength
           ) {
            return .passphrase
        }

        return nil
    }
}

private struct StageEditorView: View {
    @Binding private var stage: StageDraft
    @State private var draft: StageDraft
    @State private var validationWasRequested = false
    @FocusState private var focusedField: StageEditorValidationField?

    let number: Int
    let isLast: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        stage: Binding<StageDraft>,
        number: Int,
        isLast: Bool
    ) {
        _stage = stage
        _draft = State(initialValue: stage.wrappedValue)
        self.number = number
        self.isLast = isLast
    }

    var body: some View {
        Form {
            if validationWasRequested, firstInvalidField != nil {
                Section {
                    Label(
                        "入力していない必須項目があります",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TreasureTheme.coralText)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $draft.hint)
                        .frame(minHeight: 110)
                        .focused($focusedField, equals: .hint)
                        .stageValidationBorder(isVisible: hintIsInvalid)
                        .onChange(of: draft.hint) { _, newValue in
                            draft.hint = TreasureContentValidator.limited(
                                newValue,
                                maximumLength: TreasureContentLimits.maximumHintLength
                            )
                        }

                    if hintIsInvalid {
                        StageValidationMessage(
                            text: "ヒントを入力してください"
                        )
                    }
                }
                .id(StageEditorValidationField.hint)

                VStack(alignment: .leading, spacing: 10) {
                    Text("写真（任意）")
                        .font(.subheadline.weight(.semibold))

                    HintPhotoEditor(imageData: $draft.hintImageData)
                }
            } header: {
                Text("ヒント")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("隠し場所を直接言わず、子どもが考えられる言葉にします。")
                    Text("写真には、隠し場所の一部分など答えがすぐ分からないものがおすすめです。")
                    CharacterLimitStatus(
                        count: draft.hint.count,
                        maximum: TreasureContentLimits.maximumHintLength
                    )
                }
            }

            Section {
                ForEach($draft.extraHints) { $extraHint in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(
                                "おたすけヒント "
                                    + "\(extraHintNumber(for: extraHint.id))"
                            )
                            .font(.subheadline.weight(.semibold))

                            Spacer()

                            Button(role: .destructive) {
                                removeExtraHint(extraHint.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                "おたすけヒント "
                                    + "\(extraHintNumber(for: extraHint.id))を削除"
                            )
                        }

                        TextEditor(text: $extraHint.text)
                            .frame(minHeight: 82)
                            .focused(
                                $focusedField,
                                equals: .extraHint(extraHint.id)
                            )
                            .stageValidationBorder(
                                isVisible: extraHintIsInvalid(extraHint.text)
                            )
                            .onChange(of: extraHint.text) { _, newValue in
                                extraHint.text = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumExtraHintLength
                                )
                            }

                        if extraHintIsInvalid(extraHint.text) {
                            StageValidationMessage(
                                text: "おたすけヒントを入力するか、削除してください"
                            )
                        }

                        CharacterLimitStatus(
                            count: extraHint.text.count,
                            maximum: TreasureContentLimits.maximumExtraHintLength
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("写真（任意）")
                                .font(.subheadline.weight(.semibold))

                            HintPhotoEditor(
                                imageData: $extraHint.imageData,
                                photoAccessibilityLabel:
                                    "おたすけヒント "
                                    + "\(extraHintNumber(for: extraHint.id))の写真"
                            )
                        }
                    }
                    .id(StageEditorValidationField.extraHint(extraHint.id))
                }

                if draft.extraHints.count
                    < TreasureContentLimits.maximumExtraHintCount {
                    Button(action: addExtraHint) {
                        Label(
                            "おたすけヒントを追加",
                            systemImage: "plus.circle.fill"
                        )
                    }
                }
            } header: {
                Text("おたすけヒント（任意）")
            } footer: {
                Text(
                    "通常のヒントで難しいときに、上から順番に1つずつ開きます"
                        + "（最大\(TreasureContentLimits.maximumExtraHintCount)個）。"
                )
            }

            Section {
                if verificationIsUnavailable {
                    LabeledContent("発見方法") {
                        Label(
                            "\(draft.verification.title)（利用不可）",
                            systemImage: draft.verification.systemImage
                        )
                        .foregroundStyle(TreasureTheme.coralText)
                    }
                    .listRowSeparator(.hidden, edges: .bottom)

                    Label(
                        "この端末では\(draft.verification.title)を使えません。保存するには発見方法を変更してください。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.coralText)

                    if QRCodeScannerCapability.isSupported,
                       draft.verification != .qrCode {
                        Button {
                            draft.verification = .qrCode
                        } label: {
                            Label("QRコードに変更", systemImage: "qrcode")
                        }
                    }

                    Button {
                        draft.verification = .honesty
                    } label: {
                        Label("「みつけた！」に変更", systemImage: "hand.thumbsup.fill")
                    }
                } else {
                    Picker("発見方法", selection: $draft.verification) {
                        ForEach(availableVerifications) { verification in
                            Label(verification.title, systemImage: verification.systemImage)
                                .tag(verification)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .listRowSeparator(.hidden, edges: .bottom)
                }

                if draft.verification == .passphrase {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("宝と一緒に置く合言葉", text: $draft.passphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .passphrase)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .stageValidationBorder(
                                isVisible: passphraseIsInvalid
                            )
                            .onChange(of: draft.passphrase) { _, newValue in
                                draft.passphrase = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumPassphraseLength
                                )
                            }

                        if passphraseIsInvalid {
                            StageValidationMessage(
                                text: "合言葉を入力してください"
                            )
                        }

                        CharacterLimitStatus(
                            count: draft.passphrase.count,
                            maximum: TreasureContentLimits.maximumPassphraseLength
                        )
                    }
                    .id(StageEditorValidationField.passphrase)
                }

                if draft.verification == .qrCode && QRCodeScannerCapability.isSupported {
                    NavigationLink {
                        QRCodePreparationView(
                            payload: draft.verificationPayload,
                            treasureNumber: number
                        )
                    } label: {
                        Label("QRコードを表示・共有", systemImage: "qrcode")
                    }
                }

                if draft.verification == .nfc && NFCSessionController.isAvailable {
                    NFCWriterControl(
                        payload: draft.verificationPayload,
                        wasPreviouslyWritten: draft.nfcTagWasWritten,
                        onWriteSuccess: {
                            draft.nfcWrittenVerificationToken =
                                draft.verificationToken
                        }
                    )
                }
            } header: {
                Text("見つけたことの確認")
            } footer: {
                Text(verificationHelp)
            }

            Section {
                TextEditor(text: $draft.discoveryMessage)
                    .frame(minHeight: 82)
                    .onChange(of: draft.discoveryMessage) { _, newValue in
                        draft.discoveryMessage = TreasureContentValidator.limited(
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
                        count: draft.discoveryMessage.count,
                        maximum: TreasureContentLimits.maximumDiscoveryMessageLength
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .treasureBackground(.editor)
        .navigationTitle(isLast ? "宝 \(number)・ゴール" : "宝 \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("入力完了") {
                    finishEditing()
                }
                .fontWeight(.semibold)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("変更は「入力完了」で前の画面に反映されます。最後に「保存」を押してください。")
                .font(.footnote)
                .foregroundStyle(TreasureTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.regularMaterial)
        }
        .tint(TreasureTheme.teal)
    }

    private func extraHintNumber(for id: UUID) -> Int {
        guard let index = draft.extraHints.firstIndex(
            where: { $0.id == id }
        ) else {
            return 1
        }
        return index + 1
    }

    private func addExtraHint() {
        guard draft.extraHints.count
            < TreasureContentLimits.maximumExtraHintCount else {
            return
        }
        draft.extraHints.append(ExtraHintDraft())
    }

    private func removeExtraHint(_ id: UUID) {
        draft.extraHints.removeAll { $0.id == id }
    }

    private func finishEditing() {
        validationWasRequested = true
        if let firstInvalidField {
            focusedField = firstInvalidField
            return
        }

        stage = draft
        dismiss()
    }

    private var firstInvalidField: StageEditorValidationField? {
        StageEditorValidator.firstInvalidField(
            hint: draft.hint,
            extraHints: draft.extraHints.map {
                (id: $0.id, text: $0.text)
            },
            verification: draft.verification,
            passphrase: draft.passphrase
        )
    }

    private var hintIsInvalid: Bool {
        validationWasRequested
            && !TreasureContentValidator.isValidRequiredText(
                draft.hint,
                maximumLength: TreasureContentLimits.maximumHintLength
            )
    }

    private func extraHintIsInvalid(_ text: String) -> Bool {
        validationWasRequested
            && !TreasureContentValidator.isValidRequiredText(
                text,
                maximumLength: TreasureContentLimits.maximumExtraHintLength
            )
    }

    private var passphraseIsInvalid: Bool {
        validationWasRequested
            && draft.verification == .passphrase
            && !TreasureContentValidator.isValidRequiredText(
                draft.passphrase,
                maximumLength: TreasureContentLimits.maximumPassphraseLength
            )
    }

    private var verificationHelp: String {
        switch draft.verification {
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
        switch draft.verification {
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

private struct StageValidationMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(TreasureTheme.coralText)
    }
}

private extension View {
    func stageValidationBorder(isVisible: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isVisible ? TreasureTheme.coralText : .clear,
                    lineWidth: 2
                )
                .allowsHitTesting(false)
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
                    ? TreasureTheme.secondaryText
                    : TreasureTheme.coralText
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(maximum)文字中\(count)文字")
    }
}
