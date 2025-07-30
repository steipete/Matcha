//
//  Key.swift
//  Matcha
//
//  Keyboard input handling for the Matcha TUI framework.
//

import Foundation

/// Represents a keyboard key press event
public struct Key: Message, Equatable, CustomStringConvertible {
    /// The type of key that was pressed
    public let type: KeyType

    /// The characters associated with this key press (for regular character input)
    public let runes: [Character]

    /// Whether the Alt/Option key was held during this key press
    public let alt: Bool

    /// Whether this key press is part of a paste operation
    public let paste: Bool

    public init(type: KeyType, runes: [Character] = [], alt: Bool = false, paste: Bool = false) {
        self.type = type
        self.runes = runes
        self.alt = alt
        self.paste = paste
    }

    /// Convenience initializer for character keys
    public init(character: Character, alt: Bool = false) {
        type = .runes
        runes = [character]
        self.alt = alt
        paste = false
    }

    /// Returns a human-readable string representation of the key
    public var description: String {
        var result = ""

        if alt {
            result += "alt+"
        }

        switch type {
        case .runes:
            result += runes.map { String($0) }.joined()
        case .enter:
            result += "enter"
        case .tab:
            result += "tab"
        case .backspace:
            result += "backspace"
        case .escape:
            result += "escape"
        case .space:
            result += "space"
        case .up:
            result += "up"
        case .down:
            result += "down"
        case .left:
            result += "left"
        case .right:
            result += "right"
        case .home:
            result += "home"
        case .end:
            result += "end"
        case .pageUp:
            result += "pgup"
        case .pageDown:
            result += "pgdown"
        case .delete:
            result += "delete"
        case .insert:
            result += "insert"
        case let .function(n):
            result += "f\(n)"
        case let .control(char):
            result += "ctrl+\(char)"
        case .null:
            result += "null"
        case .break:
            result += "break"
        case .printScreen:
            result += "print"
        case .pause:
            result += "pause"
        case .capsLock:
            result += "caps"
        case .numLock:
            result += "num"
        case .scrollLock:
            result += "scroll"
        }

        return result
    }
}

/// Represents the type of key that was pressed
public enum KeyType: Sendable, Equatable {
    // Special keys
    case null
    case `break`
    case enter
    case backspace
    case tab
    case escape
    case space
    case delete

    // Navigation keys
    case up
    case down
    case right
    case left
    case home
    case end
    case pageUp
    case pageDown

    // Editing keys
    case insert

    // Function keys
    case function(Int) // F1-F20

    // Modifier keys
    case printScreen
    case pause
    case capsLock
    case numLock
    case scrollLock

    // Control sequences
    case control(Character) // Ctrl+A through Ctrl+Z, etc.

    // Regular character input
    case runes
}

/// Type alias for compatibility with Bubble Tea
public typealias KeyMsg = Key

// MARK: - Pattern Matching Support

public extension Key {
    /// Enables pattern matching with string literals
    /// Example: case "ctrl+c": handleQuit()
    static func ~= (pattern: String, key: Key) -> Bool {
        key.description == pattern
    }
}

// MARK: - Common Key Constants

public extension Key {
    // Control keys
    static let ctrlA = Key(type: .control("a"))
    static let ctrlB = Key(type: .control("b"))
    static let ctrlC = Key(type: .control("c"))
    static let ctrlD = Key(type: .control("d"))
    static let ctrlE = Key(type: .control("e"))
    static let ctrlF = Key(type: .control("f"))
    static let ctrlG = Key(type: .control("g"))
    static let ctrlH = Key(type: .control("h"))
    static let ctrlI = Key(type: .control("i"))
    static let ctrlJ = Key(type: .control("j"))
    static let ctrlK = Key(type: .control("k"))
    static let ctrlL = Key(type: .control("l"))
    static let ctrlM = Key(type: .control("m"))
    static let ctrlN = Key(type: .control("n"))
    static let ctrlO = Key(type: .control("o"))
    static let ctrlP = Key(type: .control("p"))
    static let ctrlQ = Key(type: .control("q"))
    static let ctrlR = Key(type: .control("r"))
    static let ctrlS = Key(type: .control("s"))
    static let ctrlT = Key(type: .control("t"))
    static let ctrlU = Key(type: .control("u"))
    static let ctrlV = Key(type: .control("v"))
    static let ctrlW = Key(type: .control("w"))
    static let ctrlX = Key(type: .control("x"))
    static let ctrlY = Key(type: .control("y"))
    static let ctrlZ = Key(type: .control("z"))

    // Special control sequences
    static let ctrlBackslash = Key(type: .control("\\"))
    static let ctrlRightBracket = Key(type: .control("]"))
    static let ctrlLeftBracket = Key(type: .control("["))
    static let ctrlCaret = Key(type: .control("^"))
    static let ctrlUnderscore = Key(type: .control("_"))

    // Common keys
    static let enter = Key(type: .enter)
    static let tab = Key(type: .tab)
    static let backspace = Key(type: .backspace)
    static let escape = Key(type: .escape)
    static let space = Key(type: .space)
    static let delete = Key(type: .delete)

    // Navigation
    static let up = Key(type: .up)
    static let down = Key(type: .down)
    static let left = Key(type: .left)
    static let right = Key(type: .right)
    static let home = Key(type: .home)
    static let end = Key(type: .end)
    static let pageUp = Key(type: .pageUp)
    static let pageDown = Key(type: .pageDown)
}

/// Message for unknown input bytes that couldn't be parsed
public struct UnknownInputByteMsg: Message {
    public let byte: UInt8

    public init(byte: UInt8) {
        self.byte = byte
    }
}

/// Message for unknown CSI sequences that couldn't be parsed
public struct UnknownCSISequenceMsg: Message {
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}
