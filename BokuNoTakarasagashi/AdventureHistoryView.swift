//
//  AdventureHistoryView.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI

struct AdventureHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AdventureRecord.completedAt, order: .reverse)
    private var records: [AdventureRecord]

    @State private var persistenceError: String?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    TreasureBackground(style: .history) {
                        ContentUnavailableView {
                            Label("まだ記録がありません", systemImage: "trophy")
                        } description: {
                            Text("宝探しをクリアすると、ここに冒険の記録が残ります。")
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(records) { record in
                                NavigationLink {
                                    AdventureMemoryDetailView(record: record)
                                } label: {
                                    AdventureRecordRow(record: record)
                                }
                            }
                            .onDelete(perform: deleteRecords)
                        } footer: {
                            Text("記録を開くと、写真やひとことの追加・共有ができます。左へスワイプすると削除できます。")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .treasureBackground(.history)
                }
            }
            .navigationTitle("冒険のきろく")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("記録を削除できませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(persistenceError ?? "もう一度ためしてください。")
            }
        }
        .tint(TreasureTheme.teal)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { isPresented in
                if !isPresented {
                    persistenceError = nil
                }
            }
        )
    }

    private func deleteRecords(at offsets: IndexSet) {
        let deletingRecords = offsets.map { records[$0] }
        deletingRecords.forEach(modelContext.delete)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }
}

private struct AdventureRecordRow: View {
    @Bindable var record: AdventureRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AdventureMemoryThumbnail(
                imageData: record.victoryPhotoData,
                size: 54
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(record.huntTitle)
                    .font(.headline)
                    .foregroundStyle(TreasureTheme.ink)

                if let playerName = record.playerName,
                   !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(playerName, systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TreasureTheme.teal)
                }

                Text(
                    record.completedAt,
                    format: .dateTime
                        .year()
                        .month()
                        .day()
                        .hour()
                        .minute()
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    Label(
                        "宝 \(record.treasureCount)こ",
                        systemImage: "gift.fill"
                    )

                    Label(
                        "おたすけ \(record.extraHintsUsedCount)かい",
                        systemImage: "lightbulb.fill"
                    )
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(TreasureTheme.teal)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
