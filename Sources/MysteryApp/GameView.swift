import MysteryKit
import SwiftUI

struct GameView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        @Bindable var game = game
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 262)
                .background(Palette.paperDeep)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            ZStack(alignment: .top) {
                switch game.focus {
                case .suspect(let id):
                    InterrogationView(suspectID: id).id(id)
                case .room(let role):
                    RoomView(role: role).id(role)
                case nil:
                    RoomView(role: .display)
                }
                if let banner = game.banner {
                    Label(banner, systemImage: "exclamationmark.bubble")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .foregroundStyle(Palette.accentInk)
                        .background(Palette.accent, in: .capsule)
                        .padding(.top, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.smooth, value: game.banner)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            NotebookView()
                .frame(width: 330)
                .background(Palette.paperDeep)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $game.showingAccusation) {
            AccusationView()
                .environment(game)
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(GameModel.self) private var game
    @State private var showHunch = false

    var body: some View {
        if let m = game.mystery, let engine = game.engine {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.title)
                        .font(.serif(17, .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(m.place.capitalizedFirst) · \(m.occasion)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 18)
                .padding(.top, 44)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Suspects").padding(.horizontal, 18).padding(.bottom, 4)
                        ForEach(m.suspects) { s in
                            SidebarRow(isSelected: game.focus == .suspect(s.id)) {
                                game.select(.suspect(s.id))
                            } content: {
                                HStack(spacing: 11) {
                                    Portrait(suspect: s, size: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.name)
                                            .font(.serif(13, .semibold))
                                            .lineLimit(1)
                                        Text(s.occupation.capitalizedFirst)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Palette.inkSoft)
                                            .lineLimit(1)
                                        ComposureMeter(value: engine.composure[s.id] ?? 8)
                                            .scaleEffect(0.8, anchor: .leading)
                                    }
                                    if game.thinking == s.id {
                                        Spacer(minLength: 0)
                                        ProgressView().controlSize(.mini)
                                    }
                                }
                            }
                        }

                        SectionLabel(text: "Places").padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 4)
                        ForEach(m.rooms) { room in
                            SidebarRow(isSelected: game.focus == .room(room.id)) {
                                game.select(.room(room.id))
                            } content: {
                                HStack(spacing: 10) {
                                    Image(systemName: room.id.symbol)
                                        .font(.system(size: 13))
                                        .foregroundStyle(room.id == .display ? Palette.accent : Palette.inkSoft)
                                        .frame(width: 22)
                                    Text(room.title)
                                        .font(.system(size: 13))
                                    if room.id == .display {
                                        Text("scene")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(Palette.accent)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.5)))
                                    }
                                    Spacer()
                                    if engine.searched.contains(room.id) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Palette.moss)
                                    } else if game.searching == room.id {
                                        ProgressView().controlSize(.mini)
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if showHunch {
                        Text(game.hunch)
                            .font(.serif(13).italic())
                            .foregroundStyle(Palette.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .paperCard(radius: 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    HStack {
                        Button {
                            withAnimation(.smooth) { showHunch.toggle() }
                        } label: {
                            Label(showHunch ? "Hide hunch" : "A hunch", systemImage: "lightbulb")
                        }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        Spacer()
                        Button {
                            game.readAloud.toggle()
                        } label: {
                            Image(systemName: game.readAloud ? "speaker.wave.2.fill" : "speaker.slash")
                                .frame(width: 16)
                        }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .help(game.readAloud ? "Stop reading lines aloud" : "Read lines aloud, in character")
                    }
                    Button {
                        game.showingAccusation = true
                    } label: {
                        Label("Name the thief\u{2026}", systemImage: "hand.point.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InkButtonStyle())
                    HStack {
                        Text(verbatim: "Case \(m.seed) · \(engine.questionsAsked) question\(engine.questionsAsked == 1 ? "" : "s")")
                        Spacer()
                        Button {
                            game.backToTitle()
                        } label: {
                            Image(systemName: "house")
                        }
                        .buttonStyle(.plain)
                        .help("Back to the title screen (your game is saved)")
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.inkFaint)
                }
                .padding(16)
            }
            .onChange(of: engine.known.count) { showHunch = false }
        }
    }
}

private struct SidebarRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Palette.card : (hovering ? Palette.card.opacity(0.5) : .clear), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Palette.hairline : .clear))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
    }
}

// MARK: - Interrogation

