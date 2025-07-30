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
    private let cancelReader: CancelReader?

    /// The stream of parsed messages
    public var messages: AsyncStream<any Message> {
        messageSubject.stream
    }

    private var task: Task<Void, Never>?

    public init(input: FileHandle, cancelReader: CancelReader? = nil) {
        self.input = input
        self.cancelReader = cancelReader
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
        Task {
            _ = await cancelReader?.cancel()
        }
        messageSubject.continuation.finish()
    }

    private func readInput(input: FileHandle, continuation: AsyncStream<any Message>.Continuation) async {
        let parser = ANSIParser()

        while !Task.isCancelled {
            // Check if cancelled
            if let reader = cancelReader, await reader.isCancelled {
                break
            }
            
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
        case dcs
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
                messages.append(KeyMsg(type: .delete))
            } else {
                // Regular character
                let scalar = UnicodeScalar(byte)
                let char = Character(scalar)
                messages.append(KeyMsg(character: char))
            }

        case .escape:
            buffer.append(byte)

            if byte == 0x5B { // [
                state = .csi
            } else if byte == 0x5D { // ]
                state = .osc
            } else if byte == 0x50 { // P
                state = .dcs
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
                } else if buffer.count == 6 && buffer[2] == 0x4D { // ESC[M (X10 mouse)
                    if let mouse = parseMouseX10(buffer) {
                        messages.append(mouse)
                    }
                    buffer = []
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

        case .dcs:
            buffer.append(byte)

            // DCS sequences end with ST (ESC \)
            if buffer.count >= 2 && buffer[buffer.count - 2] == 0x1B && byte == 0x5C {
                state = .ground
                // Handle DCS sequences
                if let message = parseDCSSequence(buffer) {
                    messages.append(message)
                }
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

    private func parseControlChar(_ byte: UInt8) -> KeyMsg? {
        switch byte {
        case 0x00: KeyMsg(type: .null)
        case 0x01: KeyMsg(type: .ctrlA)
        case 0x02: KeyMsg(type: .ctrlB)
        case 0x03: KeyMsg(type: .ctrlC)
        case 0x04: KeyMsg(type: .ctrlD)
        case 0x05: KeyMsg(type: .ctrlE)
        case 0x06: KeyMsg(type: .ctrlF)
        case 0x07: KeyMsg(type: .ctrlG)
        case 0x08: KeyMsg(type: .backspace)
        case 0x09: KeyMsg(type: .tab)
        case 0x0A, 0x0D: KeyMsg(type: .enter)
        case 0x0B: KeyMsg(type: .ctrlK)
        case 0x0C: KeyMsg(type: .ctrlL)
        case 0x0E: KeyMsg(type: .ctrlN)
        case 0x0F: KeyMsg(type: .ctrlO)
        case 0x10: KeyMsg(type: .ctrlP)
        case 0x11: KeyMsg(type: .ctrlQ)
        case 0x12: KeyMsg(type: .ctrlR)
        case 0x13: KeyMsg(type: .ctrlS)
        case 0x14: KeyMsg(type: .ctrlT)
        case 0x15: KeyMsg(type: .ctrlU)
        case 0x16: KeyMsg(type: .ctrlV)
        case 0x17: KeyMsg(type: .ctrlW)
        case 0x18: KeyMsg(type: .ctrlX)
        case 0x19: KeyMsg(type: .ctrlY)
        case 0x1A: KeyMsg(type: .ctrlZ)
        case 0x1B: KeyMsg(type: .escape)
        case 0x1C: KeyMsg(type: .ctrlBackslash)
        case 0x1D: KeyMsg(type: .ctrlCloseBracket)
        case 0x1E: KeyMsg(type: .ctrlCaret)
        case 0x1F: KeyMsg(type: .ctrlUnderscore)
        default: nil
        }
    }

    private func parseEscapeSequence(_ buffer: [UInt8]) -> KeyMsg? {
        // Simple Alt+key detection
        if buffer.count == 2 {
            let scalar = UnicodeScalar(buffer[1])
            let char = Character(scalar)
            return KeyMsg(character: char, alt: true)
        }
        return nil
    }

    private func parseSS3Sequence(_ buffer: [UInt8]) -> KeyMsg? {
        // Function keys using SS3 (ESC O)
        guard buffer.count == 3 else { return nil }

        switch buffer[2] {
        case 0x50: return KeyMsg(type: .f1)
        case 0x51: return KeyMsg(type: .f2)
        case 0x52: return KeyMsg(type: .f3)
        case 0x53: return KeyMsg(type: .f4)
        default: return nil
        }
    }

    private func parseCSISequence(_ buffer: [UInt8]) -> (any Message)? {
        guard buffer.count >= 3 else { return nil }

        let sequence = buffer[2...].map { String(format: "%c", $0) }.joined()

        // Arrow keys
        switch sequence {
        case "A": return KeyMsg(type: .up)
        case "B": return KeyMsg(type: .down)
        case "C": return KeyMsg(type: .right)
        case "D": return KeyMsg(type: .left)
        case "H": return KeyMsg(type: .home)
        case "F": return KeyMsg(type: .end)
        case "5~": return KeyMsg(type: .pageUp)
        case "6~": return KeyMsg(type: .pageDown)
        case "2~": return KeyMsg(type: .insert)
        case "3~": return KeyMsg(type: .delete)
        default: break
        }

        // Function keys
        if sequence.hasSuffix("~") {
            let numberPart = sequence.dropLast()
            if let num = Int(numberPart) {
                switch num {
                case 11: return KeyMsg(type: .f1)
                case 12: return KeyMsg(type: .f2)
                case 13: return KeyMsg(type: .f3)
                case 14: return KeyMsg(type: .f4)
                case 15: return KeyMsg(type: .f5)
                case 17: return KeyMsg(type: .f6)
                case 18: return KeyMsg(type: .f7)
                case 19: return KeyMsg(type: .f8)
                case 20: return KeyMsg(type: .f9)
                case 21: return KeyMsg(type: .f10)
                case 23: return KeyMsg(type: .f11)
                case 24: return KeyMsg(type: .f12)
                default: break
                }
            }
        }

        // Mouse events
        if sequence.hasPrefix("<") {
            // SGR mode
            return parseMouseSGR(sequence)
        } else if sequence.hasPrefix("M") && buffer.count == 6 {
            // X10 mode
            return parseMouseX10(buffer)
        }

        // Focus events
        if sequence == "I" {
            return FocusMsg()
        } else if sequence == "O" {
            return BlurMsg()
        }

        return UnknownCSISequenceMsg(bytes: buffer)
    }

    private func parseMouseSGR(_ sequence: String) -> MouseMsg? {
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
        case 3: .none // Motion only
        default: .none
        }

        let shift = (modifiers & 0x01) != 0
        let alt = (modifiers & 0x02) != 0
        let ctrl = (modifiers & 0x04) != 0

        let event = MouseEvent(
            x: x - 1, // Convert from 1-based to 0-based
            y: y - 1,
            shift: shift,
            alt: alt,
            ctrl: ctrl,
            action: action,
            button: button
        )
        return MouseMsg(event)
    }
    
    private func parseMouseX10(_ buffer: [UInt8]) -> MouseMsg? {
        // X10 mouse format: ESC[M<button><x><y>
        // Buffer: [ESC, '[', 'M', button+32, x+32, y+32]
        guard buffer.count == 6 else { return nil }
        
        let buttonByte = buffer[3] - 32
        let x = Int(buffer[4] - 32)
        let y = Int(buffer[5] - 32)
        
        // X10 button encoding:
        // bits 0-1: button (0=left, 1=middle, 2=right, 3=release)
        // bit 2: shift
        // bit 3: meta/alt
        // bit 4: ctrl
        // bits 5-6: motion flags
        
        let buttonCode = buttonByte & 0x03
        let shift = (buttonByte & 0x04) != 0
        let alt = (buttonByte & 0x08) != 0
        let ctrl = (buttonByte & 0x10) != 0
        let motion = (buttonByte & 0x20) != 0
        
        // Determine button and action
        let button: MouseButton
        let action: MouseAction
        
        if buttonCode == 3 {
            // Release event
            button = .none
            action = .release
        } else if motion {
            // Motion event with button pressed
            switch buttonCode {
            case 0: button = .left
            case 1: button = .middle
            case 2: button = .right
            default: button = .none
            }
            action = .motion
        } else {
            // Regular button press
            switch buttonCode {
            case 0: button = .left
            case 1: button = .middle
            case 2: button = .right
            default: button = .none
            }
            action = .press
        }
        
        // Check for wheel events (X10 encodes them specially)
        let wheelButton: MouseButton? = if buttonByte >= 64 && buttonByte <= 67 {
            switch buttonByte {
            case 64: .wheelUp
            case 65: .wheelDown
            case 66: .wheelLeft
            case 67: .wheelRight
            default: nil
            }
        } else {
            nil
        }
        
        let finalButton = wheelButton ?? button
        let finalAction: MouseAction = wheelButton != nil ? .press : action
        
        let event = MouseEvent(
            x: x - 1, // Convert from 1-based to 0-based
            y: y - 1,
            shift: shift,
            alt: alt,
            ctrl: ctrl,
            action: finalAction,
            button: finalButton
        )
        return MouseMsg(event)
    }
    
    private func parseDCSSequence(_ buffer: [UInt8]) -> (any Message)? {
        // DCS sequence format: ESC P ... ST
        // For now, we'll create a message to indicate we received a DCS sequence
        // In the future, this can be expanded to handle specific DCS sequences
        
        // Extract the DCS content (excluding ESC P at start and ST at end)
        guard buffer.count > 4 else { return nil }
        
        // The content is between ESC P and ESC \
        let content = Array(buffer[2..<buffer.count-2])
        
        // For now, return an unknown DCS message
        // In the future, we can parse specific DCS sequences here
        return UnknownDCSSequenceMsg(bytes: content)
    }
}
