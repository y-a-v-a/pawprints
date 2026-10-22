import AVFoundation
import MysteryKit

/// Reads lines aloud, with a voice and pitch to suit each animal. Off by default.
@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()

    private struct Casting {
        let voices: [String]
        let pitch: Float
        let rate: Float
    }

    /// Preferred voice names (first installed one wins), pitch and speed per species.
    private static let casting: [String: Casting] = [
        "fox": .init(voices: ["Daniel", "Reed"], pitch: 1.0, rate: 0.5),
        "mouse": .init(voices: ["Flo", "Shelley"], pitch: 1.35, rate: 0.56),
        "badger": .init(voices: ["Grandpa", "Rocko"], pitch: 0.8, rate: 0.48),
        "heron": .init(voices: ["Shelley", "Sandy"], pitch: 0.95, rate: 0.46),
        "hedgehog": .init(voices: ["Rocko", "Reed"], pitch: 1.15, rate: 0.45),
        "otter": .init(voices: ["Grandma", "Flo"], pitch: 1.1, rate: 0.53),
        "rabbit": .init(voices: ["Reed", "Eddy"], pitch: 1.25, rate: 0.57),
        "owl": .init(voices: ["Moira", "Grandma"], pitch: 0.9, rate: 0.47),
        "crow": .init(voices: ["Eddy", "Daniel"], pitch: 0.8, rate: 0.47),
        "cat": .init(voices: ["Sandy", "Shelley"], pitch: 1.15, rate: 0.48),
        "squirrel": .init(voices: ["Karen", "Flo"], pitch: 1.3, rate: 0.6),
        "toad": .init(voices: ["Grandpa", "Eddy"], pitch: 0.65, rate: 0.44),
        "mole": .init(voices: ["Rocko", "Grandpa"], pitch: 0.85, rate: 0.52),
        "duck": .init(voices: ["Eddy", "Rocko"], pitch: 1.05, rate: 0.5),
    ]

    func say(_ text: String, as suspect: Suspect?) {
        let casting = suspect.flatMap { Self.casting[$0.species] } ?? .init(voices: ["Daniel"], pitch: 1, rate: 0.5)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(named: casting.voices)
        utterance.pitchMultiplier = casting.pitch
        utterance.rate = casting.rate
        utterance.preUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .word)
    }

    private static func voice(named names: [String]) -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        for name in names {
            // Prefer a British voice of that name, then any English one, best quality first.
            let matches = english.filter { $0.name == name }.sorted { $0.quality.rawValue > $1.quality.rawValue }
            if let gb = matches.first(where: { $0.language == "en-GB" }) ?? matches.first { return gb }
        }
        return AVSpeechSynthesisVoice(language: "en-GB")
    }
}
