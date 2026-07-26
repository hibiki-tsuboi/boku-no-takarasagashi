//
//  TreasureModels.swift
//  BokuNoTakarasagashi
//

import Foundation
import SwiftData

enum TreasureVerification: String, CaseIterable, Identifiable {
    case honesty
    case passphrase
    case qrCode
    case nfc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .honesty:
            "みつけた！"
        case .passphrase:
            "合言葉"
        case .qrCode:
            "QRコード"
        case .nfc:
            "NFCタグ"
        }
    }

    var systemImage: String {
        switch self {
        case .honesty:
            "hand.thumbsup.fill"
        case .passphrase:
            "character.cursor.ibeam"
        case .qrCode:
            "qrcode"
        case .nfc:
            "wave.3.right.circle.fill"
        }
    }
}

enum HuntPlayState: String {
    case ready
    case inProgress
    case completed
}

nonisolated enum TreasureContentLimits {
    static let maximumHuntTitleLength = 100
    static let maximumOpeningMessageLength = 1_000
    static let maximumCompletionMessageLength = 1_000
    static let maximumStageCount = 10
    static let maximumHintLength = 1_000
    static let maximumExtraHintLength = 1_000
    static let maximumDiscoveryMessageLength = 1_000
    static let maximumPassphraseLength = 200
    static let maximumVerificationIdentifierLength = 40
    static let maximumStagePhotoByteCount = 5 * 1_024 * 1_024
    static let maximumTotalPhotoByteCount = 20 * 1_024 * 1_024
}

nonisolated enum TreasureContentValidator {
    private static let maximumUTF8BytesPerCharacter = 64

    static func isValidRequiredText(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isWithinLimit(value, maximumLength: maximumLength)
    }

    static func isWithinLimit(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        value.count <= maximumLength
            && value.utf8.count <= maximumUTF8ByteCount(
                forCharacterLimit: maximumLength
            )
    }

    static func limited(
        _ value: String,
        maximumLength: Int
    ) -> String {
        guard !isWithinLimit(value, maximumLength: maximumLength) else {
            return value
        }

        let maximumByteCount = maximumUTF8ByteCount(
            forCharacterLimit: maximumLength
        )
        var result = ""
        var characterCount = 0
        var byteCount = 0

        for character in value {
            let characterString = String(character)
            let characterByteCount = characterString.utf8.count
            guard characterCount < maximumLength,
                  byteCount <= maximumByteCount - characterByteCount else {
                break
            }
            result.append(character)
            characterCount += 1
            byteCount += characterByteCount
        }
        return result
    }

    static func duplicateTitle(from sourceTitle: String) -> String {
        let suffix = "（コピー）"
        let trimmedTitle = sourceTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = trimmedTitle.isEmpty ? "宝探し" : trimmedTitle
        let baseLimit = max(
            TreasureContentLimits.maximumHuntTitleLength - suffix.count,
            0
        )
        return limited(
            String(baseTitle.prefix(baseLimit)) + suffix,
            maximumLength: TreasureContentLimits.maximumHuntTitleLength
        )
    }

    static func maximumUTF8ByteCount(
        forCharacterLimit maximumLength: Int
    ) -> Int {
        maximumLength * maximumUTF8BytesPerCharacter
    }
}

@Model
final class TreasureHunt {
    var id: UUID
    var title: String
    var openingMessage: String
    var completionMessage: String
    var createdAt: Date
    var updatedAt: Date
    var currentStageIndex: Int
    var playStateRawValue: String
    var isChildModeLocked: Bool
    var revealedExtraHintStageID: UUID?
    var extraHintsUsedCount: Int?

    @Relationship(deleteRule: .cascade, inverse: \TreasureStage.hunt)
    var stages: [TreasureStage]

    init(
        title: String,
        openingMessage: String,
        completionMessage: String
    ) {
        id = UUID()
        self.title = title
        self.openingMessage = openingMessage
        self.completionMessage = completionMessage
        createdAt = .now
        updatedAt = .now
        currentStageIndex = 0
        playStateRawValue = HuntPlayState.ready.rawValue
        isChildModeLocked = false
        revealedExtraHintStageID = nil
        extraHintsUsedCount = 0
        stages = []
    }

    var sortedStages: [TreasureStage] {
        stages.sorted { lhs, rhs in
            lhs.orderIndex < rhs.orderIndex
        }
    }

