import AppKit
import FoundationModels
import MysteryKit
import SwiftUI

/// One line in an interrogation transcript.
struct Entry: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case inspector, suspect, noted }
    var id = UUID()
    var kind: Kind
    var text: String
    var action = ""
    var cards: [String] = []
}

/// Everything needed to pick a game up where it was left.
struct SaveGame: Codable {
    var engine: Engine
    var transcripts: [Int: [Entry]]
    var roomNotes: [String: String]
    var briefing: String
    var focus: Focus?
    var finished: Bool
}

enum Focus: Hashable, Codable {
    case suspect(Int)
    case room(RoomRole)
}

@Observable @MainActor
final class GameModel {
    enum Phase { case title, briefing, investigating, finale }

    var phase: Phase = .title
    var engine: Engine?
    var focus: Focus?
    var transcripts: [Int: [Entry]] = [:]
    var roomNotes: [RoomRole: String] = [:]
    var briefing = ""
    /// The suspect currently thinking of an answer.
    var thinking: Int?
    /// The suspect whose reply is still being delivered (thinking or typing).
    var replying: Int?
    var isBusy: Bool { replying != nil }
    var searching: RoomRole?
    /// Cards that just arrived, to make them glow for a moment.
    var freshCards: Set<String> = []
    /// Entries that should type themselves out (only the newest ones).
    var animating: Set<UUID> = []
    var images: [Illustrator.Subject: URL] = [:]
    var painting: Set<Illustrator.Subject> = []
    var verdict: Verdict?
    var confession: Performance?
    var finale = ""
    var banner: String?
    var showingAccusation = false
    var titleArt: URL?
    var hasSave = false
    var savedTitle = ""
    var readAloud = UserDefaults.standard.bool(forKey: "readAloud") {
        didSet {
            UserDefaults.standard.set(readAloud, forKey: "readAloud")
            if !readAloud { speaker.stop() }
        }
    }

    private let speaker = Speaker()
    @ObservationIgnored private var decoded: [URL: NSImage] = [:]

    private var voice: Voice?
    private var illustrator: Illustrator?
    private var paintQueue: [Illustrator.Subject] = []
    private var isPainting = false
    private var waitingForForeground = false
    private var isWatchingPaintings = false

