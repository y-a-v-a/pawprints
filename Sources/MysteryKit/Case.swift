import Foundation

/// How the culprit's alibi comes apart. Each plot sends the player down a different route.
public enum Plot: String, Codable, Sendable, CaseIterable {
    /// The culprit claims the quiet room, but the loner was in there all evening and saw nobody.
    case lonelyRoom
    /// The culprit claims an evening reading in the quiet room, but nobody sat in there at all:
    /// searching it shows the lamp cold and the cushions untouched.
    case coldRoom
    /// The culprit claims to have been in the crowd, but the witness by the door never saw them.
    case missingFromCrowd
}

/// The part each suspect plays in the puzzle. Only the engine ever sees this.
public enum SuspectRole: String, Codable, Sendable {
    /// Did it. Lies about being in the quiet room.
    case culprit
    /// Innocent, but lies about where they were to hide an embarrassing secret,
    /// and on the way back saw the culprit leaving the scene.
    case redHerring
    /// Was in the crowd and noticed the red herring slip away.
    case witness
    /// Was alone somewhere quiet. In the lonely-room plot, that breaks the culprit's alibi.
    case loner
}

public struct Suspect: Codable, Identifiable, Sendable, Hashable {
    public let id: Int
    public let name: String
    public let shortName: String
    public let species: String
    public let occupation: String
    public let personality: String
    public let voice: String
    public let look: String
    public let relationship: String
    public let traces: [Trace]
    public let deflections: [String]
    public let isFemale: Bool
    public let nicknames: [String]
    public let catchphrases: [String]
    public let role: SuspectRole
    public let claimedRoom: RoomRole
    public let actualRoom: RoomRole

    public var firstWord: String { name.split(separator: " ").first.map(String.init) ?? name }
    public var pronoun: String { isFemale ? "she" : "he" }

    /// Words that identify this suspect in free text: surname, first name, short name, species.
    public var nameKeys: [String] {
        let titles: Set<String> = ["dr.", "lady", "colonel", "professor", "countess", "captain", "mrs.", "mr.", "miss", "the"]
        var keys = name.lowercased().split(separator: " ").map(String.init).filter { !titles.contains($0) && $0.count > 2 }
        keys.append(shortName.lowercased().replacingOccurrences(of: "the ", with: ""))
        keys.append(species)
        keys += nicknames
        return keys
    }

    public func isMentioned(in text: String) -> Bool {
        let words = Set(text.lowercased().split { !$0.isLetter && $0 != "." }.map(String.init))
        let lower = text.lowercased()
        return nameKeys.contains { key in key.contains(" ") ? lower.contains(key) : words.contains(key) || words.contains(key + "s") }
    }
    public var possessive: String { isFemale ? "her" : "his" }
    public var objectPronoun: String { isFemale ? "her" : "him" }
    public var reflexive: String { isFemale ? "herself" : "himself" }

    /// "is X's cousin" -> "am X's cousin", "has worked for X" -> "have worked for X".
    public var relationshipInFirstPerson: String {
        if relationship.hasPrefix("is ") { return "am " + relationship.dropFirst(3) }
        if relationship.hasPrefix("has ") { return "have " + relationship.dropFirst(4) }
        return relationship
    }

    /// The same, for telling the actor who they are: "You are the Reverend's distant cousin."
    public var relationshipInSecondPerson: String {
        if relationship.hasPrefix("is ") { return "are " + relationship.dropFirst(3) }
        if relationship.hasPrefix("has ") { return "have " + relationship.dropFirst(4) }
        return relationship
    }
}

public struct Room: Codable, Identifiable, Sendable, Hashable {
    public let id: RoomRole
    public let name: String
    public let look: String

    /// "the Study" -> "The Study", for the start of a sentence or a heading.
    public var title: String { name.capitalizedFirst }

    /// Where someone would stand to see everyone come and go.
    public var vantage: String {
        if name.hasSuffix("Lawn") { return "by the gate" }
        if name.hasSuffix("Terrace") { return "by the steps" }
        if name.hasSuffix("Deck") { return "by the rail" }
        return "by the door"
    }

