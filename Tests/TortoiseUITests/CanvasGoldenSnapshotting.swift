#if os(macOS)
    import AppKit
    import SnapshotTesting

    extension Snapshotting where Value == NSImage, Format == NSImage {
        /// The comparison every canvas PNG golden uses.
        ///
        /// Byte-wise with a small tolerance, deliberately *without*
        /// `perceptualPrecision`. swift-snapshot-testing's perceptual path passes a
        /// bare `CGRect` as `CIAreaAverage`'s `inputExtent`, which Core Image on
        /// macOS 27 rejects with an uncaught `-[NSConcreteValue CGRectValue]`
        /// exception — crashing the whole test process rather than failing one
        /// test. An exact match never reaches that path, which is why the goldens
        /// still pass on the macOS they were recorded on.
        static var canvasGolden: Snapshotting {
            .image(precision: 0.995)
        }
    }
#endif
