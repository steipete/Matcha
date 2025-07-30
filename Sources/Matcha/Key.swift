//
//  Key.swift
//  Matcha
//
//  Keyboard input handling for the Matcha TUI framework.
//

import Foundation

/// KeyMsg contains information about a keypress. KeyMsgs are always sent to
/// the program's update function.
public struct KeyMsg: Message, Equatable, Sendable {
    /// The type of key that was pressed
    public let type: KeyType
    
    /// The characters associated with this key press (for regular character input)
    /// Note: This will always contain at least one character for KeyRunes type
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
    public init(character: Character, alt: Bool = false, paste: Bool = false) {
        self.type = .runes
        self.runes = [character]
        self.alt = alt
        self.paste = paste
    }
    
    /// Convenience initializer for string input
    public init(string: String, alt: Bool = false, paste: Bool = false) {
        self.type = .runes
        self.runes = Array(string)
        self.alt = alt
        self.paste = paste
    }
}

// MARK: - String Representation

extension KeyMsg: CustomStringConvertible {
    /// Returns a friendly string representation for a key message. It's safe (and
    /// encouraged) for use in key comparison.
    public var description: String {
        Key(self).description
    }
}

/// Key contains information about a keypress.
public struct Key: Equatable, Sendable {
    public let type: KeyType
    public let runes: [Character]
    public let alt: Bool
    public let paste: Bool
    
    public init(_ msg: KeyMsg) {
        self.type = msg.type
        self.runes = msg.runes
        self.alt = msg.alt
        self.paste = msg.paste
    }
    
    public init(type: KeyType, runes: [Character] = [], alt: Bool = false, paste: Bool = false) {
        self.type = type
        self.runes = runes
        self.alt = alt
        self.paste = paste
    }
}

extension Key: CustomStringConvertible {
    /// Returns a friendly string representation for a key. It's safe (and
    /// encouraged) for use in key comparison.
    public var description: String {
        var result = ""
        
        if alt {
            result += "alt+"
        }
        
        if type == .runes {
            if paste {
                // Note: bubbles/keys bindings currently do string compares to
                // recognize shortcuts. Since pasted text should never activate
                // shortcuts, we need to ensure that the binding code doesn't
                // match Key events that result from pastes. We achieve this
                // here by enclosing pastes in '[...]' so that the string
                // comparison in Matches() fails in that case.
                result += "["
            }
            result += String(runes)
            if paste {
                result += "]"
            }
            return result
        } else if let name = keyNames[type] {
            result += name
            return result
        }
        
        return ""
    }
}

/// KeyType indicates the key pressed, such as KeyEnter or KeyBreak or KeyCtrlC.
/// All other keys will be type KeyRunes. To get the rune value, check the Rune
/// method on a Key struct, or use the Key.String() method.
public enum KeyType: Int, Sendable, Equatable {
    // Control keys. We could do this with an iota, but the values are very
    // specific, so we set the values explicitly to avoid any confusion.
    //
    // See also:
    // https://en.wikipedia.org/wiki/C0_and_C1_control_codes
    case null = 0       // null, \0
    case ctrlA = 1      // start of heading
    case ctrlB = 2      // start of text
    case ctrlC = 3      // break, ctrl+c
    case ctrlD = 4      // end of transmission
    case ctrlE = 5      // enquiry
    case ctrlF = 6      // acknowledge
    case ctrlG = 7      // bell, \a
    case ctrlH = 8      // backspace (also mapped to backspace)
    case ctrlI = 9      // horizontal tabulation, \t (also mapped to tab)
    case ctrlJ = 10     // line feed, \n (also mapped to enter)
    case ctrlK = 11     // vertical tabulation \v
    case ctrlL = 12     // form feed \f
    case ctrlM = 13     // carriage return, \r
    case ctrlN = 14     // shift out
    case ctrlO = 15     // shift in
    case ctrlP = 16     // data link escape
    case ctrlQ = 17     // device control one
    case ctrlR = 18     // device control two
    case ctrlS = 19     // device control three
    case ctrlT = 20     // device control four
    case ctrlU = 21     // negative acknowledge
    case ctrlV = 22     // synchronous idle
    case ctrlW = 23     // end of transmission block
    case ctrlX = 24     // cancel
    case ctrlY = 25     // end of medium
    case ctrlZ = 26     // substitution
    case ctrlOpenBracket = 27  // escape, \e (also mapped to escape)
    case ctrlBackslash = 28    // file separator
    case ctrlCloseBracket = 29 // group separator
    case ctrlCaret = 30        // record separator
    case ctrlUnderscore = 31   // unit separator
    case space = 32            // space
    case delete = 127          // delete
    
