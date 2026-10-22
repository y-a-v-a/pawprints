import Foundation
import FoundationModels

func debug(_ message: @autoclosure () -> String) {
    if ProcessInfo.processInfo.environment["PAWPRINTS_DEBUG"] != nil {
        FileHandle.standardError.write(Data(("  · " + message() + "\n").utf8))
    }
}

/// One spoken reply, ready for the stage.
public struct Performance: Sendable, Equatable {
    public var action: String
    public var line: String
    /// True when the model couldn't answer and a canned line stood in.
    public var isFallback: Bool
}

@Generable
struct SpokenLine {
    @Guide(description: "Exactly what the character says out loud, in character, in one or two short sentences")
    var line: String
}

@Generable
struct QuestionTopic {
    @Guide(description: "What the detective is asking about", .anyOf([
        "whereabouts", "saw_anything", "about_another_person", "about_a_place", "about_the_owner",
        "about_the_stolen_item", "about_yourself", "accusation", "small_talk", "violence",
    ]))
    var topic: String
}

@Generable
struct Narration {
    @Guide(description: "Two or three vivid, cosy sentences of narration in the past tense")
    var text: String
}

/// Everything that talks to the on-device model. The engine decides *what* is said;
/// this only decides *how* it sounds.
public actor Voice {
    /// Stage directions by mood, so a rattled suspect never "smiles warmly".
    static let gestures: [Mood: [String]] = [
        .calm: ["folds both arms", "nods slowly", "tilts the head", "sits very still", "smiles thinly"],
        .friendly: ["smiles warmly", "beams", "chuckles", "leans in", "brightens"],
        .guarded: ["lowers the voice", "glances at the door", "narrows both eyes", "leans in close", "chooses each word with care"],
        .flustered: ["fidgets", "laughs nervously", "blinks rapidly", "looks away", "speaks a little too quickly"],
        .indignant: ["bristles", "draws up tall", "sniffs", "huffs", "glares"],
        .relieved: ["draws a long breath", "sighs", "sags with relief", "dabs at both eyes"],
        .rattled: ["stammers", "goes quite pale", "clears the throat", "can't meet your eye"],
    ]

    /// A nervous habit to suit the species.
    static func tic(for species: String) -> String {
        switch species {
        case "heron", "owl", "crow", "duck": "ruffles a few feathers"
        case "hedgehog": "curls up just a little"
        case "badger": "harrumphs into the moustache"
        case "toad": "puffs out both cheeks"
        case "mole": "polishes both spectacles"
        default: "twitches both whiskers"
        }
    }

    private var gestureCount: [Int: Int] = [:]

    func gesture(for s: Suspect, mood: Mood) -> String {
        let n = gestureCount[s.id, default: Int(mystery.seed % 7) + s.id]
        gestureCount[s.id] = n + 1
        var options = Self.gestures[mood] ?? ["nods"]
        if [.flustered, .rattled, .indignant].contains(mood) { options.append(Self.tic(for: s.species)) }
        return options[n % options.count]
    }

    private let mystery: Case
    private var history: [Int: [String]] = [:]

    public init(mystery: Case) {
        self.mystery = mystery
    }

    // MARK: Suspects

    private func persona(_ s: Suspect) -> String {
        let m = mystery
        return """
        You are an actor playing \(s.name), a \(s.isFemale ? "female" : "male") \(s.species), in a cosy, gentle detective story for all ages. \
        Every character in this world is an animal; there are no humans.
        Who you are: \(s.occupation). You \(s.relationship). You are \(s.personality).
        How you speak: \(s.voice). You often begin with things like "\(s.catchphrases.joined(separator: "\", \""))".
        The situation: \(m.item) has vanished during \(m.occasion) at \(m.place), and Inspector Apfel is questioning everyone.
        Each turn you get the Inspector's words and a director's note. Say what the note asks, in your own voice. \
        Never mention the director or the note. Only mention places and people that appear in the note. \
        Never mention clock times, days or dates. \
        Keep it to one or two short sentences.
        """
    }

    public func prewarm(_ suspectID: Int) {
        LanguageModelSession(instructions: persona(mystery.suspect(suspectID))).prewarm()
    }

    public func perform(_ suspectID: Int, said question: String, directive: Directive) async -> Performance {
        let s = mystery.suspect(suspectID)
        if let canned = directive.cannedLine {
            return Performance(action: gesture(for: s, mood: .indignant), line: canned, isFallback: true)
        }
        let prompt: String
        if let script = directive.script {
            prompt = """
            Your line: "\(script)"
            Director's note (mood: \(directive.mood.rawValue)): \(directive.note) \
            Say your line in your own voice and style. Keep every name, place and fact in it. Add nothing new.
            """
        } else {
            prompt = """
            The Inspector says: "\(question)"
            Director's note (mood: \(directive.mood.rawValue)): \(directive.note)
            """
        }
        let previous = history[suspectID, default: []]
        let source = [question, directive.note, directive.script ?? ""].joined(separator: " ")
        // A long script (a confession, say) keeps all its sentences; otherwise three is plenty.
        let limit = max(3, Self.sentenceCount(directive.script ?? "") + 1)
        for attempt in 0..<3 {
            do {
                let options = GenerationOptions(sampling: .random(probabilityThreshold: 0.9, seed: UInt64(attempt * 7919 + previous.count)),
                                                temperature: 0.8 + 0.1 * Double(attempt))
                let raw = try await stream(prompt, instructions: persona(s), options: options, maxSentences: limit)
                var line = Self.tidy(raw, maxSentences: limit, speaker: s)
                debug("attempt \(attempt): \(line)")
                if attempt == 2 { line = keepGrounded(line, source: source, speaker: s) }
                guard !line.isEmpty else { continue }
                let keepsFacts = directive.mustMention.allSatisfy { $0.isMentioned(in: line) }
                    && directive.mustContain.allSatisfy { line.lowercased().contains($0) }
                if attempt < 2 {
                    if !directive.isRepeat, previous.contains(where: { Self.similarity($0, line) > 0.6 }) { continue }
                    if !keepsFacts { continue }
                    if keepGrounded(line, source: source, speaker: s) != line { continue }
                } else if !keepsFacts {
                    break
                }
                history[suspectID, default: []].append(line)
                return Performance(action: gesture(for: s, mood: directive.mood), line: flavoured(line, by: s), isFallback: false)
            } catch let error as LanguageModelSession.GenerationError {
                debug("attempt \(attempt) failed: \(error)")
                if case .guardrailViolation = error, attempt > 0 { break }
                if case .refusal = error, attempt > 0 { break }
                continue
            } catch {
                debug("attempt \(attempt) failed: \(error)")
                continue
            }
        }
        // The facts matter more than the flourish: fall back to the engine's own words.
        if let script = directive.script {
            return Performance(action: gesture(for: s, mood: directive.mood), line: flavoured(script, by: s), isFallback: true)
        }
        return Performance(action: "looks away", line: s.deflections.randomElement() ?? "I'd rather not say.", isFallback: true)
    }

    private var lineCount: [Int: Int] = [:]

    /// Every third line or so gets one of the character's own openers ("Harrumph!"), unless
    /// the line already starts with a flourish of its own.
    private func flavoured(_ line: String, by s: Suspect) -> String {
        let n = lineCount[s.id, default: s.id]
        lineCount[s.id] = n + 1
        guard n % 3 == 0, !s.catchphrases.isEmpty, let first = line.split(separator: " ").first else { return line }
        let word = first.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let flourishes = Set(["oh", "ah", "well", "aye", "ahem", "harrumph", "darling", "ooh", "now", "hmm", "hmph",
                              "ahoy", "really", "my", "begging", "strictly", "blow", "look"]
            + s.catchphrases.compactMap { $0.split(separator: " ").first?.lowercased().trimmingCharacters(in: .punctuationCharacters) })
        guard !flourishes.contains(word) else { return line }
        let opener = s.catchphrases[(n / 3) % s.catchphrases.count]
        // After "Ooh, dearie," an ordinary opening word flows on in lower case; names keep their capital.
        let ordinary: Set<String> = ["the", "it", "that", "there", "this", "what", "we", "you", "a", "an", "not", "no",
                                     "yes", "as", "between", "funny", "such", "so", "nothing", "half", "heading", "how", "and"]
        let rest = opener.hasSuffix(",") && ordinary.contains(word) ? line.prefix(1).lowercased() + line.dropFirst() : line
        return opener + " " + rest
    }

    /// Streams a reply and stops as soon as it is long enough. The model sometimes
    /// never closes its string; cutting early turns that into a normal reply.
    private func stream(_ prompt: String, instructions: String, options: GenerationOptions, maxSentences: Int) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let deadline = Date().addingTimeInterval(12)
        var line = ""
        for try await snapshot in session.streamResponse(to: prompt, generating: SpokenLine.self, options: options) {
            line = snapshot.content.line ?? line
            if Self.sentenceCount(line) >= maxSentences || line.split(separator: " ").count > 20 * maxSentences || Date() > deadline {
                line = Self.completeSentences(line)
                break
            }
        }
        return line
    }

    /// Drops sentences that name a suspect or a room the director never mentioned:
    /// that's where the small model invents testimony.
    func keepGrounded(_ line: String, source: String, speaker: Suspect) -> String {
        let outsiders = mystery.suspects.filter { $0.id != speaker.id && !$0.isMentioned(in: source) }
        let lowerSource = source.lowercased()
        let foreignRooms = mystery.rooms
            .map { $0.name.replacingOccurrences(of: "the ", with: "").lowercased() }
            .filter { !lowerSource.contains($0) }
        // The owner and the stolen item only come up when the director brings them up: an innocent
        // "leaving the kitchen with the tiara" is exactly the kind of invention that misleads.
        let titles: Set<String> = ["lord", "mrs", "the", "reverend", "curator", "duchess", "of"]
        let ownerWords = mystery.ownerName.lowercased().split { !$0.isLetter }.map(String.init)
            .filter { !titles.contains($0) && $0.count > 3 }
        let itemWord = mystery.item.lowercased().split { !$0.isLetter }.last.map(String.init) ?? ""
        let foreignWords = (ownerWords + [itemWord]).filter { !lowerSource.contains($0) }
        let kept = Self.sentences(line).filter { sentence in
            let lower = sentence.lowercased()
            return !outsiders.contains { $0.isMentioned(in: sentence) } && !foreignRooms.contains { lower.contains($0) }
                && !foreignWords.contains { lower.contains($0) }
        }
        return kept.joined().trimmingCharacters(in: .whitespaces)
    }

    // MARK: Understanding the player

    /// Maps free text to a topic. Cheap keyword rules first, then the model.
    public func understand(_ text: String, asking suspectID: Int) async -> Topic {
        let mentioned = mentionedSuspect(in: text, excluding: suspectID)
        let room = mentionedRoom(in: text)
        if let quick = quickTopic(text, mentioned: mentioned, room: room, asking: suspectID) { return quick }
        let fallback: Topic = mentioned.map(Topic.aboutSuspect) ?? room.map(Topic.aboutRoom) ?? .smallTalk
        do {
            let session = LanguageModelSession(instructions: """
            Classify what a detective is asking a suspect in a cosy mystery about a theft. \
            Pick exactly one topic.
            """)
            let result = try await session.respond(to: "Detective: \"\(text)\"", generating: QuestionTopic.self,
                                                   options: GenerationOptions(sampling: .greedy)).content
            debug("classified as \(result.topic): \(text)")
            switch result.topic {
            case "whereabouts": return room.map(Topic.aboutRoom) ?? .whereabouts
            case "saw_anything": return .sawAnything
            case "about_another_person": return fallback
            case "about_a_place": return room.map(Topic.aboutRoom) ?? .whereabouts
            case "about_the_owner": return .aboutOwner
            case "about_the_stolen_item": return .aboutItem
            case "about_yourself": return .aboutSelf
            case "accusation": return .accuse
            case "violence": return .offLimits
            default: return fallback
            }
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error { return .offLimits }
            return fallback
        } catch {
            return fallback
        }
    }

    func mentionedSuspect(in text: String, excluding id: Int) -> Int? {
        mystery.suspects.first { $0.id != id && $0.isMentioned(in: text) }?.id
    }

    /// A room named in free text: its full name ("map room"), or its last word when that word
    /// is distinctive on its own ("marquee", "study"), but never a bare "room" or "tent".
    func mentionedRoom(in text: String) -> RoomRole? {
        let t = Self.normalized(text)
        let generic: Set<String> = ["room", "tent", "hall", "deck", "cupboard"]
        return mystery.rooms.first { room in
            let name = Self.normalized(room.name.replacingOccurrences(of: "the ", with: "")).trimmingCharacters(in: .whitespaces)
            if t.contains(" \(name) ") { return true }
            guard let last = name.split(separator: " ").last.map(String.init), !generic.contains(last) else { return false }
            return t.contains(" \(last) ")
        }?.id
    }

    /// Lower-cased, punctuation-free, padded with spaces, common texting shorthand expanded,
    /// so phrases can be matched as whole words: " where were you ".
    static func normalized(_ text: String) -> String {
        let shorthand = ["u": "you", "ur": "your", "r": "are", "ya": "you", "wot": "what", "wat": "what", "yu": "you"]
        let words = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "'", with: " ")
            .split { !$0.isLetter && !$0.isNumber }
            .map { shorthand[String($0)] ?? String($0) }
        return " " + words.joined(separator: " ") + " "
    }

    /// Cheap, predictable rules for the common questions; anything unclear goes to the model.
    func quickTopic(_ text: String, mentioned: Int?, room: RoomRole?, asking: Int = -1) -> Topic? {
        let t = Self.normalized(text)
        let has = { (phrases: [String]) in phrases.contains { t.contains(" \($0) ") } }
        let thing = Self.normalized(mystery.item).split(separator: " ").last.map(String.init) ?? "it"

        if has(["kill", "killed", "murder", "murdered", "stab", "stabbed", "strangle", "beat you", "hit you",
                "punch you", "shoot you", "knife", "gun", "blood", "wring", "neck", "shut up", "fool", "idiot",
                "stupid", "moron", "or else", "i ll make you", "make you talk"]) { return .offLimits }
        if has(["you stole", "you took it", "you took the \(thing)", "you nicked", "you did it", "it was you",
                "you re the thief", "you are the thief", "you thief", "you re guilty", "you are guilty",
                "just confess", "confess now", "confess it", "admit it", "admit you", "you owe", "your debts",
                "why did you take", "why did you want", "why did you steal", "you re a liar", "you are a liar",
                "your a liar", "you liar", "you re lying", "you are lying", "a liar and a thief"]) { return .accuse }
        if let me = mystery.suspects.first(where: { $0.id == asking }), me.isMentioned(in: text),
           has(["lying", "liar", "thief", "did it", "took it", "guilty", "stole"]) { return .accuse }
        if has(["where is it", "where s it", "where is the \(thing)", "where s the \(thing)", "where did you put",
                "where did you hide", "where could it be", "where has it gone"]) { return .aboutItem }
        if let mentioned, has(["did you see", "have you seen", "saw", "seen", "notice"]) { return .aboutSuspect(mentioned) }
        if has(["see anything", "saw anything", "see anyone", "see anybody", "saw anyone", "seen anyone",
                "notice", "noticed", "anything unusual", "anything odd", "anything strange", "anything suspicious",
                "did you see", "who do you think", "who did it", "who took it", "suspect anyone"]) { return .sawAnything }
        if let mentioned { return .aboutSuspect(mentioned) }
        if has(["where were you", "where was you", "where have you been", "whereabouts", "alibi", "where did you go",
                "where did you spend", "where you were", "what were you doing", "what were you up to", "what was you doing",
                "what did you do", "how did you spend"]) { return room.map(Topic.aboutRoom) ?? .whereabouts }
        if let room { return .aboutRoom(room) }
        if has(["who are you", "about yourself", "what do you do", "introduce yourself", "tell me about you"]) { return .aboutSelf }
        if let me = mystery.suspects.first(where: { $0.id == asking }), me.isMentioned(in: text),
           has(["tell me about", "what about", "who is", "what do you make of", "what do you think of"]) { return .aboutSelf }
        let ownerWords = Self.normalized(mystery.ownerName).split(separator: " ").map(String.init)
            .filter { $0.count > 3 && !["lord", "mrs", "reverend", "curator", "duchess"].contains($0) }
        if has(ownerWords) { return .aboutOwner }
        if has([thing]) { return .aboutItem }
        return nil
    }

    // MARK: Narration

    public func narrate(_ facts: String, fallback: String) async -> String {
        do {
            let session = LanguageModelSession(instructions: """
            You are the narrator of a cosy animal detective story in the style of a gentle Golden Age mystery. \
            Write warm, vivid narration. Use only the facts given. Never invent names.
            """)
            let result = try await session.respond(to: facts, generating: Narration.self).content
            let text = Self.tidy(result.text, maxSentences: 4)
            return text.isEmpty ? fallback : text
        } catch {
            return fallback
        }
    }

    // MARK: Text hygiene

    static func tidy(_ text: String, maxSentences: Int, speaker: Suspect? = nil) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip a leading "Agnes:" the model sometimes adds, but only a real name, never "As I said:".
        if let speaker, let colon = t.firstIndex(of: ":"), t.distance(from: t.startIndex, to: colon) < 40,
           speaker.isMentioned(in: String(t[..<colon])) {
            t = String(t[t.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D} "))
        return sentences(t).prefix(maxSentences).joined().trimmingCharacters(in: .whitespaces)
    }

    /// Splits text into sentences, keeping punctuation and trailing spaces, and not
    /// splitting on "Dr." or "p.m.". A trailing fragment without an ending is kept.
    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        let abbreviations: Set<String> = ["dr.", "mr.", "mrs.", "st.", "p.", "a.", "m.", "e.g.", "i.e."]
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            guard ".!?".contains(ch) else { continue }
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            let atEnd = next.isWhitespace || next == "\"" || next == "\u{201D}"
            let lastWord = current.split(separator: " ").last.map { $0.lowercased() } ?? ""
            if atEnd, ch != "." || !abbreviations.contains(lastWord) {
                result.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { result.append(current) }
        return result
    }

    static func sentenceCount(_ text: String) -> Int {
        sentences(text).filter { $0.trimmingCharacters(in: .whitespaces).last.map { ".!?".contains($0) } ?? false }.count
    }

    /// Everything up to the last finished sentence (or the whole text if none finished).
    static func completeSentences(_ text: String) -> String {
        let done = sentences(text).filter { $0.trimmingCharacters(in: .whitespaces).last.map { ".!?".contains($0) } ?? false }
        return done.isEmpty ? text : done.joined()
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let wa = Set(a.lowercased().split { !$0.isLetter }.map(String.init))
        let wb = Set(b.lowercased().split { !$0.isLetter }.map(String.init))
        guard !wa.isEmpty, !wb.isEmpty else { return 0 }
        return Double(wa.intersection(wb).count) / Double(wa.union(wb).count)
    }
}
