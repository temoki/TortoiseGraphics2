#if os(macOS)
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TortoiseTestSupport
    import TortoiseUI

    @Suite("Drawing scenario canvas snapshots")
    @MainActor
    struct DrawingScenarioCanvasTests {
        @Test("scenario matches golden canvas image", arguments: DrawingScenario.all)
        func snapshot(scenario: DrawingScenario) {
            // speed = 0 before any visible output forces instant mode, so CanvasModel
            // flushes all frames at init and a single static render shows the full drawing.
            let view = TortoiseCanvas { tortoise in
                tortoise.speed = 0
                scenario.draw(tortoise)
            }
            .frame(width: 400, height: 400)
            .background(Color.white)
            .environment(\.colorScheme, .light)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: 400, height: 400)

            guard let image = renderer.nsImage else {
                Issue.record("ImageRenderer produced no image for \(scenario.name)")
                return
            }
            assertSnapshot(
                of: image,
                as: .image(precision: 0.995, perceptualPrecision: 0.98),
                named: scenario.name,
                testName: "scenario"
            )
        }
    }
#endif
