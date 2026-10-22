import Foundation
import Testing
@testable import MysteryKit

@Suite struct CaseGeneratorTests {
    @Test func sameSeedSameCase() {
        let a = CaseGenerator.make(seed: 42)
        let b = CaseGenerator.make(seed: 42)
        #expect(a.title == b.title)
        #expect(a.plot == b.plot)
        #expect(a.suspects.map(\.name) == b.suspects.map(\.name))
        #expect(a.culprit.name == b.culprit.name)
    }

    @Test(arguments: 0..<400)
    func everyCaseIsWellFormed(seed: UInt64) {
        let m = CaseGenerator.make(seed: seed)
        #expect(m.suspects.count == 4)
        #expect(Set(m.suspects.map(\.species)).count == 4)
        #expect(!m.suspects.contains { $0.species == m.ownerSpecies })
        #expect(Set(m.suspects.map(\.role)).count == 4)
        // The trace points at exactly the culprit and the red herring.
        let traced = Set(m.suspects.filter { $0.traces.contains(m.trace) }.map(\.role))
        #expect(traced == [.culprit, .redHerring])
        #expect(m.gossipID == m.witness.id || m.gossipID == m.loner.id)
        if m.plot == .missingFromCrowd { #expect(m.gossipID == m.loner.id) }
        #expect(m.secretRoom.id != .quiet && m.secretRoom.id != .display && m.secretRoom.id != .gathering)
        // Nobody but the culprit (and the red herring, who lies) is somewhere other than they say.
        #expect(m.loner.claimedRoom == m.loner.actualRoom)
        #expect(m.loner.actualRoom != m.redHerring.actualRoom)
        if m.plot == .coldRoom { #expect(!m.suspects.contains { $0.actualRoom == .quiet }) }
        for card in m.cards.values {
            #expect(!card.text.contains("{"), "unfilled placeholder in \(card.id): \(card.text)")
            #expect(!card.text.contains("  "), "double space in \(card.id): \(card.text)")
        }
    }

    @Test func casesVary() {
        let cases = (0..<60).map { CaseGenerator.make(seed: $0) }
        #expect(Set(cases.map(\.title)).count >= 6)
        #expect(Set(cases.map(\.culprit.name)).count >= 8)
        #expect(Set(cases.map(\.plot)) == Set(Plot.allCases))
    }
}

@Suite struct EngineTests {
    /// Plays the intended route for the case's plot and checks the culprit can be proven
    /// on all three counts, by both routes to "opportunity".
    @Test(arguments: 0..<150)
    func intendedRouteSolvesTheCase(seed: UInt64) {
        var e = Engine(mystery: CaseGenerator.make(seed: seed))
        let m = e.mystery
        _ = e.search(.display)
        for s in m.suspects { _ = e.ask(s.id, .whereabouts) }
        switch m.plot {
        case .lonelyRoom: break
        case .coldRoom:
            #expect(!e.knows(CardID.alibiBroken))
            _ = e.search(.quiet)
        case .missingFromCrowd:
            #expect(!e.knows(CardID.alibiBroken))
            let d = e.ask(m.witness.id, .aboutSuspect(m.culprit.id))
            #expect(d.reveals == [CardID.notSeen])
        }
        #expect(e.knows(CardID.alibiBroken))
        _ = e.ask(m.witness.id, .sawAnything)
        #expect(e.knows(CardID.sighting))
        #expect(e.knows(CardID.redHerringLied))
        _ = e.present(CardID.sighting, to: m.redHerring.id)
        #expect(e.confessed)
        #expect(e.knows(CardID.redHerringSaw))
        _ = e.search(.cloakroom)
        #expect(e.knows(CardID.motiveDocument))

        // The red herring only glimpsed a figure; the plot's own clue is what proves opportunity.
        let plotClue = [Plot.lonelyRoom: CardID.alibiBroken, .coldRoom: CardID.coldRoom, .missingFromCrowd: CardID.notSeen][m.plot]!
        var weak = e
        #expect(weak.accuse(m.culprit.id, evidence: [.opportunity: CardID.redHerringSaw]).proven.isEmpty)
        for opportunity in [CardID.alibiBroken, plotClue] {
            var attempt = e
            let verdict = attempt.accuse(m.culprit.id, evidence: [
                .means: CardID.trace, .opportunity: opportunity, .motive: CardID.motiveDocument,
            ])
            #expect(verdict.correct)
            #expect(verdict.proven == Set(Proof.allCases))
            #expect(verdict.stars == 3)
            #expect(attempt.solved)
            #expect(attempt.hunch.contains("Case closed"))
        }
    }

    @Test(arguments: 0..<60)
    func searchingTheHidingPlaceFindsAHint(seed: UInt64) {
        var e = Engine(mystery: CaseGenerator.make(seed: seed))
        let found = e.search(e.mystery.hidingRoom)
        #expect(found.contains { $0.id == CardID.hidingHint })
    }

    @Test func accusingTheRedHerringMakesThemConfessAndCostsAStar() {
        var e = Engine(mystery: CaseGenerator.make(seed: 7))
        let m = e.mystery
        let v = e.accuse(m.redHerring.id, evidence: [.means: CardID.trace])
        #expect(!v.correct)
        #expect(v.rebuttal != nil)
        #expect(e.confessed)
        #expect(e.knows(CardID.redHerringSaw))
        #expect(!e.solved)
        let right = e.accuse(m.culprit.id, evidence: [
            .means: CardID.trace, .opportunity: CardID.alibiBroken, .motive: CardID.gossip,
        ])
        #expect(right.correct)
        #expect(right.stars == 2)
    }

    @Test func showingTheTraceRattlesButDoesNotBreakTheRedHerring() {
        var e = Engine(mystery: CaseGenerator.make(seed: 12))
        let rh = e.mystery.redHerring.id
        _ = e.search(.display)
        _ = e.present(CardID.trace, to: rh)
        #expect(!e.confessed)
        #expect(e.composure[rh]! < 8)
    }

    @Test func culpritHasADifferentAnswerForEachKindOfCard() {
        var e = Engine(mystery: CaseGenerator.make(seed: 31))
        let c = e.mystery.culprit.id
        let alibi = e.present(CardID.alibiBroken, to: c).script
        let seen = e.present(CardID.redHerringSaw, to: c).script
        let motive = e.present(CardID.motiveDocument, to: c).script
        #expect(Set([alibi, seen, motive]).count == 3)
    }

    @Test func everyAnswerHasAScriptToFallBackOn() {
        var e = Engine(mystery: CaseGenerator.make(seed: 77))
        let m = e.mystery
        let topics: [Topic] = [.whereabouts, .sawAnything, .aboutOwner, .aboutItem, .aboutSelf, .smallTalk,
                               .aboutRoom(.display), .aboutRoom(.kitchen)] + m.suspects.map { .aboutSuspect($0.id) }
        for s in m.suspects {
            for topic in topics {
                let d = e.ask(s.id, topic)
                #expect(d.script != nil || d.cannedLine != nil, "no script for \(s.role) / \(topic)")
                #expect(!(d.script ?? "").contains("I has"))
            }
        }
    }

    @Test func theFigureIsAClueNotAnAnswer() {
        var e = Engine(mystery: CaseGenerator.make(seed: 14))
        let m = e.mystery
        _ = e.search(.display)
        for s in m.suspects { _ = e.ask(s.id, .whereabouts) }
        _ = e.present(CardID.sighting, to: m.redHerring.id)
        let card = m.card(CardID.redHerringSaw)
        #expect(e.knows(card.id))
        #expect(!card.text.contains(m.culprit.name))
        #expect(card.proves == nil)
        let heading = m.plot == .missingFromCrowd ? m.room(.gathering) : m.room(.quiet)
        #expect(card.text.contains(heading.name))
        // Until the plot's clue is found, the hunch points at the room the figure was heading for.
        if m.plot != .lonelyRoom { #expect(e.hunch.contains(heading.name), "\(e.hunch)") }
    }

    @Test func confrontingInPlainEnglishShowsTheCard() {
        var e = Engine(mystery: CaseGenerator.make(seed: 31))
        let m = e.mystery
        for s in m.suspects { _ = e.ask(s.id, .whereabouts) }
        _ = e.ask(m.witness.id, .sawAnything)
        let witness = m.witness.shortName.replacingOccurrences(of: "the ", with: "")
        #expect(e.confrontation(in: "\(witness) saw you slip away. Explain yourself.", to: m.redHerring.id) == CardID.sighting)
        #expect(e.confrontation(in: "Lovely scones.", to: m.redHerring.id) == nil)
    }

    @Test func accusingNeverCalmsARattledCulprit() {
        var e = Engine(mystery: CaseGenerator.make(seed: 6161))
        let c = e.mystery.culprit.id
        _ = e.present(CardID.alibiBroken, to: c)
        _ = e.present(CardID.motiveDocument, to: c)
        let before = e.composure[c]!
        _ = e.ask(c, .accuse)
        #expect(e.composure[c]! <= before)
    }

    @Test func gossipComesFromTheRightPerson() {
        var e = Engine(mystery: CaseGenerator.make(seed: 11))
        let m = e.mystery
        guard !(m.plot == .missingFromCrowd && m.gossipID == m.witness.id) else { return }
        let d = e.ask(m.gossipID, .aboutSuspect(m.culprit.id))
        #expect(d.reveals == [CardID.gossip])
        #expect(e.knows(CardID.gossip))
    }

    @Test func pressingTheRedHerringEventuallyBreaksThem() {
        var e = Engine(mystery: CaseGenerator.make(seed: 3))
        let rh = e.mystery.redHerring.id
        _ = e.ask(rh, .accuse)
        _ = e.ask(rh, .accuse)
        #expect(e.confessed)
    }

    @Test func culpritNeverConfessesToPressure() {
        var e = Engine(mystery: CaseGenerator.make(seed: 5))
        let c = e.mystery.culprit.id
        for _ in 0..<10 { _ = e.ask(c, .accuse) }
        #expect(e.composure[c]! >= 4)
        #expect(e.knownCards.allSatisfy { $0.kind != .confession || $0.about != [c] })
    }

    @Test func deflectionsDontRepeatBackToBack() {
        var e = Engine(mystery: CaseGenerator.make(seed: 8))
        let id = e.mystery.suspects[0].id
        let lines = (0..<4).map { _ in e.ask(id, .offLimits).cannedLine }
        for (a, b) in zip(lines, lines.dropFirst()) { #expect(a != b) }
    }

    @Test func namingEvidenceFindsTheCard() {
        var e = Engine(mystery: CaseGenerator.make(seed: 9))
        _ = e.search(.display)
        let word = e.mystery.card(CardID.trace).title.lowercased().split(separator: " ").last!
        #expect(e.mentionedEvidence(in: "Why was there \(word) by the cabinet?") == CardID.trace)
        #expect(e.mentionedEvidence(in: "Lovely weather tonight.") == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        var e = Engine(mystery: CaseGenerator.make(seed: 21))
        _ = e.search(.display)
        _ = e.ask(e.mystery.witness.id, .aboutSuspect(e.mystery.redHerring.id))
        let data = try JSONEncoder().encode(e)
        let back = try JSONDecoder().decode(Engine.self, from: data)
        #expect(back.known == e.known)
        #expect(back.asked == e.asked)
        #expect(back.mystery.title == e.mystery.title)
    }
}

@Suite struct ClassifierTests {
    /// Thornbury Hall cases (the Study is the scene) with an owl among the suspects.
    func voice(where match: (Case) -> Bool) -> (Voice, Case) {
        let m = (0..<2000).lazy.map { CaseGenerator.make(seed: $0) }.first(where: match)!
        return (Voice(mystery: m), m)
    }

    @Test func innocentWordsAreNotViolence() async {
        let (v, m) = voice { $0.place == "Thornbury Hall" }
        for line in ["Was there any punch left at the party?", "You're a skilled cook, Mrs Otterly.",
                     "Did the fireworks shoot up over the Study?"] {
            let topic = await v.quickTopic(line, mentioned: nil, room: await v.mentionedRoom(in: line))
            #expect(topic != .offLimits, "\(line)")
            _ = m
        }
    }

    @Test func innocentConfessionsAreNotAccusations() async {
        let (v, _) = voice { _ in true }
        for line in ["I confess I adore your scones.", "You took your time answering the door.",
                     "What's your opinion of the weather?"] {
            #expect(await v.quickTopic(line, mentioned: nil, room: nil) != .accuse, "\(line)")
        }
        #expect(await v.quickTopic("You took it, didn't you?", mentioned: nil, room: nil) == .accuse)
    }

    @Test func textingShorthandAndRooms() async {
        let (v, m) = voice { $0.place == "Thornbury Hall" && $0.item.contains("Tiara") }
        #expect(await v.quickTopic("did u see anybody go into the study tonight", mentioned: nil, room: .display) == .sawAnything)
        #expect(await v.quickTopic("where were u when it happened", mentioned: nil, room: nil) == .whereabouts)
        let study = await v.mentionedRoom(in: "what were you doing in the study?")
        #expect(study == .display)
        #expect(await v.quickTopic("what were you doing in the study?", mentioned: nil, room: study) == .aboutRoom(.display))
        #expect(await v.quickTopic("Where's the tiara now?", mentioned: nil, room: nil) == .aboutItem)
        #expect(await v.mentionedRoom(in: "Would you like a room with a view?") == nil)
        _ = m
    }

    @Test func rudenessAndOccupations() async {
        let (v, m) = voice { $0.suspects.contains { $0.species == "fox" } }
        let fox = m.suspects.first { $0.species == "fox" }!
        let other = m.suspects.first { $0.id != fox.id }!
        #expect(await v.quickTopic("Shut up you old fool and tell me the truth", mentioned: nil, room: nil, asking: other.id) == .offLimits)
        #expect(await v.quickTopic("Your a liar and a thief doctor", mentioned: nil, room: nil, asking: fox.id) == .accuse)
        #expect(await v.quickTopic("What were you up to when it went missing?", mentioned: nil, room: nil) == .whereabouts)
        #expect(await v.mentionedSuspect(in: "What's your opinion of the doctor?", excluding: other.id) == fox.id)
        #expect(await v.quickTopic("Did you see the fox anywhere?", mentioned: fox.id, room: nil, asking: other.id) == .aboutSuspect(fox.id))
    }

    @Test func speciesNamesFindSuspects() async {
        let (v, m) = voice { $0.suspects.contains { $0.species == "owl" } }
        let owl = m.suspects.first { $0.species == "owl" }!
        let asker = m.suspects.first { $0.id != owl.id }!
        #expect(await v.mentionedSuspect(in: "What do you make of the owl?", excluding: asker.id) == owl.id)
    }
}
