import Foundation

// MARK: - Style

/// A style that can be applied to text for terminal rendering
public struct Style: Sendable {
    // MARK: - Properties

    /// Foreground color
    public var foreground: Color?

    /// Background color
    public var background: Color?

    /// Whether text is bold
    public var bold: Bool = false

    /// Whether text is italic
    public var italic: Bool = false

    /// Whether text is underlined
    public var underline: Bool = false

    /// Whether text is struck through
    public var strikethrough: Bool = false

    /// Whether text blinks
    public var blink: Bool = false

    /// Whether text is faint/dim
    public var faint: Bool = false

    /// Whether colors are reversed
    public var reverse: Bool = false

    // MARK: - Initialization

    public init() {}

    /// Returns a default style
    public static func defaultStyle() -> Style {
        Style()
    }

    // MARK: - Builder Methods

    /// Sets the foreground color
    public func foreground(_ color: Color) -> Style {
        var style = self
        style.foreground = color
        return style
    }

    /// Sets the background color
    public func background(_ color: Color) -> Style {
        var style = self
        style.background = color
        return style
    }

    /// Makes text bold
    public func bold(_ enabled: Bool = true) -> Style {
        var style = self
        style.bold = enabled
        return style
    }

    /// Makes text italic
    public func italic(_ enabled: Bool = true) -> Style {
        var style = self
        style.italic = enabled
        return style
    }

    /// Makes text underlined
    public func underline(_ enabled: Bool = true) -> Style {
        var style = self
        style.underline = enabled
        return style
    }

    /// Makes text struck through
    public func strikethrough(_ enabled: Bool = true) -> Style {
        var style = self
        style.strikethrough = enabled
        return style
    }

    /// Makes text blink
    public func blink(_ enabled: Bool = true) -> Style {
        var style = self
        style.blink = enabled
        return style
    }

    /// Makes text faint/dim
    public func faint(_ enabled: Bool = true) -> Style {
        var style = self
        style.faint = enabled
        return style
    }

    /// Reverses foreground and background colors
    public func reverse(_ enabled: Bool = true) -> Style {
        var style = self
        style.reverse = enabled
        return style
    }

    // MARK: - Rendering

    /// Renders text with this style applied
    public func render(_ text: String) -> String {
        var codes: [String] = []

        // Reset
        codes.append("0")

        // Attributes
        if bold { codes.append("1") }
        if faint { codes.append("2") }
        if italic { codes.append("3") }
        if underline { codes.append("4") }
        if blink { codes.append("5") }
        if reverse { codes.append("7") }
        if strikethrough { codes.append("9") }

        // Foreground color
        if let fg = foreground {
            codes.append(fg.foregroundCode())
        }

        // Background color
        if let bg = background {
            codes.append(bg.backgroundCode())
        }

        let prefix = "\u{1B}[\(codes.joined(separator: ";"))m"
        let suffix = "\u{1B}[0m"

        return prefix + text + suffix
    }
}

// MARK: - Color

/// Represents a color for terminal styling
public struct Color: Sendable {
    private enum ColorType {
        case ansi(UInt8)
        case ansi256(UInt8)
        case rgb(r: UInt8, g: UInt8, b: UInt8)
    }

    private let type: ColorType

    // MARK: - ANSI Colors

    public static let black = Color(ansi: 0)
    public static let red = Color(ansi: 1)
    public static let green = Color(ansi: 2)
    public static let yellow = Color(ansi: 3)
    public static let blue = Color(ansi: 4)
    public static let magenta = Color(ansi: 5)
    public static let cyan = Color(ansi: 6)
    public static let white = Color(ansi: 7)

    public static let brightBlack = Color(ansi: 8)
    public static let brightRed = Color(ansi: 9)
    public static let brightGreen = Color(ansi: 10)
    public static let brightYellow = Color(ansi: 11)
    public static let brightBlue = Color(ansi: 12)
    public static let brightMagenta = Color(ansi: 13)
    public static let brightCyan = Color(ansi: 14)
    public static let brightWhite = Color(ansi: 15)

    // MARK: - Initialization

    /// Creates a color from an ANSI color code (0-15)
    public init(ansi: UInt8) {
        self.type = .ansi(ansi)
    }

    /// Creates a color from an ANSI 256 color code
    public init(_ code: UInt8) {
        self.type = .ansi256(code)
    }

    /// Creates a color from RGB values
    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.type = .rgb(r: r, g: g, b: b)
    }

    /// Creates a color from a hex string
    public init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let hexNum = UInt32(hexString, radix: 16)
        else {
            return nil
        }

        let r = UInt8((hexNum >> 16) & 0xFF)
        let g = UInt8((hexNum >> 8) & 0xFF)
        let b = UInt8(hexNum & 0xFF)

        self.type = .rgb(r: r, g: g, b: b)
    }

    // MARK: - Code Generation

    func foregroundCode() -> String {
        switch type {
        case let .ansi(code) where code < 8:
            "3\(code)"
        case let .ansi(code) where code >= 8:
            "9\(code - 8)"
        case let .ansi256(code):
            "38;5;\(code)"
        case let .rgb(r, g, b):
            "38;2;\(r);\(g);\(b)"
        default:
            "37" // Default white
        }
    }

    func backgroundCode() -> String {
        switch type {
        case let .ansi(code) where code < 8:
            "4\(code)"
        case let .ansi(code) where code >= 8:
            "10\(code - 8)"
        case let .ansi256(code):
            "48;5;\(code)"
        case let .rgb(r, g, b):
            "48;2;\(r);\(g);\(b)"
        default:
            "40" // Default black
        }
    }
}
