//
//  TreasureModels.swift
//  BokuNoTakarasagashi
//

import CryptoKit
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

enum TreasureContentLimits {
    static let maximumDiscoveryMessageLength = 1_000
}

@Model
final class TreasureHunt {
    var id: UUID
    var title: String
    var openingMessage: String
    var completionMessage: String
    var parentPINDigest: String
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
        completionMessage: String,
        parentPIN: String
    ) {
        id = UUID()
        self.title = title
        self.openingMessage = openingMessage
        self.completionMessage = completionMessage
        parentPINDigest = ParentPIN.digest(parentPIN)
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

    func unlockChildMode() {
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

enum TreasurePayload {
    private static let prefix = "bokunotakarasagashi:treasure:"

    static func make(token: String) -> String {
        prefix + token.lowercased()
    }

    static func matches(_ candidate: String, expected: String) -> Bool {
        candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(expected) == .orderedSame
    }
}

enum ParentPIN {
    static func digest(_ pin: String) -> String {
        SHA256.hash(data: Data(pin.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func matches(_ pin: String, digest: String) -> Bool {
        self.digest(pin) == digest
    }

    static func digitsOnly(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(4))
    }
}

extension String {
    var normalizedTreasureAnswer: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
    }
}
