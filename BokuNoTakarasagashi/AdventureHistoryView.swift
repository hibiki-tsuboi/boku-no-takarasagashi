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
                    TreasureBackground {
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
                                AdventureRecordRow(record: record)
                            }
                            .onDelete(perform: deleteRecords)
                        } footer: {
                            Text("記録は宝探し本体を削除しても残ります。左へスワイプすると削除できます。")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(TreasureTheme.background)
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
    let record: AdventureRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(TreasureTheme.gold.opacity(0.2))

                Image(systemName: "trophy.fill")
                    .foregroundStyle(TreasureTheme.gold)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(record.huntTitle)
                    .font(.headline)
                    .foregroundStyle(TreasureTheme.ink)

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
