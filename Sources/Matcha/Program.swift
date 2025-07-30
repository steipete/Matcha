import Foundation

// MARK: - ProgramOptions

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

    /// External context to use for the program
    public var context: Task<Void, Never>?

    /// Whether to use TTY for input even if stdin is not a TTY
    public var forceTTY: Bool = false

    /// Whether to disable signal handling entirely
    public var disableSignals: Bool = false

    /// Whether to disable the renderer (for headless operation)
    public var disableRenderer: Bool = false

    /// Whether to disable input handling (for testing)
    public var disableInput: Bool = false

    /// Default options
    public static let `default` = ProgramOptions()

    public init() {}
}

// MARK: - MouseMode

/// Mouse tracking modes
public enum MouseMode: Sendable {
    /// No mouse tracking
    case disabled
    /// Track only mouse button presses
    case cellMotion
    /// Track all mouse movement
    case allMotion
}

// MARK: - ProgramError

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

// MARK: - Program Option Helpers

/// Type alias for program option functions
public typealias ProgramOption = (inout ProgramOptions) -> Void

/// Create a new program with the given model and options
@MainActor
public func NewProgram<M: Model>(_ model: M, _ opts: ProgramOption...) -> Program<M> {
    var options = ProgramOptions.default
    for opt in opts {
        opt(&options)
    }
    return Program(initialModel: model, options: options)
}

/// WithOutput sets the output which, by default, is stdout. In most cases you
/// won't need to use this.
public func WithOutput(_ output: any TextOutputStream & Sendable) -> ProgramOption {
    { options in
        options.output = output
    }
}

/// WithInput sets the input which, by default, is stdin. In most cases you
/// won't need to use this.
public func WithInput(_ input: FileHandle) -> ProgramOption {
    { options in
        options.input = input
    }
}

/// WithInputTTY forces the program to use TTY for input even if stdin is not a TTY.
public func WithInputTTY() -> ProgramOption {
    { options in
        options.forceTTY = true
    }
}

/// WithEnvironment sets the environment variables that the program will use.
/// This useful when the program is running in a remote session (e.g. SSH) and
/// you want to pass the environment variables from the remote session to the
/// program.
public func WithEnvironment(_ env: [String: String]) -> ProgramOption {
    { options in
        options.environment = env
    }
}

/// WithoutSignalHandler disables the signal handler that Bubble Tea sets up for
/// Programs. This is useful if you want to handle signals yourself.
public func WithoutSignalHandler() -> ProgramOption {
    { options in
        options.handleSignals = false
    }
}

/// WithoutCatchPanics disables the panic catching that Bubble Tea does by
/// default. If panic catching is disabled the terminal will be in a fairly
/// unusable state after a panic because Bubble Tea will not perform its usual
/// cleanup on exit.
public func WithoutCatchPanics() -> ProgramOption {
    { options in
        options.catchPanics = false
    }
}

/// WithoutSignals will ignore OS signals.
/// This is mainly useful for testing.
public func WithoutSignals() -> ProgramOption {
    { options in
        options.disableSignals = true
    }
}

/// WithAltScreen starts the program with the alternate screen buffer enabled
/// (i.e. the program starts in full window mode). Note that the altscreen will
/// be automatically exited when the program quits.
public func WithAltScreen() -> ProgramOption {
    { options in
        options.useAltScreen = true
    }
}

/// WithoutBracketedPaste starts the program with bracketed paste disabled.
public func WithoutBracketedPaste() -> ProgramOption {
    { options in
        options.enableBracketedPaste = false
    }
}

/// WithMouseCellMotion starts the program with the mouse enabled in "cell
/// motion" mode.
///
/// Cell motion mode enables mouse click, release, and wheel events. Mouse
/// movement events are also captured if a mouse button is pressed (i.e., drag
/// events). Cell motion mode is better supported than all motion mode.
public func WithMouseCellMotion() -> ProgramOption {
    { options in
        options.mouseMode = .cellMotion
    }
}

