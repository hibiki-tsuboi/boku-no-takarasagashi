//
//  ParentAccessAuthenticator.swift
//  BokuNoTakarasagashi
//

import LocalAuthentication

enum ParentAccessAuthenticator {
    static func authenticate(
        reason: String = "おうちの人専用画面を開くために認証します。"
    ) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "キャンセル"

        var evaluationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &evaluationError
        ) else {
            throw ParentAccessAuthenticationError.unavailable(
                evaluationError?.localizedDescription
            )
        }

        let succeeded = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
        guard succeeded else {
            throw ParentAccessAuthenticationError.failed
        }
    }
}

private enum ParentAccessAuthenticationError: LocalizedError {
    case unavailable(String?)
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            if let detail, !detail.isEmpty {
                return "この端末では認証を利用できません。端末の設定を確認してください。\n\(detail)"
            }
            return "この端末では認証を利用できません。端末の設定を確認してください。"
        case .failed:
            return "おうちの人の認証を完了できませんでした。"
        }
    }
}
