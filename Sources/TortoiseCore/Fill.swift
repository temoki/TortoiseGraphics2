/// A filled polygon completed by an `endFill` command.
public struct Fill: Sendable, Equatable {
    /// Vertices of the polygon in turtle coordinate space.
    public let points: [Point]
    public let color: Color
}
