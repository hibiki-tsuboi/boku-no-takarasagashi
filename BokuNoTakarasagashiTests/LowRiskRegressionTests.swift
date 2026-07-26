//
//  LowRiskRegressionTests.swift
//  BokuNoTakarasagashiTests
//

import SwiftData
import XCTest
@testable import BokuNoTakarasagashi

final class LowRiskRegressionTests: XCTestCase {
    @MainActor
    func testContentLimitsMatchTransferValidation() throws {
        let package = HuntTransferPackage(
            title: String(
                repeating: "宝",
                count: TreasureContentLimits.maximumHuntTitleLength
            ),
            openingMessage: String(
                repeating: "始",
                count: TreasureContentLimits.maximumOpeningMessageLength
            ),
            completionMessage: String(
                repeating: "終",
                count: TreasureContentLimits.maximumCompletionMessageLength
            ),
            stages: [
                .init(
                    hint: String(
                        repeating: "ヒ",
                        count: TreasureContentLimits.maximumHintLength
                    ),
                    extraHint: String(
                        repeating: "助",
                        count: TreasureContentLimits.maximumExtraHintLength
                    ),
                    hintImageData: nil,
                    discoveryMessage: String(
                        repeating: "発",
                        count: TreasureContentLimits.maximumDiscoveryMessageLength
                    ),
                    verificationRawValue: TreasureVerification.passphrase.rawValue,
                    passphrase: String(
                        repeating: "合",
                        count: TreasureContentLimits.maximumPassphraseLength
                    )
                ),
            ]
        )

        XCTAssertNoThrow(try package.validate())
        XCTAssertEqual(
            TreasureContentValidator.limited(
                package.title + "超",
                maximumLength: TreasureContentLimits.maximumHuntTitleLength
            ).count,
            TreasureContentLimits.maximumHuntTitleLength
        )

        let invalidPackage = HuntTransferPackage(
            title: package.title + "超",
            openingMessage: package.openingMessage,
            completionMessage: package.completionMessage,
            stages: package.stages
        )
        XCTAssertThrowsError(try invalidPackage.validate())
    }

    @MainActor
    func testContentLimitsRejectOversizedSingleGrapheme() {
        let pathologicalValue = "a" + String(
            repeating: "\u{0301}",
            count: TreasureContentValidator.maximumUTF8ByteCount(
                forCharacterLimit: TreasureContentLimits.maximumHuntTitleLength
            )
        )

        XCTAssertEqual(pathologicalValue.count, 1)
        XCTAssertFalse(
            TreasureContentValidator.isWithinLimit(
                pathologicalValue,
                maximumLength: TreasureContentLimits.maximumHuntTitleLength
            )
        )
        XCTAssertTrue(
            TreasureContentValidator.limited(
                pathologicalValue,
                maximumLength: TreasureContentLimits.maximumHuntTitleLength
            ).isEmpty
        )
    }

    @MainActor
    func testDuplicateTitleKeepsSuffixWithinSharedLimit() throws {
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
            title: String(
                repeating: "宝",
                count: TreasureContentLimits.maximumHuntTitleLength
            ),
            openingMessage: "開始",
            completionMessage: "完了",
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

        let copy = try HuntTransferService.duplicate(hunt, in: context)
        let copyPackage = HuntTransferPackage(hunt: copy)

        XCTAssertTrue(copy.title.hasSuffix("（コピー）"))
        XCTAssertLessThanOrEqual(
            copy.title.count,
            TreasureContentLimits.maximumHuntTitleLength
        )
        XCTAssertNoThrow(try copyPackage.validate())
    }

    @MainActor
    func testSpeechRequestSwitchesDirectlyToDifferentText() {
        XCTAssertEqual(
            HintSpeechRequestAction.resolve(
                isSpeaking: true,
                spokenText: "通常ヒント",
                requestedText: "おたすけヒント"
            ),
            .speak
        )
        XCTAssertEqual(
            HintSpeechRequestAction.resolve(
                isSpeaking: true,
                spokenText: "通常ヒント",
                requestedText: "通常ヒント"
            ),
            .stop
        )
        XCTAssertEqual(
            HintSpeechRequestAction.resolve(
                isSpeaking: false,
                spokenText: "",
                requestedText: "通常ヒント"
            ),
            .speak
        )
    }

    @MainActor
    func testTextColorsMeetNormalTextContrast() {
        let textColors = [
            TreasureTheme.goldTextComponents,
            TreasureTheme.coralTextComponents,
        ]

        for textColor in textColors {
            XCTAssertGreaterThanOrEqual(
                textColor.contrastRatio(with: TreasureTheme.whiteComponents),
                4.5
            )
            XCTAssertGreaterThanOrEqual(
                textColor.contrastRatio(with: TreasureTheme.creamComponents),
                4.5
            )
        }
    }
}
