//
//  ParentPINGateView.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct ParentPINGateView: View {
    let expectedDigest: String
    let onCancel: () -> Void
    let onUnlock: () -> Void

    @State private var pin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            TreasureBackground {
                VStack(spacing: 22) {
                    Spacer()

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TreasureTheme.teal)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("おうちの人専用")
                            .font(.title2.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("宝探しを作ったときの\n4桁のPINを入力してください")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        SecureField("4桁のPIN", text: $pin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.title2.monospacedDigit())
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .onChange(of: pin) { _, newValue in
                                pin = ParentPIN.digitsOnly(newValue)
                                errorMessage = nil
                            }
                            .onSubmit(unlock)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(TreasureTheme.coral)
                        }
                    }
                    .frame(maxWidth: 280)

                    Button("ロックを解除", action: unlock)
                        .buttonStyle(TreasurePrimaryButtonStyle())
                        .disabled(pin.count != 4)
                        .frame(maxWidth: 320)

                    Spacer()
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
            }
        }
    }

    private func unlock() {
        guard pin.count == 4 else { return }

        if ParentPIN.matches(pin, digest: expectedDigest) {
            onUnlock()
        } else {
            pin = ""
            errorMessage = "PINが違います。もう一度ためしてください。"
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
