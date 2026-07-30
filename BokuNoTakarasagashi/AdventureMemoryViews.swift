//
//  AdventureMemoryViews.swift
//  BokuNoTakarasagashi
//

import SwiftData
import SwiftUI
import UIKit

struct AdventureMemoryEditorView: View {
    let record: AdventureRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var playerName: String
    @State private var memoryNote: String
    @State private var victoryPhotoData: Data?
    @State private var saveError: String?
    @State private var photoPreparationTracker = PhotoPreparationTracker()

    init(record: AdventureRecord) {
        self.record = record
        _playerName = State(initialValue: record.playerName ?? "")
        _memoryNote = State(initialValue: record.memoryNote ?? "")
        _victoryPhotoData = State(initialValue: record.victoryPhotoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HintPhotoEditor(
                        imageData: $victoryPhotoData,
                        photoAccessibilityLabel: "冒険の記念写真",
                        onPreparationStateChange: { isPreparing in
                            photoPreparationTracker.setPreparing(
                                isPreparing,
                                for: record.id
                            )
                        }
                    )
                } header: {
                    Text("記念写真（任意）")
                } footer: {
                    Text("宝といっしょに撮った写真や、クリアしたときの笑顔を残せます。")
                }

                Section {
                    TextField("例：はると", text: $playerName)
                        .onChange(of: playerName) { _, newValue in
                            playerName = String(newValue.prefix(30))
                        }
                } header: {
                    Text("遊んだ人（任意）")
                } footer: {
                    Text("\(playerName.count) / 30文字")
                }

                Section {
                    TextEditor(text: $memoryNote)
                        .frame(minHeight: 120)
                        .onChange(of: memoryNote) { _, newValue in
                            memoryNote = String(newValue.prefix(200))
                        }
                } header: {
                    Text("今日のひとこと（任意）")
                } footer: {
                    Text("\(memoryNote.count) / 200文字")
                }

                Section {
                    Label(
                        "写真と入力内容はこのiPhoneの中だけに保存されます。",
                        systemImage: "lock.iphone"
                    )
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .treasureBackground(.memory)
            .navigationTitle("冒険の思い出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(photoPreparationTracker.isPreparing)
                }
            }
            .alert("思い出を保存できませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "もう一度ためしてください。")
            }
        }
        .tint(TreasureTheme.teal)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isPresented in
                if !isPresented {
                    saveError = nil
                }
            }
        )
    }

    private func save() {
        guard !photoPreparationTracker.isPreparing else { return }
        record.playerName = playerName.memoryTrimmed.nilIfEmpty
        record.memoryNote = memoryNote.memoryTrimmed.nilIfEmpty
        record.victoryPhotoData = victoryPhotoData

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

struct AdventureMemoryCard: View {
    @Bindable var record: AdventureRecord
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            if let photoData = record.victoryPhotoData {
                HintPhotoView(
                    data: photoData,
                    maxHeight: 240,
                    accessibilityLabel: "冒険の記念写真"
                )
            } else {
                ZStack {
                    Circle()
                        .fill(TreasureTheme.teal.opacity(0.14))

                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundStyle(TreasureTheme.tealText)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            }

            VStack(spacing: 6) {
                Text(record.hasSavedMemory ? "冒険の思い出" : "今日の冒険を残そう")
                    .font(.title3.bold())
                    .foregroundStyle(TreasureTheme.ink)

                if let playerName = record.playerName?.memoryTrimmed.nilIfEmpty {
                    Text("\(playerName)さんの宝探し")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TreasureTheme.tealText)
                }

                if let note = record.memoryNote?.memoryTrimmed.nilIfEmpty {
                    Text(note)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.ink)
                } else if !record.hasSavedMemory {
                    Text("記念写真や今日のひとことを、冒険のきろくに保存できます。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreasureTheme.secondaryText)
                }
            }

            Button(action: onEdit) {
                Label(
                    record.hasSavedMemory ? "思い出を編集" : "思い出を残す",
                    systemImage: record.hasSavedMemory ? "pencil" : "camera.fill"
                )
            }
            .buttonStyle(.bordered)
            .tint(TreasureTheme.teal)
        }
        .frame(maxWidth: .infinity)
        .treasureCard()
    }
}

