import AppKit
import MysteryKit
import SwiftUI

/// Parchment and ink by day, lamplight and walnut by night.
enum Palette {
    static let paper = dynamic(light: 0xF3EAD7, dark: 0x1D1814)
    static let paperDeep = dynamic(light: 0xE9DDC4, dark: 0x16120F)
    static let card = dynamic(light: 0xFBF6EC, dark: 0x29221C)
    static let cardRaised = dynamic(light: 0xFFFDF8, dark: 0x332A23)
    static let ink = dynamic(light: 0x2A2018, dark: 0xF0E5D1)
    static let inkSoft = dynamic(light: 0x6E5D4C, dark: 0xB9A88F)
    static let inkFaint = dynamic(light: 0x9C8A73, dark: 0x85765F)
    static let hairline = dynamic(light: 0xD9C9AC, dark: 0x3C3229)
    static let accent = dynamic(light: 0x8E2C2C, dark: 0xE07B6D)
    static let accentInk = dynamic(light: 0xFFF7EE, dark: 0x1D1814)
    static let brass = dynamic(light: 0xA77A2C, dark: 0xDDB466)
    static let moss = dynamic(light: 0x3E6A4D, dark: 0x86B996)
    static let inspector = dynamic(light: 0x2F4858, dark: 0x9CC0D6)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension Mood {
    var tint: Color {
        switch self {
        case .calm, .friendly, .relieved: Palette.moss
        case .guarded: Palette.brass
        case .flustered, .indignant, .rattled: Palette.accent
        }
    }
}

extension CardKind {
    var symbol: String {
        switch self {
        case .claim: "text.quote"
        case .testimony: "ear"
        case .evidence: "magnifyingglass"
        case .deduction: "lightbulb.max"
        case .confession: "heart.text.square"
        }
    }

    var tint: Color {
        switch self {
        case .claim: Palette.inkSoft
        case .testimony: Palette.inspector
        case .evidence: Palette.brass
        case .deduction: Palette.accent
        case .confession: Palette.moss
        }
    }
}

extension RoomRole {
    var symbol: String {
        switch self {
        case .display: "sparkles"
        case .gathering: "music.note.house"
        case .quiet: "books.vertical"
        case .kitchen: "cup.and.saucer"
        case .garden: "leaf"
        case .cloakroom: "hanger"
        }
    }
}

extension Suspect {
    var emoji: String {
        switch species {
        case "fox": "🦊"
        case "mouse": "🐭"
        case "badger": "🦡"
        case "heron": "🪶"
        case "hedgehog": "🦔"
        case "otter": "🦦"
        case "rabbit": "🐰"
        case "owl": "🦉"
        case "crow": "🐦‍⬛"
        case "cat": "🐱"
        case "squirrel": "🐿️"
        case "toad": "🐸"
        case "duck": "🦆"
        default: "🐾"
        }
    }
}

/// A sheet of paper: soft fill, hairline edge, faint shadow.
struct PaperCard: ViewModifier {
    var raised = false
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(raised ? Palette.cardRaised : Palette.card, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(raised ? 0.10 : 0.04), radius: raised ? 10 : 3, y: raised ? 4 : 1)
    }
}

extension View {
    func paperCard(raised: Bool = false, radius: CGFloat = 12) -> some View {
        modifier(PaperCard(raised: raised, radius: radius))
    }
}

/// Small caps label used for section headers.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Palette.inkFaint)
    }
}

/// Primary button: oxblood pill.
struct InkButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(prominent ? Palette.accentInk : Palette.ink)
            .background(prominent ? Palette.accent : Palette.card, in: .capsule)
            .overlay(Capsule().strokeBorder(prominent ? .clear : Palette.hairline))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(.capsule)
    }
}

/// Wraps children onto as many lines as needed, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
