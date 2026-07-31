//
//  PlaySessionView.swift
//  BokuNoTakarasagashi
//

import Accessibility
import SwiftData
import SwiftUI

struct PlaySessionView: View {
    let hunt: TreasureHunt

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var audioSettings: AppAudioSettings
    @EnvironmentObject private var musicCoordinator: BackgroundMusicCoordinator
    @Query private var hunts: [TreasureHunt]

    @State private var phase: PlayPhase
    @State private var safetyIsConfirmed = false
    @State private var isShowingCancellationConfirmation = false
    @State private var isShowingQRCodeScanner = false
    @State private var isShowingDiscovery = false
    @State private var isShowingExtraHintConfirmation = false
    @State private var passphrase = ""
    @State private var answerError: String?
    @State private var persistenceError: String?
    @State private var sessionError: String?
    @State private var completedRecord: AdventureRecord?
    @State private var musicRequestID: UUID?
    @FocusState private var passphraseIsFocused: Bool
    @StateObject private var speechController = HintSpeechController()
    @StateObject private var soundPlayer = GameSoundPlayer()

    init(hunt: TreasureHunt) {
        self.hunt = hunt

        let initialPhase: PlayPhase
        if hunt.isChildModeLocked {
            initialPhase = hunt.playState == .completed ? .completed : .playing
        } else {
            initialPhase = .preparation
        }
        _phase = State(initialValue: initialPhase)
    }

