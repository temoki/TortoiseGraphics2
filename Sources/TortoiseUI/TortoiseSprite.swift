import CoreGraphics
import SwiftUI

/// The visual representation of the tortoise on the canvas.
///
/// Set it with the `.tortoiseSprite(_:)` modifier. The default is
/// ``TortoiseSprite/triangle``.
///
/// ```swift
/// TortoiseCanvas(🐢)
///     .tortoiseSprite(.image(Image("Turtle"), size: CGSize(width: 40, height: 40)))
/// ```
///
/// Conformances are declared explicitly so that adding an associated value
/// to a case later cannot silently drop the implicit ones.
public enum TortoiseSprite: Sendable, Equatable {
    /// The built-in green triangle. Default.
    case triangle

    /// A custom image, drawn centered on the tortoise's position.
    ///
    /// The image is rotated so its **top edge** faces the tortoise's heading
    /// (at heading 0 — north — it is drawn upright), so supply artwork that
    /// points up. Transparency is preserved, so the drawing shows through.
    ///
    /// `size` is a bounding box in points at viewport scale 1: the image is
    /// scaled to fit inside it, preserving its aspect ratio. Like the built-in
    /// triangle, the sprite scales with the viewport, clamped to 0.5×–2×.
    ///
    /// Use `Image(uiImage:)` / `Image(nsImage:)` to pass an image you already
    /// have in memory.
    case image(Image, size: CGSize)

    /// Draw no tortoise at all — for when you are drawing your own.
    ///
    /// The drawing itself animates exactly as before; only the sprite is
    /// omitted. Pair it with ``TortoisePlayer/currentTortoiseState`` and
    /// ``ViewportMode/transform(canvasSize:viewSize:drawingBounds:spriteHalfExtent:)``
    /// to put a cursor of your own — a SwiftUI overlay, a RealityKit entity,
    /// a sprite in another engine — exactly where the canvas would have drawn
    /// the triangle.
    ///
    /// This is **not** `Tortoise.hideTortoise()`. That records a command: it
    /// travels with the drawing into every renderer and every serialized
    /// stream, and it is part of what the program says. This is a property of
    /// one view, and changing it cannot change the drawing.
    ///
    /// ``ViewportMode/autoFit`` then insets the drawing by nothing, there
    /// being no sprite to keep clear of the edge, so the drawing runs edge to
    /// edge and any margin is yours to add (SwiftUI's `.padding()`, or a
    /// smaller frame).
    case hidden
}

extension TortoiseSprite {
    /// Maximum distance from the tortoise's position to any point of the
    /// sprite at scale 1 — the half-diagonal, so it holds at every heading.
    /// ``ViewportMode/autoFit`` insets the drawing by this much (times
    /// `tortoiseScaleMax`) so the sprite never clips at the view edge.
    ///
    /// Public so that a renderer drawing its own tortoise can hand the same
    /// value to
    /// ``ViewportMode/transform(canvasSize:viewSize:drawingBounds:spriteHalfExtent:)``
    /// that the canvas uses, and so land its cursor in the same place.
    public var halfExtent: Double {
        switch self {
        case .triangle:
            // The triangle's farthest point is its tip, at `tortoiseBaseSize`.
            return tortoiseBaseSize
        case .image(_, let size):
            return (size.width * size.width + size.height * size.height).squareRoot() / 2
        case .hidden:
            return 0
        }
    }
}
