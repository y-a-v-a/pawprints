import Foundation

/// What the player wants from a suspect, after free text has been classified.
public enum Topic: Codable, Sendable, Hashable {
    case whereabouts
    case sawAnything
    case aboutSuspect(Int)
    case aboutRoom(RoomRole)
    case aboutOwner
    case aboutItem
    case aboutSelf
    case accuse
    case smallTalk
    /// Out of tone for a cosy mystery (violence and the like). Answered with a canned line.
    case offLimits
}

/// How the suspect should feel while delivering a line.
public enum Mood: String, Codable, Sendable {
    case calm, guarded, flustered, indignant, relieved, rattled, friendly

    /// A stage direction for lines the engine delivers itself.
    public var gesture: String {
        switch self {
        case .calm: "folds both arms"
        case .guarded: "lowers the voice"
        case .flustered: "fidgets"
        case .indignant: "bristles"
        case .relieved: "draws a long breath"
        case .rattled: "stammers"
        case .friendly: "smiles warmly"
        }
    }
}

/// The engine's instruction for one reply: the model voices it, the engine owns it.
public struct Directive: Sendable {
    /// How to play the line, written as a note to an actor.
    public var note: String
    public var mood: Mood
    /// Cards this reply puts into the notebook.
    public var reveals: [String]
    /// A fixed line to use instead of calling the model (guardrail-proof paths).
    public var cannedLine: String?
    /// A plain first-person line carrying the facts. The model restyles it in the
    /// character's voice; it never has to invent the facts itself. It is also what the
    /// suspect says, word for word, when the model is unavailable.
    public var script: String?
    /// People the line has to name, or the reveal didn't land and it's retried.
    public var mustMention: [Suspect] = []
    /// Words the line has to keep (a room, a key noun), checked the same way.
    public var mustContain: [String] = []
    /// The player asked this before; the suspect just repeats themselves.
    public var isRepeat = false
    /// Further beats the same suspect delivers straight after this one.
    public var then: [Directive] = []

    public var allReveals: [String] { reveals + then.flatMap(\.allReveals) }
}

public struct Verdict: Sendable {
    public let accused: Suspect
    public let correct: Bool
    /// Proof slots the player filled with a card that really proves them.
    public let proven: Set<Proof>
    /// Out of three. Wrong accusations along the way cost a star each.
    public let stars: Int
    /// What the wrongly accused says to clear their name (nil when the accusation was right).
    public let rebuttal: Directive?
}

/// Plays one case: tracks what the player knows and decides how suspects respond.
public struct Engine: Codable, Sendable {
    public let mystery: Case
    public private(set) var known: [String] = []
    public private(set) var searched: Set<RoomRole> = []
    public private(set) var composure: [Int: Int]
    public private(set) var asked: [Int: Set<Topic>] = [:]
    public private(set) var questionsAsked = 0
    public private(set) var confessed = false
    public private(set) var wrongAccusations = 0
    public private(set) var solved = false

    public init(mystery: Case) {
        self.mystery = mystery
        composure = Dictionary(uniqueKeysWithValues: mystery.suspects.map { ($0.id, 8) })
    }

    public var knownCards: [Card] { known.map(mystery.card) }
    public func knows(_ id: String) -> Bool { known.contains(id) }

    /// The card that breaks the culprit's alibi in this case's plot.
    public var alibiBreaker: String {
        switch mystery.plot {
        case .lonelyRoom: CardID.claim(mystery.loner.id)
        case .coldRoom: CardID.coldRoom
        case .missingFromCrowd: CardID.notSeen
        }
    }

    // MARK: - Interrogation

    public mutating func ask(_ suspectID: Int, _ topic: Topic) -> Directive {
        let s = mystery.suspect(suspectID)
        let repeated = asked[suspectID, default: []].contains(topic)
        asked[suspectID, default: []].insert(topic)
        questionsAsked += 1
        var d = directive(for: s, topic: topic)
        if repeated, d.allReveals.allSatisfy(knows), topic != .offLimits, let script = d.script {
            d.note = "You have already answered this; say so, a little impatiently. " + d.note
            d.script = "I've already told you this, Inspector. " + script
            d.isRepeat = true
        }
        unlock(d.allReveals)
        return d
    }