    var body: some View {
        ZStack {
            TreasureBackground(style: backgroundStyle) {
                switch phase {
                case .preparation:
                    HuntPreparationView(
                        hunt: hunt,
                        onClose: { dismiss() },
                        onContinue: {
                            withAnimation(reduceMotion ? nil : .easeInOut) {
                                phase = .safety
                            }
                        }
                    )

                case .safety:
                    SafetyCheckView(
                        isConfirmed: $safetyIsConfirmed,
                        onClose: { dismiss() },
                        onContinue: {
                            withAnimation(reduceMotion ? nil : .easeInOut) {
                                phase = .handoff
                            }
                        }
                    )

                case .handoff:
                    HandoffView(
                        hunt: hunt,
                        onClose: { dismiss() },
                        onStart: startPlaying
                    )

                case .playing:
                    playingContent

                case .completed:
                    CompletionView(
                        hunt: hunt,
                        record: completedRecord,
                        onReturnToMenu: finishAndReturnToMenu
                    )
                }
            }
            .allowsHitTesting(!isShowingDiscovery)
            .accessibilityHidden(isShowingDiscovery)

            if isShowingDiscovery, let stage = currentStage {
                DiscoveryOverlay(
                    message: stage.discoveryMessage,
                    isLast: hunt.currentStageIndex == hunt.sortedStages.count - 1,
                    onContinue: continueAfterDiscovery
                )
                .transition(discoveryTransition)
                .zIndex(2)
            }
        }
        .tint(TreasureTheme.teal)
        .interactiveDismissDisabled(hunt.isChildModeLocked)
        .sheet(isPresented: $isShowingCancellationConfirmation) {
            CancelAdventureConfirmationView(
                onCancel: {
                    isShowingCancellationConfirmation = false
                },
                onConfirm: cancelAndReturnToMenu
            )
        }
        .fullScreenCover(isPresented: $isShowingQRCodeScanner) {
            if let stage = currentStage {
                QRCodeScannerView(
                    expectedPayload: stage.verificationPayload,
                    onMatch: {
                        isShowingQRCodeScanner = false
                        revealDiscovery()
                    }
                )
            }
        }
        .confirmationDialog(
            extraHintConfirmationTitle,
            isPresented: $isShowingExtraHintConfirmation,
            titleVisibility: .visible
        ) {
            Button("おたすけヒントを見る", action: revealExtraHint)
            Button("まだ自分で考える", role: .cancel) {}
        } message: {
            Text("少し考えても分からないときに見てみよう。")
        }
        .alert("進み具合を保存できませんでした", isPresented: persistenceErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "もう一度ためしてください。")
        }
        .alert("冒険を開始できません", isPresented: sessionErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionError ?? "しかける人に確認してください。")
        }
        .sensoryFeedback(
            .success,
            trigger: isShowingDiscovery
        ) { _, isShowingDiscovery in
            audioSettings.effectsAndHapticsAreEnabled
                && isShowingDiscovery
        }
        .onAppear {
            loadCompletionRecordIfNeeded()
            beginMusicRequest()
        }
        .onChange(of: backgroundMusicTrack) { _, track in
            updateMusicRequest(track)
        }
        .onChange(of: speechController.isSpeaking) { _, isSpeaking in
            musicCoordinator.setDucked(isSpeaking)
        }
        .onDisappear {
            speechController.stop()
            musicCoordinator.setDucked(false)
            endMusicRequest()
        }
    }

    private var backgroundStyle: TreasureBackgroundStyle {
        switch phase {
        case .preparation:
            .preparation
        case .safety, .handoff:
            .safety
        case .playing:
            .playing
        case .completed:
            .completion
        }
    }

    @ViewBuilder
    private var playingContent: some View {
        if let stage = currentStage {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        isShowingCancellationConfirmation = true
                    } label: {
                        Label(
                            "しかける人にわたす",
                            systemImage: "person.crop.circle"
                        )
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(TreasureTheme.ink)

                    Spacer()

                    Text(hunt.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TreasureTheme.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 22) {
                        progressHeader

                        HuntHintCard(
                            stage: stage,
                            number: hunt.currentStageIndex + 1,
                            isLast: currentStageIsLast,
                            speechController: speechController
                        )

                        extraHintControls(for: stage)
                        verificationControls(for: stage)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        } else {
            ContentUnavailableView {
                Label("ヒントがありません", systemImage: "questionmark.folder")
            } description: {
                Text("しかける人にiPhoneをわたしてください。")
            } actions: {
                Button {
                    isShowingCancellationConfirmation = true
                } label: {
                    Label(
                        "しかける人にわたす",
                        systemImage: "person.crop.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .treasureCompactCard()
            .padding(20)
        }
    }

    @ViewBuilder
    private func extraHintControls(for stage: TreasureStage) -> some View {
        let extraHints = stage.availableExtraHintContents
        let revealedCount = min(
            hunt.revealedExtraHintCount(for: stage.id),
            extraHints.count
        )

        if !extraHints.isEmpty {
            VStack(spacing: 12) {
                ForEach(
                    Array(extraHints.prefix(revealedCount).enumerated()),
                    id: \.offset
                ) { index, extraHint in
                    HuntExtraHintCard(
                        extraHint: extraHint.text,
                        imageData: extraHint.imageData,
                        number: index + 1,
                        totalCount: extraHints.count,
                        speechController: speechController
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 0.96)
                            )
                    )
                }

                if revealedCount < extraHints.count {
                    VStack(spacing: 8) {
                        Button {
                            isShowingExtraHintConfirmation = true
                        } label: {
                            Label(
                                revealedCount == 0
                                    ? "もう少しヒントを見る"
                                    : "もうひとつヒントを見る",
                                systemImage: "lightbulb"
                            )
                            .font(.headline)
                        }
                        .buttonStyle(.bordered)
                        .tint(TreasureTheme.teal)

                        Text("分からないときに使ってね")
                            .font(.caption)
                            .foregroundStyle(
                                TreasureTheme.secondaryText
                            )
                    }
                    .treasureCompactCard()
                }
            }
        }
    }

    private var extraHintConfirmationTitle: String {
        guard let stage = currentStage else {
            return "おたすけヒントを見る？"
        }
        let totalCount = stage.availableExtraHints.count
        let nextNumber = hunt.revealedExtraHintCount(for: stage.id) + 1
        guard totalCount > 1 else {
            return "おたすけヒントを見る？"
        }
        return "おたすけヒント \(nextNumber)を見る？"
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("宝 \(hunt.currentStageIndex + 1)")
                Spacer()
                Text("\(hunt.currentStageIndex + 1) / \(hunt.sortedStages.count)")
            }
            .font(.caption.bold())
            .foregroundStyle(TreasureTheme.secondaryText)

            ProgressView(
                value: Double(hunt.currentStageIndex + 1),
                total: Double(max(hunt.sortedStages.count, 1))
            )
            .tint(currentStageIsLast ? TreasureTheme.gold : TreasureTheme.teal)
        }
        .treasureCompactCard()
    }

    @ViewBuilder
    private func verificationControls(for stage: TreasureStage) -> some View {
        switch stage.verification {
        case .honesty:
            VStack(spacing: 10) {
                Button {
                    revealDiscovery()
                } label: {
                    Label("みつけた！", systemImage: "sparkles")
                }
                .buttonStyle(TreasurePrimaryButtonStyle())

                Text("宝を見つけたら押してね")
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.secondaryText)
            }
            .treasureCompactCard()

        case .passphrase:
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("宝といっしょにある合言葉", systemImage: "key.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.ink)

                    TextField("合言葉を入力", text: $passphrase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    answerError == nil
                                        ? TreasureTheme.teal.opacity(0.25)
                                        : TreasureTheme.coral,
                                    lineWidth: 1.5
                                )
                        }
                        .onChange(of: passphrase) {
                            answerError = nil
                        }
                        .onSubmit(checkPassphrase)
                        .focused($passphraseIsFocused)

                    if let answerError {
                        Text(answerError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TreasureTheme.coralText)
                    }
                }

                Button("こたえる", action: checkPassphrase)
                    .buttonStyle(TreasurePrimaryButtonStyle())
                    .disabled(passphrase.normalizedTreasureAnswer.isEmpty)
            }
            .treasureCard()

        case .qrCode:
            if QRCodeScannerCapability.isCurrentlyAvailable {
                VStack(spacing: 10) {
                    Button {
                        isShowingQRCodeScanner = true
                    } label: {
                        Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(TreasurePrimaryButtonStyle())

                    Text("宝といっしょにあるQRコードをカメラで写してね")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.secondaryText)
                }
                .treasureCompactCard()
            } else {
                unavailableVerificationCard(title: "QRコードを読み取れません")
            }

        case .nfc:
            if NFCSessionController.isAvailable {
                NFCReaderControl(
                    expectedPayload: stage.verificationPayload,
                    onMatch: revealDiscovery
                )
                .treasureCompactCard()
            } else {
                VStack(spacing: 10) {
                    Label(
                        "この端末ではNFCを読み取れません",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(TreasureTheme.coralText)

                    Text("しかける人に渡して、発見方法を変更してもらってください。")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.secondaryText)

                    Button {
                        isShowingCancellationConfirmation = true
                    } label: {
                        Label(
                            "しかける人にわたす",
                            systemImage: "person.crop.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .treasureCard()
            }
        }
    }

    private var currentStage: TreasureStage? {
        let stages = hunt.sortedStages
        guard stages.indices.contains(hunt.currentStageIndex) else {
            return nil
        }
        return stages[hunt.currentStageIndex]
    }

    private var currentStageIsLast: Bool {
        hunt.currentStageIndex == hunt.sortedStages.count - 1
    }

    private var backgroundMusicTrack: BackgroundMusicTrack {
        if isShowingDiscovery {
            return .discovery
        }
        if case .completed = phase {
            return .discovery
        }

        if case .playing = phase {
            return BackgroundMusicTrack.gameplayTrack(
                for: hunt.currentStageIndex
            )
        }

        return .adventureMenu
    }

    private var persistenceErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { isPresented in
                if !isPresented {
                    persistenceError = nil
                }
            }
        )
    }

    private var sessionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { sessionError != nil },
            set: { isPresented in
                if !isPresented {
                    sessionError = nil
                }
            }
        )
    }

    private func beginMusicRequest() {
        guard musicRequestID == nil else {
            updateMusicRequest(backgroundMusicTrack)
            return
        }
        musicRequestID = musicCoordinator.begin(backgroundMusicTrack)
    }

    private func updateMusicRequest(_ track: BackgroundMusicTrack) {
        guard let musicRequestID else {
            beginMusicRequest()
            return
        }
        musicCoordinator.update(musicRequestID, track: track)
    }

    private func endMusicRequest() {
        guard let musicRequestID else { return }
        musicCoordinator.end(musicRequestID)
        self.musicRequestID = nil
    }

    private func startPlaying() {
        guard !hunt.sortedStages.contains(where: {
            $0.verification == .qrCode
                && !QRCodeScannerCapability.isCurrentlyAvailable
        }) else {
            sessionError = "この端末ではQRコードを読み取れません。発見方法を合言葉などへ変更してください。"
            return
        }

        guard !hunt.sortedStages.contains(where: {
            $0.verification == .nfc && !NFCSessionController.isAvailable
        }) else {
            sessionError = "この端末ではNFCを使えません。発見方法をQRコードなどへ変更してください。"
            return
        }

        guard hunts.allSatisfy({
            $0.id == hunt.id || !$0.isChildModeLocked
        }) else {
            sessionError = "別の冒険がプレイ中です。先にその冒険を終了してください。"
            return
        }

        hunt.startNewGame()
        guard saveProgress() else { return }

        withAnimation(reduceMotion ? nil : .easeInOut) {
            phase = .playing
        }
    }

    private func unavailableVerificationCard(title: String) -> some View {
        VStack(spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(TreasureTheme.coralText)

            Text("しかける人に渡して、発見方法を変更してもらってください。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreasureTheme.secondaryText)

            Button {
                isShowingCancellationConfirmation = true
            } label: {
                Label(
                    "しかける人にわたす",
                    systemImage: "person.crop.circle"
                )
            }
            .buttonStyle(.bordered)
        }
        .treasureCard()
    }

    private func checkPassphrase() {
        guard let stage = currentStage else { return }

        if stage.matches(passphrase) {
            revealDiscovery()
        } else {
            let message = "ちがうみたい。宝をもう一度よく見てみよう。"
            answerError = message
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private func revealDiscovery() {
        answerError = nil
        passphraseIsFocused = false
        speechController.stop()
        if audioSettings.effectsAndHapticsAreEnabled {
            soundPlayer.playDiscovery()
        }
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.42, dampingFraction: 0.78)
        ) {
            isShowingDiscovery = true
        }
    }

    private func revealExtraHint() {
        guard let stage = currentStage else {
            return
        }
        let availableCount = stage.availableExtraHints.count
        guard availableCount > 0 else { return }

        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.38, dampingFraction: 0.82)
        ) {
            hunt.revealNextExtraHint(
                for: stage.id,
                availableCount: availableCount
            )
        }
        _ = saveProgress()
    }

    private func continueAfterDiscovery() {
        let wasLastStage = currentStageIsLast
        var newRecord: AdventureRecord?

        if wasLastStage {
            guard hunt.playState != .completed else { return }
            let record = AdventureRecord(hunt: hunt)
            modelContext.insert(record)
            newRecord = record
            hunt.completeGame()
        } else {
            hunt.advanceToNextStage()
        }
        guard saveProgress() else { return }

        if let newRecord {
            completedRecord = newRecord
            if audioSettings.effectsAndHapticsAreEnabled {
                soundPlayer.playCompletion()
            }
        }

        passphrase = ""
        answerError = nil
        isShowingQRCodeScanner = false
        isShowingExtraHintConfirmation = false
        withAnimation(reduceMotion ? nil : .easeInOut) {
            isShowingDiscovery = false
            if wasLastStage {
                phase = .completed
            }
        }
    }

    private func cancelAndReturnToMenu() {
        hunt.cancelGame()
        guard saveProgress() else {
            isShowingCancellationConfirmation = false
            return
        }
        isShowingCancellationConfirmation = false
        dismiss()
    }

    private func finishAndReturnToMenu() {
        hunt.endPlaySession()
        guard saveProgress() else { return }
        dismiss()
    }

    private func loadCompletionRecordIfNeeded() {
        guard case .completed = phase else { return }
        guard hunt.playState == .completed,
              completedRecord == nil else {
            return
        }

        do {
            let descriptor = FetchDescriptor<AdventureRecord>(
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            let records = try modelContext.fetch(descriptor)

            if let record = records.first(where: { $0.huntID == hunt.id }) {
                completedRecord = record
            } else {
                let record = AdventureRecord(hunt: hunt)
                modelContext.insert(record)
                guard saveProgress() else { return }
                completedRecord = record
            }
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    @discardableResult
    private func saveProgress() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
            return false
        }
    }

    private var discoveryTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.92))
    }
}

