//
//  AppAudioSettings.swift
//  BokuNoTakarasagashi
//

import Combine
import Foundation
import SwiftUI

nonisolated struct AppAudioPreferences: Equatable, Sendable {
    let backgroundMusicIsEnabled: Bool
    let effectsAndHapticsAreEnabled: Bool
}

nonisolated enum AppAudioSettingsStorage {
    private static let backgroundMusicEnabledKey =
        "audio.backgroundMusicEnabled"
    private static let effectsAndHapticsEnabledKey =
        "audio.effectsAndHapticsEnabled"

    static func load(from defaults: UserDefaults) -> AppAudioPreferences {
        AppAudioPreferences(
            backgroundMusicIsEnabled: storedValue(
                forKey: backgroundMusicEnabledKey,
                in: defaults
            ),
            effectsAndHapticsAreEnabled: storedValue(
                forKey: effectsAndHapticsEnabledKey,
                in: defaults
            )
        )
    }

    static func saveBackgroundMusicEnabled(
        _ isEnabled: Bool,
        to defaults: UserDefaults
    ) {
        defaults.set(isEnabled, forKey: backgroundMusicEnabledKey)
    }

    static func saveEffectsAndHapticsEnabled(
        _ isEnabled: Bool,
        to defaults: UserDefaults
    ) {
        defaults.set(isEnabled, forKey: effectsAndHapticsEnabledKey)
    }

    private static func storedValue(
        forKey key: String,
        in defaults: UserDefaults
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return true
        }
        return defaults.bool(forKey: key)
    }
}

@MainActor
final class AppAudioSettings: ObservableObject {
    @Published var backgroundMusicIsEnabled: Bool {
        didSet {
            AppAudioSettingsStorage.saveBackgroundMusicEnabled(
                backgroundMusicIsEnabled,
                to: defaults
            )
        }
    }

    @Published var effectsAndHapticsAreEnabled: Bool {
        didSet {
            AppAudioSettingsStorage.saveEffectsAndHapticsEnabled(
                effectsAndHapticsAreEnabled,
                to: defaults
            )
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let preferences = AppAudioSettingsStorage.load(from: defaults)
        backgroundMusicIsEnabled = preferences.backgroundMusicIsEnabled
        effectsAndHapticsAreEnabled =
            preferences.effectsAndHapticsAreEnabled
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var audioSettings: AppAudioSettings

    private var appVersionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        case let (.none, .some(build)):
            return build
        case (.none, .none):
            return "—"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        isOn: $audioSettings.backgroundMusicIsEnabled
                    ) {
                        settingLabel(
                            title: "BGM",
                            description: "オープニングや冒険の音楽",
                            systemImage: "music.note"
                        )
                    }

                    Toggle(
                        isOn: $audioSettings.effectsAndHapticsAreEnabled
                    ) {
                        settingLabel(
                            title: "効果音と振動",
                            description: "発見・クリア・読み取り結果のお知らせ",
                            systemImage: "speaker.wave.2.fill"
                        )
                    }
                } header: {
                    Text("再生する音")
                } footer: {
                    Text("音量と消音モードには端末の設定が使われます。")
                }

                Section("ヒントの読み上げ") {
                    Label {
                        Text(
                            "「ヒントをきく」を押したときだけ再生され、"
                                + "上の設定ではオフになりません。"
                        )
                    } icon: {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(TreasureTheme.tealText)
                    }
                    .font(.subheadline)
                    .foregroundStyle(TreasureTheme.secondaryText)
                }

                Section("アプリ情報") {
                    LabeledContent(
                        "バージョン",
                        value: appVersionDescription
                    )
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .tint(TreasureTheme.teal)
    }

    private func settingLabel(
        title: String,
        description: String,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(TreasureTheme.secondaryText)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(TreasureTheme.tealText)
        }
    }
}