    /// Picks one of several phrasings, the same one every time for this suspect in this case,
    /// so lines don't give away who plays which part.
    private func variant(_ options: [String], _ s: Suspect, _ salt: Int = 0) -> String {
        options[Int((mystery.seed &+ UInt64(s.id * 31 + salt)) % UInt64(options.count))]
    }

    private mutating func directive(for s: Suspect, topic: Topic) -> Directive {
        let m = mystery
        let gathering = m.room(.gathering)
        let quiet = m.room(.quiet)
        let rh = m.redHerring

        switch topic {
        case .offLimits:
            return Directive(note: "", mood: .indignant, reveals: [], cannedLine: deflection(for: s))

        case .whereabouts:
            switch s.role {
            case .culprit:
                let script = switch m.plot {
                case .lonelyRoom: variant(["I was \(quiet.inside), reading, all by myself. I didn't see a soul.",
                                           "Reading, \(quiet.inside). Alone, I'm afraid, so nobody can vouch for me."], s)
                case .coldRoom: variant(["I spent the whole evening \(quiet.inside), curled up by the lamp with a good book.",
                                         "\(quiet.title), with a book and a lamp. A perfectly quiet evening."], s)
                case .missingFromCrowd: variant(["I was \(gathering.inside) with everyone else, enjoying \(m.occasion).",
                                                 "I was where everyone was, \(gathering.inside). Lovely evening, until this."], s)
                }
                return .init(note: "Answer smoothly, a touch too quickly.", mood: .calm, reveals: [CardID.claim(s.id)], script: script,
                             mustContain: [m.room(s.claimedRoom).keyword])
            case .redHerring where !confessed:
                return .init(note: "Flustered; you try to change the subject.", mood: .flustered, reveals: [CardID.claim(s.id)],
                             script: variant(["I was \(gathering.inside) with everyone else. Where else would I be?",
                                              "\(gathering.title), naturally. With all the others. The whole time."], s),
                             mustContain: [gathering.keyword])
            case .redHerring:
                return .init(note: "Sheepish.", mood: .relieved, reveals: [CardID.claim(s.id)],
                             script: "As I told you, I was really in \(m.secretRoom.name). I \(m.secretSummary). There, I've said it again.",
                             mustContain: [m.secretRoom.keyword])
            case .witness:
                return .init(note: "Cheerful.", mood: .friendly, reveals: [CardID.claim(s.id)],
                             script: variant(["I was \(gathering.inside) the whole time, \(gathering.vantage). Wouldn't have missed it for anything.",
                                              "\(gathering.title), \(gathering.vantage), the whole evening. Best spot there is."], s),
                             mustContain: [gathering.keyword])
            case .loner:
                let room = m.room(s.actualRoom)
                let script = s.actualRoom == .quiet
                    ? variant(["I was \(room.inside), all alone, the whole time. Nobody else came in all evening.",
                               "\(room.title). On my own, and not a soul came through that door."], s)
                    : "I was \(room.inside), \(SolitaryPursuits.byRoom[s.actualRoom] ?? "keeping to myself"). On my own, I'm afraid."
                return .init(note: "Calm and matter-of-fact.", mood: .calm, reveals: [CardID.claim(s.id)], script: script,
                             mustContain: [room.keyword])
            }

        case .sawAnything:
            switch s.role {
            case .witness:
                return .init(note: "You found it odd.", mood: .guarded, reveals: [CardID.sighting],
                             script: "Now that you mention it, yes. Just before it all began, I saw \(rh.name) slip away from \(gathering.name). And \(rh.pronoun) didn't come back until it was all over.",
                             mustMention: [rh], mustContain: [gathering.keyword])
            case .loner:
                return .init(note: "Calm.", mood: .calm, reveals: [CardID.claim(s.id)],
                             script: "Not a thing. I was \(m.room(s.actualRoom).inside) on my own, and nobody came by.")
            case .culprit:
                return .init(note: "As if reluctant to tell tales.", mood: .calm, reveals: [],
                             script: "I hate to tell tales, but \(rh.shortName) seemed terribly nervous all evening.")
            case .redHerring where confessed:
                return figureSighting(opening: "As I said, on my way back from")
            case .redHerring:
                return .init(note: "A bit too firmly, then change the subject.", mood: .flustered, reveals: [],
                             script: "No! Nothing at all. Nothing whatsoever. Lovely evening, wasn't it?")
            }

        case .aboutSuspect(let otherID):
            let other = m.suspect(otherID)
            if otherID == s.id {
                return directive(for: s, topic: .aboutSelf)
            }
            if s.role == .witness && other.role == .redHerring {
                return .init(note: "Lower your voice.", mood: .guarded, reveals: [CardID.sighting],
                             script: "\(other.shortName.capitalizedFirst)? Jumpy all evening. I saw \(other.objectPronoun) slip away from \(gathering.name) just before it all began, and \(other.pronoun) didn't come back until it was over.",
                             mustMention: [other], mustContain: [gathering.keyword])
            }
            if m.plot == .missingFromCrowd && s.role == .witness && other.role == .culprit {
                return .init(note: "Puzzled, as if it has only just struck you.", mood: .guarded, reveals: [CardID.notSeen],
                             script: "Funny you should ask. I stood \(gathering.vantage) \(gathering.inside) all evening, and I never once saw \(other.name) there.",
                             mustMention: [other], mustContain: ["never"])
            }
            if s.id == m.gossipID && other.role == .culprit {
                return .init(note: "Lower your voice; you love a bit of gossip.", mood: .guarded, reveals: [CardID.gossip],
                             script: "Between you and me? \(m.gossipLine).",
                             mustMention: [other], mustContain: m.gossipKeys)
            }
            if s.role == .culprit {
                return .init(note: "Speak politely and briefly about \(other.name), \(other.occupation). Do not accuse anyone.",
                             mood: .calm, reveals: [],
                             script: "\(other.shortName.capitalizedFirst)? Perfectly pleasant, as far as I know. I really couldn't say more.")
            }
            let opinion = variant([
                "\(other.shortName.capitalizedFirst)? \(other.occupation.capitalizedFirst). We say good evening, but I couldn't tell you much more.",
                "Oh, \(other.shortName)'s all right, I suppose. \(other.pronoun.capitalizedFirst) keeps \(other.reflexive) to \(other.reflexive), mostly.",
                "\(other.shortName.capitalizedFirst)? I hardly know \(other.objectPronoun), Inspector. We've only spoken once or twice.",
                "Decent enough, \(other.shortName). I've no quarrel with \(other.objectPronoun).",
            ], s, otherID)
            return .init(note: "Give your honest, in-character opinion of \(other.name), \(other.occupation), in one or two sentences. You know nothing about the theft.",
                         mood: .friendly, reveals: [], script: opinion)

        case .aboutRoom(let role):
            let room = m.room(role)
            if role == s.claimedRoom || (confessed && s.role == .redHerring && role == s.actualRoom) {
                return directive(for: s, topic: .whereabouts)
            }
            if role == .display {
                return .init(note: "Firm.", mood: s.role == .culprit ? .guarded : .calm, reveals: [],
                             script: "\(room.title)? I never went near it all evening. That's where \(m.item) was kept, isn't it?")
            }
            return .init(note: "Matter-of-fact.", mood: .calm, reveals: [],
                         script: "\(room.title)? I didn't set foot in it tonight, Inspector.")

        case .aboutOwner:
            return .init(note: "Talk briefly about \(m.ownerName), \(m.ownerDescription). You \(s.relationshipInSecondPerson).",
                         mood: s.role == .culprit ? .guarded : .friendly, reveals: [],
                         script: "\(m.ownerName.capitalizedFirst)? I \(s.relationshipInFirstPerson). A fine host, in the main.")

        case .aboutItem:
            let script = s.role == .culprit
                ? "\(m.item.capitalizedFirst)? A pity it's gone, of course. I have no idea where it is now."
                : "Such a shame about \(m.item). I can't think who would do such a thing, and I've no idea where it is now."
            return .init(note: s.role == .culprit ? "Politely uninterested." : "Shocked and sorry.",
                         mood: s.role == .culprit ? .guarded : .friendly, reveals: [], script: script,
                         mustContain: ["idea"])

        case .aboutSelf:
            return .init(note: "Introduce yourself in your own manner, with one little personal detail.",
                         mood: .friendly, reveals: [],
                         script: "I'm \(s.name), \(s.occupation). I \(s.relationshipInFirstPerson).")

        case .accuse:
            switch s.role {
            case .culprit:
                adjust(s.id, by: -1, floor: 4)
                return .init(note: "Wounded dignity.", mood: .indignant, reveals: [],
                             script: "That is a very serious charge, Inspector, and you have no proof whatsoever.")
            case .redHerring where !confessed:
                adjust(s.id, by: -3, floor: 0)
                if composure[s.id]! <= 2 {
                    return confess()
                }
                return .init(note: "Very flustered. You are hiding something, but it isn't the theft.", mood: .rattled, reveals: [],
                             script: "N-no! I didn't take it! I can't say where I was, but I didn't take it!")
            default:
                adjust(s.id, by: -1, floor: 3)
                return .init(note: "Indignant.", mood: .indignant, reveals: [],
                             script: "Me? How dare you! I had nothing to do with it.")
            }

        case .smallTalk:
            return .init(note: "Brief, in-character small talk, then ask what the Inspector wants to know.",
                         mood: .friendly, reveals: [],
                         script: variant(["What an evening \(m.occasion) has turned out to be! Now, what is it you'd like to know, Inspector?",
                                          "I'm sure that's very interesting, Inspector. But shouldn't you be finding \(m.item)?",
                                          "Ha! Well. Is there something you wanted to ask me?"], s, questionsAsked))
        }
    }

