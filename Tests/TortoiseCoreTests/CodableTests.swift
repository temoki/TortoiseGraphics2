import Foundation
import Testing
import TortoiseCore

@Suite("Codable serialization")
struct CodableTests {
    /// Every `TortoiseCommand` case paired with its frozen wire format
    /// (keys sorted, as produced by `JSONEncoder.OutputFormatting.sortedKeys`).
    ///
    /// These strings are the long-term storage contract documented in
    /// <doc:CommandSerialization> — a code change that breaks one of these
    /// breaks users' saved data, and must not ship in the 2.x series.
    private static let commandFixtures: [(command: TortoiseCommand, json: String)] = [
        (.forward(100), #"{"forward":{"distance":100}}"#),
        (.rotate(-45.5), #"{"rotate":{"degrees":-45.5}}"#),
        (.home, #"{"home":{}}"#),
        (.setPosition(Point(x: 10.5, y: -20)), #"{"setPosition":{"x":10.5,"y":-20}}"#),
        (.setHeading(270), #"{"setHeading":{"degrees":270}}"#),
        (.penDown, #"{"penDown":{}}"#),
        (.penUp, #"{"penUp":{}}"#),
        (
            .penColor(Color(red: 1, green: 0.5, blue: 0, alpha: 0.25)),
            #"{"penColor":{"alpha":0.25,"blue":0,"green":0.5,"red":1}}"#
        ),
        (.penWidth(3), #"{"penWidth":{"width":3}}"#),
        (
            .fillColor(Color(red: 0, green: 1, blue: 1)),
            #"{"fillColor":{"alpha":1,"blue":1,"green":1,"red":0}}"#
        ),
        (.beginFill, #"{"beginFill":{}}"#),
        (.endFill, #"{"endFill":{}}"#),
        (.showTortoise, #"{"showTortoise":{}}"#),
        (.hideTortoise, #"{"hideTortoise":{}}"#),
        (.speed(0), #"{"speed":{"value":0}}"#),
        (
            .backgroundColor(Color(red: 0, green: 0, blue: 0)),
            #"{"backgroundColor":{"alpha":1,"blue":0,"green":0,"red":0}}"#
        ),
        (.clear, #"{"clear":{}}"#),
        (.arc(radius: -50, extent: 180), #"{"arc":{"extent":180,"radius":-50}}"#),
        (.dot(8), #"{"dot":{"size":8}}"#),
    ]

    private static func sortedKeysJSON(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    // MARK: - TortoiseCommand

    @Test("every command case encodes to its frozen wire format", arguments: commandFixtures)
    func commandEncodesToWireFormat(command: TortoiseCommand, expected: String) throws {
        #expect(try Self.sortedKeysJSON(command) == expected)
    }

    @Test("every command case decodes from its frozen wire format", arguments: commandFixtures)
    func commandDecodesFromWireFormat(expected: TortoiseCommand, json: String) throws {
        let decoded = try JSONDecoder().decode(TortoiseCommand.self, from: Data(json.utf8))
        #expect(decoded == expected)
    }

    @Test("a full command stream round-trips through JSON")
    func commandStreamRoundTrip() throws {
        let commands = Self.commandFixtures.map(\.command)
        let data = try JSONEncoder().encode(commands)
        let decoded = try JSONDecoder().decode([TortoiseCommand].self, from: data)
        #expect(decoded == commands)
    }

    @Test("an unknown command key fails to decode")
    func unknownCommandKeyFails() {
        let json = #"{"jump":{"distance":100}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TortoiseCommand.self, from: Data(json.utf8))
        }
    }

    @Test("an object with multiple command keys fails to decode")
    func multipleCommandKeysFail() {
        let json = #"{"home":{},"clear":{}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TortoiseCommand.self, from: Data(json.utf8))
        }
    }

    @Test("an unknown key alongside a known command key fails to decode")
    func mixedKnownAndUnknownKeysFail() {
        // The raw key count must be checked with a key type that accepts any
        // key: a CodingKeys-keyed container only reports the keys it knows,
        // which would let this object silently decode as .home.
        let json = #"{"home":{},"jump":{}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TortoiseCommand.self, from: Data(json.utf8))
        }
    }

    @Test("unrecognized fields inside a payload are ignored")
    func extraPayloadFieldsAreIgnored() throws {
        // Frozen contract: payloads may gain fields in later versions, so
        // decoders must tolerate fields they don't know.
        let json = #"{"forward":{"distance":100,"note":"added in some future version"}}"#
        let decoded = try JSONDecoder().decode(TortoiseCommand.self, from: Data(json.utf8))
        #expect(decoded == .forward(100))
    }

    // MARK: - Value types

    @Test("Point encodes with x/y keys and round-trips")
    func pointWireFormat() throws {
        let point = Point(x: 10.5, y: -20)
        let json = try Self.sortedKeysJSON(point)
        #expect(json == #"{"x":10.5,"y":-20}"#)
        #expect(try JSONDecoder().decode(Point.self, from: Data(json.utf8)) == point)
    }

    @Test("Size encodes with width/height keys and round-trips")
    func sizeWireFormat() throws {
        let size = Size(width: 400, height: 300)
        let json = try Self.sortedKeysJSON(size)
        #expect(json == #"{"height":300,"width":400}"#)
        #expect(try JSONDecoder().decode(Size.self, from: Data(json.utf8)) == size)
    }

    @Test("Color encodes with red/green/blue/alpha keys and round-trips")
    func colorWireFormat() throws {
        let color = Color(red: 1, green: 0.5, blue: 0, alpha: 0.25)
        let json = try Self.sortedKeysJSON(color)
        #expect(json == #"{"alpha":0.25,"blue":0,"green":0.5,"red":1}"#)
        #expect(try JSONDecoder().decode(Color.self, from: Data(json.utf8)) == color)
    }

    @Test("Color decode clamps components to 0…1 like the initializer")
    func colorDecodeClamps() throws {
        let json = #"{"red":2,"green":-1,"blue":0.5,"alpha":9}"#
        let color = try JSONDecoder().decode(Color.self, from: Data(json.utf8))
        #expect(color == Color(red: 1, green: 0, blue: 0.5, alpha: 1))
    }

    @Test("Color alpha defaults to 1 when omitted")
    func colorAlphaDefaultsToOne() throws {
        let json = #"{"red":0.2,"green":0.4,"blue":0.6}"#
        let color = try JSONDecoder().decode(Color.self, from: Data(json.utf8))
        #expect(color == Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    }
}
