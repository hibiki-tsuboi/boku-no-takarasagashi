//
//  HuntTransferFormat.swift
//  BokuNoTakarasagashi
//

import Foundation

struct HuntTransferPackage: Codable, Equatable {
    struct Stage: Codable, Equatable {
        let hint: String
        let extraHint: String?
        let hintImageData: Data?
        let discoveryMessage: String
        let verificationRawValue: String
        let passphrase: String
    }

    static let formatIdentifier = "bokunotakarasagashi-hunt"
    static let currentVersion = 1
    static let maximumFileSize = 40 * 1_024 * 1_024

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

    func encodedData() throws -> Data {
        try validate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> HuntTransferPackage {
        guard data.count <= maximumFileSize else {
            throw HuntTransferError.fileTooLarge
        }

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

    func validate() throws {
        guard format == Self.formatIdentifier else {
            throw HuntTransferError.invalidFile
        }
        guard version == Self.currentVersion else {
            throw HuntTransferError.unsupportedVersion
        }
        guard Self.isValid(title, maximumLength: 100),
              openingMessage.count <= 1_000,
              completionMessage.count <= 1_000,
              (1...10).contains(stages.count) else {
            throw HuntTransferError.invalidContent
        }

        var totalPhotoSize = 0
        for stage in stages {
            guard Self.isValid(stage.hint, maximumLength: 1_000),
                  stage.extraHint?.count ?? 0 <= 1_000,
                  stage.discoveryMessage.count
                    <= TreasureContentLimits.maximumDiscoveryMessageLength,
                  stage.verificationRawValue.count <= 40,
                  stage.passphrase.count <= 200 else {
                throw HuntTransferError.invalidContent
            }

            if stage.verificationRawValue == "passphrase",
               stage.passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw HuntTransferError.invalidContent
            }

            if let photoData = stage.hintImageData {
                guard photoData.count <= 5 * 1_024 * 1_024 else {
                    throw HuntTransferError.invalidContent
                }
                totalPhotoSize += photoData.count
            }
        }

        guard totalPhotoSize <= 20 * 1_024 * 1_024 else {
            throw HuntTransferError.invalidContent
        }
    }

    private static func isValid(_ value: String, maximumLength: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= maximumLength
    }
}

enum HuntTransferError: LocalizedError {
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
