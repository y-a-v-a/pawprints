import Foundation
import MysteryKit

// Headless harness: plays a case against the real on-device model and prints the
// transcript, so the game can be checked end to end without clicking.
//
//   pawprints-cli case <seed>        print the generated case (spoilers!)
//   pawprints-cli play <seed>        play the intended route with the model
//   pawprints-cli ask <seed> <suspect#> "question"   ask one free-text question

setvbuf(stdout, nil, _IOLBF, 0) // flush per line, so a driver on a pipe sees replies as they come
let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    print("usage: pawprints-cli case|play|ask|repl <seed> [suspect] [question]")
    exit(0)
}
let seed = UInt64(args.dropFirst().first ?? "1") ?? 1
let mystery = CaseGenerator.make(seed: seed)

func show(_ m: Case) {
    print("\(m.title) (case \(m.seed), plot: \(m.plot.rawValue))")
    print("\(m.place), \(m.occasion), \(m.window). Owner: \(m.ownerName). Trace: \(m.trace.title)")
    for s in m.suspects {
        print("  #\(s.id) \(s.name), \(s.species), \(s.occupation) [\(s.role.rawValue)]")
    }
    print("  motive: \(m.motiveSummary)\n  secret: \(m.secretSummary) (\(m.secretRoom.name))")
}

func printCards(_ cards: [Card]) {
    for c in cards { print("      📌 [\(c.kind.label)] \(c.title): \(c.text)") }
}

@MainActor
func turn(_ engine: inout Engine, _ voice: Voice, _ suspectID: Int, _ question: String, topic: Topic? = nil) async {
    let s = engine.mystery.suspect(suspectID)
    let before = engine.known
    let t0 = Date()
    let resolved: Topic
    if let topic { resolved = topic } else { resolved = await voice.understand(question, asking: suspectID) }
    let d = engine.ask(suspectID, resolved)
    print("\n🕵️  → \(s.shortName): \(question)   [\(resolved)]")
    for beat in [d] + d.then {
        let p = await voice.perform(suspectID, said: question, directive: beat)
        let dt = Date().timeIntervalSince(t0)
        print("   \(s.name) (\(p.action)): \u{201C}\(p.line)\u{201D}\(p.isFallback ? "  [fallback]" : "")  (\(String(format: "%.1fs", dt)), composure \(engine.composure[suspectID]!))")
    }
    printCards(engine.known.filter { !before.contains($0) }.map(engine.mystery.card))
}

@MainActor
func present(_ engine: inout Engine, _ voice: Voice, _ cardID: String, to suspectID: Int) async {
    let s = engine.mystery.suspect(suspectID)
    let card = engine.mystery.card(cardID)
    let before = engine.known
    let d = engine.present(cardID, to: suspectID)
    print("\n🕵️  shows \(s.shortName) \u{2018}\(card.title)\u{2019}")
    for beat in [d] + d.then {
        let p = await voice.perform(suspectID, said: "Explain this: \(card.text)", directive: beat)
        print("   \(s.name) (\(p.action)): \u{201C}\(p.line)\u{201D}\(p.isFallback ? "  [fallback]" : "")  (composure \(engine.composure[suspectID]!))")
    }
    printCards(engine.known.filter { !before.contains($0) }.map(engine.mystery.card))
}

@MainActor
func play() async {
    var e = Engine(mystery: mystery)
    let m = mystery
    let voice = Voice(mystery: m)
    show(m)

    let intro = await voice.narrate("""
        Write the opening of the case. Facts: at \(m.place), during \(m.occasion), \(m.item) vanished from \
        \(m.room(.display).name) \(m.window). \(m.ownerName), \(m.ownerDescription), has sent for Inspector Apfel.
        """, fallback: "")
    print("\n📖 \(intro)")

    let found = e.search(.display)
    print("\n🔎 Searched \(m.room(.display).name)")
    printCards(found)

    for s in m.suspects {
        await turn(&e, voice, s.id, "Where were you \(m.window)?")
    }
    await turn(&e, voice, m.witness.id, "Did you notice anything unusual tonight?")
    await turn(&e, voice, m.redHerring.id, "You took it, didn't you?")
    await present(&e, voice, CardID.sighting, to: m.redHerring.id)
    switch m.plot {
    case .lonelyRoom: break
    case .coldRoom:
        print("\n🔎 Searched \(m.room(.quiet).name)")
        printCards(e.search(.quiet))
    case .missingFromCrowd:
        await turn(&e, voice, m.witness.id, "And what about \(m.culprit.name)?", topic: .aboutSuspect(m.culprit.id))
    }
    await turn(&e, voice, m.gossipID, "What do you make of \(m.culprit.shortName.replacingOccurrences(of: "the ", with: ""))?")
    await present(&e, voice, CardID.alibiBroken, to: m.culprit.id)
    let more = e.search(.cloakroom)
    print("\n🔎 Searched \(m.room(.cloakroom).name)")
    printCards(more)
    print("\n💡 Hunch: \(e.hunch)")

    let v = e.accuse(m.culprit.id, evidence: [.means: CardID.trace, .opportunity: CardID.alibiBroken, .motive: CardID.motiveDocument])
    print("\n⚖️  Accused \(v.accused.name): correct=\(v.correct) stars=\(v.stars) proven=\(v.proven.map(\.label).sorted())")
    let confession = await voice.perform(m.culprit.id, said: "It was you.", directive: e.confession)
    print("   \(m.culprit.name) (\(confession.action)): \u{201C}\(confession.line)\u{201D}\(confession.isFallback ? "  [fallback]" : "")")
    print("   questions asked: \(e.questionsAsked)")
}

