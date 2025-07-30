import Foundation

/// A no-op renderer implementation for testing or headless operation
public final actor NilRenderer: Renderer {
    private var altScreen = false
    private var reportFocusEnabled = false
    private var bracketedPasteEnabled = false
    private var cursorHidden = false
    
    public init() {}
    
    // MARK: - Renderer Protocol Implementation
    
    public func start() async {
        // No-op
    }
    
    public func stop() async {
        // No-op
    }
    
    public func kill() async {
        // No-op
    }
    
    public func write(_ content: String) async {
        // No-op
    }
    
    public func repaint() async {
        // No-op
    }
    
    public func clearScreen() async {
        // No-op
    }
    
    public func clear() async {
        // No-op
    }
    
    public var altScreenActive: Bool {
        get async {
            return altScreen
        }
    }
    
    public func altScreen() async -> Bool {
        return altScreen
    }
    
    public func enterAltScreen() async {
        altScreen = true
    }
    
    public func exitAltScreen() async {
        altScreen = false
    }
    
    public func showCursor() async {
        cursorHidden = false
    }
    
    public func hideCursor() async {
        cursorHidden = true
    }
    
    public func enableMouseCellMotion() async {
        // No-op
    }
    
    public func disableMouseCellMotion() async {
        // No-op
    }
    
    public func enableMouseAllMotion() async {
        // No-op
    }
    
    public func disableMouseAllMotion() async {
        // No-op
    }
    
    public func enableMouseSGRMode() async {
        // No-op
    }
    
    public func disableMouseSGRMode() async {
        // No-op
    }
    
    public func enableBracketedPaste() async {
        bracketedPasteEnabled = true
    }
    
    public func disableBracketedPaste() async {
        bracketedPasteEnabled = false
    }
    
    public var bracketedPasteActive: Bool {
        get async {
            return bracketedPasteEnabled
        }
    }
    
    public func bracketedPasteActive() async -> Bool {
        return bracketedPasteEnabled
    }
    
    public func setWindowTitle(_ title: String) async {
        // No-op
    }
    
    public var reportsFocus: Bool {
        get async {
            return reportFocusEnabled
        }
    }
    
    public func reportFocus() async -> Bool {
        return reportFocusEnabled
    }
    
    public func enableReportFocus() async {
        reportFocusEnabled = true
    }
    
    public func disableReportFocus() async {
        reportFocusEnabled = false
    }
    
    public func resetLinesRendered() async {
        // No-op
    }
    
    // MARK: - Scroll Area Support
    
    public func syncScrollArea(lines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // No-op
    }
    
    public func scrollUp(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // No-op
    }
    
    public func scrollDown(newLines: [String], topBoundary: Int, bottomBoundary: Int) async {
        // No-op
    }
    
    public func clearScrollArea() async {
        // No-op
    }
    
    // MARK: - Ignored Lines Support
    
    public func setIgnoredLineRanges(_ ranges: [Range<Int>]) async {
        // No-op
    }
    
    public func setIgnoredLinePatterns(_ patterns: [String]) async {
        // No-op
    }
    
    public func clearIgnoredLines() async {
        // No-op
    }
    
    public func setTerminalSize(width: Int, height: Int) async {
        // No-op
    }
    
    public var terminalSize: (width: Int, height: Int) {
        get async {
            (width: 80, height: 24)
        }
    }
    
    public func queueMessageLine(_ line: String) async {
        // No-op
    }
}