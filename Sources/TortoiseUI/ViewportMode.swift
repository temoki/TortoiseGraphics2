import CoreGraphics
import TortoiseCore

/// Controls how the turtle coordinate space maps onto the view.
public enum ViewportMode {
    /// Scale the logical canvas to fill the view, preserving aspect ratio (letterboxed). Default.
    case scaleToFit
    /// 1 turtle unit = 1 point, origin at view center. Wider views show more canvas.
    case original
}

extension ViewportMode {
    /// Returns a transform mapping turtle coordinates (center origin, Y up)
    /// to SwiftUI Canvas coordinates (top-left origin, Y down).
    func transform(canvasSize: Size, viewSize: CGSize) -> CGAffineTransform {
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
        }
    }
}
