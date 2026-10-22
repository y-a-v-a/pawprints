import MysteryKit
import SwiftUI

/// Pick the thief, then back it up with one card for each of means, opportunity and motive.
struct AccusationView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var accused: Int?
    @State private var evidence: [Proof: String] = [:]

    var body: some View {
        if let m = game.mystery, let engine = game.engine {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name the thief")
                        .font(.serif(28, .bold))
                    Text("Who took \(m.item)? Back it up with your notebook: a sharp accusation earns more stars, and a wrong one costs you a star.")
                        .font(.serif(14))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    ForEach(m.suspects) { s in
                        Button {
                            withAnimation(.snappy) { accused = s.id }
                        } label: {
                            VStack(spacing: 8) {
                                Portrait(suspect: s, size: 84)
                                    .overlay(Circle().strokeBorder(accused == s.id ? Palette.accent : .clear, lineWidth: 3))
                                Text(s.shortName.capitalizedFirst)
                                    .font(.serif(13, .semibold))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(accused == s.id ? Palette.accent.opacity(0.08) : .clear, in: .rect(cornerRadius: 12))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(Proof.allCases, id: \.self) { slot in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.label).font(.serif(15, .semibold))
                                Text(slot.question).font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                            }
                            .frame(width: 190, alignment: .leading)
                            Picker(slot.label, selection: binding(for: slot)) {
                                Text("Choose a card\u{2026}").tag(String?.none)
                                ForEach(engine.knownCards) { card in
                                    Text(card.title).tag(String?.some(card.id))
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                        .padding(12)
                        .paperCard(radius: 10)
                    }
                }

                HStack {
                    Button("Not yet") { dismiss() }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        if let accused { game.accuse(accused, evidence: evidence) }
                    } label: {
                        Label(accused.map { "It was \(m.suspect($0).shortName)!" } ?? "Choose a suspect", systemImage: "hand.point.right.fill")
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(accused == nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
            .frame(width: 640)
            .background(Palette.paper)
        }
    }

    private func binding(for slot: Proof) -> Binding<String?> {
        Binding(get: { evidence[slot] }, set: { evidence[slot] = $0 })
    }
}

struct FinaleView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        if let m = game.mystery, let verdict = game.verdict, let engine = game.engine {
            let c = m.culprit
            ScrollView {
                VStack(spacing: 26) {
                    Text("CASE CLOSED")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Palette.accent)
                        .padding(.top, 50)
                    Text(m.title)
                        .font(.serif(38, .bold))
                        .multilineTextAlignment(.center)
                    Stars(count: verdict.stars, size: 34)

                    HStack(alignment: .top, spacing: 28) {
                        VStack(spacing: 10) {
                            Portrait(suspect: c, size: 190)
                                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                            Text(c.name).font(.serif(17, .bold))
                            Text("The thief").font(.system(size: 11.5)).foregroundStyle(Palette.accent)
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            if let confession = game.confession {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(c.shortName.capitalizedFirst) \(confession.action)")
                                        .font(.serif(12.5).italic())
                                        .foregroundStyle(Palette.inkFaint)
                                    TypewriterText(text: "\u{201C}\(confession.line)\u{201D}", animate: true, font: .serif(19))
                                        .lineSpacing(4)
                                }
                                .padding(18)
                                .paperCard(raised: true, radius: 14)
                            } else {
                                HStack(spacing: 10) {
                                    ProgressView().controlSize(.small)
                                    Text("\(c.shortName.capitalizedFirst) opens \(c.possessive) mouth to speak\u{2026}")
                                        .font(.serif(15).italic())
                                        .foregroundStyle(Palette.inkSoft)
                                }
                            }
                            if !game.finale.isEmpty {
                                TypewriterText(text: game.finale, animate: true, font: .serif(16), color: Palette.inkSoft, speed: 110)
                                    .lineSpacing(5)
                            }
                            HStack(spacing: 14) {
                                Illustration(subject: .item, placeholder: "sparkles", cornerRadius: 12)
                                    .frame(width: 76, height: 76)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Recovered").font(.system(size: 10.5, weight: .semibold)).tracking(1.2).foregroundStyle(Palette.moss)
                                    Text(m.item.capitalizedFirst).font(.serif(15, .semibold))
                                    Text("Found \(m.hidingPlace).").font(.serif(13)).foregroundStyle(Palette.inkSoft)
                                }
                            }
                            .padding(12)
                            .paperCard(radius: 12)
                        }
                        .frame(maxWidth: 520, alignment: .leading)
                    }

                    VStack(spacing: 8) {
                        SectionLabel(text: "Your case")
                        HStack(spacing: 18) {
                            ForEach(Proof.allCases, id: \.self) { p in
                                Label(p.label, systemImage: verdict.proven.contains(p) ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundStyle(verdict.proven.contains(p) ? Palette.moss : Palette.inkFaint)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        Text("\(engine.questionsAsked) questions asked · \(engine.wrongAccusations) wrong accusation\(engine.wrongAccusations == 1 ? "" : "s") · \(engine.known.count) notebook entries")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .padding(18)
                    .frame(maxWidth: 640)
                    .paperCard()

                    HStack(spacing: 12) {
                        Button {
                            game.newCase()
                        } label: {
                            Label("A new case", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(InkButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        Button("Title screen") { game.backToTitle() }
                            .buttonStyle(InkButtonStyle(prominent: false))
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 48)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