switch command {
case "case":
    show(mystery)
case "play":
    await play()
case "ask":
    var e = Engine(mystery: mystery)
    let voice = Voice(mystery: mystery)
    let who = Int(args.dropFirst(2).first ?? "0") ?? 0
    let question = args.dropFirst(3).joined(separator: " ")
    await turn(&e, voice, who, question)
case "repl":
    var e = Engine(mystery: mystery)
    let voice = Voice(mystery: mystery)
    print("\(mystery.title) (case \(mystery.seed))")
    print("\(mystery.item.capitalizedFirst) has vanished from \(mystery.room(.display).name) at \(mystery.place), during \(mystery.occasion), \(mystery.window). \(mystery.ownerName.capitalizedFirst) has sent for you.")
    print("Suspects:")
    for s in mystery.suspects { print("  #\(s.id) \(s.name), \(s.species), \(s.occupation)") }
    print("  rooms: " + mystery.rooms.map { "\($0.id.rawValue) (\($0.name))" }.joined(separator: ", "))
    while let raw = readLine() {
        let parts = raw.split(separator: " ", maxSplits: 2).map(String.init)
        guard let verb = parts.first else { continue }
        switch verb {
        case "ask" where parts.count == 3:
            if let id = Int(parts[1]) {
                if let card = e.mentionedEvidence(in: parts[2]) ?? e.confrontation(in: parts[2], to: id) {
                    await present(&e, voice, card, to: id)
                } else {
                    await turn(&e, voice, id, parts[2])
                }
            }
        case "show" where parts.count == 3:
            if let id = Int(parts[2]), e.knows(parts[1]) { await present(&e, voice, parts[1], to: id) } else { print("  (you don't have that card)") }
        case "search" where parts.count == 2:
            if let role = RoomRole(rawValue: parts[1]) {
                let found = e.search(role)
                print("\n🔎 Searched \(mystery.room(role).name)\(found.isEmpty ? ": nothing" : "")")
                printCards(found)
            }
        case "cards":
            if e.knownCards.isEmpty { print("  (notebook empty)") }
            for c in e.knownCards { print("  \(c.id): [\(c.kind.label)] \(c.title)") }
        case "hunch":
            print("💡 \(e.hunch)")
        case "accuse" where parts.count >= 2:
            let rest = raw.split(separator: " ").dropFirst(2)
            var evidence: [Proof: String] = [:]
            for pair in rest {
                let kv = pair.split(separator: "=").map(String.init)
                if kv.count == 2, let p = Proof(rawValue: kv[0]) { evidence[p] = kv[1] }
            }
            if let id = Int(parts[1]) {
                let v = e.accuse(id, evidence: evidence)
                print("\n⚖️  Accused \(v.accused.name): correct=\(v.correct) stars=\(v.stars) proven=\(v.proven.map(\.label).sorted())")
                if let r = v.rebuttal {
                    let p = await voice.perform(id, said: "You took it!", directive: r)
                    print("   \(v.accused.name) (\(p.action)): \u{201C}\(p.line)\u{201D}")
                } else {
                    let p = await voice.perform(id, said: "It was you.", directive: e.confession)
                    print("   \(v.accused.name) (\(p.action)): \u{201C}\(p.line)\u{201D}")
                }
            }
        default:
            print("  (unknown command: \(raw))")
        }
    }
default:
    print("usage: pawprints-cli case|play|ask|repl <seed> [suspect] [question]")
}
