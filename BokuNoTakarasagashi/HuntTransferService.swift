//
//  HuntTransferService.swift
//  BokuNoTakarasagashi
//

import Foundation
import ImageIO
import SwiftData

nonisolated struct TemporaryHuntShareFile: Sendable {
    let directoryURL: URL
    let fileURL: URL

    nonisolated func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

nonisolated struct ValidatedHuntTransferPackage: Sendable {
    let package: HuntTransferPackage

    fileprivate init(package: HuntTransferPackage) {
        self.package = package
    }
}

enum HuntTransferService {
    static func duplicate(
        _ source: TreasureHunt,
        in modelContext: ModelContext
    ) throws -> TreasureHunt {
        let copyTitle = TreasureContentValidator.duplicateTitle(
            from: source.title
        )
        let package = HuntTransferPackage(
            hunt: source,
            title: copyTitle
        )
        try package.validate()

        let copy = try makeHunt(
            from: package,
            title: copyTitle,
            parentPIN: "0000",
            in: modelContext
        )
        copy.parentPINDigest = source.parentPINDigest
        try modelContext.save()
        return copy
    }

    static func importHunt(
        from validatedPackage: ValidatedHuntTransferPackage,
        parentPIN: String,
        in modelContext: ModelContext
    ) throws -> TreasureHunt {
        let package = validatedPackage.package
        let hunt = try makeHunt(
            from: package,
            title: package.title,
            parentPIN: parentPIN,
            in: modelContext
        )
        try modelContext.save()
        return hunt
    }

    nonisolated static func readPackage(
        from url: URL
    ) throws -> ValidatedHuntTransferPackage {
        try Task.checkCancellation()
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
        try Task.checkCancellation()
        let package = try HuntTransferPackage.decode(from: data)
        try validateAppContent(package)
        try Task.checkCancellation()
        return ValidatedHuntTransferPackage(package: package)
    }

    nonisolated static func makeTemporaryShareFile(
        from package: HuntTransferPackage
    ) throws -> TemporaryHuntShareFile {
        try Task.checkCancellation()
        try validateAppContent(package)
        let data = try package.encodedData()
        try Task.checkCancellation()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HuntShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL
            .appendingPathComponent(safeFileName(for: package.title))
            .appendingPathExtension("json")

        do {
            try Task.checkCancellation()
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

    nonisolated private static func validateAppContent(
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

    nonisolated private static func isValidImage(_ data: Data) -> Bool {
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

    nonisolated private static func safeFileName(for title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = title.components(separatedBy: invalidCharacters)
        let joined = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = joined.isEmpty ? "宝探し" : String(joined.prefix(60))
        return "\(baseName)-ぼくの宝探し"
    }
}

extension HuntTransferPackage {
    @MainActor
    init(
        hunt: TreasureHunt,
        title: String? = nil
    ) {
        self.init(
            title: title ?? hunt.title,
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
