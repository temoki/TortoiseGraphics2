import CoreGraphics
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
        /// An asymmetric, up-pointing sprite built in code (no test resource):
        /// a red top half over a blue bottom half, so a golden image shows both
        /// that the artwork is drawn and which way it is rotated.
        private static func spriteImage(width: Double, height: Double) -> Image? {
            let content = VStack(spacing: 0) {
                Rectangle().fill(Color.red)
                Rectangle().fill(Color.blue)
            }
            .frame(width: width, height: height)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            guard let nsImage = renderer.nsImage else { return nil }
            return Image(nsImage: nsImage)
        }

        @Test("image sprite replaces the triangle and rotates with the heading")
        func imageSprite() {
            guard let sprite = Self.spriteImage(width: 40, height: 40) else {
                Issue.record("ImageRenderer produced no sprite image")
                return
            }
            assertCanvasSnapshot(sprite: .image(sprite, size: CGSize(width: 40, height: 40)))
        }

        @Test("a non-square image is fitted inside the sprite size, not stretched")
        func imageSpriteAspectRatio() {
            guard let sprite = Self.spriteImage(width: 80, height: 40) else {
                Issue.record("ImageRenderer produced no sprite image")
                return
            }
            // A 2:1 image in a square box renders 40 x 20, not 40 x 40.
            assertCanvasSnapshot(sprite: .image(sprite, size: CGSize(width: 40, height: 40)))
        }

        /// Renders a two-segment drawing that ends heading east (90°), so a
        /// correctly rotated sprite shows its red half on the east side.
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
