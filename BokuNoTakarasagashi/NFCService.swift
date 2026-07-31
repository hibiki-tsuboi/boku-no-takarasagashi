//
//  NFCService.swift
//  BokuNoTakarasagashi
//

import Accessibility
@preconcurrency import CoreNFC
import SwiftUI

struct NFCWriterControl: View {
    let payload: String
    let wasPreviouslyWritten: Bool
    let onWriteSuccess: () -> Void

    @State private var sessionController: NFCSessionController?
    @State private var resultMessage: String?
    @State private var writeSucceeded = false
    @State private var resultIsError = false
    @State private var isConfirmingOverwrite = false

    init(
        payload: String,
        wasPreviouslyWritten: Bool = false,
        onWriteSuccess: @escaping () -> Void = {}
    ) {
        self.payload = payload
        self.wasPreviouslyWritten = wasPreviouslyWritten
        self.onWriteSuccess = onWriteSuccess
        _writeSucceeded = State(initialValue: wasPreviouslyWritten)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                beginWriting()
            } label: {
                Label(
                    writeSucceeded ? "別のタグにも書き込む" : "NFCタグに書き込む",
                    systemImage: "wave.3.right.circle.fill"
                )
            }
            .disabled(!NFCSessionController.isAvailable)

            if NFCSessionController.isAvailable {
                if let statusMessage {
                    Label(
                        statusMessage,
                        systemImage: resultIsError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        resultIsError
                            ? TreasureTheme.coralText
                            : TreasureTheme.tealText
                    )
                }
            } else {
                Text("NFCは対応する実機のiPhoneで設定できます。")
                    .font(.footnote)
                    .foregroundStyle(TreasureTheme.secondaryText)
            }
        }
        .confirmationDialog(
            "このタグの既存データを上書きしますか？",
            isPresented: $isConfirmingOverwrite,
            titleVisibility: .visible
        ) {
            Button("上書きする", role: .destructive) {
                beginWriting(allowsOverwrite: true)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("別の宝のデータやURL、連絡先など、現在タグに入っているデータは失われます。")
        }
        .onChange(of: payload) {
            resultMessage = nil
            resultIsError = false
            writeSucceeded = wasPreviouslyWritten
        }
        .onChange(of: wasPreviouslyWritten) { _, isWritten in
            if isWritten {
                writeSucceeded = true
            }
        }
    }

    private var statusMessage: String? {
        if let resultMessage {
            return resultMessage
        }
        guard writeSucceeded else { return nil }
        return "この宝のNFCタグは書き込み済みです。"
    }

    private func beginWriting(allowsOverwrite: Bool = false) {
        resultMessage = nil
        resultIsError = false

        let controller = NFCSessionController(
            operation: .write(
                payload: payload,
                allowsOverwrite: allowsOverwrite
            )
        ) { result in
            defer {
                sessionController = nil
            }
            switch result {
            case .success:
                writeSucceeded = true
                resultIsError = false
                resultMessage = "書き込みました。このタグを宝といっしょに置いてください。"
                onWriteSuccess()
            case let .failure(error):
                guard error != .cancelled else { return }
                if error == .containsExistingData {
                    isConfirmingOverwrite = true
                    return
                }
                resultIsError = true
                let message = error.errorDescription
                resultMessage = message
                AccessibilityNotification.Announcement(message).post()
            }
        }
        sessionController = controller
        controller.begin()
    }
}

struct NFCReaderControl: View {
    let expectedPayload: String
    let buttonTitle: String
    let instruction: String
    let successMessage: String
    let usesPrimaryButtonStyle: Bool
    let onMatch: () -> Void

    @State private var sessionController: NFCSessionController?
    @State private var errorMessage: String?

    init(
        expectedPayload: String,
        buttonTitle: String = "NFCタグを読み取る",
        instruction: String = "宝のNFCタグにiPhoneの上部を近づけてね",
        successMessage: String = "宝を見つけた！",
        usesPrimaryButtonStyle: Bool = true,
        onMatch: @escaping () -> Void
    ) {
        self.expectedPayload = expectedPayload
        self.buttonTitle = buttonTitle
        self.instruction = instruction
        self.successMessage = successMessage
        self.usesPrimaryButtonStyle = usesPrimaryButtonStyle
        self.onMatch = onMatch
    }

