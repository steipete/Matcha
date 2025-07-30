import Foundation

// MARK: - Renderer

/// Protocol for terminal renderers
public protocol Renderer: Actor {
    /// Starts the renderer
    func start() async

    /// Stops the renderer
    func stop() async

    /// Forces termination of the renderer
    func kill() async

    /// Writes content to be rendered
    func write(_ content: String) async

    /// Forces an immediate repaint
    func repaint() async

    /// Clears the screen
    func clearScreen() async

    /// Clears the screen (alias for clearScreen)
    func clear() async

    /// Returns whether alternate screen is active
    var altScreenActive: Bool { get async }

    /// Enters alternate screen mode
    func enterAltScreen() async

    /// Exits alternate screen mode
    func exitAltScreen() async

    /// Shows the cursor
    func showCursor() async

    /// Hides the cursor
    func hideCursor() async

    /// Enables mouse cell motion tracking
    func enableMouseCellMotion() async

    /// Disables mouse cell motion tracking
    func disableMouseCellMotion() async

    /// Enables all mouse motion tracking
    func enableMouseAllMotion() async

    /// Disables all mouse motion tracking
    func disableMouseAllMotion() async

    /// Enables SGR mouse mode
    func enableMouseSGRMode() async

    /// Disables SGR mouse mode
    func disableMouseSGRMode() async

    /// Enables bracketed paste mode
    func enableBracketedPaste() async

    /// Disables bracketed paste mode
    func disableBracketedPaste() async

    /// Returns whether bracketed paste is active
    var bracketedPasteActive: Bool { get async }

    /// Sets the window title
    func setWindowTitle(_ title: String) async

    /// Returns whether focus reporting is active
    var reportsFocus: Bool { get async }

    /// Enables focus reporting
    func enableReportFocus() async

    /// Disables focus reporting
    func disableReportFocus() async

    /// Resets the count of rendered lines
    func resetLinesRendered() async

    /// Synchronizes the scroll area with the given lines
    func syncScrollArea(lines: [String], topBoundary: Int, bottomBoundary: Int) async

    /// Scrolls up by adding new lines at the top
    func scrollUp(newLines: [String], topBoundary: Int, bottomBoundary: Int) async

    /// Scrolls down by adding new lines at the bottom
    func scrollDown(newLines: [String], topBoundary: Int, bottomBoundary: Int) async

    /// Clears the scroll area
    func clearScrollArea() async

    /// Sets line ranges that should be ignored during diff calculations
    func setIgnoredLineRanges(_ ranges: [Range<Int>]) async

    /// Sets patterns that identify lines to ignore during diff calculations
    func setIgnoredLinePatterns(_ patterns: [String]) async

    /// Clears all ignored line configuration
    func clearIgnoredLines() async

    /// Updates the terminal dimensions
    func setTerminalSize(width: Int, height: Int) async

    /// Returns the current terminal dimensions
    var terminalSize: (width: Int, height: Int) { get async }

    /// Queues a message line to be printed (for PrintLineMsg support)
    func queueMessageLine(_ line: String) async
}

// MARK: - StandardRenderer

