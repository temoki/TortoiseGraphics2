/// The result of executing a single ``TortoiseCommand``.
///
/// Renderers step through an array of `PlaybackFrame` values
/// produced by ``CommandPlayer`` to animate or export a drawing.
public struct PlaybackFrame: Sendable, Equatable {
    /// Index into the original command array.
    public let commandIndex: Int
    /// Tortoise state *after* this command has been applied.
    public let tortoiseState: TortoiseState
    /// Canvas background color after this command.
    public let backgroundColor: Color
    /// Line segment drawn by this command, if any.
    public let newStroke: Stroke?
    /// Circular arc drawn by this command, if any.
    public let newArcStroke: ArcStroke?
    /// Fill polygon completed by an `endFill` command, if any.
    public let completedFill: Fill?
    /// Filled circle drawn by a `dot` command, if any.
    public let newDot: Dot?
    /// `true` when this command cleared all previous drawing.
    public let didClear: Bool
    /// `true` when this frame was produced while a fill region was active
    /// (i.e., between `beginFill` and `endFill`).
    ///
    /// Renderers that need to place fill polygons below their outline strokes
    /// (SVG, PDF, etc.) can use this to defer stroke emission until after the
    /// corresponding ``completedFill`` is known.
    public let isFillActive: Bool
}
