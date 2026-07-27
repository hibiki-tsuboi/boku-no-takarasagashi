//
//  HuntTransferFormat.swift
//  BokuNoTakarasagashi
//

import Foundation

nonisolated struct HuntTransferPackage: Codable, Equatable, Sendable {
    struct ExtraHintContent: Codable, Equatable, Sendable {
        let text: String
        let imageData: Data?
    }

    struct Stage: Codable, Equatable, Sendable {
        let hint: String
        let extraHint: String?
        let extraHints: [String]?
        let extraHintContents: [ExtraHintContent]?
        let hintImageData: Data?
        let discoveryMessage: String
        let verificationRawValue: String
        let passphrase: String

        init(
            hint: String,
            extraHint: String?,
            hintImageData: Data?,
            discoveryMessage: String,
            verificationRawValue: String,
            passphrase: String,
            extraHints: [String]? = nil,
            extraHintContents: [ExtraHintContent]? = nil
        ) {
            self.hint = hint
            self.extraHint = extraHint
            self.extraHints = extraHints
            self.extraHintContents = extraHintContents
            self.hintImageData = hintImageData
            self.discoveryMessage = discoveryMessage
            self.verificationRawValue = verificationRawValue
            self.passphrase = passphrase
        }

        var availableExtraHints: [String] {
            if let extraHintContents {
                return extraHintContents.map(\.text)
            }
            if let extraHints {
                return extraHints
            }
            guard let extraHint,
                  !extraHint.trimmingCharacters(
                      in: .whitespacesAndNewlines
                  ).isEmpty else {
                return []
            }
            return [extraHint]
        }

        var availableExtraHintContents: [ExtraHintContent] {
            if let extraHintContents {
                return extraHintContents
            }
            return availableExtraHints.map { extraHint in
                ExtraHintContent(text: extraHint, imageData: nil)
            }
        }

        var allPhotoData: [Data] {
            var photoData = availableExtraHintContents.compactMap(\.imageData)
            if let hintImageData {
                photoData.insert(hintImageData, at: 0)
            }
            return photoData
        }
    }

    static let formatIdentifier = "bokunotakarasagashi-hunt"
    static let currentVersion = 1
    static let maximumFileSize = 40 * 1_024 * 1_024
    static let maximumStageCount = TreasureContentLimits.maximumStageCount

    let format: String
    let version: Int
    let title: String
    let openingMessage: String
    let completionMessage: String
    let stages: [Stage]

    init(
        title: String,
        openingMessage: String,
        completionMessage: String,
        stages: [Stage]
    ) {
        format = Self.formatIdentifier
        version = Self.currentVersion
        self.title = title
        self.openingMessage = openingMessage
        self.completionMessage = completionMessage
        self.stages = stages
    }

    nonisolated func encodedData() throws -> Data {
        try validate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    nonisolated static func decode(from data: Data) throws -> HuntTransferPackage {
        guard data.count <= maximumFileSize else {
            throw HuntTransferError.fileTooLarge
        }
        try HuntTransferPreflightValidator.validate(data)

        do {
            let package = try JSONDecoder().decode(HuntTransferPackage.self, from: data)
            try package.validate()
            return package
        } catch let error as HuntTransferError {
            throw error
        } catch {
            throw HuntTransferError.invalidFile
        }
    }

    nonisolated func validate() throws {
        guard format == Self.formatIdentifier else {
            throw HuntTransferError.invalidFile
        }
        guard version == Self.currentVersion else {
            throw HuntTransferError.unsupportedVersion
        }
        guard TreasureContentValidator.isValidRequiredText(
                  title,
                  maximumLength: TreasureContentLimits.maximumHuntTitleLength
              ),
              TreasureContentValidator.isWithinLimit(
                  openingMessage,
                  maximumLength: TreasureContentLimits.maximumOpeningMessageLength
              ),
              TreasureContentValidator.isWithinLimit(
                  completionMessage,
                  maximumLength: TreasureContentLimits.maximumCompletionMessageLength
              ),
              (1...Self.maximumStageCount).contains(stages.count) else {
            throw HuntTransferError.invalidContent
        }

        var totalPhotoSize = 0
        for stage in stages {
            if let extraHints = stage.extraHints {
                guard extraHints.count
                    <= TreasureContentLimits.maximumExtraHintCount,
                    extraHints.allSatisfy({
                        TreasureContentValidator.isValidRequiredText(
                            $0,
                            maximumLength: TreasureContentLimits
                                .maximumExtraHintLength
                        )
                    }) else {
                    throw HuntTransferError.invalidContent
                }
            }

            if let extraHintContents = stage.extraHintContents {
                guard extraHintContents.count
                    <= TreasureContentLimits.maximumExtraHintCount,
                    extraHintContents.allSatisfy({
                        TreasureContentValidator.isValidRequiredText(
                            $0.text,
                            maximumLength: TreasureContentLimits
                                .maximumExtraHintLength
                        )
                    }) else {
                    throw HuntTransferError.invalidContent
                }

                if let extraHints = stage.extraHints,
                   extraHints != extraHintContents.map(\.text) {
                    throw HuntTransferError.invalidContent
                }
            }

            guard TreasureContentValidator.isValidRequiredText(
                      stage.hint,
                      maximumLength: TreasureContentLimits.maximumHintLength
                  ),
                  TreasureContentValidator.isWithinLimit(
                      stage.extraHint ?? "",
                      maximumLength: TreasureContentLimits.maximumExtraHintLength
                  ),
                  stage.availableExtraHints.count
                      <= TreasureContentLimits.maximumExtraHintCount,
                  stage.availableExtraHints.allSatisfy({
                      TreasureContentValidator.isValidRequiredText(
                          $0,
                          maximumLength: TreasureContentLimits.maximumExtraHintLength
                      )
                  }),
                  TreasureContentValidator.isWithinLimit(
                      stage.discoveryMessage,
                      maximumLength: TreasureContentLimits.maximumDiscoveryMessageLength
                  ),
                  TreasureContentValidator.isWithinLimit(
                      stage.verificationRawValue,
                      maximumLength: TreasureContentLimits.maximumVerificationIdentifierLength
                  ),
                  TreasureContentValidator.isWithinLimit(
                      stage.passphrase,
                      maximumLength: TreasureContentLimits.maximumPassphraseLength
                  ) else {
                throw HuntTransferError.invalidContent
            }

            if stage.verificationRawValue == "passphrase",
               !TreasureContentValidator.isValidRequiredText(
                   stage.passphrase,
                   maximumLength: TreasureContentLimits.maximumPassphraseLength
               ) {
                throw HuntTransferError.invalidContent
            }

            for photoData in stage.allPhotoData {
                guard photoData.count
                    <= TreasureContentLimits.maximumStagePhotoByteCount else {
                    throw HuntTransferError.invalidContent
                }
                totalPhotoSize += photoData.count
            }
        }

        guard totalPhotoSize
            <= TreasureContentLimits.maximumTotalPhotoByteCount else {
            throw HuntTransferError.invalidContent
        }
    }
}

nonisolated enum HuntTransferError: LocalizedError, Sendable {
    case invalidFile
    case unsupportedVersion
    case invalidContent
    case fileTooLarge
    case unreadablePhoto

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            "「ぼくの宝探し」で作られた共有ファイルではありません。"
        case .unsupportedVersion:
            "この共有ファイルは別のバージョンで作られています。アプリを更新してからお試しください。"
        case .invalidContent:
            "共有ファイルの内容が壊れているか、読み込めない形式です。"
        case .fileTooLarge:
            "共有ファイルのサイズが大きすぎます。"
        case .unreadablePhoto:
            "共有ファイルに読み込めない写真が含まれています。"
        }
    }
}