    // Extended keys (starting from 256 to avoid conflicts)
    case runes = 256
    
    // Common keys (semantic aliases for control sequences)
    case backspace = 257   // commonly ctrl+h
    case tab = 258         // commonly ctrl+i
    case enter = 259       // commonly ctrl+j or ctrl+m
    case escape = 260      // commonly ctrl+[
    
    // Navigation keys
    case up = 261
    case down = 262
    case right = 263
    case left = 264
    case home = 265
    case end = 266
    case pageUp = 267
    case pageDown = 268
    
    // Editing keys
    case insert = 269
    
    // Function keys
    case f1 = 270
    case f2 = 271
    case f3 = 272
    case f4 = 273
    case f5 = 274
    case f6 = 275
    case f7 = 276
    case f8 = 277
    case f9 = 278
    case f10 = 279
    case f11 = 280
    case f12 = 281
    case f13 = 282
    case f14 = 283
    case f15 = 284
    case f16 = 285
    case f17 = 286
    case f18 = 287
    case f19 = 288
    case f20 = 289
    
    // Special keys with modifiers
    case shiftTab = 290
    case shiftUp = 291
    case shiftDown = 292
    case shiftRight = 293
    case shiftLeft = 294
    case shiftHome = 295
    case shiftEnd = 296
    
    case ctrlUp = 297
    case ctrlDown = 298
    case ctrlRight = 299
    case ctrlLeft = 300
    case ctrlHome = 301
    case ctrlEnd = 302
    case ctrlPageUp = 303
    case ctrlPageDown = 304
    
    case altUp = 305
    case altDown = 306
    case altRight = 307
    case altLeft = 308
    
    // Media keys
    case mediaPlayPause = 309
    case mediaStop = 310
    case mediaNext = 311
    case mediaPrev = 312
    case mediaRewind = 313
    case mediaFastForward = 314
}

// MARK: - Key Names

/// Mapping of key types to their string representations
private let keyNames: [KeyType: String] = [
    .null: "ctrl+@",
    .ctrlA: "ctrl+a",
    .ctrlB: "ctrl+b",
    .ctrlC: "ctrl+c",
    .ctrlD: "ctrl+d",
    .ctrlE: "ctrl+e",
    .ctrlF: "ctrl+f",
    .ctrlG: "ctrl+g",
    .ctrlH: "ctrl+h",
    .ctrlI: "ctrl+i",
    .ctrlJ: "ctrl+j",
    .ctrlK: "ctrl+k",
    .ctrlL: "ctrl+l",
    .ctrlM: "ctrl+m",
    .ctrlN: "ctrl+n",
    .ctrlO: "ctrl+o",
    .ctrlP: "ctrl+p",
    .ctrlQ: "ctrl+q",
    .ctrlR: "ctrl+r",
    .ctrlS: "ctrl+s",
    .ctrlT: "ctrl+t",
    .ctrlU: "ctrl+u",
    .ctrlV: "ctrl+v",
    .ctrlW: "ctrl+w",
    .ctrlX: "ctrl+x",
    .ctrlY: "ctrl+y",
    .ctrlZ: "ctrl+z",
    .ctrlOpenBracket: "ctrl+[",
    .ctrlBackslash: "ctrl+\\",
    .ctrlCloseBracket: "ctrl+]",
    .ctrlCaret: "ctrl+^",
    .ctrlUnderscore: "ctrl+_",
    .space: "space",
    .delete: "delete",
    
    // Common keys
    .backspace: "backspace",
    .tab: "tab",
    .enter: "enter",
    .escape: "esc",
    
    // Navigation
    .up: "up",
    .down: "down",
    .right: "right",
    .left: "left",
    .home: "home",
    .end: "end",
    .pageUp: "pgup",
    .pageDown: "pgdown",
    .insert: "insert",
    
    // Function keys
    .f1: "f1",
    .f2: "f2",
    .f3: "f3",
    .f4: "f4",
    .f5: "f5",
    .f6: "f6",
    .f7: "f7",
    .f8: "f8",
    .f9: "f9",
    .f10: "f10",
    .f11: "f11",
    .f12: "f12",
    .f13: "f13",
    .f14: "f14",
    .f15: "f15",
    .f16: "f16",
    .f17: "f17",
    .f18: "f18",
    .f19: "f19",
    .f20: "f20",
    
    // Modified keys
    .shiftTab: "shift+tab",
    .shiftUp: "shift+up",
    .shiftDown: "shift+down",
    .shiftRight: "shift+right",
    .shiftLeft: "shift+left",
    .shiftHome: "shift+home",
    .shiftEnd: "shift+end",
    
    .ctrlUp: "ctrl+up",
    .ctrlDown: "ctrl+down",
    .ctrlRight: "ctrl+right",
    .ctrlLeft: "ctrl+left",
    .ctrlHome: "ctrl+home",
    .ctrlEnd: "ctrl+end",
    .ctrlPageUp: "ctrl+pgup",
    .ctrlPageDown: "ctrl+pgdown",
    
    .altUp: "alt+up",
    .altDown: "alt+down",
    .altRight: "alt+right",
    .altLeft: "alt+left",
    
    // Media keys
    .mediaPlayPause: "media play/pause",
    .mediaStop: "media stop",
    .mediaNext: "media next",
    .mediaPrev: "media previous",
    .mediaRewind: "media rewind",
    .mediaFastForward: "media fast-forward"
]

