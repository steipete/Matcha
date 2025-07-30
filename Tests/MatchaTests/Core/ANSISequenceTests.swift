import Foundation
import Testing
@testable import Matcha

@Suite("ANSI Sequence Tests")
struct ANSISequenceTests {
    // MARK: - Clear Screen Tests

    @Test("Clear screen emits correct sequence")
    func clearScreenSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.clearScreen()

        #expect(output.content.contains("\u{1B}[2J")) // Clear entire screen
        #expect(output.content.contains("\u{1B}[H")) // Move cursor to home
    }

    // MARK: - Cursor Tests

    @Test("Hide cursor emits correct sequence")
    func hideCursorSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.hideCursor()

        #expect(output.content == "\u{1B}[?25l")
    }

    @Test("Show cursor emits correct sequence")
    func showCursorSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        // Hide cursor first so show cursor will emit
        await renderer.hideCursor()
        output.clear()

        await renderer.showCursor()

        #expect(output.content == "\u{1B}[?25h")
    }

    // MARK: - Alt Screen Tests

    @Test("Enter alt screen emits correct sequence")
    func enterAltScreenSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.enterAltScreen()

        #expect(output.content.contains("\u{1B}[?1049h")) // Enter alt screen
        #expect(output.content.contains("\u{1B}[2J")) // Clear screen
        #expect(output.content.contains("\u{1B}[H")) // Cursor home
    }

    @Test("Exit alt screen emits correct sequence")
    func exitAltScreenSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        // Enter alt screen first
        await renderer.enterAltScreen()
        output.clear()

        await renderer.exitAltScreen()

        #expect(output.content.contains("\u{1B}[?1049l")) // Exit alt screen
        #expect(output.content.contains("\u{1B}[?25h")) // Show cursor
    }

    // MARK: - Mouse Mode Tests

    @Test("Enable mouse cell motion emits correct sequence")
    func enableMouseCellMotionSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.enableMouseCellMotion()

        #expect(output.content.contains("\u{1B}[?1002h")) // Cell motion
        #expect(output.content.contains("\u{1B}[?1006h")) // SGR mode
    }

    @Test("Enable mouse all motion emits correct sequence")
    func enableMouseAllMotionSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.enableMouseAllMotion()

        #expect(output.content.contains("\u{1B}[?1003h")) // All motion
        #expect(output.content.contains("\u{1B}[?1006h")) // SGR mode
    }

    @Test("Disable mouse emits correct sequences")
    func disableMouseSequences() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.disableMouseCellMotion()
        #expect(output.content.contains("\u{1B}[?1002l"))

        output.clear()

        await renderer.disableMouseAllMotion()
        #expect(output.content.contains("\u{1B}[?1003l"))

        output.clear()

        await renderer.disableMouseSGRMode()
        #expect(output.content.contains("\u{1B}[?1006l"))
    }

    // MARK: - Bracketed Paste Tests

    @Test("Enable bracketed paste emits correct sequence")
    func enableBracketedPasteSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.enableBracketedPaste()

        #expect(output.content == "\u{1B}[?2004h")
    }

    @Test("Disable bracketed paste emits correct sequence")
    func disableBracketedPasteSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        // Enable first so disable will emit
        await renderer.enableBracketedPaste()
        output.clear()

        await renderer.disableBracketedPaste()

        #expect(output.content == "\u{1B}[?2004l")
    }

    // MARK: - Window Title Tests

    @Test("Set window title emits correct sequence")
    func setWindowTitleSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.setWindowTitle("Test Title")

        #expect(output.content == "\u{1B}]0;Test Title\u{07}")
    }

    // MARK: - Focus Reporting Tests

    @Test("Enable report focus emits correct sequence")
    func enableReportFocusSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.enableReportFocus()

        #expect(output.content == "\u{1B}[?1004h")
    }

    @Test("Disable report focus emits correct sequence")
    func disableReportFocusSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        // Enable first so disable will emit
        await renderer.enableReportFocus()
        output.clear()

        await renderer.disableReportFocus()

        #expect(output.content == "\u{1B}[?1004l")
    }

    // MARK: - Scroll Region Tests

    @Test("Scroll up emits insert line sequence")
    func scrollUpSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.scrollUp(newLines: ["New line 1", "New line 2"], topBoundary: 5, bottomBoundary: 10)

        // Should position at top of scroll region and insert lines
        #expect(output.content.contains("\u{1B}[5;1H")) // Position at top of scroll region
        #expect(output.content.contains("\u{1B}[2L")) // Insert 2 lines
        #expect(output.content.contains("New line 1"))
        #expect(output.content.contains("New line 2"))
    }

    @Test("Sync scroll area emits correct sequences")
    func syncScrollAreaSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        let lines = ["Line 1", "Line 2", "Line 3"]
        await renderer.syncScrollArea(lines: lines, topBoundary: 5, bottomBoundary: 8)

        // Should set scroll region and write lines
        #expect(output.content.contains("\u{1B}[5;8r")) // Set scroll region
        #expect(output.content.contains("\u{1B}[5;1H")) // Position at top
        #expect(output.content.contains("\u{1B}[3L")) // Insert 3 lines
        #expect(output.content.contains("Line 1"))
        #expect(output.content.contains("Line 2"))
        #expect(output.content.contains("Line 3"))
    }

    // MARK: - Complex Sequence Tests

    @Test("Program startup sequence")
    func programStartupSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.start()

        // Standard startup sequence
        #expect(output.content.contains("\u{1B}[?25l")) // Hide cursor
        #expect(output.content.contains("\u{1B}[?2004h")) // Enable bracketed paste

        await renderer.stop()

        // Cleanup sequence
        #expect(output.content.contains("\u{1B}[?2004l")) // Disable bracketed paste
        #expect(output.content.contains("\u{1B}[?25h")) // Show cursor
        #expect(output.content.contains("\u{1B}[?1002l")) // Disable mouse
        #expect(output.content.contains("\u{1B}[?1003l"))
        #expect(output.content.contains("\u{1B}[?1006l"))
    }

    @Test("Alt screen with mouse sequence")
    func altScreenWithMouseSequence() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)

        await renderer.start()
        output.clear()

        await renderer.enterAltScreen()
        await renderer.enableMouseCellMotion()

        // Both sequences should be present
        #expect(output.content.contains("\u{1B}[?1049h")) // Alt screen
        #expect(output.content.contains("\u{1B}[?1002h")) // Mouse cell motion
        #expect(output.content.contains("\u{1B}[?1006h")) // SGR mode

        output.clear()

        await renderer.exitAltScreen()

        // Should exit alt screen but keep mouse enabled
        #expect(output.content.contains("\u{1B}[?1049l"))
        #expect(!output.content.contains("\u{1B}[?1002l")) // Mouse not disabled
    }
}