/// Standard frame-based renderer
public actor StandardRenderer: Renderer {
    // MARK: - Properties

    private let output: any TextOutputStream & Sendable
    private let fps: Int
    private var renderTask: Task<Void, Never>?
    private var buffer: String = ""
    private var lastRenderedLines: [String] = []
    private var isRunning = false

    // Performance optimization
    private var pendingUpdates: [LineUpdate] = []
    private var renderCoalesceTimer: Task<Void, Never>?
    private let coalesceInterval: TimeInterval = 0.016 // 16ms for 60fps
    private var bufferPool: [[String]] = []
    private let maxPoolSize = 5

    // State tracking
    public private(set) var altScreenActive = false
    public private(set) var bracketedPasteActive = false
    public private(set) var reportsFocus = false
    private var cursorHidden = false
    private var mouseMode: MouseMode = .disabled

    // Terminal dimensions
    private var terminalWidth: Int = 80
    private var terminalHeight: Int = 24

    // Message queue for PrintLineMsg handling
    private var queuedMessageLines: [String] = []

    // Ignored lines configuration
    private var ignoredLineRanges: [Range<Int>] = []
    private var ignoredLinePatterns: [String] = []

    // MARK: - Line Update Tracking

    private struct LineUpdate {
        let index: Int
        let content: String
        let fullRedraw: Bool
    }

    // MARK: - Initialization

    public init(output: any TextOutputStream & Sendable, fps: Int = 60) {
        self.output = output
        self.fps = min(max(fps, 1), 120) // Clamp between 1-120 FPS
    }

    // MARK: - Renderer Protocol

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Hide cursor initially
        await hideCursor()

        // Enable bracketed paste by default (matching Bubbletea)
        await enableBracketedPaste()

        // Query terminal size at startup - only if we have a real terminal
        // Skip in test environments
        if let outputStream = output as? FileHandle,
           outputStream === FileHandle.standardOutput,
           let size = try? Terminal.current.getSize() {
            terminalWidth = size.columns
            terminalHeight = size.rows
        }

        // Start render loop
        renderTask = Task {
            let interval = 1.0 / Double(fps)
            while !Task.isCancelled {
                await flush()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    public func stop() async {
        isRunning = false
        renderTask?.cancel()
        await renderTask?.value

        // Cleanup sequence
        await disableBracketedPaste()
        await showCursor()

        // Disable all mouse modes
        await writeANSI("?1002l") // Disable cell motion
        await writeANSI("?1003l") // Disable all motion
        await writeANSI("?1006l") // Disable SGR mode
        mouseMode = .disabled
    }

    public func kill() async {
        await stop()
    }

    public func write(_ content: String) async {
        buffer = content

        // Coalesce rapid updates
        renderCoalesceTimer?.cancel()
        renderCoalesceTimer = Task {
            try? await Task.sleep(for: .seconds(coalesceInterval))
            if !Task.isCancelled {
                await flush()
            }
        }
    }

    public func repaint() async {
        await flush()
    }

    public func clearScreen() async {
        await writeANSI("2J") // Clear screen
        await writeANSI("H") // Move cursor to home
        lastRenderedLines = []
    }

    public func clear() async {
        await clearScreen()
    }

    public func enterAltScreen() async {
        guard !altScreenActive else { return }
        await writeANSI("?1049h") // Enter alternate screen
        await writeANSI("2J") // Clear screen
        await writeANSI("H") // Cursor home
        altScreenActive = true

        // Restore cursor visibility state
        if cursorHidden {
            await writeANSI("?25l")
        } else {
            await writeANSI("?25h")
        }
    }

    public func exitAltScreen() async {
        guard altScreenActive else { return }
        await writeANSI("?1049l") // Exit alternate screen
        altScreenActive = false

        // Restore cursor visibility state
        if cursorHidden {
            await writeANSI("?25l")
        } else {
            await writeANSI("?25h")
        }
    }

    public func showCursor() async {
        guard cursorHidden else { return }
        await writeANSI("?25h")
        cursorHidden = false
    }

    public func hideCursor() async {
        guard !cursorHidden else { return }
        await writeANSI("?25l")
        cursorHidden = true
    }

    public func enableMouseCellMotion() async {
        await writeANSI("?1002h")
        await writeANSI("?1006h") // Enable SGR mode
        mouseMode = .cellMotion
    }

    public func disableMouseCellMotion() async {
        await writeANSI("?1002l")
        if mouseMode == .cellMotion {
            mouseMode = .disabled
        }
    }

    public func enableMouseAllMotion() async {
        await writeANSI("?1003h")
        await writeANSI("?1006h") // Enable SGR mode
        mouseMode = .allMotion
    }

    public func disableMouseAllMotion() async {
        await writeANSI("?1003l")
        if mouseMode == .allMotion {
            mouseMode = .disabled
        }
    }

    public func enableMouseSGRMode() async {
        await writeANSI("?1006h")
    }

    public func disableMouseSGRMode() async {
        await writeANSI("?1006l")
    }

    public func enableBracketedPaste() async {
        guard !bracketedPasteActive else { return }
        await writeANSI("?2004h")
        bracketedPasteActive = true
    }

    public func disableBracketedPaste() async {
        guard bracketedPasteActive else { return }
        await writeANSI("?2004l")
        bracketedPasteActive = false
    }

    public func setWindowTitle(_ title: String) async {
        // OSC 0 sets both icon and window title
        var output = output
        output.write("\u{1B}]0;\(title)\u{07}")
    }

    public func enableReportFocus() async {
        guard !reportsFocus else { return }
        await writeANSI("?1004h")
        reportsFocus = true
    }

    public func disableReportFocus() async {
        guard reportsFocus else { return }
        await writeANSI("?1004l")
        reportsFocus = false
    }

    public func resetLinesRendered() async {
        lastRenderedLines = []
    }

    public func syncScrollArea(lines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // Implementation matching Bubble Tea's syncScrollAreaMsg handler
        // This sets up ignored lines and uses insertTop approach

        // Clear any existing ignored lines configuration
        await clearIgnoredLines()

        // Set the scroll area as ignored lines (lines that won't be touched by normal rendering)
        var ranges: [Range<Int>] = []
        if topBoundary < bottomBoundary {
            // Convert 1-based boundaries to 0-based range
            ranges.append((topBoundary - 1)..<bottomBoundary)
        }
        await setIgnoredLineRanges(ranges)

        // Now insert the content at the top of the scroll area
        // This matches Bubble Tea's approach
        var output = output

        // Set scroll region
        output.write("\u{1B}[\(topBoundary);\(bottomBoundary)r")

        // Move cursor to top of scroll area
        output.write("\u{1B}[\(topBoundary);1H")

        // Insert lines - this will set up the initial content
        output.write("\u{1B}[\(lines.count)L")

        // Write the lines
        output.write(lines.joined(separator: "\r\n"))

        // Reset scroll region
        output.write("\u{1B}[0;\(terminalHeight)r")

        // Move cursor back to where rendering expects it
        let lastLine = min(lastRenderedLines.count, terminalHeight)
        output.write("\u{1B}[\(lastLine);1H")
    }

    public func scrollUp(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // Implementation matching Bubble Tea's insertTop
        var output = output

        // Set scroll region (DECSTBM)
        output.write("\u{1B}[\(topBoundary);\(bottomBoundary)r")

        // Move cursor to top of scroll area
        output.write("\u{1B}[\(topBoundary);1H")

        // Insert lines (IL) - this pushes existing content down
        output.write("\u{1B}[\(newLines.count)L")

        // Write the new lines
        output.write(newLines.joined(separator: "\r\n"))

        // Reset scroll region to full terminal height
        output.write("\u{1B}[0;\(terminalHeight)r")

        // Move cursor back to where rendering expects it
        let lastLine = min(lastRenderedLines.count, terminalHeight)
        output.write("\u{1B}[\(lastLine);1H")
    }

    public func scrollDown(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // Implementation matching Bubble Tea's insertBottom
        var output = output

        // Set scroll region (DECSTBM)
        output.write("\u{1B}[\(topBoundary);\(bottomBoundary)r")

        // Move cursor to bottom of scroll area
        output.write("\u{1B}[\(bottomBoundary);1H")

        // Write newline followed by content - this scrolls existing content up
        output.write("\r\n" + newLines.joined(separator: "\r\n"))

        // Reset scroll region to full terminal height
        output.write("\u{1B}[0;\(terminalHeight)r")

        // Move cursor back to where rendering expects it
        let lastLine = min(lastRenderedLines.count, terminalHeight)
        output.write("\u{1B}[\(lastLine);1H")
    }

    public func clearScrollArea() async {
        // Clear any scroll area settings
        // Reset scroll region to full screen
        await writeANSI("r")
    }

    // MARK: - Ignored Lines Configuration

    /// Sets line ranges that should be ignored during diff calculations
    /// Lines in these ranges won't trigger re-renders when they change
    public func setIgnoredLineRanges(_ ranges: [Range<Int>]) async {
        ignoredLineRanges = ranges
    }

    /// Sets patterns that identify lines to ignore during diff calculations
    /// Lines containing these patterns won't trigger re-renders when they change
    public func setIgnoredLinePatterns(_ patterns: [String]) async {
        ignoredLinePatterns = patterns
    }

    /// Clears all ignored line configuration
    public func clearIgnoredLines() async {
        ignoredLineRanges = []
        ignoredLinePatterns = []
    }

    // MARK: - Terminal Size Management

    /// Updates the terminal dimensions
    public func setTerminalSize(width: Int, height: Int) async {
        terminalWidth = width
        terminalHeight = height
    }

    /// Returns the current terminal dimensions
    public var terminalSize: (width: Int, height: Int) {
        get async {
            (width: terminalWidth, height: terminalHeight)
        }
    }

    // MARK: - Message Queue Handling

    /// Queues a message line to be printed (for PrintLineMsg support)
    public func queueMessageLine(_ line: String) async {
        guard !altScreenActive else { return }

        let lines = line.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        queuedMessageLines.append(contentsOf: lines)

        // Trigger a repaint to flush queued messages
        await repaint()
    }

    // MARK: - Private Methods

    private func flush() async {
        // Check if we need to flush queued messages
        let hasQueuedMessages = !queuedMessageLines.isEmpty && !altScreenActive

        guard !buffer.isEmpty || hasQueuedMessages else { return }

        var output = output

        // Flush queued message lines first (only in non-alt screen mode)
        if hasQueuedMessages {
            for line in queuedMessageLines {
                var lineToWrite = line

                // Add erase line right if line is shorter than terminal width
                if line.count < terminalWidth {
                    lineToWrite += "\u{1B}[K" // Erase to end of line
                }

                output.write(lineToWrite)
                output.write("\r\n")
            }

            // Clear the queue
            queuedMessageLines = []
        }

        // Only process regular buffer if it's not empty
        if !buffer.isEmpty {
            let newLines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0) }

            // Perform minimal redraws using line-by-line diffing
            if altScreenActive, !lastRenderedLines.isEmpty, !hasQueuedMessages {
                await performDiffRender(newLines: newLines)
            } else {
                // Full redraw for initial render, non-alt screen, or when messages were queued
                if altScreenActive {
                    await writeANSI("H") // Home cursor
                    await writeANSI("J") // Clear from cursor to end of screen
                }

                // Limit rendering to terminal height
                let linesToRender = min(newLines.count, terminalHeight)
                for i in 0..<linesToRender {
                    output.write(newLines[i])
                    if i < linesToRender - 1 {
                        output.write("\n")
                    }
                }

                // Clear any remaining lines from previous render
                if lastRenderedLines.count > linesToRender {
                    for _ in linesToRender..<min(lastRenderedLines.count, terminalHeight) {
                        output.write("\n\u{1B}[K") // New line and clear
                    }
                }
            }

            // Recycle old line array to buffer pool if possible
            if bufferPool.count < maxPoolSize, !lastRenderedLines.isEmpty {
                bufferPool.append(lastRenderedLines)
            }

            lastRenderedLines = newLines
            buffer = ""
        }
    }

    private func performDiffRender(newLines: [String]) async {
        var output = output
        let maxLines = max(lastRenderedLines.count, newLines.count)

        // Limit rendering to terminal height to avoid rendering beyond visible area
        let renderLines = min(maxLines, terminalHeight)

        // Batch updates for better performance
        var updateBatch = ""

        for i in 0..<renderLines {
            let oldLine = i < lastRenderedLines.count ? lastRenderedLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""

            // Check if this line should be ignored
            let isIgnored = isLineIgnored(lineIndex: i, content: newLine)

            // Skip unchanged lines or ignored lines that changed
            if oldLine == newLine, i < newLines.count {
                continue
            }

            // If the line is ignored and only it changed, skip the update
            if isIgnored, i < lastRenderedLines.count, i < newLines.count {
                // Check if this is the only change by comparing surrounding lines
                let prevSame = i == 0 || (i > 0 &&
                    lastRenderedLines[i - 1] == (i - 1 < newLines.count ? newLines[i - 1] : "")
                )
                let nextSame = i == maxLines - 1 || (i < maxLines - 1 &&
                    i + 1 < lastRenderedLines.count &&
                    lastRenderedLines[i + 1] == (i + 1 < newLines.count ? newLines[i + 1] : "")
                )

                if prevSame, nextSame {
                    // This ignored line changed in isolation, skip rendering
                    continue
                }
            }

            // Always position cursor explicitly for each line update
            updateBatch += "\u{1B}[\(i + 1);1H" // Move to line i+1, column 1

            if i < newLines.count {
                // Clear line first, then write new content
                updateBatch += "\u{1B}[2K" // Clear entire line
                updateBatch += newLine
            } else {
                // Clear extra lines from previous render
                updateBatch += "\u{1B}[2K" // Clear entire line
            }
        }

        // Write batched updates
        if !updateBatch.isEmpty {
            output.write(updateBatch)
        }

        // Position cursor at end of content
        if !newLines.isEmpty {
            output.write("\u{1B}[\(newLines.count);1H")
        }
    }

    /// Checks if a line should be ignored based on configuration
    private func isLineIgnored(lineIndex: Int, content: String) -> Bool {
        // Check if line index is in any ignored range
        for range in ignoredLineRanges where range.contains(lineIndex) {
            return true
        }

        // Check if line content matches any ignored pattern
        for pattern in ignoredLinePatterns where content.contains(pattern) {
            return true
        }

        return false
    }

    private func writeANSI(_ code: String) async {
        var output = output
        output.write("\u{1B}[\(code)")

        // Ensure output is flushed for SafeOutput
        if output is SafeOutput {
            // SafeOutput flushes automatically via DispatchQueue
        }
    }
}
