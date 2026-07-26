//
//  NFCService.swift
//  BokuNoTakarasagashi
//

@preconcurrency import CoreNFC
import SwiftUI

struct NFCWriterControl: View {
    let payload: String
    let onWriteSuccess: () -> Void

    @State private var sessionController: NFCSessionController?
    @State private var resultMessage: String?
    @State private var writeSucceeded = false

    init(
        payload: String,
        onWriteSuccess: @escaping () -> Void = {}
    ) {
        self.payload = payload
        self.onWriteSuccess = onWriteSuccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: beginWriting) {
                Label(
                    writeSucceeded ? "別のタグにも書き込む" : "NFCタグに書き込む",
                    systemImage: "wave.3.right.circle.fill"
                )
            }
            .disabled(!NFCSessionController.isAvailable)

            if NFCSessionController.isAvailable {
                if let resultMessage {
                    Label(
                        resultMessage,
                        systemImage: writeSucceeded
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        writeSucceeded
                            ? TreasureTheme.teal
                            : TreasureTheme.coralText
                    )
                }
            } else {
                Text("NFCは対応する実機のiPhoneで設定できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func beginWriting() {
        resultMessage = nil

        let controller = NFCSessionController(
            operation: .write(payload: payload)
        ) { result in
            switch result {
            case .success:
                writeSucceeded = true
                resultMessage = "書き込みました。このタグを宝といっしょに置いてください。"
                onWriteSuccess()
            case let .failure(error):
                guard error != .cancelled else { return }
                writeSucceeded = false
                resultMessage = error.errorDescription
            }
            sessionController = nil
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
                    .foregroundStyle(.secondary)
            } else {
                Text("このiPhoneではNFCを読み取れません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            switch result {
            case .success:
                onMatch()
            case let .failure(error):
                guard error != .cancelled else { return }
                errorMessage = error.errorDescription
            }
            sessionController = nil
        }
        sessionController = controller
        controller.begin()
    }
}

@MainActor
final class NFCSessionController: NSObject, NFCNDEFReaderSessionDelegate {
    enum Operation {
        case read(expectedPayload: String, successMessage: String)
        case write(payload: String)
    }

    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private let operation: Operation
    private let completion: (Result<Void, TreasureNFCError>) -> Void
    private var session: NFCNDEFReaderSession?
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
                case let .write(payload):
                    self.write(
                        payload: payload,
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
                    activeSession.invalidate()
                    self.finish(.success(()))
                } else {
                    activeSession.alertMessage = "これは別の宝のNFCタグみたい。ほかのタグをさがしてみよう。"
                    activeSession.restartPolling()
                }
            }
        }
    }

    private func write(
        payload: String,
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

                    tagBox.value.writeNDEF(
                        message
                    ) { [weak self, sessionBox] error in
                        MainActor.assumeIsolated {
                            guard let self else { return }

                            let writingSession = sessionBox.value
                            if error == nil {
                                writingSession.alertMessage = "NFCタグへ書き込みました！"
                                writingSession.invalidate()
                                self.finish(.success(()))
                            } else {
                                self.fail(
                                    .writeFailed,
                                    message: "書き込みに失敗しました。もう一度ためしてください。",
                                    session: writingSession
                                )
                            }
                        }
                    }

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

        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            finish(.failure(.cancelled))
        } else {
            finish(.failure(.sessionFailed))
        }
    }

    private func finish(_ result: Result<Void, TreasureNFCError>) {
        guard !didComplete else { return }
        didComplete = true
        session = nil
        completion(result)
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
        case .writeFailed:
            "NFCタグへの書き込みに失敗しました。"
        case .sessionFailed:
            "NFCの読み取りを完了できませんでした。"
        }
    }
}
