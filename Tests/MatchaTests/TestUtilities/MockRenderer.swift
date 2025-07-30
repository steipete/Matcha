import Foundation
@testable import Matcha

/// Mock renderer that captures all rendering operations
public actor MockRenderer: Renderer {
    public var renderCalls: [String] = []
    public var isStarted = false
    public var isStopped = false

    public private(set) var altScreenActive = false
    public private(set) var bracketedPasteActive = false
    public private(set) var reportsFocus = false
    public private(set) var cursorVisible = true
    public private(set) var windowTitle = ""

    public init() {}

    public func start() async {
        isStarted = true
        renderCalls.append("start()")
    }

    public func stop() async {
        isStopped = true
        renderCalls.append("stop()")
    }

    public func kill() async {
        await stop()
        renderCalls.append("kill()")
    }

    public func write(_ content: String) async {
        renderCalls.append("write(\(content.debugDescription))")
    }

    public func repaint() async {
        renderCalls.append("repaint()")
    }

    public func clearScreen() async {
        renderCalls.append("clearScreen()")
    }

    public func clear() async {
        await clearScreen()
    }

    public func enterAltScreen() async {
        altScreenActive = true
        renderCalls.append("enterAltScreen()")
    }

    public func exitAltScreen() async {
        altScreenActive = false
        renderCalls.append("exitAltScreen()")
    }

    public func showCursor() async {
        cursorVisible = true
        renderCalls.append("showCursor()")
    }

    public func hideCursor() async {
        cursorVisible = false
        renderCalls.append("hideCursor()")
    }

    public func enableMouseCellMotion() async {
        renderCalls.append("enableMouseCellMotion()")
    }

    public func disableMouseCellMotion() async {
        renderCalls.append("disableMouseCellMotion()")
    }

    public func enableMouseAllMotion() async {
        renderCalls.append("enableMouseAllMotion()")
    }

    public func disableMouseAllMotion() async {
        renderCalls.append("disableMouseAllMotion()")
    }

    public func enableMouseSGRMode() async {
        renderCalls.append("enableMouseSGRMode()")
    }

    public func disableMouseSGRMode() async {
        renderCalls.append("disableMouseSGRMode()")
    }

    public func enableBracketedPaste() async {
        bracketedPasteActive = true
        renderCalls.append("enableBracketedPaste()")
    }

    public func disableBracketedPaste() async {
        bracketedPasteActive = false
        renderCalls.append("disableBracketedPaste()")
    }

    public func setWindowTitle(_ title: String) async {
        windowTitle = title
        renderCalls.append("setWindowTitle(\(title.debugDescription))")
    }

    public func enableReportFocus() async {
        reportsFocus = true
        renderCalls.append("enableReportFocus()")
    }

    public func disableReportFocus() async {
        reportsFocus = false
        renderCalls.append("disableReportFocus()")
    }

    public func resetLinesRendered() async {
        renderCalls.append("resetLinesRendered()")
    }

    public func syncScrollArea(lines: [String], topBoundary: Int, bottomBoundary: Int) async {
        renderCalls
            .append(
                "syncScrollArea(lines: \(lines.count), topBoundary: \(topBoundary), bottomBoundary: \(bottomBoundary))"
            )
    }

    public func scrollUp(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        renderCalls
            .append(
                "scrollUp(newLines: \(newLines.count), topBoundary: \(topBoundary), bottomBoundary: \(bottomBoundary))"
            )
    }

    public func scrollDown(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        renderCalls
            .append(
                "scrollDown(newLines: \(newLines.count), topBoundary: \(topBoundary), bottomBoundary: \(bottomBoundary))"
            )
    }

    public func clearScrollArea() async {
        renderCalls.append("clearScrollArea()")
    }

    public func setIgnoredLineRanges(_ ranges: [Range<Int>]) async {
        renderCalls.append("setIgnoredLineRanges(\(ranges.count) ranges)")
    }

    public func setIgnoredLinePatterns(_ patterns: [String]) async {
        renderCalls.append("setIgnoredLinePatterns(\(patterns.count) patterns)")
    }

    public func clearIgnoredLines() async {
        renderCalls.append("clearIgnoredLines()")
    }

    public func setTerminalSize(width: Int, height: Int) async {
        renderCalls.append("setTerminalSize(width: \(width), height: \(height))")
    }

    public var terminalSize: (width: Int, height: Int) {
        get async {
            (width: 80, height: 24)
        }
    }

    public func queueMessageLine(_ line: String) async {
        renderCalls.append("queueMessageLine(\(line.debugDescription))")
    }

    /// Verifies that a specific rendering call was made
    public func verifyCalled(_ expectedCall: String) -> Bool {
        renderCalls.contains(expectedCall)
    }

    /// Gets the number of times a specific call was made
    public func callCount(containing substring: String) -> Int {
        renderCalls.count(where: { $0.contains(substring) })
    }

    /// Resets all captured calls
    public func reset() {
        renderCalls = []
        isStarted = false
        isStopped = false
    }
}