    var body: some View {
        VStack(spacing: 10) {
            readButton

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreasureTheme.coralText)
            } else if NFCSessionController.isAvailable {
                Text(instruction)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreasureTheme.secondaryText)
            } else {
                Text("このiPhoneではNFCを読み取れません")
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var readButton: some View {
        if usesPrimaryButtonStyle {
            Button(action: beginReading) {
                Label(buttonTitle, systemImage: "wave.3.right.circle.fill")
            }
            .buttonStyle(TreasurePrimaryButtonStyle())
            .disabled(!NFCSessionController.isAvailable)
        } else {
            Button(action: beginReading) {
                Label(buttonTitle, systemImage: "wave.3.right.circle.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!NFCSessionController.isAvailable)
        }
    }

    private func beginReading() {
        errorMessage = nil

        let controller = NFCSessionController(
            operation: .read(
                expectedPayload: expectedPayload,
                successMessage: successMessage
            )
        ) { result in
            defer {
                sessionController = nil
            }
            switch result {
            case .success:
                onMatch()
            case let .failure(error):
                guard error != .cancelled else { return }
                let message = error.errorDescription
                errorMessage = message
                AccessibilityNotification.Announcement(message).post()
            }
        }
        sessionController = controller
        controller.begin()
    }
}

@MainActor
final class NFCSessionController: NSObject, NFCNDEFReaderSessionDelegate {
    enum Operation {
        case read(expectedPayload: String, successMessage: String)
        case write(payload: String, allowsOverwrite: Bool)
    }

    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private let operation: Operation
    private let completion: (Result<Void, TreasureNFCError>) -> Void
    private var session: NFCNDEFReaderSession?
    private var completionAfterInvalidation:
        Result<Void, TreasureNFCError>?
    private var didComplete = false

    init(
        operation: Operation,
        completion: @escaping (Result<Void, TreasureNFCError>) -> Void
    ) {
        self.operation = operation
        self.completion = completion
    }

    func begin() {
        guard Self.isAvailable else {
            finish(.failure(.notAvailable))
            return
        }

        let readerSession = NFCNDEFReaderSession(
            delegate: self,
            queue: .main,
            invalidateAfterFirstRead: false
        )
        switch operation {
        case .read:
            readerSession.alertMessage = "宝といっしょにあるNFCタグへ、iPhoneの上部を近づけてください。"
        case .write:
            readerSession.alertMessage = "書き込むNFCタグへ、iPhoneの上部を近づけてください。"
        }
        session = readerSession
        readerSession.begin()
    }

    nonisolated func readerSessionDidBecomeActive(
        _ session: NFCNDEFReaderSession
    ) {}

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {}

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetect tags: [NFCNDEFTag]
    ) {
        let tagsBox = UncheckedSendableBox(tags)
        let sessionBox = UncheckedSendableBox(session)
        MainActor.assumeIsolated {
            handleDetectedTags(tagsBox.value, in: sessionBox.value)
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: any Error
    ) {
        let errorBox = UncheckedSendableBox(error)
        MainActor.assumeIsolated {
            handleInvalidation(errorBox.value)
        }
    }

    private func handleDetectedTags(
        _ tags: [NFCNDEFTag],
        in session: NFCNDEFReaderSession
    ) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "NFCタグは1枚だけ近づけてください。"
            session.restartPolling()
            return
        }

        let sessionBox = UncheckedSendableBox(session)
        let tagBox = UncheckedSendableBox(tag)
        session.connect(
            to: tag
        ) { [weak self, sessionBox, tagBox] error in
            MainActor.assumeIsolated {
                guard let self else { return }

                let connectedSession = sessionBox.value
                let connectedTag = tagBox.value
                if error != nil {
                    connectedSession.alertMessage = "タグへ接続できませんでした。もう一度近づけてください。"
                    connectedSession.restartPolling()
                    return
                }

                switch self.operation {
                case let .read(expectedPayload, successMessage):
                    self.read(
                        tag: connectedTag,
                        expectedPayload: expectedPayload,
                        successMessage: successMessage,
                        session: connectedSession
                    )
                case let .write(payload, allowsOverwrite):
                    self.write(
                        payload: payload,
                        allowsOverwrite: allowsOverwrite,
                        to: connectedTag,
                        session: connectedSession
                    )
                }
            }
        }
    }

    private func read(
        tag: NFCNDEFTag,
        expectedPayload: String,
        successMessage: String,
        session: NFCNDEFReaderSession
    ) {
        let sessionBox = UncheckedSendableBox(session)
        tag.readNDEF { [weak self, sessionBox] message, error in
            let messageBox = message.map(UncheckedSendableBox.init)
            MainActor.assumeIsolated {
                guard let self else { return }

                let activeSession = sessionBox.value
                guard error == nil, let message = messageBox?.value else {
                    activeSession.alertMessage = "このタグを読み取れませんでした。別の向きでもう一度ためしてください。"
                    activeSession.restartPolling()
                    return
                }

                let values = message.records.compactMap { record -> String? in
                    let (text, _) = record.wellKnownTypeTextPayload()
                    if let text {
                        return text
                    }
                    if let url = record.wellKnownTypeURIPayload() {
                        return url.absoluteString
                    }
                    return nil
                }

                if values.contains(where: {
                    TreasurePayload.matches($0, expected: expectedPayload)
                }) {
                    activeSession.alertMessage = successMessage
                    self.finishAfterInvalidation(
                        .success(()),
                        session: activeSession
                    )
                } else {
                    activeSession.alertMessage = "これは別の宝のNFCタグみたい。ほかのタグをさがしてみよう。"
                    activeSession.restartPolling()
                }
            }
        }
    }

    private func write(
        payload: String,
        allowsOverwrite: Bool,
        to tag: NFCNDEFTag,
        session: NFCNDEFReaderSession
    ) {
        let sessionBox = UncheckedSendableBox(session)
        let tagBox = UncheckedSendableBox(tag)
        tag.queryNDEFStatus {
            [weak self, sessionBox, tagBox] status, capacity, error in
            MainActor.assumeIsolated {
                guard let self else { return }

                let activeSession = sessionBox.value
                guard error == nil else {
                    self.fail(
                        .connectionFailed,
                        message: "タグの状態を確認できませんでした。",
                        session: activeSession
                    )
                    return
                }

                switch status {
                case .notSupported:
                    self.fail(
                        .notNDEF,
                        message: "このタグはNDEF形式に対応していません。",
                        session: activeSession
                    )

                case .readOnly:
                    self.fail(
                        .readOnly,
                        message: "このタグは読み取り専用です。",
                        session: activeSession
                    )

                case .readWrite:
                    guard let record = NFCNDEFPayload.wellKnownTypeTextPayload(
                        string: payload,
                        locale: Locale(identifier: "ja_JP")
                    ) else {
                        self.fail(
                            .writeFailed,
                            message: "タグへ書き込むデータを作れませんでした。",
                            session: activeSession
                        )
                        return
                    }

                    let message = NFCNDEFMessage(records: [record])
                    guard message.length <= capacity else {
                        self.fail(
                            .capacityTooSmall,
                            message: "このタグにはデータが入りきりません。",
                            session: activeSession
                        )
                        return
                    }

                    self.prepareWrite(
                        message,
                        intendedPayload: payload,
                        allowsOverwrite: allowsOverwrite,
                        to: tagBox.value,
                        session: activeSession
                    )

                @unknown default:
                    self.fail(
                        .writeFailed,
                        message: "このNFCタグには対応していません。",
                        session: activeSession
                    )
                }
            }
        }
    }

    private func prepareWrite(
        _ message: NFCNDEFMessage,
        intendedPayload: String,
        allowsOverwrite: Bool,
        to tag: NFCNDEFTag,
        session: NFCNDEFReaderSession
    ) {
        guard !allowsOverwrite else {
            commitWrite(message, to: tag, session: session)
            return
        }

        let sessionBox = UncheckedSendableBox(session)
        let tagBox = UncheckedSendableBox(tag)
        let writeMessageBox = UncheckedSendableBox(message)
        tag.readNDEF {
            [weak self, sessionBox, tagBox, writeMessageBox]
            existingMessage,
            error in
            let messageBox = existingMessage.map(UncheckedSendableBox.init)
            MainActor.assumeIsolated {
                guard let self else { return }

                let activeSession = sessionBox.value
                if let error {
                    if NFCExistingDataReadPolicy.errorMeansTagIsEmpty(error) {
                        self.commitWrite(
                            writeMessageBox.value,
                            to: tagBox.value,
                            session: activeSession
                        )
                        return
                    }

                    self.fail(
                        .connectionFailed,
                        message: "タグの既存データを確認できませんでした。",
                        session: activeSession
                    )
                    return
                }

                if let existingMessage = messageBox?.value,
                   self.requiresOverwriteConfirmation(
                       for: existingMessage,
                       intendedPayload: intendedPayload
                   ) {
                    activeSession.alertMessage =
                        "既存データがあります。上書きする場合は、確認後にもう一度タグを近づけてください。"
                    self.finishAfterInvalidation(
                        .failure(.containsExistingData),
                        session: activeSession
                    )
                    return
                }

                self.commitWrite(
                    writeMessageBox.value,
                    to: tagBox.value,
                    session: activeSession
                )
            }
        }
    }

    private func requiresOverwriteConfirmation(
        for message: NFCNDEFMessage,
        intendedPayload: String
    ) -> Bool {
        let existingRecords = message.records.map { record in
            let (text, _) = record.wellKnownTypeTextPayload()
            if let text {
                return NFCExistingRecord.readableValue(text)
            }
            if let url = record.wellKnownTypeURIPayload() {
                return NFCExistingRecord.readableValue(url.absoluteString)
            }
            return NFCExistingRecord.unrecognized
        }

        return NFCExistingDataWritePolicy.requiresOverwriteConfirmation(
            existingRecords: existingRecords,
            intendedPayload: intendedPayload
        )
    }

    private func commitWrite(
        _ message: NFCNDEFMessage,
        to tag: NFCNDEFTag,
        session: NFCNDEFReaderSession
    ) {
        let sessionBox = UncheckedSendableBox(session)
        tag.writeNDEF(message) { [weak self, sessionBox] error in
            MainActor.assumeIsolated {
                guard let self else { return }

                let activeSession = sessionBox.value
                if error == nil {
                    activeSession.alertMessage = "NFCタグへ書き込みました！"
                    activeSession.invalidate()
                    self.finish(.success(()))
                } else {
                    self.fail(
                        .writeFailed,
                        message: "書き込みに失敗しました。もう一度ためしてください。",
                        session: activeSession
                    )
                }
            }
        }
    }

    private func fail(
        _ error: TreasureNFCError,
        message: String,
        session: NFCNDEFReaderSession
    ) {
        session.invalidate(errorMessage: message)
        finish(.failure(error))
    }

    private func handleInvalidation(_ error: any Error) {
        guard !didComplete else { return }

        let fallbackError: TreasureNFCError
        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            fallbackError = .cancelled
        } else {
            fallbackError = .sessionFailed
        }
        finish(
            NFCSessionInvalidationResultResolver.resolve(
                pendingResult: completionAfterInvalidation,
                fallbackError: fallbackError
            )
        )
    }

    private func finishAfterInvalidation(
        _ result: Result<Void, TreasureNFCError>,
        session: NFCNDEFReaderSession
    ) {
        guard !didComplete else { return }
        completionAfterInvalidation = result
        session.invalidate()
    }

    private func finish(_ result: Result<Void, TreasureNFCError>) {
        guard !didComplete else { return }
        didComplete = true
        completionAfterInvalidation = nil
        session = nil
        completion(result)
    }
}