    /// In-character refusals, never the same one twice in a row.
    private mutating func deflection(for s: Suspect) -> String {
        let extra = ["I'd rather not answer that, Inspector.", "Really! That's no question for a pleasant evening.",
                     "Let's keep this civil, shall we?"]
        let options = s.deflections + extra
        return options[questionsAsked % options.count]
    }

    public mutating func present(_ cardID: String, to suspectID: Int) -> Directive {
        let s = mystery.suspect(suspectID)
        let card = mystery.card(cardID)
        questionsAsked += 1
        let m = mystery

        switch s.role {
        case .redHerring where !confessed:
            switch cardID {
            case CardID.sighting, CardID.redHerringLied, CardID.secretEvidence:
                let d = confess()
                unlock(d.allReveals)
                return d
            case CardID.trace:
                adjust(s.id, by: -2, floor: 2)
                return .init(note: "Nervous, too defensive.", mood: .flustered, reveals: [],
                             script: "That could be anyone's! Half the guests have... well. It wasn't me, I promise you.")
            default: break
            }
        case .culprit:
            // Anything that shows the alibi is false; in the lonely-room plot, that includes
            // the loner's own statement.
            let alibiCards = [CardID.alibiBroken, CardID.coldRoom, CardID.notSeen]
                + (m.plot == .lonelyRoom ? [CardID.claim(m.loner.id)] : [])
            switch cardID {
            case _ where alibiCards.contains(cardID):
                adjust(s.id, by: -3, floor: 1)
                let script = m.plot == .missingFromCrowd
                    ? "I... I was at the back! Behind the taller guests. Nobody could have seen me from the door."
                    : "I... I must have muddled up the rooms! It was a very confusing evening, Inspector."
                return .init(note: "Bluster. You are badly rattled but you do NOT confess.", mood: .rattled, reveals: [], script: script)
            case CardID.redHerringSaw:
                adjust(s.id, by: -2, floor: 1)
                let script = m.plot == .missingFromCrowd
                    ? "Half the village was \(m.room(.gathering).inside), Inspector. That figure could have been anyone."
                    : "Heading for \(m.room(.quiet).name)? Well, I was already in there, so it can't have been me, can it?"
                return .init(note: "A little too quick to answer. You do NOT confess.", mood: .guarded, reveals: [], script: script)
            case CardID.gossip, CardID.motiveDocument:
                adjust(s.id, by: -2, floor: 1)
                return .init(note: "Deny it hotly.", mood: .rattled, reveals: [],
                             script: "That is a private matter, and it has nothing to do with \(m.item)!")
            case CardID.trace:
                adjust(s.id, by: -1, floor: 1)
                return .init(note: "Cool and dismissive.", mood: .guarded, reveals: [],
                             script: confessed
                                 ? "That proves nothing, Inspector. Anyone could have left that."
                                 : "That proves nothing. \(m.redHerring.shortName.capitalizedFirst) could just as easily have left that.")
            case CardID.hidingHint:
                adjust(s.id, by: -1, floor: 1)
                return .init(note: "A flicker of alarm, quickly hidden.", mood: .guarded, reveals: [],
                             script: "How very odd. I'm sure I wouldn't know anything about that.")
            default: break
            }
        default: break
        }

        if cardID == CardID.coldRoom {
            // The room's emptiness only matters to whoever claimed to be in it.
            return .init(note: "Mildly puzzled.", mood: .calm, reveals: [],
                         script: "An empty room? I never went in there myself, Inspector.")
        }
        if card.about.contains(s.id) {
            return .init(note: "The Inspector shows you this note: \"\(card.text)\". You are innocent of the theft. React calmly in one or two sentences.",
                         mood: .guarded, reveals: [],
                         script: "I can explain that, Inspector, but it has nothing to do with the theft. Nothing at all.")
        }
        if let other = card.about.first.map(m.suspect) {
            return .init(note: "The Inspector shows you this note about \(other.name): \"\(card.text)\". React with surprise in one or two sentences. You know nothing more.",
                         mood: .friendly, reveals: [],
                         script: "Well I never. \(other.shortName.capitalizedFirst)? I had no idea.")
        }
        return .init(note: "Look at it, puzzled.", mood: .calm, reveals: [],
                     script: "I'm sorry, Inspector, I don't see what that has to do with me.")
    }

