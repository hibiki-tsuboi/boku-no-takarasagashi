//
//  TreasureTheme.swift
//  BokuNoTakarasagashi
//

import Foundation
import SwiftUI

nonisolated struct TreasureColorComponents: Sendable {
    let red: Double
    let green: Double
    let blue: Double

    nonisolated var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    nonisolated func contrastRatio(
        with background: TreasureColorComponents
    ) -> Double {
        let brighter = max(relativeLuminance, background.relativeLuminance)
        let darker = min(relativeLuminance, background.relativeLuminance)
        return (brighter + 0.05) / (darker + 0.05)
    }

    nonisolated func composited(
        over background: TreasureColorComponents,
        opacity: Double
    ) -> TreasureColorComponents {
        let opacity = min(max(opacity, 0), 1)
        return TreasureColorComponents(
            red: red * opacity + background.red * (1 - opacity),
            green: green * opacity + background.green * (1 - opacity),
            blue: blue * opacity + background.blue * (1 - opacity)
        )
    }

    nonisolated private var relativeLuminance: Double {
        0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    nonisolated private func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

enum TreasureTheme {
    static let blackComponents = TreasureColorComponents(
        red: 0,
        green: 0,
        blue: 0
    )
    static let whiteComponents = TreasureColorComponents(
        red: 1,
        green: 1,
        blue: 1
    )
    static let creamComponents = TreasureColorComponents(
        red: 1.00,
        green: 0.97,
        blue: 0.88
    )
    static let goldTextComponents = TreasureColorComponents(
        red: 0.43,
        green: 0.28,
        blue: 0.03
    )
    static let coralTextComponents = TreasureColorComponents(
        red: 0.68,
        green: 0.18,
        blue: 0.12
    )
    static let inkComponents = TreasureColorComponents(
        red: 0.13,
        green: 0.20,
        blue: 0.25
    )
    static let tealComponents = TreasureColorComponents(
        red: 0.10,
        green: 0.48,
        blue: 0.49
    )
    static let tealTextComponents = TreasureColorComponents(
        red: 0.07,
        green: 0.41,
        blue: 0.42
    )
    static let secondaryTextComponents = TreasureColorComponents(
        red: 0.32,
        green: 0.36,
        blue: 0.39
    )
    static let goldComponents = TreasureColorComponents(
        red: 0.95,
        green: 0.64,
        blue: 0.15
    )
    static let coralComponents = TreasureColorComponents(
        red: 0.91,
        green: 0.35,
        blue: 0.27
    )

    static let cardSurfaceOpacity = 0.96
    static let titleSecondaryScrimOpacity = 0.58

    static let ink = inkComponents.color
    static let teal = tealComponents.color
    static let tealText = tealTextComponents.color
    static let secondaryText = secondaryTextComponents.color
    static let gold = goldComponents.color
    static let coral = coralComponents.color
    static let goldText = goldTextComponents.color
    static let coralText = coralTextComponents.color
    static let dangerBackground = coralText
    static let cream = creamComponents.color
    static let cardSurface = Color.white.opacity(cardSurfaceOpacity)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.93, green: 0.98, blue: 0.95),
            Color(red: 1.00, green: 0.96, blue: 0.84),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum TreasureBackgroundStyle: String {
    case home = "BackgroundParent"
    case editor = "BackgroundEditor"
    case preparation = "BackgroundPreparation"
    case safety = "BackgroundSafety"
    case playing = "BackgroundPlaying"
    case completion = "BackgroundCompletion"
    case history = "BackgroundHistory"
    case memory = "BackgroundMemory"
    case security = "BackgroundSecurity"
}

struct TreasureBackgroundArtwork: View {
    let style: TreasureBackgroundStyle

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TreasureTheme.background

                Image(style.rawValue)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .clipped()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct TreasureBackground<Content: View>: View {
    private let style: TreasureBackgroundStyle
    private let content: Content

    init(
        style: TreasureBackgroundStyle = .home,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        ZStack {
            TreasureBackgroundArtwork(style: style)

            content
        }
    }
}

struct TreasureCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                TreasureTheme.cardSurface,
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: TreasureTheme.ink.opacity(0.08), radius: 18, y: 8)
    }
}

struct TreasureCompactCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                TreasureTheme.cardSurface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
    }
}

extension View {
    func treasureCard() -> some View {
        modifier(TreasureCardModifier())
    }

    func treasureCompactCard() -> some View {
        modifier(TreasureCompactCardModifier())
    }

    func treasureBackground(_ style: TreasureBackgroundStyle) -> some View {
        background {
            TreasureBackgroundArtwork(style: style)
        }
    }
}

struct TreasurePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(
                isEnabled ? Color.white : TreasureTheme.secondaryText
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isEnabled ? TreasureTheme.teal : TreasureTheme.cardSurface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isEnabled
                            ? Color.clear
                            : TreasureTheme.secondaryText.opacity(0.28),
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