enum NFCSessionInvalidationResultResolver {
    static func resolve(
        pendingResult: Result<Void, TreasureNFCError>?,
        fallbackError: TreasureNFCError
    ) -> Result<Void, TreasureNFCError> {
        pendingResult ?? .failure(fallbackError)
    }
}

enum NFCExistingDataReadPolicy {
    static func errorMeansTagIsEmpty(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == NFCErrorDomain
            && error.code
                == NFCReaderError.Code
                    .ndefReaderSessionErrorZeroLengthMessage.rawValue
    }
}

enum NFCExistingRecord: Equatable {
    case readableValue(String)
    case unrecognized
}

enum NFCExistingDataWritePolicy {
    static func requiresOverwriteConfirmation(
        existingRecords: [NFCExistingRecord],
        intendedPayload: String
    ) -> Bool {
        existingRecords.contains { record in
            switch record {
            case let .readableValue(value):
                !TreasurePayload.matches(value, expected: intendedPayload)
            case .unrecognized:
                true
            }
        }
    }
}

private nonisolated final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

enum TreasureNFCError: Error, Equatable {
    case cancelled
    case notAvailable
    case connectionFailed
    case notNDEF
    case readOnly
    case capacityTooSmall
    case containsExistingData
    case writeFailed
    case sessionFailed

    var errorDescription: String {
        switch self {
        case .cancelled:
            "キャンセルしました。"
        case .notAvailable:
            "このiPhoneではNFCを利用できません。"
        case .connectionFailed:
            "NFCタグへ接続できませんでした。"
        case .notNDEF:
            "NDEF形式に対応したNFCタグを使ってください。"
        case .readOnly:
            "読み取り専用のため書き込めません。"
        case .capacityTooSmall:
            "タグの保存容量が足りません。"
        case .containsExistingData:
            "このタグには既存のデータがあります。"
        case .writeFailed:
            "NFCタグへの書き込みに失敗しました。"
        case .sessionFailed:
            "NFCの読み取りを完了できませんでした。"
        }
    }
}
