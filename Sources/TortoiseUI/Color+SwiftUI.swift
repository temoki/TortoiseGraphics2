import SwiftUI
import TortoiseCore

extension SwiftUI.Color {
    /// Create a SwiftUI Color from a TortoiseCore Color.
    public init(_ color: TortoiseCore.Color) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}