struct InterrogationView: View {
    @Environment(GameModel.self) private var game
    let suspectID: Int
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        if let m = game.mystery, let engine = game.engine {
            let s = m.suspect(suspectID)
            let entries = game.transcripts[suspectID] ?? []
            VStack(spacing: 0) {
                header(s, composure: engine.composure[suspectID] ?? 8)
                Rectangle().fill(Palette.hairline).frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if entries.isEmpty {
                                Text("\(s.shortName.capitalizedFirst) waits for your first question.")
                                    .font(.serif(14).italic())
                                    .foregroundStyle(Palette.inkFaint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            }
                            ForEach(entries) { entry in
                                EntryView(entry: entry, suspect: s)
                                    .id(entry.id)
                            }
                            if game.thinking == suspectID {
                                ThinkingBubble(name: s.shortName.capitalizedFirst)
                                    .id("thinking")
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)
                    }
                    .onChange(of: entries.count) { withAnimation(.smooth) { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: game.thinking) { withAnimation(.smooth) { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                Rectangle().fill(Palette.hairline).frame(height: 1)
                composer(s, mystery: m)
            }
        }
    }

    private func header(_ s: Suspect, composure: Int) -> some View {
        HStack(alignment: .center, spacing: 20) {
            Portrait(suspect: s, size: 112)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(s.name)
                    .font(.serif(26, .bold))
                Text("\(s.occupation.capitalizedFirst). \(s.firstPersonRelationship)")
                    .font(.serif(14))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text("Composure")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                    ComposureMeter(value: composure)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 18)
    }

    private func composer(_ s: Suspect, mystery m: Case) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 7) {
                ForEach(Array(game.suggestions(for: suspectID).enumerated()), id: \.offset) { _, chip in
                    ChipButton(label: chip.label, done: game.asked(suspectID, chip.topic)) {
                        game.ask(suspectID, text: chip.label, topic: chip.topic)
                    }
                }
                Menu {
                    ForEach(m.suspects.filter { $0.id != suspectID }) { other in
                        Button("What do you make of \(other.name)?") {
                            game.ask(suspectID, text: "What do you make of \(other.name)?", topic: .aboutSuspect(other.id))
                        }
                    }
                } label: {
                    Text("Ask about someone\u{2026}")
                }
                .menuStyle(.button)
                .buttonStyle(ChipStyle(done: false))
                .fixedSize()
            }
            .disabled(game.isBusy)

            HStack(spacing: 10) {
                TextField("Ask \(s.shortName) anything\u{2026}", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.serif(15))
                    .focused($fieldFocused)
                    .onSubmit(send)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.cardRaised, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(fieldFocused ? Palette.accent.opacity(0.6) : Palette.hairline))
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(InkButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || game.isBusy)
                .keyboardShortcut(.return, modifiers: [])
                Menu {
                    let cards = game.engine?.knownCards ?? []
                    if cards.isEmpty {
                        Text("Your notebook is empty")
                    }
                    ForEach(cards) { card in
                        Button(card.title) { game.present(card.id, to: suspectID) }
                    }
                } label: {
                    Label("Show evidence", systemImage: "rectangle.portrait.on.rectangle.portrait")
                }
                .menuStyle(.button)
                .buttonStyle(InkButtonStyle(prominent: false))
                .fixedSize()
                .disabled(game.isBusy)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Palette.paper)
    }

    private func send() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty, !game.isBusy else { return }
        draft = ""
        game.ask(suspectID, text: text)
    }
}

private struct ChipButton: View {
    let label: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if done { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                Text(label)
            }
        }
        .buttonStyle(ChipStyle(done: done))
    }
}

private struct ChipStyle: ButtonStyle {
    let done: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(done ? Palette.inkFaint : Palette.ink)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(configuration.isPressed ? Palette.paperDeep : Palette.card, in: .capsule)
            .overlay(Capsule().strokeBorder(Palette.hairline))
            .contentShape(.capsule)
    }
}

private struct EntryView: View {
    @Environment(GameModel.self) private var game
    let entry: Entry
    let suspect: Suspect

