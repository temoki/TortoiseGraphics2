import TortoiseCore

/// The gallery of example drawings in this directory, in README order.
///
/// Consumed by the `ExamplesRunner` executable (`swift run ExamplesRunner`)
/// to regenerate the `docs/examples/*.svg` images from the same drawing
/// code the SwiftUI `#Preview`s use.
public enum Gallery {
    @MainActor
    public static let drawings: [(file: String, draw: @MainActor (Tortoise) -> Void)] = [
        ("square-spiral", SquareSpiral.draw),
        ("fractal-tree", FractalTree.draw),
        ("koch-snowflake", KochSnowflake.draw),
        ("circle-rosette", CircleRosette.draw),
        ("filled-star", FilledStar.draw),
        ("waves", Waves.draw),
    ]
}
