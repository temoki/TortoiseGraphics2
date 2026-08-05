import Foundation
import SwiftUI
import Testing
import TortoiseCore

@testable import TortoiseUI

@Suite("Canvas background")
@MainActor
struct CanvasBackgroundTests {
    @Test("a program with no background command replays as white, not clear (#44)")
    func defaultBackgroundIsWhite() {
        let tortoise = Tortoise()
        tortoise.speed = 0
        tortoise.forward(40)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        #expect(model.backgroundColor == .defaultBackground)
    }

    @Test("an empty tortoise reports the same background it renders (#44)")
    func emptyStreamMatchesTortoise() {
        let tortoise = Tortoise()
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        #expect(model.backgroundColor == tortoise.backgroundColor)
    }

    @Test("an explicit clear background stays transparent")
    func explicitClearStaysTransparent() {
        let tortoise = Tortoise()
        tortoise.backgroundColor = .clear
        tortoise.forward(40)
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        #expect(model.backgroundColor == .clear)
    }

    @Test("seeking back before the first command keeps the default background")
    func seekToStartKeepsDefault() {
        let tortoise = Tortoise()
        tortoise.forward(40)
        tortoise.backgroundColor = .cyan
        let model = CanvasModel(
            commands: tortoise.commands, canvasSize: tortoise.canvasSize, sourceKey: nil)
        model.seek(to: model.frames.count - 1)
        #expect(model.backgroundColor == .cyan)
        model.seek(to: -1)
        #expect(model.backgroundColor == .defaultBackground)
    }
}

#if os(macOS)
    /// The issue's own reproduction: put the canvas on a red backdrop and read a
    /// corner pixel. Before the fix it came back red (#FF2600) because nothing
    /// was painted; it must now be the tortoise's white paper.
    @Suite("Canvas background rendering")
    @MainActor
    struct CanvasBackgroundRenderingTests {
        private func cornerPixel(_ view: some View) -> (r: Double, g: Double, b: Double, a: Double)?
        {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: 60, height: 60)
            guard let cgImage = renderer.cgImage else { return nil }
            var pixel = [UInt8](repeating: 0, count: 4)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                let ctx = CGContext(
                    data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            // Sample a corner pixel — the drawing sits in the middle, so every
            // corner is background.
            ctx.draw(
                cgImage,
                in: CGRect(
                    x: 0, y: -(cgImage.height - 1), width: cgImage.width, height: cgImage.height))
            return (
                Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255,
                Double(pixel[3]) / 255
            )
        }

        @Test("the canvas paints white over the host's backdrop (#44)")
        func paintsOverBackdrop() {
            let tortoise = Tortoise()
            tortoise.speed = 0
            tortoise.penDown()
            tortoise.forward(40)

            let view = TortoiseCanvas(tortoise)
                .frame(width: 60, height: 60)
                .background(Color(red: 1, green: 0, blue: 0))

            guard let px = cornerPixel(view) else {
                Issue.record("ImageRenderer produced no image")
                return
            }
            // Loose thresholds on purpose: the assertion is "white paper, not
            // the red backdrop", and exact components would make the test
            // depend on the render target's color space (cf. #43).
            #expect(px.a == 1.0)
            #expect(px.r > 0.9)
            #expect(px.g > 0.9)
            #expect(px.b > 0.9)
        }

        @Test("an explicit clear background still lets the backdrop through")
        func clearLetsBackdropThrough() {
            let tortoise = Tortoise()
            tortoise.speed = 0
            tortoise.backgroundColor = .clear
            tortoise.penDown()
            tortoise.forward(40)

            let view = TortoiseCanvas(tortoise)
                .frame(width: 60, height: 60)
                .background(Color(red: 1, green: 0, blue: 0))

            guard let px = cornerPixel(view) else {
                Issue.record("ImageRenderer produced no image")
                return
            }
            #expect(px.r > 0.8)
            #expect(px.g < 0.3)
            #expect(px.b < 0.3)
        }
    }
#endif
