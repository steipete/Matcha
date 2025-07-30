//
//  Program.swift
//  Matcha
//
//  Main program runner for Matcha TUI applications.
//

import Foundation

/// Options for configuring a Program
public struct ProgramOptions: Sendable {
    /// The output writer (defaults to stdout)
    public var output: any TextOutputStream & Sendable = SafeOutput()

    /// The input source (defaults to stdin)
    public var input: FileHandle = .standardInput

    /// Whether to use alternate screen buffer
    public var useAltScreen: Bool = false

    /// Whether to enable mouse support
    public var mouseMode: MouseMode = .disabled

    /// The target frame rate for rendering (default 60 FPS)
    public var fps: Int = 60

    /// Whether to report focus events
    public var reportFocus: Bool = false

    /// Whether to enable bracketed paste mode
    public var enableBracketedPaste: Bool = true

    /// Whether to catch panics
    public var catchPanics: Bool = true

    /// Whether to handle system signals
    public var handleSignals: Bool = true

    /// Optional message filter
    public var filter: (@Sendable (any Model, any Message) -> (any Message)?)?

    /// Environment variables
    public var environment: [String: String] = ProcessInfo.processInfo.environment

    /// Default options
    public static let `default` = ProgramOptions()

    public init() {}
}

/// Mouse tracking modes
public enum MouseMode: Sendable {
    /// No mouse tracking
    case disabled
    /// Track only mouse button presses
    case cellMotion
    /// Track all mouse movement
    case allMotion
}

/// Errors that can occur during program execution
public enum ProgramError: Error, Sendable {
    /// The program panicked during execution
    case panic(String)
    /// The program was forcefully killed
    case killed
    /// The program was interrupted
    case interrupted
    /// Terminal I/O error
    case terminalError(Error)
}

/// The main program runner for Matcha applications
@MainActor
public final class Program<M: Model> {
    // MARK: - Properties

    /// The current model state
    private var model: M

    /// The initial model for reset purposes
    private let initialModel: M

    /// Program options
    private let options: ProgramOptions

    /// The renderer for output
    private var renderer: (any Renderer)?

    /// Input handler
    private var inputHandler: InputHandler?

    /// Whether the program is currently running
    private var isRunning = false

    /// Task for the main run loop
    private var runTask: Task<Void, Never>?

    /// Channel for receiving messages
    private let messageChannel = AsyncChannel<any Message>()

    /// Original terminal state for restoration
    private var originalTerminalState: TerminalState?

    // MARK: - Initialization

    /// Creates a new program with the given initial model and options
    public init(initialModel: M, options: ProgramOptions = .default) {
        model = initialModel
        self.initialModel = initialModel
        self.options = options
    }

    // MARK: - Public Methods

    /// Runs the program and returns the final model state
    @discardableResult
    public func run() async throws -> M {
        guard !isRunning else {
            throw ProgramError.terminalError(TerminalError.alreadyRunning)
        }

        isRunning = true
        defer { isRunning = false }

        // Setup phase
        try await setup()

        // Run the main loop
        await withTaskCancellationHandler {
            await mainLoop()
        } onCancel: {
            Task { @MainActor in
                await self.shutdown()
            }
        }

        // Cleanup phase
        await cleanup()

        return model
    }

    /// Sends a message to the program from outside the main loop
    public func send(_ message: any Message) {
        guard isRunning else { return }
        Task {
            await messageChannel.send(message)
        }
    }

    /// Gracefully quits the program
    public func quit() {
        send(QuitMsg())
    }

    /// Forcefully kills the program
    public func kill() {
        runTask?.cancel()
    }

    /// Waits for the program to finish
    public func wait() async {
        await runTask?.value
    }

    /// Temporarily releases terminal control
    public func releaseTerminal() async throws {
        guard isRunning else { return }
        
        // Hide cursor and exit alt screen if needed
        await renderer?.showCursor()
        if options.useAltScreen {
            await renderer?.exitAltScreen()
        }
        
        // Restore terminal state
        if let originalState = originalTerminalState {
            try Terminal.current.setState(originalState)
        }
        
        // Stop the renderer temporarily
        await renderer?.stop()
    }

    /// Restores terminal control
    public func restoreTerminal() async throws {
        guard isRunning else { return }
        
        // Re-enter raw mode
        try Terminal.current.enterRawMode()
        
        // Restart the renderer
        await renderer?.start()
        
        // Re-enter alt screen if needed
        if options.useAltScreen {
            await renderer?.enterAltScreen()
        }
        
        // Restore mouse mode
        switch options.mouseMode {
        case .disabled:
            break
        case .cellMotion:
            await renderer?.enableMouseCellMotion()
        case .allMotion:
            await renderer?.enableMouseAllMotion()
        }
        
        // Restore other settings
        if options.enableBracketedPaste {
            await renderer?.enableBracketedPaste()
        }
        
        if options.reportFocus {
            await renderer?.enableReportFocus()
        }
        
        // Hide cursor and force a full redraw
        await renderer?.hideCursor()
        await renderer?.clearScreen()
        await render()
    }

