//
//  InputHandler.swift
//  Matcha
//
//  Input handling and ANSI sequence parsing.
//

import Foundation

/// Handles terminal input and converts it to messages
public final class InputHandler: @unchecked Sendable {
    private let input: FileHandle
    private let messageSubject = AsyncStream<any Message>.makeStream()

    /// The stream of parsed messages
    public var messages: AsyncStream<any Message> {
        messageSubject.stream
    }

    private var task: Task<Void, Never>?

    public init(input: FileHandle) {
        self.input = input
        start()
    }

    private func start() {
        let input = input
        let continuation = messageSubject.continuation

        task = Task { [weak self] in
            await self?.readInput(input: input, continuation: continuation)
        }
    }

    public func stop() {
        task?.cancel()
        messageSubject.continuation.finish()
    }

    private func readInput(input: FileHandle, continuation: AsyncStream<any Message>.Continuation) async {
        let parser = ANSIParser()

        while !Task.isCancelled {
            // Read available data
            let data = input.availableData
            guard !data.isEmpty else {
                // No data available, yield to prevent busy waiting
                try? await Task.sleep(for: .milliseconds(10))
                continue
            }

            // Parse each byte
            for byte in data {
                if let messages = parser.parse(byte) {
                    for message in messages {
                        continuation.yield(message)
                    }
                }
            }
        }

        continuation.finish()
    }
}

/// ANSI sequence parser
final class ANSIParser {
    private var state: ParserState = .ground
    private var buffer: [UInt8] = []
    private var pasteBuffer: String = ""
    private var isPasting = false

    /// Parser states for ANSI sequence parsing
    private enum ParserState {
        case ground
        case escape
        case csi
        case osc
        case paste
    }

    /// Parses a single byte and returns any complete messages
    func parse(_ byte: UInt8) -> [any Message]? {
        var messages: [any Message] = []

        switch state {
        case .ground:
            if byte == 0x1B { // ESC
                state = .escape
                buffer = [byte]
            } else if byte < 0x20 { // Control character
                if let key = parseControlChar(byte) {
                    messages.append(key)
                }
            } else if byte == 0x7F { // DEL
                messages.append(Key(type: .delete))
            } else {
                // Regular character
                let scalar = UnicodeScalar(byte)
                let char = Character(scalar)
                messages.append(Key(character: char))
            }

        case .escape:
            buffer.append(byte)

            if byte == 0x5B { // [
                state = .csi
            } else if byte == 0x5D { // ]
                state = .osc
            } else if byte == 0x4F { // O (SS3)
                // Function keys on some terminals
                state = .ground
                if let key = parseSS3Sequence(buffer) {
                    messages.append(key)
                }
                buffer = []
            } else {
                // Other escape sequences
                state = .ground
                if let key = parseEscapeSequence(buffer) {
                    messages.append(key)
                }
                buffer = []
            }

        case .csi:
            buffer.append(byte)

            // Check if sequence is complete
            if (0x40...0x7E).contains(byte) {
                state = .ground

                // Check for bracketed paste
                if buffer == [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E] { // ESC[200~
                    isPasting = true
                    state = .paste
                    pasteBuffer = ""
                } else if let message = parseCSISequence(buffer) {
                    messages.append(message)
                }
                buffer = []
            }

        case .osc:
            buffer.append(byte)

            // OSC sequences end with ST (ESC \) or BEL
            if byte == 0x07 || (buffer.count >= 2 && buffer[buffer.count - 2] == 0x1B && byte == 0x5C) {
                state = .ground
                // Handle OSC sequences (like window title)
                buffer = []
            }

        case .paste:
            // In paste mode, collect characters until ESC[201~
            if byte == 0x1B {
                buffer = [byte]
            } else if !buffer.isEmpty {
                buffer.append(byte)

                // Check for end of paste
                if buffer == [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E] { // ESC[201~
                    isPasting = false
                    state = .ground

                    // Send a single PasteMsg with all the text
                    messages.append(PasteMsg(text: pasteBuffer))
                    
                    // Also send individual character messages with paste flag if needed
                    // (commented out - use one approach or the other)
                    // for char in pasteBuffer {
                    //     messages.append(Key(character: char, alt: false, paste: true))
                    // }

                    pasteBuffer = ""
                    buffer = []
                }
            } else {
                let scalar = UnicodeScalar(byte)
                let char = Character(scalar)
                pasteBuffer.append(char)
            }
        }

        return messages.isEmpty ? nil : messages
    }

