//
//  MediumRiskRegressionTests.swift
//  BokuNoTakarasagashiTests
//

import ImageIO
import SwiftData
import UIKit
import XCTest
@testable import BokuNoTakarasagashi

final class MediumRiskRegressionTests: XCTestCase {
    @MainActor
    func testParentPINNormalizesAndMatches() {
        let digest = ParentPIN.digest("1234")

        XCTAssertTrue(ParentPIN.matches("1234", digest: digest))
        XCTAssertTrue(ParentPIN.matches("１２３４", digest: digest))
        XCTAssertFalse(ParentPIN.matches("4321", digest: digest))
        XCTAssertEqual(ParentPIN.digitsOnly("1a２3-45"), "1234")
    }

    @MainActor
    func testPreparationRequiresConfirmedQRAndNFCWrite() {
        XCTAssertFalse(
            TreasurePreparationRequirement.isToolPrepared(
                verification: .qrCode,
                qrCodeIsPrepared: false,
                qrCodeIsAvailable: true,
                nfcWasWritten: false,
                nfcIsAvailable: true
            )
        )
        XCTAssertTrue(
            TreasurePreparationRequirement.isToolPrepared(
                verification: .qrCode,
                qrCodeIsPrepared: true,
                qrCodeIsAvailable: true,
                nfcWasWritten: false,
                nfcIsAvailable: true
            )
        )
        XCTAssertFalse(
            TreasurePreparationRequirement.isToolPrepared(
                verification: .qrCode,
                qrCodeIsPrepared: true,
                qrCodeIsAvailable: false,
                nfcWasWritten: false,
                nfcIsAvailable: true
            )
        )
        XCTAssertFalse(
            TreasurePreparationRequirement.isToolPrepared(
                verification: .nfc,
                qrCodeIsPrepared: true,
                qrCodeIsAvailable: true,
                nfcWasWritten: false,
                nfcIsAvailable: true
            )
        )
        XCTAssertTrue(
            TreasurePreparationRequirement.isToolPrepared(
                verification: .nfc,
                qrCodeIsPrepared: false,
                qrCodeIsAvailable: true,
                nfcWasWritten: true,
                nfcIsAvailable: true
            )
        )
    }