nonisolated enum HuntTransferPreflightValidator {
    nonisolated static func validate(_ data: Data) throws {
        var foundStages = false

        try data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var index = 0
            var containerStack: [UInt8] = []

            while index < bytes.count {
                let byte = bytes[index]

                if byte == asciiQuote {
                    let start = index + 1
                    let end = try stringEnd(in: bytes, startingAt: start)

                    if containerStack == [asciiOpenBrace],
                       matchesStagesKey(in: bytes, from: start, to: end) {
                        var lookahead = end + 1
                        skipWhitespace(in: bytes, index: &lookahead)
                        if lookahead < bytes.count,
                           bytes[lookahead] == asciiColon {
                            lookahead += 1
                            skipWhitespace(in: bytes, index: &lookahead)
                            guard lookahead < bytes.count,
                                  bytes[lookahead] == asciiOpenBracket else {
                                throw HuntTransferError.invalidFile
                            }
                            try validateStageArray(
                                in: bytes,
                                openingBracketIndex: lookahead
                            )
                            foundStages = true
                        }
                    }

                    index = end + 1
                    continue
                }

                switch byte {
                case asciiOpenBrace, asciiOpenBracket:
                    containerStack.append(byte)
                case asciiCloseBrace:
                    if containerStack.last == asciiOpenBrace {
                        containerStack.removeLast()
                    }
                case asciiCloseBracket:
                    if containerStack.last == asciiOpenBracket {
                        containerStack.removeLast()
                    }
                default:
                    break
                }
                index += 1
            }
        }

        guard foundStages else {
            throw HuntTransferError.invalidFile
        }
    }

    nonisolated private static func validateStageArray(
        in bytes: UnsafeBufferPointer<UInt8>,
        openingBracketIndex: Int
    ) throws {
        var index = openingBracketIndex + 1
        var depth = 1
        var stageCount = 0
        var isExpectingElement = true

        while index < bytes.count {
            let byte = bytes[index]

            if byte == asciiQuote {
                if depth == 1, isExpectingElement {
                    try registerStage(
                        stageCount: &stageCount,
                        isExpectingElement: &isExpectingElement
                    )
                }
                index = try stringEnd(in: bytes, startingAt: index + 1) + 1
                continue
            }

            if isWhitespace(byte) {
                index += 1
                continue
            }

            switch byte {
            case asciiOpenBrace, asciiOpenBracket:
                if depth == 1, isExpectingElement {
                    try registerStage(
                        stageCount: &stageCount,
                        isExpectingElement: &isExpectingElement
                    )
                }
                depth += 1
            case asciiCloseBrace:
                depth -= 1
                guard depth >= 1 else {
                    throw HuntTransferError.invalidFile
                }
            case asciiCloseBracket:
                depth -= 1
                if depth == 0 {
                    return
                }
                guard depth >= 1 else {
                    throw HuntTransferError.invalidFile
                }
            case asciiComma where depth == 1:
                guard !isExpectingElement else {
                    throw HuntTransferError.invalidFile
                }
                isExpectingElement = true
            default:
                if depth == 1, isExpectingElement {
                    try registerStage(
                        stageCount: &stageCount,
                        isExpectingElement: &isExpectingElement
                    )
                }
            }
            index += 1
        }

        throw HuntTransferError.invalidFile
    }

    nonisolated private static func registerStage(
        stageCount: inout Int,
        isExpectingElement: inout Bool
    ) throws {
        stageCount += 1
        guard stageCount <= HuntTransferPackage.maximumStageCount else {
            throw HuntTransferError.invalidContent
        }
        isExpectingElement = false
    }

    nonisolated private static func stringEnd(
        in bytes: UnsafeBufferPointer<UInt8>,
        startingAt start: Int
    ) throws -> Int {
        var index = start
        var isEscaped = false

        while index < bytes.count {
            let byte = bytes[index]
            if isEscaped {
                isEscaped = false
            } else if byte == asciiBackslash {
                isEscaped = true
            } else if byte == asciiQuote {
                return index
            }
            index += 1
        }

        throw HuntTransferError.invalidFile
    }

    nonisolated private static func matchesStagesKey(
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int
    ) -> Bool {
        let key: [UInt8] = [115, 116, 97, 103, 101, 115]
        guard end - start == key.count else { return false }
        return key.indices.allSatisfy { bytes[start + $0] == key[$0] }
    }

    nonisolated private static func skipWhitespace(
        in bytes: UnsafeBufferPointer<UInt8>,
        index: inout Int
    ) {
        while index < bytes.count, isWhitespace(bytes[index]) {
            index += 1
        }
    }

    nonisolated private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
    }

    private static let asciiQuote: UInt8 = 0x22
    private static let asciiBackslash: UInt8 = 0x5C
    private static let asciiColon: UInt8 = 0x3A
    private static let asciiComma: UInt8 = 0x2C
    private static let asciiOpenBrace: UInt8 = 0x7B
    private static let asciiCloseBrace: UInt8 = 0x7D
    private static let asciiOpenBracket: UInt8 = 0x5B
    private static let asciiCloseBracket: UInt8 = 0x5D
}