    /// One word that identifies the room in speech: "library", "marquee", "map".
    public var keyword: String {
        let generic: Set<String> = ["room", "tent", "hall", "deck", "cupboard", "of", "the"]
        let words = name.lowercased().split { !$0.isLetter }.map(String.init).filter { !generic.contains($0) }
        return words.last ?? name.lowercased()
    }

    /// "in the Study", "on the Terrace".
    public var inside: String {
        let outdoors = ["Terrace", "Deck", "Lawn"].contains { name.hasSuffix($0) }
        return (outdoors ? "on " : "in ") + name
    }
}

extension String {
    /// Upper-cases only the first letter, so "the Countess" becomes "The Countess".
    public var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Which part of the case a card helps prove.
public enum Proof: String, Codable, Sendable, CaseIterable {
    case means, opportunity, motive

    public var label: String {
        switch self {
        case .means: "Means"
        case .opportunity: "Opportunity"
        case .motive: "Motive"
        }
    }

    public var question: String {
        switch self {
        case .means: "What ties them to the scene?"
        case .opportunity: "How could they have done it?"
        case .motive: "Why would they do it?"
        }
    }
}

public enum CardKind: String, Codable, Sendable {
    case claim, testimony, evidence, deduction, confession

    public var label: String {
        switch self {
        case .claim: "Statement"
        case .testimony: "Testimony"
        case .evidence: "Evidence"
        case .deduction: "Deduction"
        case .confession: "Confession"
        }
    }
}

/// A notebook entry. All card text is written by the engine, never the model,
/// so the notebook is the canon the player can trust.
public struct Card: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: CardKind
    public let title: String
    public let text: String
    public let source: String
    /// Suspects this card points at.
    public let about: [Int]
    /// What this card proves, and against whom.
    public let proves: Proof?
    public let imagePrompt: String?
}

public struct Case: Codable, Sendable {
    public let seed: UInt64
    public let plot: Plot
    public let title: String
    public let place: String
    public let occasion: String
    public let window: String
    public let ownerName: String
    public let ownerSpecies: String
    public let ownerDescription: String
    public let ownerLook: String
    public let item: String
    public let itemLook: String
    public let coverLook: String
    public let rooms: [Room]
    public let suspects: [Suspect]
    public let trace: Trace
    public let motiveSummary: String
    public let motiveConfession: String
    public let secretSummary: String
    public let secretConfession: String
    public let secretKeyword: String
    /// Where the stolen item is found once the thief is unmasked, and the room it's in.
    public let hidingPlace: String
    public let hidingRoom: RoomRole
    /// Which suspect knows about the culprit's motive, and what they'd say.
    public let gossipID: Int
    public let gossipLine: String
    public let gossipKeys: [String]
    public let cards: [String: Card]

    public func room(_ role: RoomRole) -> Room { rooms.first { $0.id == role }! }
    public func suspect(_ id: Int) -> Suspect { suspects.first { $0.id == id }! }
    public func suspect(role: SuspectRole) -> Suspect { suspects.first { $0.role == role }! }

    public var culprit: Suspect { suspect(role: .culprit) }
    public var redHerring: Suspect { suspect(role: .redHerring) }
    public var witness: Suspect { suspect(role: .witness) }
    public var loner: Suspect { suspect(role: .loner) }
    public var secretRoom: Room { room(redHerring.actualRoom) }

    public func card(_ id: String) -> Card { cards[id]! }
}

/// Stable card identifiers.
public enum CardID {
    public static func claim(_ suspect: Int) -> String { "claim.\(suspect)" }
    public static let sighting = "testimony.sighting"
    public static let gossip = "testimony.gossip"
    public static let trace = "evidence.trace"
    public static let motiveDocument = "evidence.motive"
    public static let secretEvidence = "evidence.secret"
    public static let confession = "confession.redherring"
    public static let redHerringSaw = "testimony.redherring-saw"
    public static let alibiBroken = "deduction.alibi"
    public static let coldRoom = "evidence.cold-room"
    public static let notSeen = "testimony.not-seen"
    public static let hidingHint = "evidence.hiding"
    public static let redHerringLied = "deduction.redherring-lied"
}
