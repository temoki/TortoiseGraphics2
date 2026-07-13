import TortoiseCore

/// A named tortoise program exercising one functional group of drawing commands.
///
/// Scenarios are shared between the SVG golden tests and the UI snapshot tests
/// so both renderers are verified against the exact same command streams.
public struct DrawingScenario: Identifiable, Sendable, CustomStringConvertible {
    /// Stable ASCII identifier; becomes part of the golden file name.
    public let name: String

    /// The tortoise program for this scenario.
    public let draw: @MainActor @Sendable (Tortoise) -> Void

    public var id: String { name }

    public var description: String { name }

    public init(_ name: String, draw: @escaping @MainActor @Sendable (Tortoise) -> Void) {
        self.name = name
        self.draw = draw
    }

    /// Runs the program on a fresh tortoise (default canvas size) and returns it.
    @MainActor
    public func makeTortoise() -> Tortoise {
        let tortoise = Tortoise()
        draw(tortoise)
        return tortoise
    }
}
