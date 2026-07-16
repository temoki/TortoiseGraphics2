/// JSON serialization for the command stream and its value types.
///
/// Every `Codable` conformance in this file uses explicit coding keys and a
/// hand-written encode/decode implementation, so the wire format is decoupled
/// from Swift identifier names and guaranteed stable across 2.x releases —
/// renaming a Swift case or property never changes serialized data.
/// See <doc:CommandSerialization> for the format definition and the
/// stability guarantee.

// MARK: - Point

extension Point: Codable {
    private enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// MARK: - Size

extension Size: Codable {
    private enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

// MARK: - Color

extension Color: Codable {
    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    /// Decodes a color, clamping each component to 0…1 (the same rule the
    /// memberwise initializer applies). `alpha` may be omitted and defaults to 1.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }
}

// MARK: - TortoiseCommand

extension TortoiseCommand: Codable {
    /// Wire-format command names. One key per case; the key string — not the
    /// Swift case name — is what serialized data depends on.
    ///
    /// When adding a command case: add a `CodingKeys` case, handle it in both
    /// switches below, add a fixture to `CodableTests.commandFixtures`, and
    /// add a row to the table in `CommandSerialization.md`. Only the first
    /// two are enforced by the compiler — do not skip the other two; they
    /// are the frozen-format contract.
    private enum CodingKeys: String, CodingKey {
        case forward
        case rotate
        case home
        case setPosition
        case setHeading
        case penDown
        case penUp
        case penColor
        case penWidth
        case fillColor
        case beginFill
        case endFill
        case showTortoise
        case hideTortoise
        case speed
        case backgroundColor
        case clear
        case arc
        case dot
    }

    /// Wire-format names for scalar payload fields.
    private enum PayloadKeys: String, CodingKey {
        case distance
        case degrees
        case width
        case value
        case radius
        case extent
        case size
    }

    /// Accepts any key. Used to count the raw keys of a command object:
    /// a container keyed by `CodingKeys` only reports the keys it knows, so
    /// it cannot see an unknown key riding along next to a known one.
    private struct RawCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: any Decoder) throws {
        let rawKeys = try decoder.container(keyedBy: RawCodingKey.self).allKeys
        guard rawKeys.count == 1, let rawKey = rawKeys.first,
            let key = CodingKeys(stringValue: rawKey.stringValue)
        else {
            let found = rawKeys.map(\.stringValue).sorted().joined(separator: ", ")
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "Expected an object with exactly one known command key, found: [\(found)]"
                ))
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func payload() throws -> KeyedDecodingContainer<PayloadKeys> {
            try container.nestedContainer(keyedBy: PayloadKeys.self, forKey: key)
        }

        switch key {
        case .forward:
            self = .forward(try payload().decode(Double.self, forKey: .distance))
        case .rotate:
            self = .rotate(try payload().decode(Double.self, forKey: .degrees))
        case .home:
            self = .home
        case .setPosition:
            self = .setPosition(try container.decode(Point.self, forKey: .setPosition))
        case .setHeading:
            self = .setHeading(try payload().decode(Double.self, forKey: .degrees))
        case .penDown:
            self = .penDown
        case .penUp:
            self = .penUp
        case .penColor:
            self = .penColor(try container.decode(Color.self, forKey: .penColor))
        case .penWidth:
            self = .penWidth(try payload().decode(Double.self, forKey: .width))
        case .fillColor:
            self = .fillColor(try container.decode(Color.self, forKey: .fillColor))
        case .beginFill:
            self = .beginFill
        case .endFill:
            self = .endFill
        case .showTortoise:
            self = .showTortoise
        case .hideTortoise:
            self = .hideTortoise
        case .speed:
            self = .speed(try payload().decode(Double.self, forKey: .value))
        case .backgroundColor:
            self = .backgroundColor(try container.decode(Color.self, forKey: .backgroundColor))
        case .clear:
            self = .clear
        case .arc:
            let arcPayload = try payload()
            self = .arc(
                radius: try arcPayload.decode(Double.self, forKey: .radius),
                extent: try arcPayload.decode(Double.self, forKey: .extent)
            )
        case .dot:
            self = .dot(try payload().decode(Double.self, forKey: .size))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        func encodeEmpty(_ key: CodingKeys) {
            _ = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: key)
        }
        func encodeScalar(_ scalar: Double, _ field: PayloadKeys, forKey key: CodingKeys) throws {
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: key)
            try payload.encode(scalar, forKey: field)
        }

        switch self {
        case .forward(let distance):
            try encodeScalar(distance, .distance, forKey: .forward)
        case .rotate(let degrees):
            try encodeScalar(degrees, .degrees, forKey: .rotate)
        case .home:
            encodeEmpty(.home)
        case .setPosition(let position):
            try container.encode(position, forKey: .setPosition)
        case .setHeading(let degrees):
            try encodeScalar(degrees, .degrees, forKey: .setHeading)
        case .penDown:
            encodeEmpty(.penDown)
        case .penUp:
            encodeEmpty(.penUp)
        case .penColor(let color):
            try container.encode(color, forKey: .penColor)
        case .penWidth(let width):
            try encodeScalar(width, .width, forKey: .penWidth)
        case .fillColor(let color):
            try container.encode(color, forKey: .fillColor)
        case .beginFill:
            encodeEmpty(.beginFill)
        case .endFill:
            encodeEmpty(.endFill)
        case .showTortoise:
            encodeEmpty(.showTortoise)
        case .hideTortoise:
            encodeEmpty(.hideTortoise)
        case .speed(let value):
            try encodeScalar(value, .value, forKey: .speed)
        case .backgroundColor(let color):
            try container.encode(color, forKey: .backgroundColor)
        case .clear:
            encodeEmpty(.clear)
        case .arc(let radius, let extent):
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .arc)
            try payload.encode(radius, forKey: .radius)
            try payload.encode(extent, forKey: .extent)
        case .dot(let size):
            try encodeScalar(size, .size, forKey: .dot)
        }
    }
}
