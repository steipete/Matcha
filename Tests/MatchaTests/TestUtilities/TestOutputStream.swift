import Foundation
@testable import Matcha

// MARK: - TestOutputStream

/// Test output stream that conforms to TextOutputStream for use with StandardRenderer and ProgramOptions
/// This version interprets basic ANSI escape sequences for testing
public final class TestOutputStream: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var _content = ""
    private var interpretANSI: Bool

    public init(interpretANSI: Bool = true) {
        self.interpretANSI = interpretANSI
    }

    public var content: String {
        lock.lock()
        defer { lock.unlock() }
        return _content
    }

    public func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }

        if interpretANSI {
            _content = processANSI(_content + string)
        } else {
            _content += string
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _content = ""
    }

    public func reset() {
        clear()
    }

    /// Process ANSI escape sequences to simulate terminal behavior
    private func processANSI(_ input: String) -> String {
        var result = input

        // Clear screen: ESC[2J
        if result.contains("\u{1B}[2J") {
            result = ""
        }

        // Home cursor: ESC[H or ESC[1;1H
        if result.contains("\u{1B}[H") || result.contains("\u{1B}[1;1H") {
            // After clearing screen and homing, we start fresh
            result = result.replacingOccurrences(of: "\u{1B}[H", with: "")
            result = result.replacingOccurrences(of: "\u{1B}[1;1H", with: "")
        }

        // Clear from cursor to end of screen: ESC[J
        if let range = result.range(of: "\u{1B}[J") {
            result = String(result[..<range.lowerBound])
        }

        // Remove other ANSI sequences for clean output
        // This is a simplified version - just removes common sequences
        let ansiPattern = "\u{1B}\\[[0-9;]*[A-Za-z]"
        if let regex = try? NSRegularExpression(pattern: ansiPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }

        // Remove cursor hide/show sequences
        result = result.replacingOccurrences(of: "\u{1B}[?25l", with: "")
        result = result.replacingOccurrences(of: "\u{1B}[?25h", with: "")
        result = result.replacingOccurrences(of: "\u{1B}[?2004h", with: "")
        result = result.replacingOccurrences(of: "\u{1B}[?2004l", with: "")

        return result
    }
}

/// Test output stream that can be used as TextOutputStream in ProgramOptions
/// This wraps TestOutputStream to make it easy to use
public typealias TestOutput = TestOutputStream