    private func parseControlChar(_ byte: UInt8) -> Key? {
        switch byte {
        case 0x00: Key(type: .null)
        case 0x01: Key(type: .control("a"))
        case 0x02: Key(type: .control("b"))
        case 0x03: Key(type: .control("c"))
        case 0x04: Key(type: .control("d"))
        case 0x05: Key(type: .control("e"))
        case 0x06: Key(type: .control("f"))
        case 0x07: Key(type: .control("g"))
        case 0x08: Key(type: .backspace)
        case 0x09: Key(type: .tab)
        case 0x0A, 0x0D: Key(type: .enter)
        case 0x0B: Key(type: .control("k"))
        case 0x0C: Key(type: .control("l"))
        case 0x0E: Key(type: .control("n"))
        case 0x0F: Key(type: .control("o"))
        case 0x10: Key(type: .control("p"))
        case 0x11: Key(type: .control("q"))
        case 0x12: Key(type: .control("r"))
        case 0x13: Key(type: .control("s"))
        case 0x14: Key(type: .control("t"))
        case 0x15: Key(type: .control("u"))
        case 0x16: Key(type: .control("v"))
        case 0x17: Key(type: .control("w"))
        case 0x18: Key(type: .control("x"))
        case 0x19: Key(type: .control("y"))
        case 0x1A: Key(type: .control("z"))
        case 0x1B: Key(type: .escape)
        case 0x1C: Key(type: .control("\\"))
        case 0x1D: Key(type: .control("]"))
        case 0x1E: Key(type: .control("^"))
        case 0x1F: Key(type: .control("_"))
        default: nil
        }
    }

    private func parseEscapeSequence(_ buffer: [UInt8]) -> Key? {
        // Simple Alt+key detection
        if buffer.count == 2 {
            let scalar = UnicodeScalar(buffer[1])
            let char = Character(scalar)
            return Key(character: char, alt: true)
        }
        return nil
    }

    private func parseSS3Sequence(_ buffer: [UInt8]) -> Key? {
        // Function keys using SS3 (ESC O)
        guard buffer.count == 3 else { return nil }

        switch buffer[2] {
        case 0x50: return Key(type: .function(1))
        case 0x51: return Key(type: .function(2))
        case 0x52: return Key(type: .function(3))
        case 0x53: return Key(type: .function(4))
        default: return nil
        }
    }

    private func parseCSISequence(_ buffer: [UInt8]) -> (any Message)? {
        guard buffer.count >= 3 else { return nil }

        let sequence = buffer[2...].map { String(format: "%c", $0) }.joined()

        // Arrow keys
        switch sequence {
        case "A": return Key(type: .up)
        case "B": return Key(type: .down)
        case "C": return Key(type: .right)
        case "D": return Key(type: .left)
        case "H": return Key(type: .home)
        case "F": return Key(type: .end)
        case "5~": return Key(type: .pageUp)
        case "6~": return Key(type: .pageDown)
        case "2~": return Key(type: .insert)
        case "3~": return Key(type: .delete)
        default: break
        }

        // Function keys
        if sequence.hasSuffix("~") {
            let numberPart = sequence.dropLast()
            if let num = Int(numberPart) {
                switch num {
                case 11...15: return Key(type: .function(num - 10))
                case 17...21: return Key(type: .function(num - 11))
                case 23...24: return Key(type: .function(num - 12))
                default: break
                }
            }
        }

        // Mouse events (SGR mode)
        if sequence.hasPrefix("<") {
            return parseMouseSGR(sequence)
        }

        // Focus events
        if sequence == "I" {
            return FocusMsg()
        } else if sequence == "O" {
            return BlurMsg()
        }

        return UnknownCSISequenceMsg(bytes: buffer)
    }

    private func parseMouseSGR(_ sequence: String) -> MouseEvent? {
        // SGR mouse format: <button;x;y[M/m]
        guard sequence.hasPrefix("<") else { return nil }

        let parts = sequence.dropFirst().dropLast().split(separator: ";")
        guard parts.count == 3,
              let buttonCode = Int(parts[0]),
              let x = Int(parts[1]),
              let y = Int(parts[2]) else { return nil }

        let isRelease = sequence.hasSuffix("m")
        let action: MouseAction = isRelease ? .release : .press

        // Parse button and modifiers
        let buttonBase = buttonCode & 0x03
        let modifiers = buttonCode >> 2

        let button: MouseButton = switch buttonBase {
        case 0: .left
        case 1: .middle
        case 2: .right
        case 3: .noButton // Motion only
        default: .noButton
        }

        let shift = (modifiers & 0x01) != 0
        let alt = (modifiers & 0x02) != 0
        let ctrl = (modifiers & 0x04) != 0

        return MouseEvent(
            x: x - 1, // Convert from 1-based to 0-based
            y: y - 1,
            shift: shift,
            alt: alt,
            ctrl: ctrl,
            action: action,
            button: button
        )
    }
}