private enum PlayPhase {
    case preparation
    case safety
    case handoff
    case playing
    case completed
}

private struct CancelAdventureConfirmationView: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            TreasureBackground(style: .security) {
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 22) {
                            ZStack {
                                Circle()
                                    .fill(TreasureTheme.coral.opacity(0.14))

                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 42))
                                    .foregroundStyle(TreasureTheme.coralText)
                            }
                            .frame(width: 88, height: 88)
                            .accessibilityHidden(true)

                            VStack(spacing: 9) {
                                Text("冒険を中止する？")
                                    .font(.title2.bold())
                                    .foregroundStyle(TreasureTheme.ink)

                                Text(
                                    "ここまでの進み具合は取り消され、"
                                        + "次は最初のヒントから始まります。"
                                        + "iPhoneをしかける人にわたしてから進んでください。"
                                )
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.secondaryText)
                            }
                            .treasureCard()
                        }
                        .frame(maxWidth: 420)
                        .padding(24)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: proxy.size.height
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 12) {
                        Button(role: .destructive, action: onConfirm) {
                            Label(
                                "中止してメニューへ戻る",
                                systemImage: "xmark.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TreasureTheme.dangerBackground)

                        Button("まだ遊ぶ", action: onCancel)
                            .buttonStyle(.bordered)
                            .tint(TreasureTheme.ink)
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("冒険を中止")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
            }
        }
        .tint(TreasureTheme.teal)
    }
}

