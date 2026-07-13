import SnapshotTesting
import Testing
import TortoiseSVG
import TortoiseTestSupport

extension Snapshotting where Value == String, Format == String {
    /// Full-string SVG golden comparison; failures print a line diff.
    @MainActor
    fileprivate static let svg = Snapshotting(pathExtension: "svg", diffing: .lines)
}

@Suite("Drawing scenario SVG goldens")
@MainActor
struct DrawingScenarioSVGTests {
    @Test("scenario matches golden SVG", arguments: DrawingScenario.all)
    func golden(scenario: DrawingScenario) {
        let output = TortoiseSVG.render(scenario.makeTortoise())
        assertSnapshot(of: output, as: .svg, named: scenario.name, testName: "scenario")
    }
}
