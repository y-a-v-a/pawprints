import MysteryKit
import SwiftUI

struct RootView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch game.phase {
            case .title:
                TitleView().transition(.opacity)
            case .briefing:
                BriefingView().transition(.opacity)
            case .investigating:
                GameView().transition(.opacity)
            case .finale:
                FinaleView().transition(.opacity)
            }
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
    }
}

struct TitleView: View {
    @Environment(GameModel.self) private var game
    @State private var caseNumber = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Palette.accent)
                        .rotationEffect(.degrees(-14))
                    Text("Pawprints")
                        .font(.serif(56, .bold))
                }
                Text("Cosy mysteries in the village of Mossbury.\nWritten, voiced and illustrated on your Mac, by Apple Intelligence.")
                    .font(.serif(19))
                    .foregroundStyle(Palette.inkSoft)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 12) {
                    if game.hasSave {
                        Button {
                            game.resume()
                        } label: {
                            Label("Continue \u{201C}\(game.savedTitle)\u{201D}", systemImage: "book")
                        }
                        .buttonStyle(InkButtonStyle())
                    }
                    Button {
                        game.newCase()
                    } label: {
                        Label("New case", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(InkButtonStyle(prominent: !game.hasSave))
                    .keyboardShortcut(.defaultAction)

                    HStack(spacing: 8) {
                        TextField("Case number", text: $caseNumber)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .frame(width: 130)
                            .background(Palette.card, in: .capsule)
                            .overlay(Capsule().strokeBorder(Palette.hairline))
                            .onSubmit(openNumbered)
                        Button("Open", action: openNumbered)
                            .buttonStyle(InkButtonStyle(prominent: false))
                            .disabled(UInt64(caseNumber) == nil)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label(game.modelStatus.text, systemImage: game.modelStatus.ok ? "checkmark.seal" : "exclamationmark.triangle")
                        .foregroundStyle(game.modelStatus.ok ? Palette.moss : Palette.accent)
                    if !game.modelStatus.ok {
                        Text("You can still play: the suspects will just speak plainly, without pictures.")
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .font(.system(size: 12))
                Spacer()
                Text("Every case is invented on the spot: suspects, secrets, clues and pictures. Nothing leaves this Mac.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(56)
            .frame(maxWidth: 560, alignment: .leading)

            ZStack {
                if let art = game.titleArt, let image = NSImage(contentsOf: art) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Palette.paperDeep
                    Text("🦊🔍").font(.system(size: 80)).opacity(0.4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .leading) {
                LinearGradient(colors: [Palette.paper, Palette.paper.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90)
            }
            .animation(.easeIn(duration: 1), value: game.titleArt)
        }
        .ignoresSafeArea()
    }

    private func openNumbered() {
        if let n = UInt64(caseNumber) { game.newCase(seed: n) }
    }
}

struct BriefingView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        if let m = game.mystery {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Illustration(subject: .cover, placeholder: "building.columns", cornerRadius: 18)
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "CASE \(m.seed) · \(m.place.uppercased()) · \(m.occasion.uppercased())")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(Palette.accent)
                            Text(m.title)
                                .font(.serif(40, .bold))
                        }
                        Spacer(minLength: 20)
                        Button {
                            game.beginInvestigation()
                        } label: {
                            Label("Take the case", systemImage: "arrow.right")
                                .labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(InkButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .padding(.bottom, 8)
                    }

                    HStack(alignment: .top, spacing: 24) {
                        Group {
                            if game.briefing.isEmpty {
                                HStack(spacing: 10) {
                                    ProgressView().controlSize(.small)
                                    Text("The narrator clears their throat\u{2026}")
                                        .font(.serif(16).italic())
                                        .foregroundStyle(Palette.inkSoft)
                                }
                            } else {
                                TypewriterText(text: game.briefing, animate: true, font: .serif(17), speed: 120)
                                    .lineSpacing(5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .top, spacing: 14) {
                            BriefingFigure(subject: .item, placeholder: "sparkles", title: m.item.capitalizedFirst, caption: "What was taken", round: false)
                            BriefingFigure(subject: .owner, placeholder: "🎩", title: m.ownerName.capitalizedFirst, caption: "Your client", round: true)
                        }
                    }

                    SectionLabel(text: "The suspects")
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(m.suspects) { s in
                            VStack(spacing: 10) {
                                Portrait(suspect: s, size: 104)
                                Text(s.name)
                                    .font(.serif(14, .semibold))
                                    .multilineTextAlignment(.center)
                                Text(s.occupation.capitalizedFirst)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Palette.inkSoft)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .paperCard()
                        }
                    }

                    HowToPlay()

                    Text("Painted on-device by Image Playground. Pictures appear as they're ready.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.inkFaint)
                }
                .padding(.horizontal, 56)
                .padding(.top, 40)
                .padding(.bottom, 36)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

private struct BriefingFigure: View {
    let subject: Illustrator.Subject
    let placeholder: String
    let title: String
    let caption: String
    let round: Bool

    var body: some View {
        VStack(spacing: 8) {
            Illustration(subject: subject, placeholder: placeholder, cornerRadius: round ? 55 : 14)
                .frame(width: 110, height: 110)
            Text(title)
                .font(.serif(12.5, .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkFaint)
        }
        .frame(width: 130)
    }
}

private struct HowToPlay: View {
    private let steps: [(String, String, String)] = [
        ("bubble.left.and.text.bubble.right", "Question the suspects", "Click a suggestion or type anything you like."),
        ("magnifyingglass", "Search the rooms", "Start at the scene of the crime."),
        ("rectangle.portrait.on.rectangle.portrait", "Show your evidence", "A card from your notebook can loosen a tongue."),
        ("hand.point.right", "Name the thief", "Back it up with means, opportunity and motive."),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: step.0)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 30, height: 30)
                        .background(Palette.accent.opacity(0.1), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.1).font(.serif(13.5, .semibold))
                        Text(step.2)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, i < steps.count - 1 ? 14 : 0)
            }
        }
        .padding(16)
        .paperCard()
    }
}
