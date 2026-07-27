//
//  GameAudio.swift
//  BokuNoTakarasagashi
//

import AVFoundation
import Combine
import SwiftUI

nonisolated enum HintSpeechRequestAction: Equatable, Sendable {
    case stop
    case speak

    static func resolve(
        isSpeaking: Bool,
        spokenText: String,
        requestedText: String
    ) -> HintSpeechRequestAction {
        isSpeaking && spokenText == requestedText
            ? .stop
            : .speak
    }
}

nonisolated enum HintSpeechTextFormatter {
    private static let terminalPunctuation = "。！？!?．.…"
    private static let closingPunctuation = "」』）)]】"

    static func naturalized(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        var result = ""
        for line in lines {
            if !result.isEmpty {
                result += endsInTerminalPunctuation(result)
                    ? " "
                    : "。 "
            }
            result += line
        }

        guard !result.isEmpty,
              !endsInTerminalPunctuation(result) else {
            return result
        }
        return result + "。"
    }

    private static func endsInTerminalPunctuation(
        _ text: String
    ) -> Bool {
        var remainingText = text[...]
        while let lastCharacter = remainingText.last,
              closingPunctuation.contains(lastCharacter) {
            remainingText.removeLast()
        }
        guard let lastCharacter = remainingText.last else {
            return false
        }
        return terminalPunctuation.contains(lastCharacter)
    }
}

private enum HintSpeechVoiceSelector {
    static func preferredJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let defaultVoice = AVSpeechSynthesisVoice(language: "ja-JP")
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == "ja-JP"
                && !$0.voiceTraits.contains(.isNoveltyVoice)
                && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        if let defaultVoice,
           defaultVoice.quality == .premium {
            return defaultVoice
        }
        return voices.first {
            $0.quality == .premium
        } ?? defaultVoice
    }
}

@MainActor
final class HintSpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var spokenText = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(text: String) {
        switch HintSpeechRequestAction.resolve(
            isSpeaking: isSpeaking,
            spokenText: spokenText,
            requestedText: text
        ) {
        case .stop:
            stop()
        case .speak:
            speak(text)
        }
    }

    private func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(
            string: HintSpeechTextFormatter.naturalized(text)
        )
        utterance.voice =
            HintSpeechVoiceSelector.preferredJapaneseVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1
        utterance.prefersAssistiveTechnologySettings = true
        currentUtteranceID = ObjectIdentifier(utterance)
        spokenText = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        clearSpeechState()
    }

    private func clearSpeechState() {
        currentUtteranceID = nil
        isSpeaking = false
        spokenText = ""
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.currentUtteranceID == utteranceID else { return }
            self?.clearSpeechState()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.currentUtteranceID == utteranceID else { return }
            self?.clearSpeechState()
        }
    }
}

struct HintSpeechButton: View {
    @ObservedObject var controller: HintSpeechController
    let text: String

    var body: some View {
        Button {
            controller.toggle(text: text)
        } label: {
            Label(
                controller.isSpeaking && controller.spokenText == text
                    ? "読み上げをとめる"
                    : "ヒントをきく",
                systemImage: controller.isSpeaking && controller.spokenText == text
                    ? "stop.fill"
                    : "speaker.wave.2.fill"
            )
        }
        .buttonStyle(.bordered)
        .tint(TreasureTheme.teal)
        .accessibilityHint(
            controller.isSpeaking && controller.spokenText == text
                ? "ヒントの読み上げを停止します"
                : "ヒントを声で読み上げます"
        )
    }
}

@MainActor
final class GameSoundPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func playDiscovery() {
        play(
            notes: [
                .init(frequency: 659.25, duration: 0.12),
                .init(frequency: 783.99, duration: 0.12),
                .init(frequency: 987.77, duration: 0.24),
            ]
        )
    }

    func playCompletion() {
        play(
            notes: [
                .init(frequency: 523.25, duration: 0.14),
                .init(frequency: 659.25, duration: 0.14),
                .init(frequency: 783.99, duration: 0.14),
                .init(frequency: 1046.50, duration: 0.42),
            ]
        )
    }

    private func play(notes: [GeneratedSound.Note]) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)

            player = try AVAudioPlayer(data: GeneratedSound.waveData(notes: notes))
            player?.volume = 0.45
            player?.prepareToPlay()
            player?.play()
        } catch {
            // Sound is supplementary; gameplay continues if audio is unavailable.
        }
    }
}

private enum GeneratedSound {
    struct Note {
        let frequency: Double
        let duration: Double
    }

    private static let sampleRate = 44_100

    static func waveData(notes: [Note]) -> Data {
        var samples: [Int16] = []

        for note in notes {
            let sampleCount = Int(note.duration * Double(sampleRate))
            let fadeCount = max(Int(Double(sampleRate) * 0.018), 1)

            for index in 0..<sampleCount {
                let attack = min(Double(index) / Double(fadeCount), 1)
                let release = min(Double(sampleCount - index) / Double(fadeCount), 1)
                let envelope = min(attack, release)
                let angle = 2 * Double.pi * note.frequency * Double(index) / Double(sampleRate)
                let value = sin(angle) * envelope * 0.32
                samples.append(Int16(value * Double(Int16.max)))
            }

            samples.append(
                contentsOf: repeatElement(
                    Int16(0),
                    count: Int(Double(sampleRate) * 0.025)
                )
            )
        }

        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)

        for sample in samples {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
