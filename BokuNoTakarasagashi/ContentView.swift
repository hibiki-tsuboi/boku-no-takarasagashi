//
//  ContentView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let onShowTitle: (() -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TreasureHunt.updatedAt, order: .reverse)
    private var hunts: [TreasureHunt]

    @State private var isCreatingHunt = false
    @State private var isShowingHistory = false
    @State private var isImportingHunt = false
    @State private var editingHunt: TreasureHunt?
    @State private var playingHunt: TreasureHunt?
    @State private var huntToPrepareAfterPreview: TreasureHunt?
    @State private var startsPlayingInPreparation = false
    @State private var huntActionRequest: HuntActionRequest?
    @State private var importCandidate: HuntImportCandidate?
    @State private var importError: String?
    @State private var huntPendingDeletion: TreasureHunt?
    @State private var deletionError: String?
    @State private var importReadTask: Task<Void, Never>?
    @State private var isReadingImportFile = false

    init(onShowTitle: (() -> Void)? = nil) {
        self.onShowTitle = onShowTitle
    }

    var body: some View {
        NavigationStack {
            TreasureBackground(style: .parent) {
                ScrollView {
                    VStack(spacing: 28) {
                        hero

                        if hunts.isEmpty {
                            emptyState
                        } else {
                            huntList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if let onShowTitle {
                        Button(action: onShowTitle) {
                            Label(
                                "タイトルへ戻る",
                                systemImage: "chevron.backward"
                            )
                        }
                        .tint(TreasureTheme.teal)
                    }

                    Button {
                        isShowingHistory = true
                    } label: {
                        Label("冒険のきろく", systemImage: "clock.arrow.circlepath")
                    }
                    .tint(TreasureTheme.teal)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isCreatingHunt = true
                        } label: {
                            Label(
                                "新しくつくる",
                                systemImage: "plus.circle"
                            )
                        }

                        Button {
                            isImportingHunt = true
                        } label: {
                            Label(
                                "共有ファイルを読み込む",
                                systemImage: "square.and.arrow.down"
                            )
                        }
                    } label: {
                        Label("宝探しを追加", systemImage: "plus")
                    }
                    .tint(TreasureTheme.teal)
                }
            }
        }
        .allowsHitTesting(!isReadingImportFile)
        .accessibilityHidden(isReadingImportFile)
        .sheet(isPresented: $isCreatingHunt) {
            HuntCreationFlowView()
        }
        .sheet(isPresented: $isShowingHistory) {
            AdventureHistoryView()
        }
        .sheet(item: $editingHunt) { hunt in
            ProtectedHuntEditorView(hunt: hunt)
        }
        .sheet(
            item: $huntActionRequest,
            onDismiss: startPreparationAfterPreview
        ) { request in
            ProtectedHuntActionView(
                request: request,
                onPrepare: {
                    huntToPrepareAfterPreview = request.hunt
                    huntActionRequest = nil
                }
            )
        }
        .sheet(item: $importCandidate) { candidate in
            HuntImportView(validatedPackage: candidate.validatedPackage)
        }
        .fullScreenCover(
            item: $playingHunt,
            onDismiss: { startsPlayingInPreparation = false }
        ) { hunt in
            PlaySessionView(
                hunt: hunt,
                startsInPreparation: startsPlayingInPreparation,
                parentIsAuthorized: startsPlayingInPreparation
            )
        }
        .fileImporter(
            isPresented: $isImportingHunt,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportedFile
        )
        .alert("共有ファイルを読み込めませんでした", isPresented: importErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "もう一度ためしてください。")
        }
        .confirmationDialog(
            "この宝探しを削除しますか？",
            isPresented: deletionConfirmationIsPresented,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive, action: deletePendingHunt)
            Button("キャンセル", role: .cancel) {
                huntPendingDeletion = nil
            }
        } message: {
            Text("ヒントや写真も端末から削除されます。過去の冒険のきろくは残ります。")
        }
        .alert("宝探しを削除できませんでした", isPresented: deletionErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "もう一度ためしてください。")
        }
        .overlay {
            if isReadingImportFile {
                ZStack {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()

                    ProgressView("共有ファイルを確認しています…")
                        .font(.headline)
                        .padding(22)
                        .background(
                            .white.opacity(0.96),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("共有ファイルを確認しています")
            }
        }
        .onAppear(perform: resumeLockedSessionIfNeeded)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                resumeLockedSessionIfNeeded()
            }
        }
        .onDisappear {
            importReadTask?.cancel()
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TreasureTheme.gold)
                    .frame(width: 76, height: 76)
                    .shadow(color: TreasureTheme.gold.opacity(0.35), radius: 14, y: 7)

                Image(systemName: "map.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text("ぼくの宝探し")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(TreasureTheme.ink)

            Text("家の中が、きょうの冒険になる。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(TreasureTheme.goldText)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("最初の冒険をつくろう")
                    .font(.title3.bold())
                    .foregroundStyle(TreasureTheme.ink)

                Text("ヒントと宝を用意したら、\niPhoneをさがす人に渡してスタート。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                isCreatingHunt = true
            } label: {
                Label("宝探しをつくる", systemImage: "plus.circle.fill")
            }
            .buttonStyle(TreasurePrimaryButtonStyle())
        }
        .treasureCard()
    }

    private var huntList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("宝探し")
                    .font(.title2.bold())
                    .foregroundStyle(TreasureTheme.ink)

                Spacer()

                Text("\(hunts.count)こ")
                    .font(.caption.bold())
                    .foregroundStyle(TreasureTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(TreasureTheme.teal.opacity(0.12), in: Capsule())
            }

            ForEach(hunts) { hunt in
                HuntCard(
                    hunt: hunt,
                    onPlay: { startPlaying(hunt) },
                    onEdit: { editingHunt = hunt },
                    onPreview: {
                        huntActionRequest = HuntActionRequest(
                            hunt: hunt,
                            action: .preview
                        )
                    },
                    onDuplicate: {
                        huntActionRequest = HuntActionRequest(
                            hunt: hunt,
                            action: .duplicate
                        )
                    },
                    onShare: {
                        huntActionRequest = HuntActionRequest(
                            hunt: hunt,
                            action: .share
                        )
                    },
                    onDelete: { huntPendingDeletion = hunt }
                )
            }

            Button {
                isCreatingHunt = true
            } label: {
                Label("新しい宝探しをつくる", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(TreasureTheme.teal)
        }
    }

    private func resumeLockedSessionIfNeeded() {
        guard playingHunt == nil else { return }
        startsPlayingInPreparation = false
        playingHunt = hunts.first(where: \.isChildModeLocked)
    }

    private func startPlaying(_ hunt: TreasureHunt) {
        startsPlayingInPreparation = false
        playingHunt = hunt
    }

    private func startPreparationAfterPreview() {
        guard let hunt = huntToPrepareAfterPreview else { return }
        huntToPrepareAfterPreview = nil
        startsPlayingInPreparation = true
        playingHunt = hunt
    }

    private var importErrorIsPresented: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { isPresented in
                if !isPresented {
                    importError = nil
                }
            }
        )
    }

    private var deletionConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { huntPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    huntPendingDeletion = nil
                }
            }
        )
    }

    private var deletionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { deletionError != nil },
            set: { isPresented in
                if !isPresented {
                    deletionError = nil
                }
            }
        )
    }

    private func deletePendingHunt() {
        guard let hunt = huntPendingDeletion else { return }
        huntPendingDeletion = nil

        modelContext.delete(hunt)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }

    private func handleImportedFile(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard let url = try result.get().first else { return }
            importReadTask?.cancel()
            isReadingImportFile = true
            importError = nil

            importReadTask = Task {
                defer {
                    isReadingImportFile = false
                    importReadTask = nil
                }

                do {
                    let validatedPackage = try await Task.detached(priority: .userInitiated) {
                        try HuntTransferService.readPackage(from: url)
                    }.value
                    try Task.checkCancellation()
                    importCandidate = HuntImportCandidate(
                        validatedPackage: validatedPackage
                    )
                } catch is CancellationError {
                    return
                } catch {
                    importError = error.localizedDescription
                }
            }
        } catch {
            if (error as? CocoaError)?.code == .userCancelled {
                return
            }
            importError = error.localizedDescription
        }
    }
}