private struct SafetyCheckView: View {
    @Binding var isConfirmed: Bool

    let onClose: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupHeader(title: "安全の確認", onClose: onClose)

            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(TreasureTheme.teal.opacity(0.14))

                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(TreasureTheme.tealText)
                    }
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("安全に冒険しよう")
                            .font(.title.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("スタートする前に、しかけた場所を\nもう一度確認してください。")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.secondaryText)
                    }
                    .treasureCompactCard()

                    VStack(spacing: 14) {
                        SafetyRow(
                            icon: "car.fill",
                            text: "道路や駐車場の近くではありません"
                        )
                        SafetyRow(
                            icon: "drop.fill",
                            text: "水辺や高い場所ではありません"
                        )
                        SafetyRow(
                            icon: "hand.raised.fill",
                            text: "立入禁止や危険な場所ではありません"
                        )
                        SafetyRow(
                            icon: "person.2.fill",
                            text: "外では一緒に遊ぶ人と安全を確認します"
                        )
                    }
                    .treasureCard()

                    Button {
                        isConfirmed.toggle()
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: isConfirmed ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(
                                    isConfirmed
                                        ? TreasureTheme.tealText
                                        : TreasureTheme.secondaryText
                                )

                            Text("安全を確認しました")
                                .font(.headline)
                                .foregroundStyle(TreasureTheme.ink)

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            TreasureTheme.cardSurface,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("安全を確認しました")
                    .accessibilityValue(isConfirmed ? "確認済み" : "未確認")
                    .accessibilityAddTraits(isConfirmed ? .isSelected : [])

                    Button("つぎへ", action: onContinue)
                        .buttonStyle(TreasurePrimaryButtonStyle())
                        .disabled(!isConfirmed)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
    }
}