    private mutating func confess() -> Directive {
        confessed = true
        let rh = mystery.redHerring
        composure[rh.id] = 6
        return .init(note: "You give up, embarrassed, and confess the real reason you lied.", mood: .flustered, reveals: [CardID.confession],
                     script: "Oh, very well! \(mystery.secretConfession). But I never went anywhere near \(mystery.room(.display).name), I swear it!",
                     mustContain: [mystery.secretKeyword],
                     then: [figureSighting(opening: "And there's something else. On my way back from")])
    }

    /// What the red herring glimpsed on the way back: a figure, not a face.
    private func figureSighting(opening: String) -> Directive {
        let m = mystery
        let heading = m.plot == .missingFromCrowd ? m.room(.gathering) : m.room(.quiet)
        return .init(note: "Lower your voice; this matters.", mood: .guarded, reveals: [CardID.redHerringSaw],
                     script: "\(opening) \(m.secretRoom.name), I saw someone hurry out of \(m.room(.display).name) with something hidden under one arm, heading \(m.plot == .missingFromCrowd ? "back towards" : "towards") \(heading.name). It was too dark to see who.",
                     mustContain: [m.room(.display).keyword, heading.keyword])
    }

    /// Pressure lowers composure but never past `floor`, and never raises it.
    private mutating func adjust(_ id: Int, by delta: Int, floor: Int) {
        let current = composure[id]!
        let lowered = current + delta
        composure[id] = min(10, lowered >= floor ? lowered : min(current, floor))
    }