    /// Prints formatted text to the terminal output
    public func println(_ items: Any...) async throws {
        guard isRunning else { return }
        
        // Temporarily show cursor and pause rendering
        await renderer?.showCursor()
        await renderer?.stop()
        
        // Format the output
        let formattedString = items.map { String(describing: $0) }.joined(separator: " ")
        
        // Write directly to output
        print(formattedString)
        
        // Restart rendering
        await renderer?.start()
        await renderer?.hideCursor()
        await render()
    }

    /// Prints formatted text to the terminal output using format string
    public func printf(_ format: String, _ args: Any...) async throws {
        guard isRunning else { return }
        
        // Temporarily show cursor and pause rendering  
        await renderer?.showCursor()
        await renderer?.stop()
        
        // Format the output
        let formattedString = String(format: format, arguments: args.map { arg in
            if let intArg = arg as? Int { return String(intArg) as CVarArg }
            else if let doubleArg = arg as? Double { return doubleArg as CVarArg }
            else if let stringArg = arg as? String { return stringArg as CVarArg }
            else { return String(describing: arg) as CVarArg }
        })
        
        // Write directly to output
        print(formattedString, terminator: "")
        
        // Restart rendering
        await renderer?.start()
        await renderer?.hideCursor()
        await render()
    }

    // MARK: - Private Methods

    private func setup() async throws {
        // Save original terminal state
        originalTerminalState = try Terminal.current.getState()

        // Enter raw mode
        try Terminal.current.enterRawMode()

        // Setup renderer
        let renderer = StandardRenderer(
            output: options.output,
            fps: options.fps
        )
        self.renderer = renderer
        await renderer.start()

        // Setup alt screen if requested
        if options.useAltScreen {
            await renderer.enterAltScreen()
            await renderer.clearScreen()
        }

        // Setup mouse mode
        switch options.mouseMode {
        case .disabled:
            break
        case .cellMotion:
            await renderer.enableMouseCellMotion()
        case .allMotion:
            await renderer.enableMouseAllMotion()
        }
        
        if options.enableBracketedPaste {
            await renderer.enableBracketedPaste()
        }
        
        if options.reportFocus {
            await renderer.enableReportFocus()
        }
        
        // Hide cursor and clear screen for initial render
        await renderer.hideCursor()
        await renderer.clearScreen()
        
        // Setup input handler
        let inputHandler = InputHandler(input: options.input)
        self.inputHandler = inputHandler
        
        // Start input handling
        Task {
            for await message in inputHandler.messages {
                await messageChannel.send(message)
            }
        }
        
        // Setup signal handlers if requested
        if options.handleSignals {
            SignalManager.shared.onSignal = { signal in
                Task { @MainActor in
                    switch signal {
                    case .interrupt:
                        await self.messageChannel.send(InterruptMsg())
                    case .suspend:
                        await self.messageChannel.send(SuspendMsg())
                    case .windowChanged:
                        if let size = try? Terminal.current.getSize() {
                            await self.messageChannel.send(WindowSizeMsg(width: size.columns, height: size.rows))
                        } else {
                            await self.messageChannel.send(WindowSizeMsg(width: 80, height: 24))
                        }
                    case .terminated:
                        await self.messageChannel.send(QuitMsg())
                    case .continued:
                        await self.messageChannel.send(ResumeMsg())
                    }
                }
            }
        }
        
        // Get initial window size
        if let size = try? Terminal.current.getSize() {
            await messageChannel.send(WindowSizeMsg(width: size.columns, height: size.rows))
        }
        
        await render()
    }

    private func cleanup() async {
        // Stop input handling
        inputHandler?.stop()
        
        // Show cursor
        await renderer?.showCursor()
        
        // Exit alt screen if we're using it
        if options.useAltScreen {
            await renderer?.exitAltScreen()
        }
        
        // Disable mouse modes
        await renderer?.disableMouseAllMotion()
        await renderer?.disableMouseCellMotion()
        
        // Disable bracketed paste
        await renderer?.disableBracketedPaste()
        
        // Disable focus reporting
        await renderer?.disableReportFocus()
        
        // Stop renderer
        await renderer?.stop()
        
        // Restore terminal state
        if let originalState = originalTerminalState {
            try? Terminal.current.setState(originalState)
        }
    }

