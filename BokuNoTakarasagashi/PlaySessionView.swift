//
//  PlaySessionView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct PlaySessionView: View {
    let hunt: TreasureHunt

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var phase: PlayPhase
    @State private var safetyIsConfirmed = false
    @State private var isShowingParentGate = false
    @State private var isShowingQRCodeScanner = false
    @State private var isShowingDiscovery = false
    @State private var isShowingExtraHintConfirmation = false
    @State private var passphrase = ""
    @State private var answerError: String?
    @State private var persistenceError: String?
    @State private var completedRecord: AdventureRecord?
    @StateObject private var speechController = HintSpeechController()
    @StateObject private var soundPlayer = GameSoundPlayer()

    init(
        hunt: TreasureHunt,
        startsInPreparation: Bool = false
    ) {
        self.hunt = hunt

        let initialPhase: PlayPhase
        if startsInPreparation {
            initialPhase = .preparation
        } else if hunt.isChildModeLocked {
            initialPhase = hunt.playState == .completed ? .completed : .playing
        } else if hunt.playState == .inProgress {
            initialPhase = .handoff
        } else {
            initialPhase = .preparation
        }
        _phase = State(initialValue: initialPhase)
    }

    var body: some View {
        ZStack {
            TreasureBackground {
                switch phase {
                case .preparation:
                    HuntPreparationView(
                        hunt: hunt,
                        onClose: { dismiss() },
                        onContinue: {
                            withAnimation(.easeInOut) {
                                phase = .safety
                            }
                        }
                    )

                case .safety:
                    SafetyCheckView(
                        isConfirmed: $safetyIsConfirmed,
                        onClose: { dismiss() },
                        onContinue: {
                            withAnimation(.easeInOut) {
                                phase = .handoff
                            }
                        }
                    )

                case .handoff:
                    HandoffView(
                        hunt: hunt,
                        isResuming: hunt.playState == .inProgress,
                        onClose: { dismiss() },
                        onStart: startPlaying
                    )

                case .playing:
                    playingContent

                case .completed:
                    CompletionView(
                        hunt: hunt,
                        record: completedRecord,
                        onReturnToParent: { isShowingParentGate = true }
                    )
                }
            }

            if isShowingDiscovery, let stage = currentStage {
                DiscoveryOverlay(
                    message: stage.discoveryMessage,
                    isLast: hunt.currentStageIndex == hunt.sortedStages.count - 1,
                    onContinue: continueAfterDiscovery
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(2)
            }
        }
        .tint(TreasureTheme.teal)
        .interactiveDismissDisabled(hunt.isChildModeLocked)
        .sheet(isPresented: $isShowingParentGate) {
            ParentPINGateView(
                expectedDigest: hunt.parentPINDigest,
                onCancel: { isShowingParentGate = false },
                onUnlock: returnToParent
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
            "おたすけヒントを見る？",
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
        .sensoryFeedback(.success, trigger: isShowingDiscovery)
        .onAppear(perform: loadCompletionRecordIfNeeded)
        .onDisappear {
            speechController.stop()
        }
    }

    @ViewBuilder
    private var playingContent: some View {
        if let stage = currentStage {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        isShowingParentGate = true
                    } label: {
                        Label("おうちの人", systemImage: "lock.fill")
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
                Text("おうちの人にiPhoneをわたしてください。")
            } actions: {
                Button("おうちの人", action: { isShowingParentGate = true })
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func extraHintControls(for stage: TreasureStage) -> some View {
        if let extraHint = stage.availableExtraHint {
            if hunt.revealedExtraHintStageID == stage.id {
                HuntExtraHintCard(
                    extraHint: extraHint,
                    speechController: speechController
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 8) {
                    Button {
                        isShowingExtraHintConfirmation = true
                    } label: {
                        Label("もう少しヒントを見る", systemImage: "lightbulb")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(TreasureTheme.coral)

                    Text("分からないときに使ってね")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("宝 \(hunt.currentStageIndex + 1)")
                Spacer()
                Text("\(hunt.currentStageIndex + 1) / \(hunt.sortedStages.count)")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            ProgressView(
                value: Double(hunt.currentStageIndex + 1),
                total: Double(max(hunt.sortedStages.count, 1))
            )
            .tint(currentStageIsLast ? TreasureTheme.gold : TreasureTheme.teal)
        }
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
                    .foregroundStyle(.secondary)
            }

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

                    if let answerError {
                        Text(answerError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TreasureTheme.coral)
                    }
                }

                Button("こたえる", action: checkPassphrase)
                    .buttonStyle(TreasurePrimaryButtonStyle())
                    .disabled(passphrase.normalizedTreasureAnswer.isEmpty)
            }
            .treasureCard()

        case .qrCode:
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
                    .foregroundStyle(.secondary)
            }

        case .nfc:
            NFCReaderControl(
                expectedPayload: stage.verificationPayload,
                onMatch: revealDiscovery
            )
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

    private func startPlaying() {
        if hunt.playState == .inProgress {
            hunt.resumeGame()
        } else {
            hunt.startNewGame()
        }
        saveProgress()

        withAnimation(.easeInOut) {
            phase = .playing
        }
    }

    private func checkPassphrase() {
        guard let stage = currentStage else { return }

        if stage.matches(passphrase) {
            revealDiscovery()
        } else {
            answerError = "ちがうみたい。宝をもう一度よく見てみよう。"
        }
    }

    private func revealDiscovery() {
        answerError = nil
        speechController.stop()
        soundPlayer.playDiscovery()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            isShowingDiscovery = true
        }
    }

    private func revealExtraHint() {
        guard let stage = currentStage,
              stage.availableExtraHint != nil else {
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            hunt.revealExtraHint(for: stage.id)
        }
        saveProgress()
    }

    private func continueAfterDiscovery() {
        let wasLastStage = currentStageIsLast

        if wasLastStage {
            guard hunt.playState != .completed else { return }
            let record = AdventureRecord(hunt: hunt)
            modelContext.insert(record)
            completedRecord = record
            soundPlayer.playCompletion()
            hunt.completeGame()
        } else {
            hunt.advanceToNextStage()
        }
        saveProgress()

        passphrase = ""
        answerError = nil
        isShowingQRCodeScanner = false
        isShowingExtraHintConfirmation = false
        withAnimation(.easeInOut) {
            isShowingDiscovery = false
            if wasLastStage {
                phase = .completed
            }
        }
    }

    private func returnToParent() {
        hunt.unlockChildMode()
        saveProgress()
        isShowingParentGate = false
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
                completedRecord = record
                try modelContext.save()
            }
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func saveProgress() {
        do {
            try modelContext.save()
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private enum PlayPhase {
    case preparation
    case safety
    case handoff
    case playing
    case completed
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
                            .foregroundStyle(TreasureTheme.teal)
                    }
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("安全に冒険しよう")
                            .font(.title.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("スタートする前に、しかけた場所を\nもう一度確認してください。")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

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
                            icon: "figure.2.and.child.holdinghands",
                            text: "外では大人が一緒に見守ります"
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
                                    isConfirmed ? TreasureTheme.teal : .secondary
                                )

                            Text("安全を確認しました")
                                .font(.headline)
                                .foregroundStyle(TreasureTheme.ink)

                            Spacer()
                        }
                        .padding(16)
                        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

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
                .foregroundStyle(TreasureTheme.coral)
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
    let isResuming: Bool
    let onClose: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupHeader(
                title: isResuming ? "冒険のつづき" : "準備できました",
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
                        Text(isResuming ? "さがす人にわたそう" : "冒険をはじめよう！")
                            .font(.title.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("ここから先は、さがす人の画面です。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        Text(hunt.title)
                            .font(.title2.bold())
                            .foregroundStyle(TreasureTheme.ink)
                            .multilineTextAlignment(.center)

                        if !hunt.openingMessage.isEmpty {
                            Text(hunt.openingMessage)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }

                        Label(
                            isResuming
                                ? "宝 \(hunt.currentStageIndex + 1) から再開"
                                : "宝は \(hunt.stages.count)こ",
                            systemImage: "gift.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.teal)
                    }
                    .frame(maxWidth: .infinity)
                    .treasureCard()

                    VStack(spacing: 9) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(TreasureTheme.coral)
                            .accessibilityHidden(true)

                        Text("iPhoneをさがす人に渡してから\n下のボタンを押してください")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.ink)
                    }

                    Button(
                        isResuming ? "つづきをスタート" : "冒険スタート",
                        action: onStart
                    )
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
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(TreasureTheme.ink)
            .accessibilityLabel("閉じる")

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundStyle(TreasureTheme.ink)

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct DiscoveryOverlay: View {
    let message: String
    let isLast: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isLast ? TreasureTheme.gold : TreasureTheme.coral)
                        .shadow(
                            color: (isLast ? TreasureTheme.gold : TreasureTheme.coral).opacity(0.35),
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

                if !message.isEmpty {
                    Text(message)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.ink)
                }

                Button(isLast ? "宝箱をあける" : "つぎのヒント", action: onContinue)
                    .buttonStyle(TreasurePrimaryButtonStyle())
            }
            .frame(maxWidth: 360)
            .treasureCard()
            .padding(24)
        }
    }
}

private struct CompletionView: View {
    let hunt: TreasureHunt
    let record: AdventureRecord?
    let onReturnToParent: () -> Void

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
                        .foregroundStyle(TreasureTheme.teal)
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
                        .foregroundStyle(TreasureTheme.coral)

                    if hunt.usedExtraHintCount > 0 {
                        Label(
                            "おたすけヒント \(hunt.usedExtraHintCount)かい",
                            systemImage: "lightbulb.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(TreasureTheme.teal)
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
                    onReturnToParent()
                } label: {
                    Label("おうちの人にわたす", systemImage: "lock.fill")
                }
                .buttonStyle(TreasurePrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.58).delay(0.1)) {
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