    /// The faceless helper that does the painting, so this process never holds Image Playground
    /// (which would lock command-line apps like apfel out of the on-device model). Nil when the
    /// game runs outside its bundle, in which case it paints in-process.
    private let painterApp: URL? = {
        let url = Bundle.main.bundleURL.appending(path: "Contents/Helpers/Pawprints Painter.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }()
    private static let painterID = "dev.apfel.pawprints.painter"

    var mystery: Case? { engine?.mystery }

    init() {
        if let save = Self.loadSave() {
            hasSave = !save.finished
            savedTitle = save.engine.mystery.title
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resumePainting() }
        }
    }

    // MARK: Availability

    var modelStatus: (ok: Bool, text: String) {
        switch SystemLanguageModel.default.availability {
        case .available: (true, "Apple Intelligence is ready")
        case .unavailable(.appleIntelligenceNotEnabled): (false, "Apple Intelligence is turned off in System Settings")
        case .unavailable(.modelNotReady): (false, "The on-device model is still downloading")
        case .unavailable(.deviceNotEligible): (false, "This Mac can't run Apple Intelligence")
        case .unavailable: (false, "Apple Intelligence is unavailable")
        }
    }

    // MARK: Starting and resuming

    func newCase(seed: UInt64? = nil) {
        let seed = seed ?? UInt64.random(in: 1...9999)
        let mystery = CaseGenerator.make(seed: seed)
        start(Engine(mystery: mystery))
        phase = .briefing
        focus = .room(.display)
        Task { await writeBriefing() }
        queuePaintings([.cover, .owner, .item] + mystery.suspects.map { .suspect($0.id) } + [.room(.display)])
        save()
    }

    func resume() {
        guard let save = Self.loadSave() else { return }
        start(save.engine)
        transcripts = save.transcripts
        roomNotes = Dictionary(uniqueKeysWithValues: save.roomNotes.compactMap { key, value in RoomRole(rawValue: key).map { ($0, value) } })
        briefing = save.briefing
        focus = save.focus ?? .room(.display)
        phase = .investigating
        let m = save.engine.mystery
        var wanted: [Illustrator.Subject] = [.cover, .owner, .item] + m.suspects.map { .suspect($0.id) }
        wanted += save.engine.searched.map { .room($0) }
        wanted += save.engine.known.filter { m.card($0).imagePrompt != nil }.map { .card($0) }
        queuePaintings(wanted)
    }

    private func start(_ engine: Engine) {
        self.engine = engine
        voice = Voice(mystery: engine.mystery)
        illustrator = Illustrator(mystery: engine.mystery)
        transcripts = [:]
        roomNotes = [:]
        briefing = ""
        freshCards = []
        animating = []
        verdict = nil
        confession = nil
        finale = ""
        banner = nil
        images = [:]
        paintQueue = []
        painting = []
        PaintJob.clearQueue()
        for subject in [Illustrator.Subject.cover, .owner, .item] + engine.mystery.suspects.map({ .suspect($0.id) }) {
            if let url = illustrator?.cached(subject) { images[subject] = url }
        }
    }

    func beginInvestigation() {
        withAnimation(.smooth(duration: 0.5)) { phase = .investigating }
    }

    func backToTitle() {
        save()
        if let save = Self.loadSave() {
            hasSave = !save.finished
            savedTitle = save.engine.mystery.title
        }
        withAnimation { phase = .title }
    }

    private func writeBriefing() async {
        guard let m = mystery, let voice else { return }
        let fallback = "\(m.item.capitalizedFirst) has vanished from \(m.room(.display).name) at \(m.place), \(m.window). \(m.ownerName), \(m.ownerDescription), has sent for Inspector Apfel. Four guests had the chance. One of them is lying."
        let text = await voice.narrate("""
            Write the opening of the case in three or four sentences. Facts: it is \(m.occasion) at \(m.place). \
            \(m.item.capitalizedFirst) (\(m.itemLook)) has vanished from \(m.room(.display).name) \(m.window). \
            \(m.ownerName), \(m.ownerDescription), has sent for Inspector Apfel, who has just arrived. \
            End by saying that one of the guests must be the thief.
            """, fallback: fallback)
        if mystery?.seed == m.seed {
            briefing = text
            if readAloud { speaker.say(text, as: nil) }
            save()
        }
    }

    // MARK: Interrogation

    func select(_ focus: Focus) {
        self.focus = focus
        if case .suspect(let id) = focus {
            Task { await voice?.prewarm(id) }
        }
        if case .room(let role) = focus {
            queuePaintings([.room(role)], first: true)
        }
        save()
    }

    /// Chips: questions the engine knows how to answer, phrased for this suspect.
    func suggestions(for suspectID: Int) -> [(label: String, topic: Topic)] {
        guard let m = mystery else { return [] }
        return [
            ("Where were you \(m.window)?", .whereabouts),
            ("Did you notice anything unusual?", .sawAnything),
            ("Tell me about yourself.", .aboutSelf),
            ("What do you make of \(m.item)?", .aboutItem),
            ("How do you know \(m.ownerName)?", .aboutOwner),
            ("You took it, didn't you?", .accuse),
        ]
    }

    func asked(_ suspectID: Int, _ topic: Topic) -> Bool {
        engine?.asked[suspectID]?.contains(topic) ?? false
    }

    func ask(_ suspectID: Int, text: String, topic: Topic? = nil) {
        guard !isBusy, let voice, engine != nil else { return }
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        // Naming evidence, or throwing a known fact at them, works like showing the card.
        if topic == nil, let engine,
           let cardID = engine.mentionedEvidence(in: question) ?? engine.confrontation(in: question, to: suspectID) {
            present(cardID, to: suspectID, saying: question)
            return
        }
        append(suspectID, Entry(kind: .inspector, text: question))
        thinking = suspectID
        replying = suspectID
        Task {
            let resolved: Topic
            if let topic { resolved = topic } else { resolved = await voice.understand(question, asking: suspectID) }
            guard var engine = self.engine else { return }
            let before = engine.known
            let directive = engine.ask(suspectID, resolved)
            self.engine = engine
            await deliver(directive, from: suspectID, question: question, before: before)
        }
    }

    func present(_ cardID: String, to suspectID: Int, saying words: String? = nil) {
        guard !isBusy, voice != nil, var engine, let card = mystery?.card(cardID) else { return }
        append(suspectID, Entry(kind: .inspector, text: words ?? "Shows: \u{201C}\(card.title)\u{201D}", cards: [cardID]))
        thinking = suspectID
        replying = suspectID
        let before = engine.known
        let directive = engine.present(cardID, to: suspectID)
        self.engine = engine
        Task { await deliver(directive, from: suspectID, question: "Explain this: \(card.text)", before: before) }
    }

    private func deliver(_ directive: Directive, from suspectID: Int, question: String, before: [String]) async {
        guard let voice else { return }
        replying = suspectID
        defer { replying = nil }
        for beat in [directive] + directive.then {
            thinking = suspectID
            let performance = await voice.perform(suspectID, said: question, directive: beat)
            let entry = Entry(kind: .suspect, text: performance.line, action: performance.action)
            animating.insert(entry.id)
            append(suspectID, entry)
            if readAloud { speaker.say(performance.line, as: mystery?.suspect(suspectID)) }
            thinking = nil
            // Let the line type itself out before the next beat starts.
            try? await Task.sleep(for: .milliseconds(min(2400, 300 + performance.line.count * 14)))
        }
        thinking = nil
        noteNewCards(since: before, in: suspectID)
        save()
    }

    private func noteNewCards(since before: [String], in suspectID: Int?) {
        guard let engine else { return }
        let new = engine.known.filter { !before.contains($0) }
        guard !new.isEmpty else { return }
        if let suspectID {
            append(suspectID, Entry(kind: .noted, text: "", cards: new))
        }
        withAnimation(.spring(duration: 0.5)) { freshCards.formUnion(new) }
        let paintable = new.filter { engine.mystery.card($0).imagePrompt != nil }
        queuePaintings(paintable.map { .card($0) })
        Task {
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.easeOut(duration: 1)) { freshCards.subtract(new) }
        }
    }

