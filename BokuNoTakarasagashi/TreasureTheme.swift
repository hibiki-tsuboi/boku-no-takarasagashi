//
//  TreasureTheme.swift
//  BokuNoTakarasagashi
//

import SwiftUI

enum TreasureTheme {
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.25)
    static let teal = Color(red: 0.10, green: 0.48, blue: 0.49)
    static let gold = Color(red: 0.95, green: 0.64, blue: 0.15)
    static let coral = Color(red: 0.91, green: 0.35, blue: 0.27)
    static let cream = Color(red: 1.00, green: 0.97, blue: 0.88)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.93, green: 0.98, blue: 0.95),
            Color(red: 1.00, green: 0.96, blue: 0.84),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TreasureBackground<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            TreasureTheme.background
                .ignoresSafeArea()

            Circle()
                .fill(TreasureTheme.gold.opacity(0.14))
                .frame(width: 260, height: 260)
                .offset(x: 150, y: -310)

            Circle()
                .fill(TreasureTheme.teal.opacity(0.10))
                .frame(width: 320, height: 320)
                .offset(x: -180, y: 360)

            content
        }
    }
}

struct TreasureCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: TreasureTheme.ink.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func treasureCard() -> some View {
        modifier(TreasureCardModifier())
    }
}

struct TreasurePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isEnabled ? TreasureTheme.teal : Color.secondary.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