    /// A known piece of evidence the player names in free text ("why was there a feather?"),
    /// so asking about it works like showing the card.
    public func mentionedEvidence(in text: String) -> String? {
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        let filler: Set<String> = ["a", "an", "the", "of", "and", "about", "something", "out", "place", "room",
                                   "untouched", "empty", "two", "old", "torn"]
        return knownCards.last { card in
            guard card.kind == .evidence else { return false }
            let keys = card.title.lowercased().split { !$0.isLetter }.map(String.init).filter { !filler.contains($0) && $0.count > 2 }
            return keys.contains { key in words.contains(key) || words.contains(key + "s") || (key.hasSuffix("s") && words.contains(String(key.dropLast()))) }
        }?.id
    }

    /// A known card the player throws at a suspect in plain English: "Mrs Otterly saw you slip
    /// away", "you were never in the crowd". The card's source named in the text, or the
    /// suspect's own lie described, counts as showing it.
    public func confrontation(in text: String, to suspectID: Int) -> String? {
        let t = " " + text.lowercased().split { !$0.isLetter }.joined(separator: " ") + " "
        let accusing = [" saw you ", " seen you ", " never saw you ", " didn t see you ", " wasn t there ", " weren t there ",
                        " you lied ", " you re lying ", " you are lying ", " explain ", " your alibi ", " not where you said ",
                        " nobody sat ", " lamp was cold ", " never there "].contains { t.contains($0) }
        guard accusing else { return nil }
        let candidates = knownCards.filter { card in
            card.about.contains(suspectID) && [.testimony, .deduction, .evidence].contains(card.kind)
        }
        // Prefer the card whose source is the person named; otherwise the strongest card.
        for card in candidates.reversed() {
            if let source = mystery.suspects.first(where: { $0.name == card.source }), source.id != suspectID,
               source.isMentioned(in: text) {
                return card.id
            }
        }
        let strongest = [CardID.alibiBroken, CardID.notSeen, CardID.coldRoom, CardID.redHerringLied, CardID.sighting]
        return strongest.first { id in candidates.contains { $0.id == id } }
    }