    private func mainLoop() async {
        // Initial render
        await render()

        // Message processing loop
        for await message in messageChannel {
            // Handle system messages first
            if await handleSystemMessage(message) {
                continue
            }

            // Apply filter if present
            let filteredMessage: any Message
            if let filter = options.filter {
                if let filtered = filter(model, message) {
                    filteredMessage = filtered
                } else {
                    continue // Message was filtered out
                }
            } else {
                filteredMessage = message
            }

            // Check filtered message for system messages
            if await handleSystemMessage(filteredMessage) {
                continue
            }

            // Type-erase and dispatch to model
            if let msg = filteredMessage as? M.Msg {
                let (newModel, command) = model.update(msg)
                model = newModel

                // Execute any resulting command
                if let command {
                    Task {
                        if let resultMessage = await command.execute() {
                            await messageChannel.send(resultMessage)
                        }
                    }
                }

                // Render the updated view
                await render()
            }
        }
    }

    private func handleSystemMessage(_ message: any Message) async -> Bool {
        switch message {
        case is QuitMsg:
            // Signal to exit the main loop
            await messageChannel.finish()
            return true

        case is SuspendMsg:
            // TODO: Implement suspend functionality
            return true

        case is InterruptMsg:
            // TODO: Implement interrupt handling
            return true

        case let msg as SetWindowTitleMsg:
            await renderer?.setWindowTitle(msg.title)
            return true

        case is ClearScreenMsg:
            await renderer?.clear()
            return true

        case is EnterAltScreenMsg:
            await renderer?.enterAltScreen()
            return true

        case is ExitAltScreenMsg:
            await renderer?.exitAltScreen()
            return true

        case is ShowCursorMsg:
            await renderer?.showCursor()
            return true

        case is HideCursorMsg:
            await renderer?.hideCursor()
            return true

        case let msg as ExecMessage:
            // Execute the command in a separate task
            Task { @MainActor in
                self.executeCommand(msg.command, callback: msg.callback, stdin: msg.stdin, stdout: msg.stdout, stderr: msg.stderr)
            }
            return true

        case is EnableReportFocusMsg:
            await renderer?.enableReportFocus()
            return true

        case is DisableReportFocusMsg:
            await renderer?.disableReportFocus()
            return true

        case is EnableBracketedPasteMsg:
            await renderer?.enableBracketedPaste()
            return true

        case is DisableBracketedPasteMsg:
            await renderer?.disableBracketedPaste()
            return true

        case let msg as PrintLineMsg:
            // Temporarily stop rendering to print
            await renderer?.stop()
            print("\r\u{1B}[K", terminator: "")
            print(msg.text)
            await renderer?.start()
            await render()
            return true

        case let msg as PrintFormattedMsg:
            // Temporarily stop rendering to print
            await renderer?.stop()
            print("\r\u{1B}[K", terminator: "")
            print(msg.text)
            await renderer?.start()
            await render()
            return true

        default:
            return false
        }
    }

    private func render() async {
        let view = model.view()
        await renderer?.write(view)
    }


    private func shutdown() async {
        await messageChannel.finish()
        await cleanup()
    }
}

// MARK: - Supporting Types

/// Represents saved terminal state
public struct TerminalState: Sendable {
    #if os(macOS) || os(Linux)
        let termios: termios

        init(termios: termios) {
            self.termios = termios
        }
    #endif

    init() {
        #if os(macOS) || os(Linux)
            termios = Darwin.termios()
        #endif
    }
}

/// Terminal-related errors
public enum TerminalError: Error, Sendable {
    case alreadyRunning
    case notATTY
    case rawModeError(Error)
}

// MARK: - Async Channel for Message Passing

/// A simple async channel for message passing
actor AsyncChannel<Element: Sendable> {
    private var buffer: [Element] = []
    private var continuations: [CheckedContinuation<Element?, Never>] = []
    private var isFinished = false

    func send(_ element: Element) {
        guard !isFinished else { return }

        if let continuation = continuations.first {
            continuations.removeFirst()
            continuation.resume(returning: element)
        } else {
            buffer.append(element)
        }
    }

    func finish() {
        isFinished = true
        // Resume all waiting continuations with nil to signal completion
        for continuation in continuations {
            continuation.resume(returning: nil)
        }
        continuations.removeAll()
    }

    fileprivate func next() async -> Element? {
        if isFinished, buffer.isEmpty {
            return nil
        }

        if !buffer.isEmpty {
            return buffer.removeFirst()
        }

        return await withCheckedContinuation { continuation in
            if isFinished {
                continuation.resume(returning: nil)
            } else {
                continuations.append(continuation)
            }
        }
    }
}

// Make AsyncChannel conform to AsyncSequence
extension AsyncChannel: AsyncSequence {
    typealias Element = Element

    struct AsyncIterator: AsyncIteratorProtocol {
        let channel: AsyncChannel<Element>

        mutating func next() async -> Element? {
            await channel.next()
        }
    }

    nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(channel: self)
    }
}
