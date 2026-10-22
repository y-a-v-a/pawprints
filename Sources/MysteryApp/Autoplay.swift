import MysteryKit
import SwiftUI

/// Plays the intended route through the real UI, slowly enough to watch (and screenshot).
@MainActor
enum Autoplay {
    static func run(_ game: GameModel, until phase: String?) async {
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func settle() async {
            while game.isBusy || game.searching != nil { await pause(0.3) }
            await pause(2.5)
        }
        if game.engine == nil { game.newCase(seed: 1) }
        guard let m = game.mystery else { return }

        while game.briefing.isEmpty { await pause(0.5) }
        await pause(6)
        if phase == "briefing" { return }
        game.beginInvestigation()
        await pause(1.5)

        game.select(.room(.display))
        game.search(.display)
        await settle()
        if phase == "room" { return }

        for s in m.suspects {
            game.select(.suspect(s.id))
            game.ask(s.id, text: "Where were you \(m.window)?", topic: .whereabouts)
            await settle()
        }
        switch m.plot {
        case .lonelyRoom: break
        case .coldRoom:
            game.select(.room(.quiet))
            game.search(.quiet)
            await settle()
        case .missingFromCrowd:
            game.select(.suspect(m.witness.id))
            game.ask(m.witness.id, text: "And what about \(m.culprit.name)?", topic: .aboutSuspect(m.culprit.id))
            await settle()
        }
        game.select(.suspect(m.witness.id))
        game.ask(m.witness.id, text: "Did you notice anything unusual?", topic: .sawAnything)
        await settle()
        if phase == "witness" { return }

        game.select(.suspect(m.redHerring.id))
        game.present(CardID.sighting, to: m.redHerring.id)
        await settle()
        await pause(2)
        if phase == "confession" { return }

        game.select(.suspect(m.gossipID))
        game.ask(m.gossipID, text: "What do you make of \(m.culprit.name)?", topic: .aboutSuspect(m.culprit.id))
        await settle()

        game.select(.room(.cloakroom))
        game.search(.cloakroom)
        await settle()
        if phase == "evidence" { return }

        game.select(.suspect(m.culprit.id))
        game.ask(m.culprit.id, text: "Where exactly were you, and who can vouch for it?")
        await settle()
        if phase == "culprit" { return }

        game.showingAccusation = true
        await pause(3)
        game.accuse(m.culprit.id, evidence: [.means: CardID.trace, .opportunity: CardID.alibiBroken, .motive: CardID.motiveDocument])
    }
}

/// Paints every prompt in the content tables and logs which ones Image Playground
/// refuses, so the tables can be fixed before a player ever meets a blank portrait.
@MainActor
enum PaintAll {
    static func run(file: String? = nil) async {
        var prompts: [(String, String)] = []
        if let file, let text = try? String(contentsOfFile: file, encoding: .utf8) {
            for line in text.split(separator: "\n") where line.contains("|") {
                let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
                prompts.append((parts[0], parts[1]))
            }
        } else {
        for (i, t) in Cast.all.enumerated() { prompts.append(("cast-\(i)-\(t.species)", "\(t.look), character portrait")) }
        for (i, s) in Settings.all.enumerated() {
            prompts.append(("cover-\(i)", "\(s.look), cosy storybook scene"))
            prompts.append(("owner-\(i)", "\(s.owner.look), friendly portrait"))
            for r in s.rooms { prompts.append(("room-\(i)-\(r.role.rawValue)", "\(r.look), cosy storybook interior, no people")) }
            for (j, item) in s.items.enumerated() { prompts.append(("item-\(i)-\(j)", item.look)) }
        }
        for t in Trace.allCases { prompts.append(("trace-\(t.rawValue)", t.illustration)) }
        for (i, m) in Motives.all.enumerated() { prompts.append(("motive-\(i)", m.documentLook)) }
        for (i, s) in Secrets.all.enumerated() { prompts.append(("secret-\(i)", s.evidenceLook)) }
        }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "Pawprints/paint-all")
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        var log = ""
        for (key, prompt) in prompts {
            let start = Date()
            do {
                _ = try await Illustrator.shared(key: "paint-all/\(key)", prompt: prompt, side: key.hasPrefix("icon") ? 1536 : 768)
                log += "ok    \(key) \(String(format: "%.1fs", Date().timeIntervalSince(start)))\n"
            } catch {
                log += "FAIL  \(key) \(error) :: \(prompt)\n"
            }
            try? log.write(to: caches.appending(path: "log.txt"), atomically: true, encoding: .utf8)
        }
        log += "done\n"
        try? log.write(to: caches.appending(path: "log.txt"), atomically: true, encoding: .utf8)
    }
}
