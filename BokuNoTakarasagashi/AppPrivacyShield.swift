//
//  AppPrivacyShield.swift
//  BokuNoTakarasagashi
//

import Combine
import SwiftUI
import UIKit

enum AppPrivacyShieldMode: Equatable {
    case background
    case parentLocked(isAuthenticating: Bool, errorMessage: String?)
}

@MainActor
final class AppPrivacyShieldWindowController: ObservableObject {
    private var hostingController: UIHostingController<AnyView>?

    func update(
        mode: AppPrivacyShieldMode?,
        onUnlock: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        guard let mode else {
            hide()
            return
        }
        guard let window = applicationWindow else { return }

        let rootView = AnyView(
            AppPrivacyShieldContent(
                mode: mode,
                onUnlock: onUnlock,
                onExit: onExit
            )
        )

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let controller = UIHostingController(rootView: rootView)
            controller.view.backgroundColor = .clear
            controller.view.frame = window.bounds
            controller.view.autoresizingMask = [
                .flexibleWidth,
                .flexibleHeight,
            ]
            window.addSubview(controller.view)
            hostingController = controller
        }

        if hostingController?.view.superview !== window {
            hostingController?.view.removeFromSuperview()
            if let view = hostingController?.view {
                view.frame = window.bounds
                window.addSubview(view)
            }
        }
        if let view = hostingController?.view {
            window.bringSubviewToFront(view)
        }
    }

    func hide() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }

    private var applicationWindow: UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return windowScenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
            ?? windowScenes
                .flatMap(\.windows)
                .first(where: { !$0.isHidden && $0.windowLevel == .normal })
    }
}

private struct AppPrivacyShieldContent: View {
    let mode: AppPrivacyShieldMode
    let onUnlock: () -> Void
    let onExit: () -> Void

    var body: some View {
        TreasureBackgroundArtwork(style: .security)
            .overlay {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .accessibilityHidden(true)

                    Text("おうちの人専用")
                        .font(.title2.bold())

                    if case let .parentLocked(isAuthenticating, errorMessage) = mode {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TreasureTheme.coralText)
                                .frame(maxWidth: 320)
                        }

                        Button(action: onUnlock) {
                            if isAuthenticating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label(
                                    "認証して編集に戻る",
                                    systemImage: "faceid"
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(TreasurePrimaryButtonStyle())
                        .disabled(isAuthenticating)
                        .frame(maxWidth: 320)

                        Button("タイトルへ戻る", action: onExit)
                            .buttonStyle(.bordered)
                            .disabled(isAuthenticating)
                    }
                }
                .padding(24)
                .foregroundStyle(TreasureTheme.ink)
            }
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
    }
}