private struct SafetyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(TreasureTheme.coralText)
                .frame(width: 26)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TreasureTheme.ink)

            Spacer()
        }
    }
}

private struct HandoffView: View {
    let hunt: TreasureHunt
    let onClose: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupHeader(
                title: "準備できました",
                onClose: onClose
            )

            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(TreasureTheme.gold)
                            .shadow(color: TreasureTheme.gold.opacity(0.3), radius: 16, y: 8)

                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 92, height: 92)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("冒険をはじめよう！")
                            .font(.title.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("ここから先は、さがす人の画面です。")
                            .foregroundStyle(TreasureTheme.secondaryText)
                    }
                    .treasureCompactCard()

                    VStack(spacing: 14) {
                        Text(hunt.title)
                            .font(.title2.bold())
                            .foregroundStyle(TreasureTheme.ink)
                            .multilineTextAlignment(.center)

                        if !hunt.openingMessage.isEmpty {
                            Text(hunt.openingMessage)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.secondaryText)
                        }

                        Label(
                            "宝は \(hunt.stages.count)こ",
                            systemImage: "gift.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.tealText)
                    }
                    .frame(maxWidth: .infinity)
                    .treasureCard()

                    VStack(spacing: 9) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(TreasureTheme.coralText)
                            .accessibilityHidden(true)

                        Text("iPhoneをさがす人に渡してから\n下のボタンを押してください")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.ink)
                    }
                    .treasureCompactCard()

                    Button("冒険スタート", action: onStart)
                    .buttonStyle(TreasurePrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
    }
}

