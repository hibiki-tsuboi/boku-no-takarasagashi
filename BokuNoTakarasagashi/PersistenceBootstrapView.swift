//
//  PersistenceBootstrapView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct PersistenceBootstrapView: View {
    @State private var modelContainer: ModelContainer?
    @State private var startupFailure: PersistenceStartupFailure?
    @State private var loadAttempt = 0

    var body: some View {
        Group {
            if let modelContainer {
                AppRootView()
                    .modelContainer(modelContainer)
            } else if let startupFailure {
                PersistenceRecoveryView(
                    failure: startupFailure,
                    onRetry: retry,
                    onReset: resetLocalData
                )
            } else {
                TreasureBackgroundArtwork(style: .home)
                    .overlay {
                        ProgressView("冒険のデータを準備しています…")
                            .font(.headline)
                            .tint(TreasureTheme.teal)
                            .foregroundStyle(TreasureTheme.ink)
                            .padding(22)
                            .background(
                                .white.opacity(0.92),
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                    }
            }
        }
        .task(id: loadAttempt) {
            loadContainer()
        }
    }

    private func loadContainer() {
        guard modelContainer == nil else { return }
        startupFailure = nil

        do {
            modelContainer = try PersistenceStoreFactory.makeContainer()
        } catch {
            startupFailure = PersistenceStartupFailure(
                summary: error.localizedDescription,
                diagnostics: String(reflecting: error)
            )
        }
    }

    private func retry() {
        modelContainer = nil
        startupFailure = nil
        loadAttempt += 1
    }

    private func resetLocalData() {
        do {
            try PersistenceStoreFactory.removeStore()
            retry()
        } catch {
            startupFailure = PersistenceStartupFailure(
                summary: "端末内データを初期化できませんでした。",
                diagnostics: String(reflecting: error)
            )
        }
    }
}

struct PersistenceStartupFailure {
    let summary: String
    let diagnostics: String
}

enum PersistenceStoreFactory {
    static var storeURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "default.store", directoryHint: .notDirectory)
    }

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            TreasureHunt.self,
            TreasureStage.self,
            AdventureRecord.self,
        ])
        let directoryURL = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    static func removeStore() throws {
        try removeStore(at: storeURL)
    }

    static func removeStore(at storeURL: URL) throws {
        let relatedURLs = [
            storeURL,
            URL(filePath: storeURL.path + "-shm"),
            URL(filePath: storeURL.path + "-wal"),
            URL(filePath: storeURL.path + "_SUPPORT", directoryHint: .isDirectory),
        ]
        var firstError: Error?

        for url in relatedURLs where FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError {
            throw firstError
        }
    }
}

private struct PersistenceRecoveryView: View {
    let failure: PersistenceStartupFailure
    let onRetry: () -> Void
    let onReset: () -> Void

    @State private var isShowingResetConfirmation = false

    var body: some View {
        TreasureBackground(style: .security) {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                            .font(.system(size: 52))
                            .foregroundStyle(TreasureTheme.coralText)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("冒険のデータを開けません")
                                .font(.title2.bold())
                                .foregroundStyle(TreasureTheme.ink)

                            Text("データは削除していません。まずはもう一度ためしてください。")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(
                                    TreasureTheme.secondaryText
                                )
                        }
                    }
                    .treasureCompactCard()

                    Button("もう一度ためす", action: onRetry)
                        .buttonStyle(TreasurePrimaryButtonStyle())

                    DisclosureGroup("診断情報") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(failure.summary)
                            Text(failure.diagnostics)
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(TreasureTheme.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    }
                    .treasureCard()

                    VStack(spacing: 12) {
                        Button("端末内データを初期化", role: .destructive) {
                            isShowingResetConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .tint(TreasureTheme.coralText)

                        Text("初期化すると、宝探し・冒険のきろく・写真がこの端末から削除され、元に戻せません。")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TreasureTheme.coralText)
                    }
                    .treasureCompactCard()
                }
                .frame(maxWidth: 520)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(
            "端末内データを初期化しますか？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("すべて削除して初期化", role: .destructive, action: onReset)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
    }
}
