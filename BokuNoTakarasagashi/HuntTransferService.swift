//
//  HuntTransferService.swift
//  BokuNoTakarasagashi
//

import Foundation
import ImageIO
import SwiftData

struct TemporaryHuntShareFile {
    let directoryURL: URL
    let fileURL: URL

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

enum HuntTransferService {
    static func duplicate(
        _ source: TreasureHunt,
        in modelContext: ModelContext
    ) throws -> TreasureHunt {
        let copy = TreasureHunt(
            title: "\(source.title)（コピー）",
            openingMessage: source.openingMessage,
            completionMessage: source.completionMessage,
            parentPIN: "0000"
        )
        copy.parentPINDigest = source.parentPINDigest
        modelContext.insert(copy)

        for (index, sourceStage) in source.sortedStages.enumerated() {
            let stage = TreasureStage(
                orderIndex: index,
                hint: sourceStage.hint,
                extraHint: sourceStage.extraHint,
                hintImageData: sourceStage.hintImageData,
                discoveryMessage: sourceStage.discoveryMessage,
                verification: sourceStage.verification,
                passphrase: sourceStage.passphrase,
                verificationToken: UUID().uuidString,
                hunt: copy
            )
            modelContext.insert(stage)
            copy.stages.append(stage)
        }
        try modelContext.save()
        return copy
    }

    static func importHunt(
        from package: HuntTransferPackage,
        parentPIN: String,
        in modelContext: ModelContext
    ) throws -> TreasureHunt {
        let hunt = try makeHunt(
            from: package,
            title: package.title,
            parentPIN: parentPIN,
            in: modelContext
        )
        try modelContext.save()
        return hunt
    }

    static func readPackage(from url: URL) throws -> HuntTransferPackage {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize,
           fileSize > HuntTransferPackage.maximumFileSize {
            throw HuntTransferError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let package = try HuntTransferPackage.decode(from: data)
        try validateAppContent(package)
        return package
    }

    static func makeTemporaryShareFile(
        for hunt: TreasureHunt
    ) throws -> TemporaryHuntShareFile {
        let package = HuntTransferPackage(hunt: hunt)
        try validateAppContent(package)
        let data = try package.encodedData()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HuntShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL
            .appendingPathComponent(safeFileName(for: hunt.title))
            .appendingPathExtension("json")

        do {
            try data.write(to: fileURL, options: .atomic)
            return TemporaryHuntShareFile(
                directoryURL: directoryURL,
                fileURL: fileURL
            )
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }
    }

    private static func makeHunt(
        from package: HuntTransferPackage,
        title: String,
        parentPIN: String,
        in modelContext: ModelContext
    ) throws -> TreasureHunt {
        try package.validate()
        try validateAppContent(package)

        let hunt = TreasureHunt(
            title: title,
            openingMessage: package.openingMessage,
            completionMessage: package.completionMessage,
            parentPIN: parentPIN
        )
        modelContext.insert(hunt)

        for (index, transferredStage) in package.stages.enumerated() {
            guard let verification = TreasureVerification(
                rawValue: transferredStage.verificationRawValue
            ) else {
                throw HuntTransferError.invalidContent
            }

            let stage = TreasureStage(
                orderIndex: index,
                hint: transferredStage.hint,
                extraHint: transferredStage.extraHint,
                hintImageData: transferredStage.hintImageData,
                discoveryMessage: transferredStage.discoveryMessage,
                verification: verification,
                passphrase: transferredStage.passphrase,
                verificationToken: UUID().uuidString,
                hunt: hunt
            )
            modelContext.insert(stage)
            hunt.stages.append(stage)
        }
        return hunt
    }

    private static func validateAppContent(
        _ package: HuntTransferPackage
    ) throws {
        for stage in package.stages {
            guard TreasureVerification(rawValue: stage.verificationRawValue) != nil else {
                throw HuntTransferError.invalidContent
            }
            if let imageData = stage.hintImageData,
               !isValidImage(imageData) {
                throw HuntTransferError.unreadablePhoto
            }
        }
    }

    private static func isValidImage(_ data: Data) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(
                  source,
                  0,
                  options
              ) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return false
        }

        let pixelWidth = width.intValue
        let pixelHeight = height.intValue
        return (1...4_096).contains(pixelWidth)
            && (1...4_096).contains(pixelHeight)
            && pixelWidth * pixelHeight <= 16_000_000
    }

    private static func safeFileName(for title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = title.components(separatedBy: invalidCharacters)
        let joined = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = joined.isEmpty ? "宝探し" : String(joined.prefix(60))
        return "\(baseName)-ぼくの宝探し"
    }
}

private extension HuntTransferPackage {
    init(hunt: TreasureHunt) {
        self.init(
            title: hunt.title,
            openingMessage: hunt.openingMessage,
            completionMessage: hunt.completionMessage,
            stages: hunt.sortedStages.map { stage in
                Stage(
                    hint: stage.hint,
                    extraHint: stage.extraHint,
                    hintImageData: stage.hintImageData,
                    discoveryMessage: stage.discoveryMessage,
                    verificationRawValue: stage.verification.rawValue,
                    passphrase: stage.passphrase
                )
            }
        )
    }
}