struct PlaySetupHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(TreasureTheme.ink, in: Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("閉じる")

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(TreasureTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct DiscoveryOverlay: View {
    let message: String
    let isLast: Bool
    let onContinue: () -> Void
    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(isLast ? TreasureTheme.gold : TreasureTheme.coral)
                                    .shadow(
                                        color: (isLast ? TreasureTheme.gold : TreasureTheme.coral)
                                            .opacity(0.35),
                                        radius: 18,
                                        y: 8
                                    )

                                Image(systemName: isLast ? "gift.fill" : "checkmark")
                                    .font(.system(size: 42, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 94, height: 94)
                            .accessibilityHidden(true)

                            Text("みつけた！")
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                                .foregroundStyle(TreasureTheme.ink)
                                .accessibilityFocused($headingIsFocused)

                            if !message.isEmpty {
                                Text(message)
                                    .font(.title3.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(TreasureTheme.ink)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(20)
                    }

                    Divider()

                    Button(
                        isLast ? "宝箱をあける" : "つぎのヒント",
                        action: onContinue
                    )
                    .buttonStyle(TreasurePrimaryButtonStyle())
                    .padding(20)
                }
                .frame(
                    maxWidth: 360,
                    maxHeight: max(proxy.size.height - 48, 1)
                )
                .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.8), lineWidth: 1)
                }
                .shadow(color: TreasureTheme.ink.opacity(0.15), radius: 18, y: 8)
                .padding(24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            headingIsFocused = true
        }
    }
}

private struct CompletionView: View {
    let hunt: TreasureHunt
    let record: AdventureRecord?
    let onReturnToMenu: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCelebrating = false
    @State private var isShowingMemoryEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 34)

                ZStack {
                    ForEach(0..<10, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 18 : 11))
                            .foregroundStyle(
                                index.isMultiple(of: 3)
                                    ? TreasureTheme.coral
                                    : TreasureTheme.gold
                            )
                            .offset(
                                x: cos(Double(index) * .pi / 5) * 112,
                                y: sin(Double(index) * .pi / 5) * 92
                            )
                            .scaleEffect(isCelebrating ? 1 : 0.15)
                            .opacity(isCelebrating ? 1 : 0)
                    }

                    Circle()
                        .fill(TreasureTheme.gold)
                        .frame(width: 132, height: 132)
                        .shadow(color: TreasureTheme.gold.opacity(0.38), radius: 24, y: 10)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }
                .frame(height: 210)
                .accessibilityHidden(true)

                VStack(spacing: 9) {
                    Text("冒険クリア！")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(TreasureTheme.ink)

                    Text("ぜんぶの宝を見つけました")
                        .font(.headline)
                        .foregroundStyle(TreasureTheme.ink)
                }

                VStack(spacing: 15) {
                    if !hunt.completionMessage.isEmpty {
                        Text(hunt.completionMessage)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.ink)
                    }

                    Label("宝 \(hunt.stages.count)こ 発見", systemImage: "gift.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.goldText)

                    if hunt.usedExtraHintCount > 0 {
                        Label(
                            "おたすけヒント \(hunt.usedExtraHintCount)かい",
                            systemImage: "lightbulb.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.tealText)
                    }
                }
                .frame(maxWidth: .infinity)
                .treasureCard()

                if let record {
                    AdventureMemoryCard(
                        record: record,
                        onEdit: { isShowingMemoryEditor = true }
                    )
                }

                Button {
                    onReturnToMenu()
                } label: {
                    Label(
                        "メニューへ戻る",
                        systemImage: "house.fill"
                    )
                }
                .buttonStyle(TreasurePrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(
                reduceMotion
                    ? nil
                    : .spring(
                        response: 0.7,
                        dampingFraction: 0.58
                    )
                    .delay(0.1)
            ) {
                isCelebrating = true
            }
        }
        .sheet(isPresented: $isShowingMemoryEditor) {
            if let record {
                AdventureMemoryEditorView(record: record)
            }
        }
    }
}
