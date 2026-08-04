import CoreGraphics
import Foundation
import SwiftUI
import Testing
import TortoiseCore

@testable import TortoiseUI

@Suite("Tortoise sprite")
struct TortoiseSpriteTests {
    @Test("triangle half-extent is the tip distance")
    func triangleHalfExtent() {
        #expect(TortoiseSprite.triangle.halfExtent == tortoiseBaseSize)
    }

    @Test("image half-extent is the half-diagonal, so rotation never clips")
    func imageHalfExtent() {
        let sprite = TortoiseSprite.image(Image(systemName: "tortoise"), size: .init(40, 40))
        // hypot(40, 40) / 2
        #expect(abs(sprite.halfExtent - 28.284271) < 0.0001)
    }

    @Test("autoFit insets by the sprite half-extent, so a larger sprite zooms out")
    func autoFitInsetsForSprite() {
        // A 200 x 200 drawing centered on the origin.
        var builder = DrawingBounds.Builder()
        builder.expand(to: Point(x: -100, y: -100))
        builder.expand(to: Point(x: 100, y: 100))
        let bounds = builder.build()
        let viewSize = CGSize(width: 400, height: 400)
        let scale = { (sprite: TortoiseSprite) in
            ViewportMode.autoFit.transform(
                canvasSize: .defaultCanvas, viewSize: viewSize, drawingBounds: bounds,
                spriteHalfExtent: sprite.halfExtent
            ).a
        }
        // 400 / (200 + 2 * 10 * tortoiseScaleMax)
        #expect(abs(scale(.triangle) - 400.0 / 240.0) < 0.0001)

        let image = TortoiseSprite.image(Image(systemName: "tortoise"), size: .init(40, 40))
        #expect(scale(image) < scale(.triangle))
        // 400 / (200 + 2 * hypot(40, 40) / 2 * tortoiseScaleMax)
        #expect(abs(scale(image) - 400.0 / (200 + 2 * 28.284271 * tortoiseScaleMax)) < 0.0001)
    }

    @Test("equality distinguishes the built-in triangle from an image")
    func equality() {
        let image = Image(systemName: "tortoise")
        #expect(TortoiseSprite.triangle == .triangle)
        #expect(TortoiseSprite.triangle != .image(image, size: .init(40, 40)))
        #expect(
            TortoiseSprite.image(image, size: .init(40, 40)) == .image(image, size: .init(40, 40)))
        #expect(
            TortoiseSprite.image(image, size: .init(40, 40)) != .image(image, size: .init(20, 20)))
    }
}

extension CGSize {
    fileprivate init(_ width: Double, _ height: Double) {
        self.init(width: width, height: height)
    }
}

#if os(macOS)
    import SnapshotTesting

    @Suite("Tortoise sprite canvas snapshots")
    @MainActor
    struct TortoiseSpriteCanvasTests {
        /// An asymmetric, up-pointing sprite: a red top half over a blue bottom
        /// half, so a golden image shows both that the artwork is drawn and
        /// which way it is rotated.
        ///
        /// The pixels are written out explicitly in sRGB rather than rendered
        /// from a SwiftUI view. `ImageRenderer` was used at first and made the
        /// goldens machine-dependent: `Color.red` / `Color.blue` are semantic
        /// colors whose components depend on the display gamut and appearance,
        /// and `ImageRenderer.nsImage` hands back a bitmap tagged with the
        /// host's display profile — so the goldens recorded on a P3 Mac failed
        /// on CI with a pure color shift (perceptual precision 0.956).
        private static func spriteImage(pixelWidth: Int, pixelHeight: Int) -> Image? {
            let bytesPerPixel = 4
            var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * bytesPerPixel)
            for y in 0..<pixelHeight {
                let isTopHalf = y < pixelHeight / 2
                for x in 0..<pixelWidth {
                    let i = (y * pixelWidth + x) * bytesPerPixel
                    pixels[i + 0] = isTopHalf ? 220 : 30  // R
                    pixels[i + 1] = 30  // G
                    pixels[i + 2] = isTopHalf ? 30 : 220  // B
                    pixels[i + 3] = 255  // A
                }
            }
            guard let provider = CGDataProvider(data: Data(pixels) as CFData),
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                let cgImage = CGImage(
                    width: pixelWidth, height: pixelHeight,
                    bitsPerComponent: 8, bitsPerPixel: 8 * bytesPerPixel,
                    bytesPerRow: pixelWidth * bytesPerPixel,
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false,
                    intent: .defaultIntent)
            else { return nil }
            // scale 2 → the CGImage's pixels map to half as many points.
            return Image(decorative: cgImage, scale: 2)
        }

        @Test("image sprite replaces the triangle and rotates with the heading")
        func imageSprite() {
            // 80 x 80 px at scale 2 = 40 x 40 pt, drawn into a 40 x 40 box at
            // viewport scale 1: an exact 1:1 pixel mapping, so no resampling.
            guard let sprite = Self.spriteImage(pixelWidth: 80, pixelHeight: 80) else {
                Issue.record("could not build the sprite image")
                return
            }
            assertCanvasSnapshot(sprite: .image(sprite, size: CGSize(width: 40, height: 40)))
        }

        @Test("a non-square image is fitted inside the sprite size, not stretched")
        func imageSpriteAspectRatio() {
            // 160 x 80 px at scale 2 = 80 x 40 pt. In an 80 x 80 box it renders
            // 80 x 40 (aspect preserved), not 80 x 80 — again 1:1.
            guard let sprite = Self.spriteImage(pixelWidth: 160, pixelHeight: 80) else {
                Issue.record("could not build the sprite image")
                return
            }
            assertCanvasSnapshot(sprite: .image(sprite, size: CGSize(width: 80, height: 80)))
        }

        /// Renders a two-segment drawing that ends heading east (90°), so a
        /// correctly rotated sprite shows its red half on the east side.
        ///
        /// `.original` fixes the viewport scale at 1 so the sprite bitmap lands
        /// on the device pixel grid without resampling, keeping the golden
        /// reproducible across machines.
        private func assertCanvasSnapshot(
            sprite: TortoiseSprite, fileID: StaticString = #fileID,
            filePath: StaticString = #filePath,
            function: String = #function, line: UInt = #line, column: UInt = #column
        ) {
            let view = TortoiseCanvas { tortoise in
                tortoise.speed = 0
                tortoise.forward(100)
                tortoise.right(90)
                tortoise.forward(100)
            }
            .tortoiseSprite(sprite)
            .tortoiseViewport(.original)
            .frame(width: 400, height: 400)
            .background(Color.white)
            .environment(\.colorScheme, .light)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: 400, height: 400)

            guard let image = renderer.nsImage else {
                Issue.record("ImageRenderer produced no image")
                return
            }
            assertSnapshot(
                of: image, as: .image(precision: 0.995, perceptualPrecision: 0.98),
                fileID: fileID, file: filePath, testName: function, line: line, column: column)
        }
    }
#endif