    @MainActor
    func testTransferRejectsEleventhStageBeforeDecodingPackage() throws {
        let stage = """
        {
          "discoveryMessage": "発見",
          "hint": "ヒント",
          "passphrase": "",
          "verificationRawValue": "honesty"
        }
        """
        let stages = Array(
            repeating: stage,
            count: HuntTransferPackage.maximumStageCount + 1
        ).joined(separator: ",")
        let json = """
        {
          "completionMessage": "完了",
          "format": "\(HuntTransferPackage.formatIdentifier)",
          "openingMessage": "開始",
          "stages": [\(stages)],
          "title": "テスト",
          "version": \(HuntTransferPackage.currentVersion)
        }
        """

        XCTAssertThrowsError(
            try HuntTransferPackage.decode(from: Data(json.utf8))
        ) { error in
            guard case HuntTransferError.invalidContent = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    func testTransferAllowsStagesTextInsideTitle() throws {
        let package = HuntTransferPackage(
            title: "文字列の中の \"stages\"",
            openingMessage: "開始",
            completionMessage: "完了",
            stages: [
                .init(
                    hint: "ヒント",
                    extraHint: nil,
                    hintImageData: nil,
                    discoveryMessage: "発見",
                    verificationRawValue: TreasureVerification.honesty.rawValue,
                    passphrase: ""
                ),
            ]
        )

        let decoded = try HuntTransferPackage.decode(
            from: package.encodedData()
        )

        XCTAssertEqual(decoded, package)
    }

    @MainActor
    func testDeletingHuntCascadesToStages() throws {
        let schema = Schema([
            TreasureHunt.self,
            TreasureStage.self,
            AdventureRecord.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let hunt = TreasureHunt(
            title: "削除テスト",
            openingMessage: "",
            completionMessage: "",
            parentPIN: "1234"
        )
        let stage = TreasureStage(
            orderIndex: 0,
            hint: "ヒント",
            discoveryMessage: "発見",
            verification: .honesty,
            passphrase: "",
            hunt: hunt
        )
        context.insert(hunt)
        context.insert(stage)
        hunt.stages.append(stage)
        try context.save()

        context.delete(hunt)
        try context.save()

        let verificationContext = ModelContext(container)
        XCTAssertTrue(
            try verificationContext.fetch(FetchDescriptor<TreasureHunt>()).isEmpty
        )
        XCTAssertTrue(
            try verificationContext.fetch(FetchDescriptor<TreasureStage>()).isEmpty
        )
    }

    @MainActor
    func testStoreResetRemovesOnlyKnownStoreFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let storeURL = directory.appending(path: "test.store")
        let relatedURLs = [
            storeURL,
            URL(filePath: storeURL.path + "-shm"),
            URL(filePath: storeURL.path + "-wal"),
        ]
        for url in relatedURLs {
            try Data("test".utf8).write(to: url)
        }
        let supportURL = URL(
            filePath: storeURL.path + "_SUPPORT",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: supportURL,
            withIntermediateDirectories: true
        )
        let unrelatedURL = directory.appending(path: "keep.txt")
        try Data("keep".utf8).write(to: unrelatedURL)

        try PersistenceStoreFactory.removeStore(at: storeURL)

        for url in relatedURLs + [supportURL] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
    }

    @MainActor
    func testPhotoProcessorDownsamplesBeforeStorage() throws {
        let size = CGSize(width: 2_000, height: 1_000)
        let sourceImage = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let sourceData = try XCTUnwrap(sourceImage.pngData())

        let storedData = try HintPhotoProcessor.storedData(from: sourceData)
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        try sourceData.write(to: sourceURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }
        let storedFileData = try HintPhotoProcessor.storedData(from: sourceURL)
        let source = try XCTUnwrap(
            CGImageSourceCreateWithData(storedData as CFData, nil)
        )
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        )
        let width = try XCTUnwrap(
            properties[kCGImagePropertyPixelWidth] as? NSNumber
        ).intValue
        let height = try XCTUnwrap(
            properties[kCGImagePropertyPixelHeight] as? NSNumber
        ).intValue

        XCTAssertLessThanOrEqual(max(width, height), 1_600)
        XCTAssertLessThanOrEqual(
            storedData.count,
            TreasureContentLimits.maximumStagePhotoByteCount
        )
        XCTAssertLessThanOrEqual(
            storedFileData.count,
            TreasureContentLimits.maximumStagePhotoByteCount
        )
    }

    @MainActor
    func testTransferShareFileSupportsLongEmojiTitle() throws {
        let package = HuntTransferPackage(
            title: String(repeating: "👨‍👩‍👧‍👦", count: 60),
            openingMessage: "開始",
            completionMessage: "完了",
            stages: [
                .init(
                    hint: "ヒント",
                    extraHint: nil,
                    hintImageData: nil,
                    discoveryMessage: "発見",
                    verificationRawValue: TreasureVerification.honesty.rawValue,
                    passphrase: ""
                ),
            ]
        )

        let shareFile = try HuntTransferService.makeTemporaryShareFile(
            from: package
        )
        defer {
            shareFile.remove()
        }

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: shareFile.fileURL.path)
        )
        XCTAssertLessThanOrEqual(
            shareFile.fileURL.lastPathComponent
                .decomposedStringWithCanonicalMapping
                .utf8
                .count,
            255
        )
    }

    @MainActor
    func testTreasurePayloadOwnershipDetection() {
        let payload = TreasurePayload.make(token: UUID().uuidString)

        XCTAssertTrue(TreasurePayload.isTreasurePayload(payload))
        XCTAssertFalse(
            TreasurePayload.isTreasurePayload("https://example.com")
        )
    }
}