    var body: some View {
        switch entry.kind {
        case .inspector:
            HStack {
                Spacer(minLength: 80)
                Text(entry.text)
                    .font(.serif(14.5))
                    .foregroundStyle(Palette.accentInk)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Palette.inspector, in: .rect(cornerRadius: 14))
                    .textSelection(.enabled)
            }
        case .suspect:
            HStack(alignment: .top, spacing: 12) {
                Portrait(suspect: suspect, size: 34)
                VStack(alignment: .leading, spacing: 5) {
                    if !entry.action.isEmpty {
                        Text("\(suspect.shortName.capitalizedFirst) \(entry.action)")
                            .font(.serif(12).italic())
                            .foregroundStyle(Palette.inkFaint)
                    }
                    TypewriterText(text: "\u{201C}\(entry.text)\u{201D}", animate: game.animating.contains(entry.id), font: .serif(16)) {
                        game.animating.remove(entry.id)
                    }
                    .lineSpacing(3)
                }
                .padding(.horizontal, 15).padding(.vertical, 11)
                .paperCard(raised: true, radius: 14)
                Spacer(minLength: 60)
            }
        case .noted:
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.list.clipboard")
                Text("Noted: " + entry.cards.compactMap { game.mystery?.card($0).title }.joined(separator: " · "))
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .padding(.leading, 46)
        }
    }
}

private struct ThinkingBubble: View {
    let name: String
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Palette.inkFaint)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1 : 0.3)
                }
            }
            Text("\(name) considers this\u{2026}")
                .font(.serif(12.5).italic())
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.leading, 46)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Rooms

struct RoomView: View {
    @Environment(GameModel.self) private var game
    let role: RoomRole

    var body: some View {
        if let m = game.mystery, let engine = game.engine {
            let room = m.room(role)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Illustration(subject: .room(role), placeholder: role.symbol, cornerRadius: 16)
                        .frame(height: 340)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        if role == .display {
                            Text("THE SCENE OF THE CRIME")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(Palette.accent)
                        }
                        Text(room.title)
                            .font(.serif(30, .bold))
                    }
                    if let note = game.roomNotes[role] {
                        TypewriterText(text: note, animate: game.searching == nil && game.freshCards.contains { m.card($0).source.hasSuffix(room.name) } , font: .serif(16), speed: 140)
                            .lineSpacing(4)
                        let found = engine.knownCards.filter { $0.source == "Found in \(room.name)" }
                        if found.isEmpty {
                            Label("Nothing of interest here.", systemImage: "eye.slash")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Palette.inkFaint)
                        } else {
                            SectionLabel(text: "Found here")
                            ForEach(found) { card in
                                ClueCard(card: card)
                            }
                        }
                    } else if game.searching == role {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Inspector Apfel searches \(room.name)\u{2026}")
                                .font(.serif(15).italic())
                                .foregroundStyle(Palette.inkSoft)
                        }
                    } else {
                        Text(role == .display
                             ? "This is where \(m.item) was last seen. Look closely."
                             : "Nobody has searched \(room.name) yet.")
                            .font(.serif(15))
                            .foregroundStyle(Palette.inkSoft)
                        Button {
                            game.search(role)
                        } label: {
                            Label("Search \(room.name)", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(game.searching != nil)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 40)
                .padding(.bottom, 30)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Notebook

struct NotebookView: View {
    @Environment(GameModel.self) private var game

    private let order: [(CardKind, String)] = [
        (.deduction, "Deductions"), (.evidence, "Evidence"), (.testimony, "Testimony"),
        (.confession, "Confessions"), (.claim, "Statements"),
    ]

    var body: some View {
        let cards = game.engine?.knownCards ?? []
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notebook")
                    .font(.serif(22, .bold))
                Spacer()
                Text("\(cards.count) \(cards.count == 1 ? "entry" : "entries")")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, 18)
            .padding(.top, 44)
            .padding(.bottom, 12)

            if cards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.inkFaint)
                    Text("Search the scene and question the suspects. What you learn is written here, and only what is certain.")
                        .font(.serif(13).italic())
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(order, id: \.0) { kind, label in
                        let group = cards.filter { $0.kind == kind }.reversed()
                        if !group.isEmpty {
                            SectionLabel(text: label).padding(.top, 8)
                            ForEach(Array(group)) { card in
                                ClueCard(card: card, action: showAction(for: card))
                                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .animation(.spring(duration: 0.5), value: cards.count)
            }
        }
    }

    private func showAction(for card: Card) -> (label: String, perform: () -> Void)? {
        guard case .suspect(let id) = game.focus, let s = game.mystery?.suspect(id), !game.isBusy else { return nil }
        return ("Show to \(s.shortName)", { game.present(card.id, to: id) })
    }
}

extension Suspect {
    /// "is an old school friend of X" -> "An old school friend of X."
    var firstPersonRelationship: String {
        var r = relationship
        if r.hasPrefix("is ") { r.removeFirst(3) }
        return r.capitalizedFirst + "."
    }
}
