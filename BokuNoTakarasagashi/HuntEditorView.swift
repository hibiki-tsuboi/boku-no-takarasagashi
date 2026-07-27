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
            && stagesAreValid
            && photosAreValid
    }

    private var totalPhotoByteCount: Int {
        draft.stages.reduce(into: 0) { total, stage in
            total += stage.hintImageData?.count ?? 0
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
        destination.extraHintsUsedCount = 0
        destination.updatedAt = .now

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

private struct HuntDraft: Equatable {
    var title: String
    var openingMessage: String
    var completionMessage: String
    var stages: [StageDraft]

    init(hunt: TreasureHunt?, template: HuntTemplate? = nil) {
        title = hunt?.title ?? ""
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
                    extraHint: stage.extraHint,
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

            if stage.hintImageData != nil {
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.coralText)
                    .accessibilityLabel("写真ヒントあり")
            }

            Image(systemName: stage.verification.systemImage)
                .font(.caption)
                .foregroundStyle(TreasureTheme.tealText)
                .accessibilityLabel("発見方法、\(stage.verification.title)")
        }
        .padding(.vertical, 3)
    }
}

private struct StageEditorView: View {
    @Binding private var stage: StageDraft
    @State private var draft: StageDraft

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
            Section {
                TextEditor(text: $draft.hint)
                    .frame(minHeight: 110)
                    .onChange(of: draft.hint) { _, newValue in
                        draft.hint = TreasureContentValidator.limited(
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
                        count: draft.hint.count,
                        maximum: TreasureContentLimits.maximumHintLength
                    )
                }
            }

            Section {
                TextEditor(text: $draft.extraHint)
                    .frame(minHeight: 82)
                    .onChange(of: draft.extraHint) { _, newValue in
                        draft.extraHint = TreasureContentValidator.limited(
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
                        count: draft.extraHint.count,
                        maximum: TreasureContentLimits.maximumExtraHintLength
                    )
                }
            }

            Section {
                HintPhotoEditor(imageData: $draft.hintImageData)
            } header: {
                Text("写真ヒント（任意）")
            } footer: {
                Text("隠し場所の一部分など、答えがすぐ分からない写真がおすすめです。")
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
                }

                if draft.verification == .passphrase {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("宝と一緒に置く合言葉", text: $draft.passphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: draft.passphrase) { _, newValue in
                                draft.passphrase = TreasureContentValidator.limited(
                                    newValue,
                                    maximumLength: TreasureContentLimits
                                        .maximumPassphraseLength
                                )
                            }

                        CharacterLimitStatus(
                            count: draft.passphrase.count,
                            maximum: TreasureContentLimits.maximumPassphraseLength
                        )
                    }
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
                    NFCWriterControl(payload: draft.verificationPayload)
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
                    stage = draft
                    dismiss()
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
