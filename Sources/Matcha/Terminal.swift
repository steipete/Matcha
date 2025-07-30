//
//  Terminal.swift
//  Matcha
//
//  Terminal control and raw mode handling.
//

import Foundation
#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

/// Provides terminal control functionality
public struct Terminal: Sendable {
    /// The current terminal instance
    public static let current = Terminal()

    private init() {}

    /// Terminal size information
    public struct Size: Sendable {
        public let rows: Int
        public let columns: Int
    }

    /// Gets the current terminal size
    public func getSize() throws -> Size {
        #if os(macOS) || os(Linux)
            var winsize = winsize()
            if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
                return Size(rows: Int(winsize.ws_row), columns: Int(winsize.ws_col))
            } else {
                throw TerminalError.notATTY
            }
        #else
            // Windows implementation would go here
            return Size(rows: 24, columns: 80) // Default size
        #endif
    }

    /// Gets the current terminal state
    public func getState() throws -> TerminalState {
        #if os(macOS) || os(Linux)
            var state = termios()
            if tcgetattr(STDIN_FILENO, &state) != 0 {
                throw TerminalError.notATTY
            }
            return TerminalState(termios: state)
        #else
            return TerminalState()
        #endif
    }

    /// Sets the terminal state
    public func setState(_ state: TerminalState) throws {
        #if os(macOS) || os(Linux)
            var termiosState = state.termios
            if tcsetattr(STDIN_FILENO, TCSAFLUSH, &termiosState) != 0 {
                throw TerminalError.rawModeError(POSIXError(.EINVAL))
            }
        #endif
    }

    /// Enters raw mode for character-by-character input
    public func enterRawMode() throws {
        #if os(macOS) || os(Linux)
            var raw = termios()
            if tcgetattr(STDIN_FILENO, &raw) != 0 {
                throw TerminalError.notATTY
            }

            // Modify flags for raw mode
            raw.c_iflag &= ~UInt(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON)
            raw.c_oflag &= ~UInt(OPOST)
            raw.c_lflag &= ~UInt(ECHO | ECHONL | ICANON | ISIG | IEXTEN)
            raw.c_cflag &= ~UInt(CSIZE | PARENB)
            raw.c_cflag |= UInt(CS8)

            // Set minimum characters and timeout
            // Note: c_cc is a tuple in Swift, not an array
            // We'll use withUnsafeMutablePointer to access it
            withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
                ptr.withMemoryRebound(to: cc_t.self, capacity: 20) { ccPtr in
                    ccPtr[Int(VMIN)] = 1
                    ccPtr[Int(VTIME)] = 0
                }
            }

            // Apply changes
            if tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0 {
                throw TerminalError.rawModeError(POSIXError(.EINVAL))
            }
        #endif
    }

    /// Exits raw mode
    public func exitRawMode() throws {
        // TODO: Restore original termios state
    }

    /// Opens a TTY for input
    public func openTTY() throws -> FileHandle {
        #if os(macOS) || os(Linux)
            let ttyPath = "/dev/tty"
            let fd = open(ttyPath, O_RDONLY)
            if fd < 0 {
                throw TerminalError.notATTY
            }
            return FileHandle(fileDescriptor: fd)
        #else
            throw TerminalError.notATTY
        #endif
    }

    /// Hides the cursor
    public func hideCursor() {
        print("\u{1B}[?25l", terminator: "")
        fflush(stdout)
    }

    /// Shows the cursor
    public func showCursor() {
        print("\u{1B}[?25h", terminator: "")
        fflush(stdout)
    }

    /// Clears the screen
    public func clear() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        fflush(stdout)
    }
}