    // MARK: - Searching

    /// Searches a room, returning the cards found there (empty if nothing).
    public mutating func search(_ role: RoomRole) -> [Card] {
        searched.insert(role)
        var found: [String] = []
        if role == .display { found.append(CardID.trace) }
        if role == .cloakroom { found.append(CardID.motiveDocument) }
        if role == mystery.redHerring.actualRoom { found.append(CardID.secretEvidence) }
        if role == .quiet && mystery.plot == .coldRoom { found.append(CardID.coldRoom) }
        if role == mystery.hidingRoom { found.append(CardID.hidingHint) }
        let fresh = found.filter { !knows($0) }
        unlock(fresh)
        return fresh.map(mystery.card)
    }

    // MARK: - Notebook

    private mutating func unlock(_ ids: [String]) {
        for id in ids where !knows(id) { known.append(id) }
        // The notebook joins the dots on its own, once both halves are in it.
        let c = mystery.culprit, rh = mystery.redHerring
        if knows(CardID.claim(c.id)), knows(alibiBreaker), !knows(CardID.alibiBroken) {
            known.append(CardID.alibiBroken)
        }
        if knows(CardID.claim(rh.id)), knows(CardID.sighting), !knows(CardID.redHerringLied), !confessed {
            known.append(CardID.redHerringLied)
        }
    }