/// WithMouseAllMotion starts the program with the mouse enabled in "all motion"
/// mode.
///
/// EnableMouseAllMotion is a special command that enables mouse click, release,
/// wheel, and motion events, which are delivered regardless of whether a mouse
/// button is pressed, effectively enabling support for hover interactions.
public func WithMouseAllMotion() -> ProgramOption {
    { options in
        options.mouseMode = .allMotion
    }
}

/// WithoutRenderer disables the renderer. This is useful for testing and
/// headless operation.
public func WithoutRenderer() -> ProgramOption {
    { options in
        options.disableRenderer = true
    }
}

/// WithFPS sets the maximum FPS (frames per second) at which the renderer will
/// run. The default is 60.
public func WithFPS(_ fps: Int) -> ProgramOption {
    { options in
        options.fps = fps
    }
}

/// WithFilter sets a message filter function. If a filter is set, all messages
/// will be passed through it and potentially transformed or blocked (by
/// returning nil).
public func WithFilter(_ filter: @escaping @Sendable (any Model, any Message) -> (any Message)?) -> ProgramOption {
    { options in
        options.filter = filter
    }
}

/// WithReportFocus enables focus reporting. When enabled, the program will
/// receive FocusMsg and BlurMsg when the terminal gains or loses focus.
public func WithReportFocus() -> ProgramOption {
    { options in
        options.reportFocus = true
    }
}

/// WithContext lets you specify a context in which to run the Program. This is
/// useful if you want to cancel the execution from outside. When a Program gets
/// cancelled it will exit with an error ErrProgramKilled.
public func WithContext(_ context: Task<Void, Never>) -> ProgramOption {
    { options in
        options.context = context
    }
}

/// WithANSICompressor removes redundant ANSI sequences to produce potentially
/// smaller output, at the cost of some processing overhead.
///
/// This feature is provisional, and may be changed or removed in a future version
/// of this package.
///
/// Deprecated: this incurs a noticeable performance hit. A future release will
/// optimize ANSI automatically without the performance penalty.
@available(
    *,
    deprecated,
    message: "This incurs a noticeable performance hit. A future release will optimize ANSI automatically without the performance penalty."
)
public func WithANSICompressor() -> ProgramOption {
    { _ in
        // Note: In Swift implementation, we don't implement ANSI compression
        // as it's deprecated and will be replaced with automatic optimization
    }
}

