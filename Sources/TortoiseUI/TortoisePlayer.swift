import Foundation
import Observation
import TortoiseCore

/// Playback controller for ``TortoiseCanvas``: pause, resume, single-step,
/// seek, and override the playback speed of a running drawing.
///
/// Create a player, pass it to ``TortoiseCanvas/init(_:player:)``, and drive
/// it from your own controls:
///
/// ```swift
/// @State private var player = TortoisePlayer()
///
/// var body: some View {
///     TortoiseCanvas(🐢, player: player)
///     Toggle("Pause", systemImage: "pause.fill", isOn: $player.isPaused)
///     Button("Step", systemImage: "forward.frame.fill") { player.step() }
/// }
/// ```
///
/// All observation properties participate in SwiftUI observation — bind UI
/// (a block highlight, a progress bar) directly to ``currentCommandIndex``
/// or ``isFinished``.
///
/// ### Speed is two layers
///
/// `.speed()` commands in the stream (``Tortoise/speed``) are the *author's*
/// tempo — part of the drawing itself. ``speedOverride`` is the *viewer's*
/// control, like a video player's playback-speed button: while non-nil it
/// takes precedence over every `.speed()` command in the stream, and setting
/// it back to `nil` returns control to the stream. Changing it never rewinds
/// or restarts playback — the current position is preserved.
@Observable
@MainActor
public final class TortoisePlayer {
    /// The playback model of the canvas this player is attached to.
    /// Set by `TortoiseCanvas` when it appears and whenever it rebuilds
    /// its model after the tortoise is mutated.
    var model: CanvasModel?

    public init() {}

    // MARK: - Observation

    /// Index into `Tortoise.commands` of the most recently committed command;
    /// -1 when playback has not started.
    ///
    /// Commands and playback frames are 1:1, so this is the command the
    /// canvas has fully drawn (the next one may be mid-animation).
    public var currentCommandIndex: Int { model?.currentFrameIndex ?? -1 }

    /// Whether playback has reached the end of the command stream.
    /// `false` until the player is attached to a ``TortoiseCanvas``.
    public var isFinished: Bool { model?.isFinished ?? false }

    // MARK: - Control

    /// Suspends playback while `true`; the canvas stops advancing and stops
    /// redrawing entirely (its `TimelineView` schedule is paused).
    /// Use ``step()`` to advance manually while paused.
    public var isPaused: Bool = false {
        didSet {
            // Drop the tick baseline so resuming doesn't replay the wall-clock
            // time spent paused as one giant animation jump.
            if !isPaused { model?.resetTickBaseline() }
        }
    }

    /// Viewer-side playback speed: 1 (slowest) … 10 (fastest), 0 = instant.
    ///
    /// `nil` (the default) follows the stream's `.speed()` commands; a
    /// non-nil value takes precedence over them while set. Changing it takes
    /// effect immediately and preserves the current playback position.
    public var speedOverride: Double?

    /// Advances playback by exactly one command, committing it instantly
    /// (no walk animation). Most useful while ``isPaused``; does nothing
    /// once playback is finished.
    public func step() {
        model?.step()
    }

    /// Jumps to just after the command at `commandIndex`, rebuilding the
    /// canvas contents for that position. Works forward and backward.
    ///
    /// The index is clamped to `-1...(commands.count - 1)`; pass -1 to
    /// rewind to before the first command.
    public func seek(to commandIndex: Int) {
        model?.seek(to: commandIndex)
    }
}
