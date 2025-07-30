//
//  Renderer.swift
//  Matcha
//
//  Rendering system for terminal output.
//

import Foundation

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
}

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

        // Show cursor on stop
        await showCursor()
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
        altScreenActive = true
    }

    public func exitAltScreen() async {
        guard altScreenActive else { return }
        await writeANSI("?1049l") // Exit alternate screen
        altScreenActive = false
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

    // MARK: - Private Methods

    private func flush() async {
        guard !buffer.isEmpty else { return }

        let newLines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        // Perform minimal redraws using line-by-line diffing
        if altScreenActive && !lastRenderedLines.isEmpty {
            await performDiffRender(newLines: newLines)
        } else {
            // Full redraw for initial render or non-alt screen
            await writeANSI("H") // Home cursor
            await writeANSI("J") // Clear from cursor to end of screen
            var output = output
            output.write(buffer)
            
            // Clear any remaining lines from previous render
            if lastRenderedLines.count > newLines.count {
                for _ in newLines.count..<lastRenderedLines.count {
                    output.write("\n\u{1B}[K") // New line and clear
                }
            }
        }

        // Recycle old line array to buffer pool if possible
        if bufferPool.count < maxPoolSize && !lastRenderedLines.isEmpty {
            bufferPool.append(lastRenderedLines)
        }
        
        lastRenderedLines = newLines
        buffer = ""
    }
    
    private func performDiffRender(newLines: [String]) async {
        var output = output
        let maxLines = max(lastRenderedLines.count, newLines.count)
        
        // Batch updates for better performance
        var updateBatch = ""
        
        for i in 0..<maxLines {
            let oldLine = i < lastRenderedLines.count ? lastRenderedLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""
            
            // Skip unchanged lines
            if oldLine == newLine && i < newLines.count {
                continue
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
        if newLines.count > 0 {
            output.write("\u{1B}[\(newLines.count);1H")
        }
    }

    private func writeANSI(_ code: String) async {
        var output = output
        output.write("\u{1B}[\(code)")
        
        // Ensure output is flushed for SafeOutput
        if let safeOutput = output as? SafeOutput {
            // SafeOutput flushes automatically via DispatchQueue
        }
    }
}

