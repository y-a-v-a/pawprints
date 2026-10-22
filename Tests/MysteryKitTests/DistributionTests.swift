import Testing
@testable import MysteryKit

@Suite struct DistributionTests {
    /// Every table entry should turn up regularly; a skewed pick makes cases feel samey.
    @Test func choicesAreSpreadEvenly() {
        let cases = (1...600).map { CaseGenerator.make(seed: $0) }
        func spread<T: Hashable>(_ values: [T]) -> [T: Int] { values.reduce(into: [:]) { $0[$1, default: 0] += 1 } }
        let hiding = spread(cases.map(\.hidingRoom))
        let plots = spread(cases.map(\.plot))
        let places = spread(cases.map(\.place))
        for (_, n) in hiding { #expect(n > 60) }
        for (_, n) in plots { #expect(n > 120) }
        for (_, n) in places { #expect(n > 60) }
    }
}
