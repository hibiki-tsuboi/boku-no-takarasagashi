//
//  HuntPreviewView.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct HuntPreviewView: View {
    let hunt: TreasureHunt
    let onPrepare: () -> Void

    @EnvironmentObject private var musicCoordinator: BackgroundMusicCoordinator

    @State private var stageIndex = 0
    @State private var revealedExtraHintStageIDs: Set<UUID> = []
    @State private var isShowingCompletion = false
    @State private var isShowingDiscovery = false
    @State private var isShowingQRCodeScanner = false
    @State private var passphrase = ""
    @State private var answerError: String?
    @State private var isCelebrating = false
    @State private var musicRequestID: UUID?
    @StateObject private var speechController = HintSpeechController()
    @StateObject private var soundPlayer = GameSoundPlayer()

    private var stages: [TreasureStage] {
        hunt.sortedStages
    }

    var body: some View {
        ZStack {
            Group {
                if isShowingCompletion {
                    completionPreview
                } else if let stage = currentStage {
                    stagePreview(stage)
                } else {
                    ContentUnavailableView {
                        Label("ヒントがありません", systemImage: "questionmark.folder")
                    } description: {
                        Text("宝を追加してからプレビューしてください。")
                    }
                }
            }

            if isShowingDiscovery,
               let stage = currentStage {
                DiscoveryOverlay(
                    message: stage.discoveryMessage,
                    isLast: currentStageIsLast,
                    onContinue: continueAfterDiscovery
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(2)
            }
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
        .sensoryFeedback(.success, trigger: isShowingDiscovery)
        .onAppear {
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

    private func stagePreview(_ stage: TreasureStage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                previewNotice
                progressHeader

                HuntHintCard(
                    stage: stage,
                    number: stageIndex + 1,
                    isLast: currentStageIsLast,
                    speechController: speechController
                )

                extraHintPreview(for: stage)
                verificationPreview(for: stage)
                stageNavigation

                Button(action: onPrepare) {
                    Label(
                        "この内容で準備する",
                        systemImage: "shippingbox.fill"
                    )
                }
                .buttonStyle(TreasurePrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var previewNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .font(.title3)
                .foregroundStyle(TreasureTheme.teal)

            VStack(alignment: .leading, spacing: 3) {
                Text("保護者プレビュー")
                    .font(.subheadline.bold())
                    .foregroundStyle(TreasureTheme.ink)

                Text("ここでの操作は進み具合に保存されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(currentStageIsLast ? "ゴールの宝" : "宝 \(stageIndex + 1)")
                Spacer()
                Text("\(stageIndex + 1) / \(stages.count)")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            ProgressView(
                value: Double(stageIndex + 1),
                total: Double(max(stages.count, 1))
            )
            .tint(currentStageIsLast ? TreasureTheme.gold : TreasureTheme.teal)
        }
    }

    @ViewBuilder
    private func extraHintPreview(for stage: TreasureStage) -> some View {
        if let extraHint = stage.availableExtraHint {
            if revealedExtraHintStageIDs.contains(stage.id) {
                VStack(spacing: 8) {
                    HuntExtraHintCard(
                        extraHint: extraHint,
                        speechController: speechController
                    )

                    Button {
                        speechController.stop()
                        revealedExtraHintStageIDs.remove(stage.id)
                    } label: {
                        Label(
                            "おたすけヒントを隠す",
                            systemImage: "eye.slash"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(TreasureTheme.ink)
                }
            } else {
                VStack(spacing: 8) {
                    Button {
                        revealedExtraHintStageIDs.insert(stage.id)
                    } label: {
                        Label(
                            "もう少しヒントを見る",
                            systemImage: "lightbulb"
                        )
                        .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(TreasureTheme.coral)

                    Text("本番と同じように、おたすけヒントを確認できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func verificationPreview(for stage: TreasureStage) -> some View {
        switch stage.verification {
        case .honesty:
            VStack(spacing: 10) {
                Button(action: revealDiscovery) {
                    Label("みつけた！", systemImage: "sparkles")
                }
                .buttonStyle(TreasurePrimaryButtonStyle())

                previewOperationNote
            }

        case .passphrase:
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        "宝といっしょにある合言葉",
                        systemImage: "key.fill"
                    )
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
                            .foregroundStyle(TreasureTheme.coralText)
                    }
                }

                Button("こたえる", action: checkPassphrase)
                    .buttonStyle(TreasurePrimaryButtonStyle())
                    .disabled(passphrase.normalizedTreasureAnswer.isEmpty)

                previewOperationNote
            }
            .treasureCard()

        case .qrCode:
            VStack(spacing: 10) {
                Button {
                    isShowingQRCodeScanner = true
                } label: {
                    Label(
                        "QRコードを読み取りテスト",
                        systemImage: "qrcode.viewfinder"
                    )
                }
                .buttonStyle(TreasurePrimaryButtonStyle())

                previewOperationNote
            }

        case .nfc:
            VStack(spacing: 10) {
                NFCReaderControl(
                    expectedPayload: stage.verificationPayload,
                    onMatch: revealDiscovery
                )

                previewOperationNote
            }
        }
    }

    private var previewOperationNote: some View {
        Text("発見演出は表示されますが、本番の進み具合は変わりません。")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
    }

    private var stageNavigation: some View {
        HStack(spacing: 12) {
            Button {
                moveToStage(stageIndex - 1)
            } label: {
                Label("前の宝", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(stageIndex == 0)

            Button {
                if currentStageIsLast {
                    showCompletion()
                } else {
                    moveToStage(stageIndex + 1)
                }
            } label: {
                Label(
                    currentStageIsLast ? "クリア画面" : "次の宝",
                    systemImage: "chevron.right"
                )
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .tint(TreasureTheme.teal)
    }

    private var completionPreview: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                ZStack {
                    ForEach(0..<10, id: \.self) { index in
                        Image(
                            systemName: index.isMultiple(of: 2)
                                ? "sparkle"
                                : "star.fill"
                        )
                        .font(.system(size: index.isMultiple(of: 2) ? 18 : 11))
                        .foregroundStyle(
                            index.isMultiple(of: 3)
                                ? TreasureTheme.coral
                                : TreasureTheme.gold
                        )
                        .offset(
                            x: cos(Double(index) * .pi / 5) * 100,
                            y: sin(Double(index) * .pi / 5) * 82
                        )
                        .scaleEffect(isCelebrating ? 1 : 0.15)
                        .opacity(isCelebrating ? 1 : 0)
                    }

                    Circle()
                        .fill(TreasureTheme.gold)
                        .frame(width: 122, height: 122)
                        .shadow(
                            color: TreasureTheme.gold.opacity(0.38),
                            radius: 22,
                            y: 9
                        )

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                }
                .frame(height: 190)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("冒険クリア！")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(TreasureTheme.ink)

                    Text("クリア画面のプレビュー")
                        .font(.headline)
                        .foregroundStyle(TreasureTheme.teal)
                }

                VStack(spacing: 14) {
                    if !hunt.completionMessage.isEmpty {
                        Text(hunt.completionMessage)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.ink)
                    }

                    Label(
                        "宝 \(stages.count)こ 発見",
                        systemImage: "gift.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(TreasureTheme.coralText)
                }
                .frame(maxWidth: .infinity)
                .treasureCard()

                Button {
                    isShowingCompletion = false
                    moveToStage(max(stages.count - 1, 0))
                } label: {
                    Label(
                        "最後のヒントに戻る",
                        systemImage: "chevron.left"
                    )
                }
                .buttonStyle(.bordered)

                Button(action: onPrepare) {
                    Label(
                        "この内容で準備する",
                        systemImage: "shippingbox.fill"
                    )
                }
                .buttonStyle(TreasurePrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    private var currentStage: TreasureStage? {
        guard stages.indices.contains(stageIndex) else { return nil }
        return stages[stageIndex]
    }

    private var currentStageIsLast: Bool {
        stageIndex == stages.count - 1
    }

    private var backgroundMusicTrack: BackgroundMusicTrack {
        if isShowingDiscovery || isShowingCompletion {
            return .discovery
        }
        return BackgroundMusicTrack.gameplayTrack(for: stageIndex)
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

    private func checkPassphrase() {
        guard let stage = currentStage else { return }

        if stage.matches(passphrase) {
            revealDiscovery()
        } else {
            answerError = "ちがうみたい。本番と同じ合言葉を入力してください。"
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

    private func continueAfterDiscovery() {
        let wasLast = currentStageIsLast

        withAnimation(.easeInOut) {
            isShowingDiscovery = false
        }

        if wasLast {
            showCompletion()
        } else {
            moveToStage(stageIndex + 1)
        }
    }

    private func moveToStage(_ index: Int) {
        guard stages.indices.contains(index) else { return }
        speechController.stop()
        passphrase = ""
        answerError = nil
        isShowingQRCodeScanner = false
        withAnimation(.easeInOut) {
            stageIndex = index
        }
    }

    private func showCompletion() {
        speechController.stop()
        soundPlayer.playCompletion()
        isCelebrating = false
        withAnimation(.easeInOut) {
            isShowingCompletion = true
        }
        withAnimation(
            .spring(response: 0.7, dampingFraction: 0.58).delay(0.1)
        ) {
            isCelebrating = true
        }
    }
}
