import Foundation

/// Builds a complete, solvable case from a seed. Pure and deterministic: the same
/// seed always gives the same mystery, so cases can be shared ("try case 4127").
public enum CaseGenerator {
    public static func make(seed: UInt64) -> Case {
        var rng = SeededRNG(seed: seed)
        let setting = Settings.all.pick(using: &rng)
        let item = setting.items.pick(using: &rng)
        let owner = setting.owner

        // Cast: the culprit and the red herring must share a trace, so the evidence at the
        // scene points at both of them. The other two must not, so it points at no one else.
        let eligible = Cast.all.filter { $0.species != owner.species }.shuffled(using: &rng)
        var picked: (CharacterTemplate, CharacterTemplate, Trace, [CharacterTemplate])?
        search: for culprit in eligible {
            for herring in eligible where herring.name != culprit.name {
                guard let shared = culprit.traces.first(where: herring.traces.contains) else { continue }
                let others = eligible.filter { $0.name != culprit.name && $0.name != herring.name && !$0.traces.contains(shared) }
                guard others.count >= 2 else { continue }
                picked = (culprit, herring, shared, Array(others.prefix(2)))
                break search
            }
        }
        guard let (culpritT, herringT, trace, othersT) = picked else {
            preconditionFailure("content tables cannot form a case")
        }
        let witnessT = othersT[0]
        let lonerT = othersT[1]

        let motive = Motives.all.pick(using: &rng)
        let secret = Secrets.all.pick(using: &rng)
        let plot = Plot.allCases.pick(using: &rng)
        // In the cold-room plot the loner is alone somewhere else, away from the red herring.
        let lonerRoom: RoomRole = plot == .coldRoom
            ? [RoomRole.kitchen, .garden].filter { $0 != secret.room }.pick(using: &rng)
            : .quiet

        var relationships = [
            "is an old school friend of {owner}",
            "is {owner}'s distant cousin",
            "is {owner}'s bridge partner",
            "is {owner}'s next-door neighbour",
            "is an old rival of {owner}",
            "is {owner}'s godchild",
        ].shuffled(using: &rng)
        let years = ["three", "seven", "twelve", "twenty"].shuffled(using: &rng)

        func makeSuspect(_ t: CharacterTemplate, id: Int, role: SuspectRole) -> Suspect {
            let claimed: RoomRole
            let actual: RoomRole
            switch role {
            case .culprit: (claimed, actual) = (plot == .missingFromCrowd ? .gathering : .quiet, .display)
            case .redHerring: (claimed, actual) = (.gathering, secret.room)
            case .witness: (claimed, actual) = (.gathering, .gathering)
            case .loner: (claimed, actual) = (lonerRoom, lonerRoom)
            }
            let occupation = t.isStaff
                ? "\(owner.name)'s \(t.occupation.replacingOccurrences(of: "the ", with: ""))"
                : t.occupation
            let relationship = t.isStaff
                ? "has worked for \(owner.name) for \(years[id]) years"
                : relationships.removeFirst().replacingOccurrences(of: "{owner}", with: owner.name)
            return Suspect(id: id, name: t.name, shortName: t.shortName, species: t.species,
                           occupation: occupation, personality: t.personality, voice: t.voice,
                           look: t.look, relationship: relationship, traces: t.traces,
                           deflections: t.deflections, isFemale: t.isFemale, nicknames: t.nicknames,
                           catchphrases: t.catchphrases, role: role, claimedRoom: claimed, actualRoom: actual)
        }

        // Shuffle seating order so the culprit isn't always first in the list.
        var roles: [(CharacterTemplate, SuspectRole)] = [
            (culpritT, .culprit), (herringT, .redHerring), (witnessT, .witness), (lonerT, .loner),
        ]
        roles.shuffle(using: &rng)
        let suspects = roles.enumerated().map { makeSuspect($1.0, id: $0, role: $1.1) }

        let rooms = setting.rooms.map { Room(id: $0.role, name: $0.name, look: $0.look) }
        func room(_ r: RoomRole) -> Room { rooms.first { $0.id == r }! }

        let c = suspects.first { $0.role == .culprit }!
        let rh = suspects.first { $0.role == .redHerring }!
        let w = suspects.first { $0.role == .witness }!
        let l = suspects.first { $0.role == .loner }!
        // The witness's word about the culprit is the alibi-breaker in the crowd plot,
        // so the gossip has to come from the loner there.
        let gossip = plot == .missingFromCrowd || Bool.random(using: &rng) ? l : w

        let fill = { (s: String) in
            s.replacingOccurrences(of: "{cObj}", with: c.objectPronoun)
                .replacingOccurrences(of: "{oObj}", with: owner.isFemale ? "her" : "him")
                .replacingOccurrences(of: "{c}", with: c.name)
                .replacingOccurrences(of: "{owner}", with: owner.name)
                .replacingOccurrences(of: "{item}", with: item.name)
                .replacingOccurrences(of: "{room}", with: room(secret.room).name)
        }

        let display = room(.display).name
        let gathering = room(.gathering).name
        let inGathering = room(.gathering).inside
        let inQuiet = room(.quiet).inside
        let inLonerRoom = room(lonerRoom).inside
        let window = setting.window

        var cards: [Card] = []
        let culpritClaim = switch plot {
        case .lonelyRoom: "\(c.name) claims to have been alone \(inQuiet), reading, \(window)."
        case .coldRoom: "\(c.name) claims to have spent the whole evening \(inQuiet), reading by the lamp."
        case .missingFromCrowd: "\(c.name) claims to have been \(inGathering) with everyone else \(window)."
        }
        cards.append(Card(id: CardID.claim(c.id), kind: .claim, title: "\(c.shortName.capitalizedFirst)'s story",
                          text: culpritClaim, source: c.name, about: [c.id], proves: nil, imagePrompt: nil))
        cards.append(Card(id: CardID.claim(rh.id), kind: .claim, title: "\(rh.shortName.capitalizedFirst)'s story",
                          text: "\(rh.name) claims to have stayed \(inGathering) with everyone else \(window).",
                          source: rh.name, about: [rh.id], proves: nil, imagePrompt: nil))
        cards.append(Card(id: CardID.claim(w.id), kind: .claim, title: "\(w.shortName.capitalizedFirst)'s story",
                          text: "\(w.name) was \(inGathering) with the crowd \(window).",
                          source: w.name, about: [w.id], proves: nil, imagePrompt: nil))
        let lonerClaim = lonerRoom == .quiet
            ? "\(l.name) was alone \(inQuiet) the whole time \(window), and insists nobody else came in."
            : "\(l.name) was alone \(inLonerRoom) \(window), \(SolitaryPursuits.byRoom[lonerRoom] ?? "keeping to themselves")."
        cards.append(Card(id: CardID.claim(l.id), kind: .claim, title: "\(l.shortName.capitalizedFirst)'s story",
                          text: lonerClaim, source: l.name, about: [l.id], proves: nil, imagePrompt: nil))
        cards.append(Card(id: CardID.sighting, kind: .testimony, title: "\(w.shortName.capitalizedFirst) saw \(rh.shortName) slip away",
                          text: "\(w.name) saw \(rh.name) slip away from \(gathering) just before it all began, and not come back until it was over.",
                          source: w.name, about: [rh.id], proves: nil, imagePrompt: nil))
        cards.append(Card(id: CardID.gossip, kind: .testimony, title: "Gossip about \(c.shortName)",
                          text: "\(gossip.name) says: \u{201C}\(fill(motive.gossip)).\u{201D}",
                          source: gossip.name, about: [c.id], proves: .motive, imagePrompt: nil))
        cards.append(Card(id: CardID.trace, kind: .evidence, title: trace.title,
                          text: "In \(display): \(trace.clue). \(trace.meaning)",
                          source: "Found in \(display)", about: suspects.filter { $0.traces.contains(trace) }.map(\.id),
                          proves: .means, imagePrompt: trace.illustration))
        cards.append(Card(id: CardID.motiveDocument, kind: .evidence, title: motive.documentTitle,
                          text: fill(motive.document),
                          source: "Found in \(room(.cloakroom).name)", about: [c.id], proves: .motive,
                          imagePrompt: motive.documentLook))
        cards.append(Card(id: CardID.secretEvidence, kind: .evidence, title: secret.evidenceTitle,
                          text: fill(secret.evidence),
                          source: "Found in \(room(secret.room).name)", about: [rh.id], proves: nil,
                          imagePrompt: secret.evidenceLook))
        cards.append(Card(id: CardID.confession, kind: .confession, title: "\(rh.shortName.capitalizedFirst) comes clean",
                          text: "\(rh.name) admits: \u{201C}\(fill(secret.confession)).\u{201D} \(rh.shortName.capitalizedFirst) was never near \(item.name).",
                          source: rh.name, about: [rh.id], proves: nil, imagePrompt: nil))
        // The red herring only glimpses a figure. Where it was heading is the clue: it points at
        // whoever claims to have been in that room, and the plot's own clue proves which of them lied.
        let heading = plot == .missingFromCrowd ? "back towards \(gathering)" : "towards \(room(.quiet).name)"
        cards.append(Card(id: CardID.redHerringSaw, kind: .testimony, title: "\(rh.shortName.capitalizedFirst) saw a figure",
                          text: "On the way back from \(room(secret.room).name), \(rh.name) saw a figure hurry out of \(display) with something hidden under one arm, heading \(heading). It was too dark to see who.",
                          source: rh.name, about: [], proves: nil, imagePrompt: nil))
        let alibiFalse = switch plot {
        case .lonelyRoom: "\(c.name) claims to have been \(inQuiet), but \(l.name) was there the whole time and saw nobody."
        case .coldRoom: "\(c.name) claims to have spent the evening reading \(inQuiet), but nobody sat in there all evening."
        case .missingFromCrowd: "\(c.name) claims to have been \(inGathering), but \(w.name) was \(room(.gathering).vantage) the whole time and never saw \(c.shortName) there."
        }
        cards.append(Card(id: CardID.alibiBroken, kind: .deduction, title: "\(c.shortName.capitalizedFirst)'s alibi is false",
                          text: alibiFalse + " So where was \(c.shortName), really?",
                          source: "Your deduction", about: [c.id], proves: .opportunity, imagePrompt: nil))
        cards.append(Card(id: CardID.coldRoom, kind: .evidence, title: "An untouched room",
                          text: "In \(room(.quiet).name): the reading lamp is cold, the cushions are perfectly plumped and the newspapers are still folded. Nobody sat in here this evening.",
                          source: "Found in \(room(.quiet).name)", about: [c.id], proves: .opportunity,
                          imagePrompt: "a cold empty reading room at night with an unlit lamp, plumped cushions and folded newspapers"))
        cards.append(Card(id: CardID.notSeen, kind: .testimony, title: "\(w.shortName.capitalizedFirst) never saw \(c.shortName)",
                          text: "\(w.name) stood \(room(.gathering).vantage) \(inGathering) all evening, and never once saw \(c.name) there.",
                          source: w.name, about: [c.id], proves: .opportunity, imagePrompt: nil))
        cards.append(Card(id: CardID.redHerringLied, kind: .deduction, title: "\(rh.shortName.capitalizedFirst) is hiding something",
                          text: "\(rh.name) claims to have stayed \(inGathering), but \(w.name) saw \(rh.shortName) slip away.",
                          source: "Your deduction", about: [rh.id], proves: nil, imagePrompt: nil))

        let hiding = HidingPlaces.all.pick(using: &rng)
        let hidingRoom = room(hiding.role)
        let hidingPlace = hiding.text.replacingOccurrences(of: "{room}", with: hiding.role == .gathering || hiding.role == .quiet ? hidingRoom.inside : hidingRoom.name)
        cards.append(Card(id: CardID.hidingHint, kind: .evidence, title: "Something out of place",
                          text: "In \(hidingRoom.name): \(hiding.hint) Worth remembering.",
                          source: "Found in \(hidingRoom.name)", about: [], proves: nil, imagePrompt: nil))

        let title = "The Mystery of \(item.name.hasPrefix("the ") ? "the " + item.name.dropFirst(4) : item.name)"

        return Case(
            seed: seed, plot: plot, title: title, place: setting.place, occasion: setting.occasion, window: window,
            ownerName: owner.name, ownerSpecies: owner.species, ownerDescription: owner.description,
            ownerLook: owner.look, item: item.name, itemLook: item.look, coverLook: setting.look,
            rooms: rooms, suspects: suspects, trace: trace,
            motiveSummary: fill(motive.summary), motiveConfession: fill(motive.confession),
            secretSummary: secret.summary, secretConfession: fill(secret.confession), secretKeyword: secret.keyword,
            hidingPlace: hidingPlace, hidingRoom: hiding.role,
            gossipID: gossip.id,
            gossipLine: fill(motive.gossip),
            gossipKeys: motive.gossipKeys,
            cards: Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        )
    }
}
