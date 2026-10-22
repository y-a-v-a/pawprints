import MysteryKit
import SwiftUI

/// An on-device illustration, with a gently shimmering placeholder while it is painted.
struct Illustration: View {
    @Environment(GameModel.self) private var game
    let subject: Illustrator.Subject
    var placeholder: String = "🐾"
    var cornerRadius: CGFloat = 14

    var body: some View {
        // Color.clear takes exactly the size the caller offers; the picture fills it and is clipped,
        // instead of growing the view to the picture's own aspect ratio.
        Color.clear
            .overlay {
                if let image = game.image(subject) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Placeholder(symbol: placeholder, isPainting: game.painting.contains(subject))
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Palette.hairline.opacity(0.8), lineWidth: 1))
    }
}

private struct Placeholder: View {
    let symbol: String
    let isPainting: Bool
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            let large = geo.size.width > 220
            ZStack {
                LinearGradient(colors: [Palette.paperDeep, Palette.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 10) {
                    if symbol.unicodeScalars.first?.properties.isEmoji == true && symbol.count <= 2 {
                        Text(symbol)
                            .font(.system(size: max(14, min(geo.size.width, geo.size.height) * (large ? 0.22 : 0.42))))
                            .opacity(0.5)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: max(14, min(geo.size.width, geo.size.height) * 0.18), weight: .light))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    if large && isPainting {
                        Text("Painting\u{2026}")
                            .font(.serif(13).italic())
                            .foregroundStyle(Palette.inkFaint)
                    }
                }
                if isPainting {
                    LinearGradient(colors: [.clear, Palette.cardRaised.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: sweep ? geo.size.width : -geo.size.width)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}

/// Round portrait of a suspect.
struct Portrait: View {
    let suspect: Suspect
    var size: CGFloat = 44

    var body: some View {
        Illustration(subject: .suspect(suspect.id), placeholder: suspect.emoji, cornerRadius: size / 2)
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Portrait of \(suspect.name), a \(suspect.species)")
            .accessibilityAddTraits(.isImage)
    }
}

/// Text that types itself out, like a telegram arriving. Click to finish at once.
struct TypewriterText: View {
    let text: String
    let animate: Bool
    var font: Font = .serif(15)
    var color: Color = Palette.ink
    var speed: Double = 70
    var onFinish: () -> Void = {}

    @State private var shown = 0

    var body: some View {
        // The full text sits underneath, invisible, so layout never jumps while typing.
        Text(text)
            .font(font)
            .foregroundStyle(.clear)
            .overlay(alignment: .topLeading) {
                Text(String(text.prefix(animate ? shown : text.count)))
                    .font(font)
                    .foregroundStyle(color)
            }
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .onTapGesture { shown = text.count }
            .task(id: text) {
                guard animate else { shown = text.count; return }
                shown = 0
                for i in 0...text.count {
                    shown = i
                    try? await Task.sleep(for: .seconds(1 / speed))
                    if Task.isCancelled { break }
                }
                shown = text.count
                onFinish()
            }
    }
}

/// Ten pips, from unflappable (green) to cracking (red).
struct ComposureMeter: View {
    let value: Int

    var color: Color {
        switch value {
        case 7...: Palette.moss
        case 4...6: Palette.brass
        default: Palette.accent
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(i < value ? color : Palette.hairline)
                    .frame(width: 9, height: 5)
            }
        }
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement()
        .accessibilityLabel("Composure \(value) out of 10")
    }
}

/// A notebook card. Everything on it was written by the engine, so it can be trusted.
struct ClueCard: View {
    @Environment(GameModel.self) private var game
    let card: Card
    var compact = false
    var action: (label: String, perform: () -> Void)?

    var isFresh: Bool { game.freshCards.contains(card.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: card.kind.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(card.kind.tint)
                    .frame(width: 22, height: 22)
                    .background(card.kind.tint.opacity(0.13), in: .circle)
                Text(card.title)
                    .font(.serif(13.5, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if isFresh {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .foregroundStyle(Palette.accentInk)
                        .background(Palette.accent, in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            if !compact {
                HStack(alignment: .top, spacing: 10) {
                    if card.imagePrompt != nil {
                        Illustration(subject: .card(card.id), placeholder: "magnifyingglass", cornerRadius: 8)
                            .frame(width: 54, height: 54)
                    }
                    Text(card.text)
                        .font(.serif(12.5))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Text(card.kind.label + " · " + card.source)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(1)
                    Spacer()
                    if let action {
                        Button(action.label, action: action.perform)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
        }
        .padding(12)
        .paperCard(raised: isFresh, radius: 10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.accent.opacity(isFresh ? 0.7 : 0), lineWidth: 1.5))
    }
}

/// Magnifying glasses for the final rating.
struct Stars: View {
    let count: Int
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                    .font(.system(size: size))
                    .foregroundStyle(i < count ? Palette.brass : Palette.hairline)
            }
        }
    }
}