    private func append(_ suspectID: Int, _ entry: Entry) {
        withAnimation(.smooth(duration: 0.25)) {
            transcripts[suspectID, default: []].append(entry)
        }
    }

    // MARK: Searching

    func search(_ role: RoomRole) {
        guard searching == nil, var engine, let voice, let m = mystery else { return }
        let before = engine.known
        let found = engine.search(role)
        self.engine = engine
        searching = role
        let room = m.room(role)
        Task {
            let foundText = found.isEmpty
                ? "There is nothing out of place."
                : "The Inspector finds: " + found.map { $0.text }.joined(separator: " ")
            let fallback = "Inspector Apfel searches \(room.name) carefully. " + (found.isEmpty ? "Nothing seems out of place." : "Something catches the eye.")
            let note = await voice.narrate("""
                Describe Inspector Apfel searching \(room.name) (\(room.look)) in two or three sentences. \
                \(foundText) Do not name any people.
                """, fallback: fallback)
            withAnimation(.smooth) {
                roomNotes[role] = note
                searching = nil
            }
            noteNewCards(since: before, in: nil)
            save()
        }
    }

    // MARK: Accusation

    func accuse(_ suspectID: Int, evidence: [Proof: String]) {
        guard var engine else { return }
        let before = engine.known
        let verdict = engine.accuse(suspectID, evidence: evidence)
        self.engine = engine
        showingAccusation = false
        if verdict.correct {
            self.verdict = verdict
            withAnimation(.smooth(duration: 0.6)) { phase = .finale }
            Task { await writeFinale() }
        } else if let rebuttal = verdict.rebuttal {
            focus = .suspect(suspectID)
            append(suspectID, Entry(kind: .inspector, text: "It was you, \(verdict.accused.shortName). You took \(engine.mystery.item)!"))
            banner = "\(verdict.accused.shortName.capitalizedFirst) has an answer for that. A wrong accusation costs you a star."
            thinking = suspectID
            replying = suspectID
            Task {
                await deliver(rebuttal, from: suspectID, question: "You took it!", before: before)
                try? await Task.sleep(for: .seconds(5))
                withAnimation { banner = nil }
            }
        }
        save()
    }

    private func writeFinale() async {
        guard let engine, let voice else { return }
        let m = engine.mystery
        let c = m.culprit
        confession = await voice.perform(c.id, said: "It was you, \(c.shortName).", directive: engine.confession)
        if readAloud, let line = confession?.line { speaker.say(line, as: c) }
        let fallback = "And so \(m.item) was returned to \(m.ownerName), and \(m.place) breathed a sigh of relief. Inspector Apfel tipped a hat, and went home for a well-earned cup of tea."
        finale = await voice.narrate("""
            Write the happy ending of a cosy mystery in three sentences. Facts: Inspector Apfel unmasked \(c.name), \
            \(c.occupation), as the thief. \(m.item.capitalizedFirst) was found \(m.hidingPlace) and returned to \(m.ownerName). \
            Everyone at \(m.occasion) cheered. End with Inspector Apfel going home for a cup of tea.
            """, fallback: fallback)
        save(finished: true)
        hasSave = false
    }

    var hunch: String { engine?.hunch ?? "" }

    // MARK: Pictures