private struct HuntCard: View {
    let hunt: TreasureHunt
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onPreview: () -> Void
    let onDuplicate: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(statusAccentColor.opacity(0.15))

                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusTextColor)
                }
                .frame(width: 50, height: 50)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(hunt.title)
                        .font(.title3.bold())
                        .foregroundStyle(TreasureTheme.ink)
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        Text(statusTitle)
                            .foregroundStyle(statusTextColor)

                        Text("・")

                        Text("宝 \(hunt.stages.count)こ")
                    }
                    .font(.caption.weight(.semibold))
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label("編集", systemImage: "pencil")
                    }

                    Button(action: onPreview) {
                        Label("プレビュー", systemImage: "eye")
                    }

                    Button(action: onDuplicate) {
                        Label(
                            "複製",
                            systemImage: "plus.square.on.square"
                        )
                    }

                    Button(action: onShare) {
                        Label(
                            "共有",
                            systemImage: "square.and.arrow.up"
                        )
                    }

                    Divider()

                    Button(role: .destructive, action: onDelete) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(TreasureTheme.ink)
                .accessibilityLabel("\(hunt.title)の保護者メニュー")
            }

            if hunt.playState == .inProgress, !hunt.stages.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("いまの場所")
                        Spacer()
                        Text("\(min(hunt.currentStageIndex + 1, hunt.stages.count)) / \(hunt.stages.count)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ProgressView(
                        value: Double(min(hunt.currentStageIndex, hunt.stages.count)),
                        total: Double(hunt.stages.count)
                    )
                    .tint(TreasureTheme.gold)
                }
            }

            Button(action: onPlay) {
                Label(playButtonTitle, systemImage: playButtonIcon)
            }
            .buttonStyle(TreasurePrimaryButtonStyle())
        }
        .treasureCard()
    }

    private var statusTitle: String {
        switch hunt.playState {
        case .ready:
            "準備できました"
        case .inProgress:
            "冒険の途中"
        case .completed:
            "クリア"
        }
    }

    private var statusIcon: String {
        switch hunt.playState {
        case .ready:
            "map.fill"
        case .inProgress:
            "figure.walk.motion"
        case .completed:
            "trophy.fill"
        }
    }

    private var statusAccentColor: Color {
        switch hunt.playState {
        case .ready:
            TreasureTheme.teal
        case .inProgress:
            TreasureTheme.coral
        case .completed:
            TreasureTheme.gold
        }
    }

    private var statusTextColor: Color {
        switch hunt.playState {
        case .ready:
            TreasureTheme.teal
        case .inProgress:
            TreasureTheme.coralText
        case .completed:
            TreasureTheme.goldText
        }
    }

    private var playButtonTitle: String {
        switch hunt.playState {
        case .ready:
            "この冒険をはじめる"
        case .inProgress:
            "つづきから"
        case .completed:
            "もういちど遊ぶ"
        }
    }

    private var playButtonIcon: String {
        hunt.playState == .inProgress ? "arrow.right.circle.fill" : "play.fill"
    }
}

#Preview {
    ContentView()
        .environmentObject(BackgroundMusicCoordinator())
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
