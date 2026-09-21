#if os(macOS)
    import AppKit
    import SnapshotTesting

    extension Snapshotting where Value == NSImage, Format == NSImage {
        /// The comparison every canvas PNG golden uses.
        ///
        /// `perceptualPrecision` absorbs the OS-level antialiasing drift that makes
        /// byte-wise comparison of rendered text and curves brittle across machines.
        ///
        /// It was removed for a while: swift-snapshot-testing through 1.19.5 passed a
        /// bare `CGRect` as `CIAreaAverage`'s `inputExtent`, which Core Image on
        /// macOS 27 rejects with an uncaught `-[NSConcreteValue CGRectValue]`
        /// exception — crashing the whole test process rather than failing one test.
        /// Fixed upstream in 1.19.6 (pointfreeco/swift-snapshot-testing#1120), which
        /// is why `Package.swift` floors the dependency there. See #49.
        static var canvasGolden: Snapshotting {
            .image(precision: 0.995, perceptualPrecision: 0.98)
        }
    }
#endif
