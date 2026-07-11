/// The result of executing a single ``TurtleCommand``.
///
/// Renderers step through an array of `PlaybackFrame` values
/// produced by ``CommandPlayer`` to animate or export a drawing.
public struct PlaybackFrame: Sendable {
    /// Index into the original command array.
    public let commandIndex: Int
    /// Turtle state *after* this command has been applied.
    public let turtleState: TurtleState
    /// Canvas background color after this command.
    public let backgroundColor: Color
    /// Line segment drawn by this command, if any.
    public let newStroke: Stroke?
    /// Fill polygon completed by an `endFill` command, if any.
    public let completedFill: Fill?
    /// `true` when this command cleared all previous drawing.
    public let didClear: Bool
}
