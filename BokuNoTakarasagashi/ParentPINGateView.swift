//
//  ParentPINGateView.swift
//  BokuNoTakarasagashi
//

import LocalAuthentication
import SwiftUI

struct ParentPINGateView: View {
    let expectedDigest: String
    let onCancel: () -> Void
    let onUnlock: () -> Void

    @State private var pin = ""
    @State private var errorMessage: String?
    @State private var isAuthenticatingDeviceOwner = false
    @FocusState private var pinIsFocused: Bool

    var body: some View {
        NavigationStack {
            TreasureBackground(style: .security) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(TreasureTheme.tealText)
                                .accessibilityHidden(true)

                            VStack(spacing: 8) {
                                Text("おうちの人専用")
                                    .font(.title2.bold())
                                    .foregroundStyle(TreasureTheme.ink)

                                Text("宝探しを作ったときの\n4桁のPINを入力してください")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(TreasureTheme.secondaryText)
                            }
                            .treasureCompactCard()

                            VStack(spacing: 10) {
                                SecureField("4桁のPIN", text: $pin)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .font(.title2.monospacedDigit())
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                    .focused($pinIsFocused)
                                    .onChange(of: pin) { _, newValue in
                                        pin = ParentPIN.digitsOnly(newValue)
                                        errorMessage = nil
                                    }
                                    .onSubmit(unlock)

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote.weight(.semibold))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(TreasureTheme.coralText)
                                }

                                Button(action: recoverWithDeviceAuthentication) {
                                    if isAuthenticatingDeviceOwner {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Label(
                                            "PINを忘れた場合",
                                            systemImage: "faceid"
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isAuthenticatingDeviceOwner)
                                .accessibilityHint(
                                    "Face ID、Touch ID、または端末のパスコードで確認します"
                                )
                            }
                            .frame(maxWidth: 280)
                            .treasureCompactCard()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    Divider()

                    Button("ロックを解除", action: unlock)
                        .buttonStyle(TreasurePrimaryButtonStyle())
                        .disabled(pin.count != 4)
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        if pin.count == 4 {
                            unlock()
                        } else {
                            pinIsFocused = false
                        }
                    }
                }
            }
        }
    }

    private func unlock() {
        guard pin.count == 4 else { return }

        if ParentPIN.matches(pin, digest: expectedDigest) {
            pinIsFocused = false
            onUnlock()
        } else {
            pin = ""
            errorMessage = "PINが違います。もう一度ためしてください。"
            pinIsFocused = true
        }
    }

    private func recoverWithDeviceAuthentication() {
        guard !isAuthenticatingDeviceOwner else { return }
        pinIsFocused = false
        errorMessage = nil
        isAuthenticatingDeviceOwner = true

        Task {
            defer {
                isAuthenticatingDeviceOwner = false
            }

            do {
                try await ParentAccessAuthenticator.authenticate(
                    reason: "保護者PINを忘れた場合のロック解除のために認証します。"
                )
                onUnlock()
            } catch let error as LAError where error.code == .userCancel
                || error.code == .appCancel
                || error.code == .systemCancel {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ProtectedHuntEditorView: View {
    let hunt: TreasureHunt

    @Environment(\.dismiss) private var dismiss
    @State private var isUnlocked = false

    var body: some View {
        if isUnlocked {
            HuntEditorView(hunt: hunt)
        } else {
            ParentPINGateView(
                expectedDigest: hunt.parentPINDigest,
                onCancel: { dismiss() },
                onUnlock: { isUnlocked = true }
            )
        }
    }
}