// MARK: - Program

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

    /// Kill flag to signal program termination
    private var isKilled = false

    /// Channel for receiving messages
    private let messageChannel = AsyncChannel<any Message>()

    /// Channel for receiving errors
    private let errorChannel = AsyncChannel<Error>()

    /// Original terminal state for restoration
    private var originalTerminalState: TerminalState?

    /// Context task for cancellation
    private var contextTask: Task<Void, Never>?

    /// Completion handler called when program finishes
    private var finishedHandler: (@Sendable () async -> Void)?

    /// Cancel reader for input handling (similar to Bubbletea's cancelReader)
    private var cancelReader: CancelReader?

    /// Queue for messages sent before run() is called
    private var earlyMessageQueue: [any Message] = []
    
    /// Active command tasks
    /// Note: Like Bubbletea, we don't wait on these during shutdown to avoid latency.
    /// Commands can run for a long time and Swift Tasks can't be forcefully cancelled.
    private var commandTasks: Set<Task<Void, Never>> = []

    // MARK: - Initialization

    /// Creates a new program with the given initial model and options
    public init(initialModel: M, options: ProgramOptions = .default) {
        self.model = initialModel
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
        defer {
            isRunning = false
            isKilled = false
        }

        // Send any queued messages before starting main loop
        let queuedMessages = earlyMessageQueue
        earlyMessageQueue.removeAll()
        for msg in queuedMessages {
            await messageChannel.send(msg)
        }

        // Create actor to safely store error across tasks
        let errorStore = ErrorStore()

        // Panic recovery if enabled
        if options.catchPanics {
            do {
                // Setup phase
                try await setup(errorStore: errorStore)

                // Run the main loop with panic recovery
                await withTaskCancellationHandler {
                    await mainLoop()
                } onCancel: {
                    Task { @MainActor in
                        await self.shutdown()
                    }
                }
            } catch {
                await errorStore.setError(error)
                await recoverFromPanic(error)
            }
        } else {
            // Setup phase
            try await setup(errorStore: errorStore)

            // Run the main loop
            await withTaskCancellationHandler {
                await mainLoop()
            } onCancel: {
                Task { @MainActor in
                    await self.shutdown()
                }
            }
        }

        // Cleanup phase
        await cleanup()

        // Handle different error cases like Bubbletea
        if let error = await errorStore.getError() {
            // Check for context cancellation
            if error is CancellationError {
                // Check if external context was cancelled
                if let context = options.context, context.isCancelled {
                    // Return error that includes external context cancellation
                    throw ErrProgramKilled(underlyingError: CancellationError())
                } else {
                    // Internal cancellation only
                    throw ErrProgramKilled()
                }
            } else if error is ErrInterrupted {
                // Pass through interrupt errors
                throw error
            } else if error is ErrProgramPanic {
                // Pass through panic errors
                throw error
            } else {
                // Wrap other errors as killed with underlying error
                throw ErrProgramKilled(underlyingError: error)
            }
        }

        return model
    }

    /// Sends a message to the program from outside the main loop
    public func send(_ message: any Message) {
        if isRunning {
            Task {
                await messageChannel.send(message)
            }
        } else {
            // Queue messages sent before run() is called
            earlyMessageQueue.append(message)
        }
    }

    /// Gracefully quits the program
    public func quit() {
        send(QuitMsg())
    }

    /// Forcefully kills the program
    public func kill() {
        isKilled = true
        Task {
            await errorChannel.send(CancellationError())
            await messageChannel.finish()
        }
    }

    /// Waits for the program to finish
    public func wait() async {
        await runTask?.value
    }

    /// Sets a completion handler to be called when the program finishes
    public func onFinished(_ handler: @escaping @Sendable () async -> Void) {
        finishedHandler = handler
    }

    /// Sends an error to the error channel
    public func sendError(_ error: Error) {
        Task {
            await errorChannel.send(error)
        }
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

        let isTestMode = !(options.input === FileHandle.standardInput)
        if !isTestMode {
            // Re-enter raw mode
            try Terminal.current.enterRawMode()
        }

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

    /// Suspends the program (Ctrl+Z)
    private func suspend() async {
        do {
            // Release terminal before suspending
            try await releaseTerminal()

            // Send SIGTSTP to suspend the process
            #if os(macOS)
                Darwin.kill(getpid(), SIGTSTP)
            #elseif os(Linux)
                Glibc.kill(getpid(), SIGTSTP)
            #endif

            // When we resume, restore terminal and send ResumeMsg
            // Note: The actual resume will happen when SIGCONT is received
            // which triggers the continued signal handler
        } catch {
            // If we can't release terminal, don't suspend
            debugPrint("Failed to release terminal for suspension: \(error)")
        }
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
            if let intArg = arg as? Int { String(intArg) as CVarArg } else if let doubleArg = arg as? Double { doubleArg as CVarArg } else if let stringArg = arg as? String { stringArg as CVarArg } else { String(describing: arg) as CVarArg }
        })

        // Write directly to output
        print(formattedString, terminator: "")

        // Restart rendering
        await renderer?.start()
        await renderer?.hideCursor()
        await render()
    }

    // MARK: - Private Methods

    private func setup(errorStore: ErrorStore) async throws {
        // Skip terminal setup if using custom input/output (e.g., in tests)
        let isTestMode = !(options.input === FileHandle.standardInput)

        if !isTestMode {
            // Save original terminal state
            originalTerminalState = try Terminal.current.getState()

            // Enter raw mode
            try Terminal.current.enterRawMode()
        }

        // Setup renderer if not disabled
        if !options.disableRenderer {
            let renderer = StandardRenderer(
                output: options.output,
                fps: options.fps
            )
            self.renderer = renderer
            await renderer.start()
        }

        // Setup alt screen if requested
        if options.useAltScreen {
            await renderer?.enterAltScreen()
            await renderer?.clearScreen()
        }

        // Setup mouse mode
        switch options.mouseMode {
        case .disabled:
            break
        case .cellMotion:
            await renderer?.enableMouseCellMotion()
        case .allMotion:
            await renderer?.enableMouseAllMotion()
        }

        if options.enableBracketedPaste {
            await renderer?.enableBracketedPaste()
        }

        if options.reportFocus {
            await renderer?.enableReportFocus()
        }

        // Hide cursor and clear screen for initial render
        await renderer?.hideCursor()
        await renderer?.clearScreen()

        // Setup context if provided and monitor for cancellation
        if let context = options.context {
            contextTask = context

            // Monitor external context for cancellation
            Task {
                await context.value
                // External context was cancelled, send error
                await errorChannel.send(ErrProgramKilled(underlyingError: CancellationError()))
            }
        }

        // Setup cancel reader
        let asyncCancelReader = AsyncCancelReader()
        cancelReader = asyncCancelReader

        // Setup input handler unless disabled
        if !options.disableInput {
            let inputSource: FileHandle = if isTestMode {
                options.input
            } else {
                options.forceTTY ? try Terminal.current.openTTY() : options.input
            }
            let inputHandler = InputHandler(input: inputSource, cancelReader: asyncCancelReader)
            self.inputHandler = inputHandler

            // Start input handling
            Task {
                for await message in inputHandler.messages {
                    await messageChannel.send(message)
                }
            }
        }

        // Start error handling task
        Task {
            for await error in errorChannel {
                // Handle critical errors that should terminate the program
                if error is ErrProgramKilled || error is ErrProgramPanic || error is CancellationError {
                    // Store the error for later handling
                    await errorStore.setError(error)
                    // Signal to exit the main loop
                    await messageChannel.finish()
                } else {
                    // Log non-critical errors
                    debugPrint("Program error: \(error)")
                }
            }
        }

        // Setup signal handlers if requested and not disabled
        if options.handleSignals, !options.disableSignals, !isTestMode {
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
                        // Restore terminal after suspension
                        do {
                            try await self.restoreTerminal()
                            await self.messageChannel.send(ResumeMsg())
                        } catch {
                            debugPrint("Failed to restore terminal after suspension: \(error)")
                        }
                    }
                }
            }
        }

        // Get initial window size
        if !isTestMode, let size = try? Terminal.current.getSize() {
            await messageChannel.send(WindowSizeMsg(width: size.columns, height: size.rows))
        } else if isTestMode {
            // Send a default size for tests
            await messageChannel.send(WindowSizeMsg(width: 80, height: 24))
        }

        // Execute the model's init command
        if let initCommand = model.`init`() {
            let task = Task {
                await executeCommand(initCommand)
            }
            commandTasks.insert(task)
            // Clean up when done
            Task {
                _ = await task.value
                commandTasks.remove(task)
            }
        }

        await render()
    }

    private func cleanup() async {
        // Stop input handling
        inputHandler?.stop()

        // Cancel the reader
        Task {
            _ = await cancelReader?.cancel()
        }

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

        // Restore terminal state if not in test mode
        let isTestMode = !(options.input === FileHandle.standardInput)
        if !isTestMode, let originalState = originalTerminalState {
            try? Terminal.current.setState(originalState)
        }

        // Cancel context if needed
        contextTask?.cancel()
        
        // Give command tasks a brief grace period to complete
        // Like Bubbletea, we don't wait forever as commands can run for a long time
        if !commandTasks.isEmpty {
            // Create a timeout task
            let timeoutTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            // Wait for either timeout or all tasks to complete
            await withTaskGroup(of: Void.self) { group in
                // Add the timeout task
                group.addTask {
                    await timeoutTask.value
                }
                
                // Add all command tasks
                for task in commandTasks {
                    group.addTask {
                        _ = await task.value
                    }
                }
                
                // Wait for timeout (first task to complete)
                _ = await group.next()
                
                // Cancel remaining tasks
                group.cancelAll()
            }
            
            // Clear the task set - any remaining tasks will complete on their own
            // This matches Bubbletea's behavior of "leaking" goroutines
            commandTasks.removeAll()
        }

        // Call finished handler if set
        if let handler = finishedHandler {
            await handler()
        }
    }

    private func mainLoop() async {
        // Initial render
        await render()

        // Message processing loop
        for await message in messageChannel {
            // Check for kill flag or task cancellation
            if isKilled || Task.isCancelled {
                await errorChannel.send(CancellationError())
                break
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

            // Handle system messages
            if await handleSystemMessage(filteredMessage) {
                continue
            }

            // Type-erase and dispatch to model
            if let msg = filteredMessage as? M.Msg {
                let (newModel, command) = model.update(msg)
                model = newModel

                // Execute any resulting command
                if let command {
                    let task = Task {
                        await executeCommand(command)
                    }
                    commandTasks.insert(task)
                    // Clean up when done
                    Task {
                        _ = await task.value
                        commandTasks.remove(task)
                    }
                }

                // Render the updated view
                await render()
            }
        }

        // If we exited the loop due to cancellation or kill, send error
        if isKilled || Task.isCancelled {
            await errorChannel.send(CancellationError())
        }
    }

    private func handleSystemMessage(_ message: any Message) async -> Bool {
        switch message {
        case is QuitMsg:
            // Signal to exit the main loop
            await messageChannel.finish()
            return true

        case is SuspendMsg:
            // Handle terminal suspension (Ctrl+Z)
            Task { @MainActor in
                await self.suspend()
            }
            return true

        case is InterruptMsg:
            // Handle interrupt (Ctrl+C) - typically quits the program
            // But we allow the model to handle it if it wants to
            return false

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

        case let msg as ExecMsg:
            // Execute the command with proper terminal handling
            Task { @MainActor in
                await self.executeExternalCommand(msg.cmd, callback: msg.fn)
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

        case is EnableMouseCellMotionMsg:
            await renderer?.enableMouseCellMotion()
            await renderer?.enableMouseSGRMode()
            return true

        case is EnableMouseAllMotionMsg:
            await renderer?.enableMouseAllMotion()
            await renderer?.enableMouseSGRMode()
            return true

        case is DisableMouseMsg:
            await renderer?.disableMouseAllMotion()
            await renderer?.disableMouseCellMotion()
            await renderer?.disableMouseSGRMode()
            return true

        case let msg as WindowSizeMsg:
            await renderer?.setTerminalSize(width: msg.width, height: msg.height)
            return false // Let the model handle it too

        case let msg as PrintLineMsg:
            // Queue the message to be printed by the renderer
            await renderer?.queueMessageLine(msg.text)
            return true

        case let msg as PrintFormattedMsg:
            // Temporarily stop rendering to print
            await renderer?.stop()
            print("\r\u{1B}[K", terminator: "")
            print(msg.text)
            await renderer?.start()
            await render()
            return true

        case let msg as BatchMsg<M.Msg>:
            // Execute all batched commands concurrently
            await withTaskGroup(of: Void.self) { group in
                for command in msg.commands {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.executeCommandWithRecovery(command)
                    }
                }
            }
            return true

        case let msg as SequenceMsg<M.Msg>:
            // Execute commands sequentially
            for command in msg.commands {
                await executeCommandWithRecovery(command)
            }
            return true

        case is RepaintMsg:
            await renderer?.repaint()
            await render()
            return true

        case let msg as ScrollSyncMsg:
            await renderer?.syncScrollArea(
                lines: msg.lines,
                topBoundary: msg.topBoundary,
                bottomBoundary: msg.bottomBoundary
            )
            return true

        case let msg as ScrollUpMsg:
            await renderer?.scrollUp(
                newLines: msg.lines,
                topBoundary: msg.topBoundary,
                bottomBoundary: msg.bottomBoundary
            )
            return true

        case let msg as ScrollDownMsg:
            await renderer?.scrollDown(
                newLines: msg.lines,
                topBoundary: msg.topBoundary,
                bottomBoundary: msg.bottomBoundary
            )
            return true

        case is ClearScrollAreaMsg:
            await renderer?.clearScrollArea()
            return true

        case is WindowSizeRequestMsg:
            // Query terminal size and send WindowSizeMsg
            let isTestMode = !(options.input === FileHandle.standardInput)
            if !isTestMode, let size = try? Terminal.current.getSize() {
                await messageChannel.send(WindowSizeMsg(width: size.columns, height: size.rows))
            } else if isTestMode {
                // Send default size for tests
                await messageChannel.send(WindowSizeMsg(width: 80, height: 24))
            }
            return true

        default:
            return false
        }
    }

    private func render() async {
        let view = model.view()
        if let renderer = renderer {
            await renderer.write(view)
        } else if options.disableRenderer {
            // When renderer is disabled, write view directly to output for testing
            var output = options.output
            output.write(view)
        }
    }

    private func shutdown() async {
        await messageChannel.finish()
        await cleanup()
    }

    /// Recovers from a panic, prints the stack trace, and restores terminal state
    private func recoverFromPanic(_ error: Error) async {
        // Send error to error channel
        await errorChannel.send(ErrProgramPanic())

        // Shutdown the program
        await shutdown()

        // Print panic information
        print("\nCaught panic:\n\n\(error)\n\nRestoring terminal...\n")

        // Print stack trace if available
        if let nsError = error as NSError? {
            if let stackTrace = nsError.userInfo[NSUnderlyingErrorKey] as? String {
                print("Stack trace:\n\(stackTrace)\n")
            }
        }

        // In Swift, we can use Thread.callStackSymbols for stack trace
        let symbols = Thread.callStackSymbols
        print("Call stack:\n\(symbols.joined(separator: "\n"))\n")
    }

    /// Executes a command, handling batch and sequence commands specially
    private func executeCommand(_ command: Command<M.Msg>) async {
        // Check if this is a batch command
        if command.isBatch {
            // Execute all commands concurrently
            await withTaskGroup(of: Void.self) { group in
                // Helper function to flatten nested batches
                func addCommandsToGroup(_ cmds: [Command<M.Msg>]) {
                    for cmd in cmds {
                        if cmd.isBatch {
                            // Recursively flatten nested batches
                            addCommandsToGroup(cmd.batchCommands)
                        } else {
                            group.addTask { [weak self] in
                                guard let self else { return }
                                await self.executeCommandWithRecovery(cmd)
                            }
                        }
                    }
                }

                addCommandsToGroup(command.batchCommands)
            }
            return
        }

        // Check if this is a sequence command
        if command.isSequence {
            // Execute commands sequentially
            for cmd in command.sequenceCommands {
                await executeCommandWithRecovery(cmd)
            }
            return
        }

        // Regular command
        await executeCommandWithRecovery(command)
    }

    /// Executes a command with panic recovery
    private func executeCommandWithRecovery(_ command: Command<some Message>) async {
        // Note: In Swift, we can't directly catch panics like Go's recover()
        // However, we can handle Task cancellation and other errors

        // Check if this is a quit command
        if command.isQuit {
            await messageChannel.send(QuitMsg())
            return
        }

        // Check if this is a batch command
        if command.isBatch {
            // Execute all commands concurrently
            await withTaskGroup(of: Void.self) { group in
                for cmd in command.batchCommands {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.executeCommandWithRecovery(cmd)
                    }
                }
            }
            return
        }

        // Check if this is a sequence command
        if command.isSequence {
            // Execute commands sequentially
            for cmd in command.sequenceCommands {
                await executeCommandWithRecovery(cmd)
            }
            return
        }

        // Regular command
        if let resultMessage = await command.execute() {
            await messageChannel.send(resultMessage)
        }
    }

    /// Executes an external command (like vim) with proper terminal handling
    private func executeExternalCommand(_ cmd: any ExecCommand, callback: ExecCallback?) async {
        do {
            // Release terminal before running command
            try await releaseTerminal()

            // Set up command I/O
            cmd.setStdin(options.input)
            cmd.setStdout(FileHandle.standardOutput)
            cmd.setStderr(FileHandle.standardError)

            // Run the command
            var cmdError: Error?
            do {
                try cmd.run()
            } catch {
                cmdError = error
            }

            // Restore terminal after command finishes
            try await restoreTerminal()

            // Call the callback if provided
            if let callback {
                let message = callback(cmdError)
                await messageChannel.send(message)
            }
        } catch {
            // If we fail to release/restore terminal, recover from panic
            if options.catchPanics {
                await recoverFromPanic(error)
            }
        }
    }

    // MARK: - Deprecated Methods

    /// EnterAltScreen enters the alternate screen buffer, which consumes the entire
    /// terminal window. ExitAltScreen will return the terminal to its former state.
    ///
    /// Deprecated: Use the WithAltScreen ProgramOption instead.
    @available(*, deprecated, message: "Use the WithAltScreen ProgramOption instead")
    public func enterAltScreen() async {
        await renderer?.enterAltScreen()
    }

    /// ExitAltScreen exits the alternate screen buffer.
    ///
    /// Deprecated: The altscreen will exited automatically when the program exits.
    @available(*, deprecated, message: "The altscreen will exit automatically when the program exits")
    public func exitAltScreen() async {
        await renderer?.exitAltScreen()
    }

    /// EnableMouseCellMotion enables mouse click, release, wheel and motion events
    /// if a mouse button is pressed (i.e., drag events).
    ///
    /// Deprecated: Use the WithMouseCellMotion ProgramOption instead.
    @available(*, deprecated, message: "Use the WithMouseCellMotion ProgramOption instead")
    public func enableMouseCellMotion() async {
        await renderer?.enableMouseCellMotion()
    }

    /// DisableMouseCellMotion disables Mouse Cell Motion tracking. This will be
    /// called automatically when exiting a Bubble Tea program.
    ///
    /// Deprecated: The mouse will automatically be disabled when the program exits.
    @available(*, deprecated, message: "The mouse will automatically be disabled when the program exits")
    public func disableMouseCellMotion() async {
        await renderer?.disableMouseCellMotion()
    }

    /// EnableMouseAllMotion enables mouse click, release, wheel and motion events,
    /// regardless of whether a mouse button is pressed. Many modern terminals
    /// support this, but not all.
    ///
    /// Deprecated: Use the WithMouseAllMotion ProgramOption instead.
    @available(*, deprecated, message: "Use the WithMouseAllMotion ProgramOption instead")
    public func enableMouseAllMotion() async {
        await renderer?.enableMouseAllMotion()
    }

    /// DisableMouseAllMotion disables All Motion mouse tracking. This will be
    /// called automatically when exiting a Bubble Tea program.
    ///
    /// Deprecated: The mouse will automatically be disabled when the program exits.
    @available(*, deprecated, message: "The mouse will automatically be disabled when the program exits")
    public func disableMouseAllMotion() async {
        await renderer?.disableMouseAllMotion()
    }

    /// SetWindowTitle sets the terminal window title.
    ///
    /// Deprecated: Use the SetWindowTitle command instead.
    @available(*, deprecated, message: "Use the SetWindowTitle command instead")
    public func setWindowTitle(_ title: String) async {
        await renderer?.setWindowTitle(title)
    }
}

// MARK: - TerminalState

/// Represents saved terminal state
public struct TerminalState: Sendable {
    #if os(macOS) || os(Linux)
        let termios: termios

        init(termios: termios) {
            self.termios = termios
        }
    #endif

    init() {
        #if os(macOS)
            self.termios = Darwin.termios()
        #elseif os(Linux)
            self.termios = Glibc.termios()
        #endif
    }
}

// MARK: - TerminalError

/// Terminal-related errors
public enum TerminalError: Error, Sendable {
    case alreadyRunning
    case notATTY
    case rawModeError(Error)
}

// MARK: - ErrorStore

/// Actor to safely store errors across tasks
private actor ErrorStore {
    private var error: Error?

    func setError(_ error: Error) {
        if self.error == nil {
            self.error = error
        }
    }

    func getError() -> Error? {
        error
    }
}

// MARK: - AsyncChannel

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

// MARK: AsyncSequence

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