    /// The single most useful next step, for the "hunch" button.
    public var hunch: String {
        let m = mystery
        if solved {
            return "Case closed. Time for a well-earned cup of tea."
        }
        let display = m.room(.display)
        if !searched.contains(.display) {
            return "Start at the scene of the crime. Search \(display.name)."
        }
        let missingClaims = m.suspects.filter { !knows(CardID.claim($0.id)) }
        if missingClaims.count >= 2 {
            return "Find out where everyone was \(m.window)."
        }
        if !knows(CardID.alibiBroken) && knows(CardID.claim(m.culprit.id)) {
            switch m.plot {
            case .coldRoom where !searched.contains(.quiet):
                return "Someone says they spent the evening \(m.room(.quiet).inside). Has anyone looked in there?"
            case .missingFromCrowd where !knows(CardID.notSeen):
                return "\(m.witness.shortName.capitalizedFirst) watched \(m.room(.gathering).name) from the door all evening. Ask about the others who say they were there."
            default: break
            }
        }
        if !knows(CardID.sighting) && !confessed {
            return "Someone in \(m.room(.gathering).name) might have noticed who slipped away. Ask what they saw."
        }
        if knows(CardID.sighting) && !confessed {
            return "\(m.redHerring.shortName.capitalizedFirst) is hiding something. Show \(m.redHerring.objectPronoun) what you know."
        }
        if knows(CardID.redHerringSaw) && !knows(CardID.alibiBroken) {
            let room = m.plot == .missingFromCrowd ? m.room(.gathering) : m.room(.quiet)
            switch m.plot {
            case .coldRoom where !searched.contains(.quiet):
                return "The figure was heading for \(room.name). Who says they spent the evening there? Take a look inside."
            case .missingFromCrowd:
                return "The figure was heading back to \(room.name). Who says they were there all along? Ask the one who watched \(room.vantage)."
            default:
                return "The figure was heading for \(room.name). Who says they were in there? Can they both be telling the truth?"
            }
        }
        if let s = missingClaims.first {
            return "You still haven't asked \(s.shortName) where \(s.pronoun) was."
        }
        let proofs = Set(knownCards.compactMap { $0.proves == nil || !$0.about.contains(m.culprit.id) ? nil : $0.proves })
        if !proofs.contains(.motive) {
            return searched.contains(.cloakroom)
                ? "Every thief has a reason. Ask around about the others."
                : "Coats have pockets. Search \(m.room(.cloakroom).name)."
        }
        if proofs.count == 3 {
            return "You have enough to name the thief. Gather everyone and make your accusation."
        }
        return "Look again at the stories that don't fit together."
    }

    // MARK: - Accusation

    public mutating func accuse(_ suspectID: Int, evidence: [Proof: String]) -> Verdict {
        let accused = mystery.suspect(suspectID)
        guard accused.role == .culprit else {
            wrongAccusations += 1
            return Verdict(accused: accused, correct: false, proven: [], stars: 0, rebuttal: rebuttal(for: accused))
        }
        var proven: Set<Proof> = []
        for (slot, cardID) in evidence {
            let card = mystery.card(cardID)
            if card.proves == slot, card.about.contains(suspectID) { proven.insert(slot) }
        }
        solved = true
        let stars = max(1, proven.count - wrongAccusations)
        return Verdict(accused: accused, correct: true, proven: proven, stars: stars, rebuttal: nil)
    }

    /// A wrongly accused suspect clears their name, which usually teaches the player something.
    private mutating func rebuttal(for s: Suspect) -> Directive {
        let m = mystery
        adjust(s.id, by: -2, floor: 2)
        switch s.role {
        case .redHerring where !confessed:
            let d = confess()
            unlock(d.allReveals)
            return d
        case .redHerring:
            return .init(note: "Hurt and indignant.", mood: .indignant, reveals: [],
                         script: "Me? I told you already, I was in \(m.secretRoom.name) the whole time! I never went near \(m.item).")
        case .witness:
            unlock([CardID.claim(s.id)])
            return .init(note: "Indignant.", mood: .indignant, reveals: [CardID.claim(s.id)],
                         script: "Preposterous! I was \(m.room(.gathering).inside) with the whole crowd. Ask anyone!")
        case .loner:
            unlock([CardID.claim(s.id)])
            return .init(note: "Cold and offended.", mood: .indignant, reveals: [CardID.claim(s.id)],
                         script: "Nonsense. I was \(m.room(s.actualRoom).inside) the entire time, and I never left it.")
        case .culprit:
            return .init(note: "", mood: .calm, reveals: [])
        }
    }

    /// The thief's confession, delivered in the finale.
    public var confession: Directive {
        let m = mystery
        return .init(note: "The game is up. Confess with feeling.", mood: .rattled, reveals: [],
                     script: "Very well, Inspector, I confess. I took \(m.item), because \(m.motiveConfession). You'll find it \(m.hidingPlace).")
    }
}