    var playState: HuntPlayState {
        get { HuntPlayState(rawValue: playStateRawValue) ?? .ready }
        set { playStateRawValue = newValue.rawValue }
    }

    var usedExtraHintCount: Int {
        extraHintsUsedCount ?? 0
    }

    func startNewGame() {
        currentStageIndex = 0
        playState = .inProgress
        isChildModeLocked = true
        revealedExtraHintStageID = nil
        extraHintsUsedCount = 0
        updatedAt = .now
    }

    func resumeGame() {
        playState = .inProgress
        isChildModeLocked = true
        updatedAt = .now
    }

    func advanceToNextStage() {
        currentStageIndex += 1
        revealedExtraHintStageID = nil
        updatedAt = .now
    }

    func revealExtraHint(for stageID: UUID) {
        guard revealedExtraHintStageID != stageID else { return }
        revealedExtraHintStageID = stageID
        extraHintsUsedCount = usedExtraHintCount + 1
        updatedAt = .now
    }

    func completeGame() {
        playState = .completed
        revealedExtraHintStageID = nil
        updatedAt = .now
    }

    func endPlaySession() {
        isChildModeLocked = false
        updatedAt = .now
    }
}

@Model
final class TreasureStage {
    var id: UUID
    var orderIndex: Int
    var hint: String
    var extraHint: String?
    @Attribute(.externalStorage) var hintImageData: Data?
    var discoveryMessage: String
    var verificationRawValue: String
    var passphrase: String
    var verificationToken: String?
    var hunt: TreasureHunt?

    init(
        orderIndex: Int,
        hint: String,
        extraHint: String? = nil,
        hintImageData: Data? = nil,
        discoveryMessage: String,
        verification: TreasureVerification,
        passphrase: String,
        verificationToken: String = UUID().uuidString,
        hunt: TreasureHunt? = nil
    ) {
        id = UUID()
        self.orderIndex = orderIndex
        self.hint = hint
        self.extraHint = extraHint
        self.hintImageData = hintImageData
        self.discoveryMessage = discoveryMessage
        verificationRawValue = verification.rawValue
        self.passphrase = passphrase
        self.verificationToken = verificationToken
        self.hunt = hunt
    }

    var verification: TreasureVerification {
        get { TreasureVerification(rawValue: verificationRawValue) ?? .honesty }
        set { verificationRawValue = newValue.rawValue }
    }

    func matches(_ answer: String) -> Bool {
        answer.normalizedTreasureAnswer == passphrase.normalizedTreasureAnswer
    }

    var verificationPayload: String {
        TreasurePayload.make(token: verificationToken ?? id.uuidString)
    }

    var availableExtraHint: String? {
        guard let extraHint else {
            return nil
        }

        let value = extraHint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        return value
    }
}

@Model
final class AdventureRecord {
    var id: UUID
    var huntID: UUID
    var huntTitle: String
    var completedAt: Date
    var treasureCount: Int
    var extraHintsUsedCount: Int
    var playerName: String?
    var memoryNote: String?
    @Attribute(.externalStorage) var victoryPhotoData: Data?

    init(
        huntID: UUID,
        huntTitle: String,
        completedAt: Date = .now,
        treasureCount: Int,
        extraHintsUsedCount: Int,
        playerName: String? = nil,
        memoryNote: String? = nil,
        victoryPhotoData: Data? = nil
    ) {
        id = UUID()
        self.huntID = huntID
        self.huntTitle = huntTitle
        self.completedAt = completedAt
        self.treasureCount = treasureCount
        self.extraHintsUsedCount = extraHintsUsedCount
        self.playerName = playerName
        self.memoryNote = memoryNote
        self.victoryPhotoData = victoryPhotoData
    }

    convenience init(hunt: TreasureHunt) {
        self.init(
            huntID: hunt.id,
            huntTitle: hunt.title,
            treasureCount: hunt.stages.count,
            extraHintsUsedCount: hunt.usedExtraHintCount
        )
    }

    var hasSavedMemory: Bool {
        victoryPhotoData != nil
            || playerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

nonisolated enum TreasurePayload {
    private static let prefix = "bokunotakarasagashi:treasure:"

    static func make(token: String) -> String {
        prefix + token.lowercased()
    }

    static func matches(_ candidate: String, expected: String) -> Bool {
        candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(expected) == .orderedSame
    }

    static func isTreasurePayload(_ candidate: String) -> Bool {
        candidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix(prefix)
    }
}

extension String {
    nonisolated var normalizedTreasureAnswer: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
    }
}