    func image(_ subject: Illustrator.Subject) -> NSImage? {
        guard let url = images[subject] else { return nil }
        if let cached = decoded[url] { return cached }
        let image = NSImage(contentsOf: url)
        decoded[url] = image
        return image
    }

    func queuePaintings(_ subjects: [Illustrator.Subject], first: Bool = false) {
        guard let illustrator else { return }
        for subject in subjects where images[subject] == nil && !paintQueue.contains(subject) && !painting.contains(subject) {
            if let url = illustrator.cached(subject) {
                images[subject] = url
            } else if painterApp != nil, let job = illustrator.job(for: subject) {
                if (try? job.enqueue(urgent: first)) != nil { painting.insert(subject) }
            } else if first {
                paintQueue.insert(subject, at: 0)
            } else {
                paintQueue.append(subject)
            }
        }
        if painterApp != nil {
            launchPainterIfNeeded()
            watchPaintings()
        } else {
            pumpPaintings()
        }
    }

    private func launchPainterIfNeeded() {
        guard let painterApp, !PaintJob.pending().isEmpty,
              NSRunningApplication.runningApplications(withBundleIdentifier: Self.painterID).isEmpty else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: painterApp, configuration: config)
    }

    /// Picks up pictures as the helper finishes them.
    private func watchPaintings() {
        guard !isWatchingPaintings else { return }
        isWatchingPaintings = true
        Task {
            while !painting.isEmpty {
                try? await Task.sleep(for: .milliseconds(400))
                guard let illustrator else { break }
                for subject in painting {
                    let url = illustrator.file(for: subject)
                    let failed = PaintJob.failureMarker(for: url)
                    if FileManager.default.fileExists(atPath: url.path) {
                        withAnimation(.easeIn(duration: 0.6)) { images[subject] = url }
                        painting.remove(subject)
                    } else if FileManager.default.fileExists(atPath: failed.path) {
                        try? FileManager.default.removeItem(at: failed)
                        painting.remove(subject)
                    }
                }
                // The helper may have quit just as new work arrived.
                launchPainterIfNeeded()
            }
            isWatchingPaintings = false
        }
    }

    private func resumePainting() {
        waitingForForeground = false
        pumpPaintings()
    }

    private func pumpPaintings() {
        guard !isPainting, !waitingForForeground, let illustrator else { return }
        guard !paintQueue.isEmpty else {
            Task { await illustrator.release() }
            return
        }
        let subject = paintQueue.removeFirst()
        isPainting = true
        painting.insert(subject)
        let seed = mystery?.seed
        Task {
            do {
                let url = try await illustrator.image(for: subject)
                if mystery?.seed == seed {
                    withAnimation(.easeIn(duration: 0.6)) { images[subject] = url }
                }
            } catch Illustrator.Failure.needsForeground {
                paintQueue.insert(subject, at: 0)
                waitingForForeground = true
            } catch {
                // Unavailable: leave the placeholder.
            }
            painting.remove(subject)
            isPainting = false
            pumpPaintings()
        }
    }

    func paintTitleArt() {
        let prompt = "a fox detective in a deerstalker hat holding a magnifying glass, in a cosy English village lane at dusk with glowing windows, storybook"
        let url = Illustrator.sharedFile(key: "title")
        if FileManager.default.fileExists(atPath: url.path) {
            titleArt = url
            return
        }
        guard painterApp != nil else {
            Task { titleArt = try? await Illustrator.shared(key: "title", prompt: prompt) }
            return
        }
        try? PaintJob(prompts: [prompt, "a fox detective with a magnifying glass, storybook"], output: url).enqueue(urgent: true)
        launchPainterIfNeeded()
        Task {
            for _ in 0..<120 where titleArt == nil {
                try? await Task.sleep(for: .milliseconds(500))
                if FileManager.default.fileExists(atPath: url.path) { titleArt = url }
            }
        }
    }

    // MARK: Saving

    private static var saveURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Pawprints", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appending(path: "save.json")
    }

    private static func loadSave() -> SaveGame? {
        guard let data = try? Data(contentsOf: saveURL) else { return nil }
        return try? JSONDecoder().decode(SaveGame.self, from: data)
    }

    func save(finished: Bool = false) {
        guard let engine else { return }
        let save = SaveGame(engine: engine, transcripts: transcripts,
                            roomNotes: Dictionary(uniqueKeysWithValues: roomNotes.map { ($0.key.rawValue, $0.value) }),
                            briefing: briefing, focus: focus, finished: finished || engine.solved)
        if let data = try? JSONEncoder().encode(save) {
            try? data.write(to: Self.saveURL, options: .atomic)
        }
    }
}
