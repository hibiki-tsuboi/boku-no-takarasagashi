//
//  TitleScreenView.swift
//  BokuNoTakarasagashi
//

import SwiftUI

struct TitleScreenView: View {
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var artworkScale: CGFloat = 1.035
    @State private var controlsAreVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("TitleScreen")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .clipped()
                    .scaleEffect(artworkScale)
                    .accessibilityLabel(
                        "ぼくの宝探し。宝箱と地図が描かれたタイトル画面"
                    )

                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.08),
                        .black.opacity(0.78),
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)

                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: onStart) {
                            Label(
                                "PRESS START",
                                systemImage: "map.fill"
                            )
                        }
                        .buttonStyle(TitlePrimaryButtonStyle())
                        .accessibilityLabel("ぼうけんをはじめる")
                    }
                    .padding(.horizontal, 24)
                    .padding(
                        .bottom,
                        max(proxy.safeAreaInsets.bottom, 16) + 32
                    )
                    .opacity(controlsAreVisible ? 1 : 0)
                    .offset(y: controlsAreVisible ? 0 : 24)
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear(perform: showControls)
    }

    private func showControls() {
        guard !controlsAreVisible else { return }

        if reduceMotion {
            artworkScale = 1
            controlsAreVisible = true
            return
        }

        withAnimation(.easeOut(duration: 1.2)) {
            artworkScale = 1
        }

        withAnimation(
            .spring(response: 0.6, dampingFraction: 0.86)
                .delay(0.18)
        ) {
            controlsAreVisible = true
        }
    }
}

private struct TitlePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.heavy))
            .foregroundStyle(TreasureTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.82, blue: 0.25),
                        TreasureTheme.gold,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.65), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(0.32),
                radius: 12,
                y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

#Preview {
    TitleScreenView(onStart: {})
}