struct AdventureMemoryDetailView: View {
    @Bindable var record: AdventureRecord

    @State private var isEditing = false
    @State private var isSharing = false

    var body: some View {
        TreasureBackground(style: .memory) {
            ScrollView {
                VStack(spacing: 20) {
                    if let photoData = record.victoryPhotoData {
                        HintPhotoView(
                            data: photoData,
                            maxHeight: 380,
                            accessibilityLabel: "冒険の記念写真"
                        )
                        .treasureCard()
                    } else {
                        ZStack {
                            Circle()
                                .fill(TreasureTheme.gold)
                                .shadow(
                                    color: TreasureTheme.gold.opacity(0.3),
                                    radius: 16,
                                    y: 7
                                )

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 104, height: 104)
                        .accessibilityHidden(true)
                    }

                    VStack(spacing: 7) {
                        Text(record.huntTitle)
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .multilineTextAlignment(.center)
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
                        .font(.subheadline)
                        .foregroundStyle(TreasureTheme.secondaryText)
                    }
                    .treasureCompactCard()

                    HStack(spacing: 20) {
                        Label(
                            "宝 \(record.treasureCount)こ",
                            systemImage: "gift.fill"
                        )
                        .foregroundStyle(TreasureTheme.goldText)

                        Label(
                            "おたすけ \(record.extraHintsUsedCount)かい",
                            systemImage: "lightbulb.fill"
                        )
                        .foregroundStyle(TreasureTheme.tealText)
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .treasureCard()

                    if let playerName = record.playerName?.memoryTrimmed.nilIfEmpty {
                        MemoryTextCard(
                            title: "遊んだ人",
                            text: playerName,
                            systemImage: "person.fill"
                        )
                    }

                    if let note = record.memoryNote?.memoryTrimmed.nilIfEmpty {
                        MemoryTextCard(
                            title: "今日のひとこと",
                            text: note,
                            systemImage: "text.quote"
                        )
                    }

                    if !record.hasSavedMemory {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundStyle(TreasureTheme.tealText)

                            Text("この冒険に写真やひとことを追加できます。")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .treasureCard()
                    }

                    VStack(spacing: 10) {
                        Button {
                            isEditing = true
                        } label: {
                            Label("思い出を編集", systemImage: "pencil")
                        }
                        .buttonStyle(TreasurePrimaryButtonStyle())

                        Button {
                            isSharing = true
                        } label: {
                            Label("思い出を共有", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.bordered)
                        .tint(TreasureTheme.teal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("冒険の思い出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            AdventureMemoryEditorView(record: record)
        }
        .sheet(isPresented: $isSharing) {
            AdventureShareSheet(activityItems: shareItems)
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = [shareText]
        if let photoData = record.victoryPhotoData,
           let image = UIImage(data: photoData) {
            items.insert(image, at: 0)
        }
        return items
    }

    private var shareText: String {
        var lines = [
            "『\(record.huntTitle)』をクリア！",
            record.completedAt.formatted(date: .long, time: .shortened),
            "宝 \(record.treasureCount)こ・おたすけ \(record.extraHintsUsedCount)かい",
        ]

        if let playerName = record.playerName?.memoryTrimmed.nilIfEmpty {
            lines.append("遊んだ人：\(playerName)")
        }
        if let note = record.memoryNote?.memoryTrimmed.nilIfEmpty {
            lines.append(note)
        }
        lines.append("ぼくの宝探し")
        return lines.joined(separator: "\n")
    }
}

struct AdventureMemoryThumbnail: View {
    let imageData: Data?
    var size: CGFloat = 54

    var body: some View {
        if let imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(TreasureTheme.gold.opacity(0.2))

                Image(systemName: "trophy.fill")
                    .foregroundStyle(TreasureTheme.goldText)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }
}

private struct MemoryTextCard: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(TreasureTheme.tealText)

            Text(text)
                .font(.body)
                .foregroundStyle(TreasureTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .treasureCard()
    }
}

private struct AdventureShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

private extension String {
    var memoryTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