// MARK: - Pattern Matching Support

public extension KeyMsg {
    /// Enables pattern matching with string literals
    /// Example: case "ctrl+c": handleQuit()
    static func ~= (pattern: String, key: KeyMsg) -> Bool {
        key.description == pattern
    }
}

// MARK: - Common Key Constants

public extension KeyMsg {
    // Control keys
    static let ctrlA = KeyMsg(type: .ctrlA)
    static let ctrlB = KeyMsg(type: .ctrlB)
    static let ctrlC = KeyMsg(type: .ctrlC)
    static let ctrlD = KeyMsg(type: .ctrlD)
    static let ctrlE = KeyMsg(type: .ctrlE)
    static let ctrlF = KeyMsg(type: .ctrlF)
    static let ctrlG = KeyMsg(type: .ctrlG)
    static let ctrlH = KeyMsg(type: .ctrlH)
    static let ctrlI = KeyMsg(type: .ctrlI)
    static let ctrlJ = KeyMsg(type: .ctrlJ)
    static let ctrlK = KeyMsg(type: .ctrlK)
    static let ctrlL = KeyMsg(type: .ctrlL)
    static let ctrlM = KeyMsg(type: .ctrlM)
    static let ctrlN = KeyMsg(type: .ctrlN)
    static let ctrlO = KeyMsg(type: .ctrlO)
    static let ctrlP = KeyMsg(type: .ctrlP)
    static let ctrlQ = KeyMsg(type: .ctrlQ)
    static let ctrlR = KeyMsg(type: .ctrlR)
    static let ctrlS = KeyMsg(type: .ctrlS)
    static let ctrlT = KeyMsg(type: .ctrlT)
    static let ctrlU = KeyMsg(type: .ctrlU)
    static let ctrlV = KeyMsg(type: .ctrlV)
    static let ctrlW = KeyMsg(type: .ctrlW)
    static let ctrlX = KeyMsg(type: .ctrlX)
    static let ctrlY = KeyMsg(type: .ctrlY)
    static let ctrlZ = KeyMsg(type: .ctrlZ)

    // Special control sequences
    static let ctrlBackslash = KeyMsg(type: .ctrlBackslash)
    static let ctrlRightBracket = KeyMsg(type: .ctrlCloseBracket)
    static let ctrlLeftBracket = KeyMsg(type: .ctrlOpenBracket)
    static let ctrlCaret = KeyMsg(type: .ctrlCaret)
    static let ctrlUnderscore = KeyMsg(type: .ctrlUnderscore)

    // Common keys
    static let enter = KeyMsg(type: .enter)
    static let tab = KeyMsg(type: .tab)
    static let backspace = KeyMsg(type: .backspace)
    static let escape = KeyMsg(type: .escape)
    static let space = KeyMsg(type: .space)
    static let delete = KeyMsg(type: .delete)

    // Navigation
    static let up = KeyMsg(type: .up)
    static let down = KeyMsg(type: .down)
    static let left = KeyMsg(type: .left)
    static let right = KeyMsg(type: .right)
    static let home = KeyMsg(type: .home)
    static let end = KeyMsg(type: .end)
    static let pageUp = KeyMsg(type: .pageUp)
    static let pageDown = KeyMsg(type: .pageDown)
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

/// Message for unknown DCS sequences that couldn't be parsed
public struct UnknownDCSSequenceMsg: Message {
    public let bytes: [UInt8]
    
    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}
