import CoreGraphics
import TortoiseCore

/// Controls how the tortoise coordinate space maps onto the view.
public enum ViewportMode {
    /// Scale the logical canvas to fill the view, preserving aspect ratio (letterboxed). Default.
    case scaleToFit
    /// 1 tortoise unit = 1 point, origin at view center. Wider views show more canvas.
    case original
    /// Scale and translate so the actual drawing bounding box fills the view with optional padding.
    ///
    /// `padding` is in logical tortoise units added on each side. Falls back to `.scaleToFit`
    /// when the command stream produces no visible output.
    case autoFit(padding: Double = 8)
}

extension ViewportMode {
    /// Returns a transform mapping tortoise coordinates (center origin, Y up)
    /// to SwiftUI Canvas coordinates (top-left origin, Y down).
    func transform(canvasSize: Size, viewSize: CGSize, drawingBounds: DrawingBounds?)
        -> CGAffineTransform
    {
        let tx = viewSize.width / 2
        let ty = viewSize.height / 2
        switch self {
        case .scaleToFit:
            let scale = min(viewSize.width / canvasSize.width, viewSize.height / canvasSize.height)
            // x' = scale * x + tx,  y' = -scale * y + ty
            return CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: tx, ty: ty)
        case .original:
            // x' = x + tx,  y' = -y + ty
            return CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: tx, ty: ty)
        case .autoFit(let padding):
            guard let bb = drawingBounds else {
                // No visible output — fall back to scaleToFit.
                let scale = min(
                    viewSize.width / canvasSize.width, viewSize.height / canvasSize.height)
                return CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: tx, ty: ty)
            }
            let pw = bb.width + 2 * padding
            let ph = bb.height + 2 * padding
            // Protect against a degenerate bounding box (single point or horizontal/vertical line).
            let scale = min(
                pw > 0 ? viewSize.width / pw : 1,
                ph > 0 ? viewSize.height / ph : 1
            )
            // Map bb center in tortoise space to the view center.
            // x' = scale * x + atx,  y' = -scale * y + aty
            // atx = viewW/2 - scale * bb.centerX
            // aty = viewH/2 + scale * bb.centerY  (Y-axis is flipped)
            let atx = viewSize.width / 2 - scale * bb.centerX
            let aty = viewSize.height / 2 + scale * bb.centerY
            return CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: atx, ty: aty)
        }
    }
}
