//
//  AppPrivacyShield.swift
//  BokuNoTakarasagashi
//

import Combine
import SwiftUI
import UIKit

enum AppPrivacyShieldMode: Equatable {
    case background
}

@MainActor
final class AppPrivacyShieldWindowController: ObservableObject {
    private var hostingController: UIHostingController<AnyView>?

    func update(
        mode: AppPrivacyShieldMode?
    ) {
        guard mode != nil else {
            hide()
            return
        }
        guard let window = applicationWindow else { return }

        let rootView = AnyView(
            AppPrivacyShieldContent()
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
    var body: some View {
        TreasureBackgroundArtwork(style: .security)
            .overlay {
                VStack(spacing: 18) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 44))
                        .accessibilityHidden(true)

                    Text("ぼくの宝探し")
                        .font(.title2.bold())
                }
                .frame(maxWidth: 368)
                .treasureCard()
                .padding(24)
                .foregroundStyle(TreasureTheme.ink)
            }
            .ignoresSafeArea()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("アプリの内容を非表示にしています")
    }
}
