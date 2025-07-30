//
//  Core.swift
//  Matcha
//
//  Core protocols and types for the Matcha TUI framework.
//

import Foundation

// MARK: - Duration Extensions

extension Duration {
    /// Convert Duration to TimeInterval (seconds)
    var timeInterval: TimeInterval {
        let components = self.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1e18
        return seconds + attoseconds
    }
}

/// A message represents an event that can trigger updates in the application.
/// All messages must be Sendable for thread safety in Swift 6.
public protocol Message: Sendable {}

/// Type alias for compatibility with Bubble Tea naming
public typealias Msg = Message

/// A command represents an asynchronous operation that produces a message.
/// Commands are the way to perform side effects in the Elm Architecture.
public struct Command<M: Message>: Sendable {
    /// The async operation that produces a message
    private let operation: @Sendable () async -> M?
    
    /// Internal flag for batch commands
    internal var isBatch: Bool = false
    internal var batchCommands: [Command<M>] = []
    
    /// Internal flag for sequence commands
    internal var isSequence: Bool = false
    internal var sequenceCommands: [Command<M>] = []
    
    /// Internal flag for quit command
    internal var isQuit: Bool = false

    /// Creates a new command from an async operation
    public init(operation: @escaping @Sendable () async -> M?) {
        self.operation = operation
    }

    /// Creates a new command from a synchronous operation
    public init(_ operation: @escaping @Sendable () -> M?) {
        self.operation = { operation() }
    }

    /// Executes the command and returns the resulting message
    public func execute() async -> M? {
        await operation()
    }

    /// Creates a command that immediately returns a message
    public static func pure(_ message: M) -> Command<M> {
        Command { message }
    }

    /// Creates a command that does nothing
    public static var empty: Command<M> {
        Command { nil }
    }
}

/// Type alias for compatibility with Bubble Tea naming
public typealias Cmd<M: Message> = Command<M>

/// Protocol for application models following The Elm Architecture.
/// Models must be Sendable for thread safety in Swift 6.
public protocol Model: Sendable {
    /// The type of messages this model handles
    associatedtype Msg: Message

    /// Initializes the model with its default state
    init()

    /// Called once when the program starts. Returns an optional initial command.
    func `init`() -> Command<Msg>?

    /// Updates the model in response to a message, returning the updated model and an optional command.
    /// Note: In Swift, we return a new model instance to maintain immutability.
    func update(_ message: Msg) -> (Self, Command<Msg>?)

    /// Renders the current state of the model as a string for display in the terminal.
    func view() -> String
}

// MARK: - Built-in Messages

/// Message sent when the user requests to quit the application
public struct QuitMsg: Message {
    public init() {}
}

/// Message sent when the user requests to suspend the application (Ctrl+Z)
public struct SuspendMsg: Message {
    public init() {}
}

/// Message sent when the application resumes from suspension
public struct ResumeMsg: Message {
    public init() {}
}

/// Message sent when the user interrupts the application (Ctrl+C)
public struct InterruptMsg: Message {
    public init() {}
}

/// Message containing the current terminal window size
public struct WindowSizeMsg: Message {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Message sent when the terminal window gains focus
public struct FocusMsg: Message {
    public init() {}
}

/// Message sent when the terminal window loses focus
public struct BlurMsg: Message {
    public init() {}
}

/// Message sent when text is pasted (bracketed paste mode)
public struct PasteMsg: Message {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

/// Message to set the terminal window title
public struct SetWindowTitleMsg: Message {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

/// Message to clear the screen
public struct ClearScreenMsg: Message {
    public init() {}
}

/// Message to enter alternate screen buffer
public struct EnterAltScreenMsg: Message {
    public init() {}
}

/// Message to exit alternate screen buffer
public struct ExitAltScreenMsg: Message {
    public init() {}
}

/// Message to show the cursor
public struct ShowCursorMsg: Message {
    public init() {}
}

/// Message to hide the cursor
public struct HideCursorMsg: Message {
    public init() {}
}

// MARK: - Command Helpers

public extension Command {
    /// Batches multiple commands to run concurrently.
    /// Returns a command that executes all given commands and returns the first non-nil message.
    static func batch(_ commands: [Command<M>]) -> Command<M> {
        Command { () async -> M? in
            await withTaskGroup(of: M?.self) { group in
                for command in commands {
                    group.addTask {
                        await command.execute()
                    }
                }

                // Return the first non-nil message
                for await message in group {
                    if let message {
                        return message
                    }
                }

                return nil
            }
        }
    }

    /// Convenience method for batching commands using variadic parameters
    static func batch(_ commands: Command<M>...) -> Command<M> {
        batch(commands)
    }

    /// Sequences multiple commands to run one after another.
    /// Each command waits for the previous one to complete.
    static func sequence(_ commands: [Command<M>]) -> Command<M> {
        var seqCmd = Command<M> { nil }
        seqCmd.isSequence = true
        seqCmd.sequenceCommands = commands
        return seqCmd
    }

    /// Convenience method for sequencing commands using variadic parameters
    static func sequence(_ commands: Command<M>...) -> Command<M> {
        sequence(commands)
    }
}

// MARK: - Timer Commands

/// Message sent for timer ticks
public struct TickMsg: Message {
    public let time: Date

    public init(time: Date = Date()) {
        self.time = time
    }
}

/// Creates a command that waits for the specified duration and then produces a message
public func tick<M: Message>(_ duration: Duration, _ handler: @escaping @Sendable (Date) -> M) -> Command<M> {
    Command { () async -> M? in
        try? await Task.sleep(for: duration)
        return handler(Date())
    }
}

/// Creates a command that produces messages at regular intervals
/// Note: This returns after producing ONE message. To continue receiving messages,
/// the model should return this command again from its update function.
public func every<M: Message>(_ duration: Duration, _ handler: @escaping @Sendable (Date) -> M) -> Command<M> {
    Command { () async -> M? in
        try? await Task.sleep(for: duration)
        return handler(Date())
    }
}

/// Every is a command that ticks in sync with the system clock. So, if you
/// wanted to tick with the system clock every second, minute or hour you
/// could use this. It's also handy for having different things tick in sync.
///
/// Because we're ticking with the system clock the tick will likely not run for
/// the entire specified duration. For example, if we're ticking for one minute
/// and the clock is at 12:34:20 then the next tick will happen at 12:35:00, 40
/// seconds later.
///
/// To produce the command, pass a duration and a function which returns
/// a message containing the time at which the tick occurred.
///
///     struct TickMsg: Message {
///         let time: Date
///     }
///
///     let cmd = Every(.seconds(1)) { t in
///         TickMsg(time: t)
///     }
///
/// Beginners' note: Every sends a single message and won't automatically
/// dispatch messages at an interval. To do that, you'll want to return another
/// Every command after receiving your tick message.
///
/// Every is analogous to Tick in the Elm Architecture.
public func Every<M: Message>(_ duration: Duration, _ fn: @escaping @Sendable (Date) -> M) -> Command<M> {
    Command { () async -> M? in
        let now = Date()
        let interval = duration.timeInterval
        
        // Calculate next aligned time
        let timeSinceEpoch = now.timeIntervalSince1970
        let nextAligned = ceil(timeSinceEpoch / interval) * interval
        let delay = nextAligned - timeSinceEpoch
        
        // Sleep until the next aligned time
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return fn(Date())
    }
}

/// Tick produces a command at an interval independent of the system clock at
/// the given duration. That is, the timer begins precisely when invoked,
/// and runs for its entire duration.
///
/// To produce the command, pass a duration and a function which returns
/// a message containing the time at which the tick occurred.
///
///     struct TickMsg: Message {
///         let time: Date
///     }
///
///     let cmd = Tick(.seconds(1)) { t in
///         TickMsg(time: t)
///     }
///
/// Beginners' note: Tick sends a single message and won't automatically
/// dispatch messages at an interval. To do that, you'll want to return another
/// Tick command after receiving your tick message.
public func Tick<M: Message>(_ d: Duration, _ fn: @escaping @Sendable (Date) -> M) -> Command<M> {
    tick(d, fn)
}

// MARK: - Control Commands

/// Quit is a special command that tells the Bubble Tea program to exit.
public func Quit<M: Message>() -> M? {
    QuitMsg() as? M
}

/// Creates a command that immediately sends a quit message
public func quit<M: Message>() -> Command<M> {
    var cmd = Command<M> { () async -> M? in
        // Return nil since QuitMsg can't be cast to M
        // The Program will handle this specially
        return nil
    }
    // Mark this as a special quit command
    cmd.isQuit = true
    return cmd
}

/// Suspend is a command that suspends the program.
public func Suspend<M: Message>() -> M? {
    SuspendMsg() as? M
}

/// Creates a command that immediately sends a suspend message
public func suspend<M: Message>() -> Command<M> {
    Command { () async -> M? in
        SuspendMsg() as? M
    }
}

/// Interrupt is a command that interrupts the program.
public func Interrupt<M: Message>() -> M? {
    InterruptMsg() as? M
}

/// Creates a command that immediately sends an interrupt message
public func interrupt<M: Message>() -> Command<M> {
    Command { () async -> M? in
        InterruptMsg() as? M
    }
}

// MARK: - Window Commands

/// SetWindowTitle produces a command that sets the terminal title.
///
/// For example:
///
///     func (m model) Init() -> Cmd {
///         // Set title.
///         return SetWindowTitle("My App")
///     }
public func SetWindowTitle<M: Message>(_ title: String) -> M? {
    SetWindowTitleMsg(title: title) as? M
}

/// Creates a command to set the terminal window title
public func setWindowTitle<M: Message>(_ title: String) -> Command<M> {
    Command { () async -> M? in
        SetWindowTitleMsg(title: title) as? M
    }
}

// Internal message type for window size request
struct WindowSizeRequestMsg: Message {}

/// WindowSize is a command that queries the terminal for its current size. It
/// delivers the results to Update via a WindowSizeMsg. Keep in mind that
/// WindowSizeMsgs will automatically be delivered to Update when the Program
/// starts and when the window dimensions change so in many cases you will not
/// need to explicitly invoke this command.
public func WindowSize<M: Message>() -> Command<M> {
    Command { () async -> M? in
        WindowSizeRequestMsg() as? M
    }
}

// MARK: - Screen Commands

/// ClearScreen is a special command that tells the program to clear the screen
/// before the next update. This can be used to move the cursor to the top left
/// of the screen and clear visual clutter when the alt screen is not in use.
///
/// Note that it should never be necessary to call ClearScreen() for regular
/// redraws.
public func ClearScreen<M: Message>() -> M? {
    ClearScreenMsg() as? M
}

/// Creates a command to clear the screen
public func clearScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ClearScreenMsg() as? M
    }
}

/// EnterAltScreen is a special command that tells the Bubble Tea program to
/// enter the alternate screen buffer.
///
/// Because commands run asynchronously, this command should not be used in your
/// model's Init function. To initialize your program with the altscreen enabled
/// use the WithAltScreen ProgramOption instead.
public func EnterAltScreen<M: Message>() -> M? {
    EnterAltScreenMsg() as? M
}

/// Creates a command to enter alternate screen buffer
public func enterAltScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnterAltScreenMsg() as? M
    }
}

/// ExitAltScreen is a special command that tells the Bubble Tea program to exit
/// the alternate screen buffer. This command should be used to exit the
/// alternate screen buffer while the program is running.
///
/// Note that the alternate screen buffer will be automatically exited when the
/// program quits.
public func ExitAltScreen<M: Message>() -> M? {
    ExitAltScreenMsg() as? M
}

/// Creates a command to exit alternate screen buffer
public func exitAltScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ExitAltScreenMsg() as? M
    }
}

// MARK: - Cursor Commands

/// ShowCursor is a special command for manually instructing Bubble Tea to show
/// the cursor.
public func ShowCursor<M: Message>() -> M? {
    ShowCursorMsg() as? M
}

/// Creates a command to show the cursor
public func showCursor<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ShowCursorMsg() as? M
    }
}

/// HideCursor is a special command for manually instructing Bubble Tea to hide
/// the cursor. In some rare cases, certain operations will cause the terminal
/// to show the cursor, which is normally hidden for the duration of a Bubble
/// Tea program's lifetime. You will most likely not need to use this command.
public func HideCursor<M: Message>() -> M? {
    HideCursorMsg() as? M
}

/// Creates a command to hide the cursor
public func hideCursor<M: Message>() -> Command<M> {
    Command { () async -> M? in
        HideCursorMsg() as? M
    }
}

// MARK: - Focus Commands

/// Message to enable focus reporting
public struct EnableReportFocusMsg: Message {
    public init() {}
}

/// Message to disable focus reporting
public struct DisableReportFocusMsg: Message {
    public init() {}
}

/// EnableReportFocus is a special command that tells the Bubble Tea program to
/// report focus events to the program.
public func EnableReportFocus<M: Message>() -> M? {
    EnableReportFocusMsg() as? M
}

/// Creates a command to enable focus reporting
public func enableReportFocus<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableReportFocusMsg() as? M
    }
}

/// DisableReportFocus is a special command that tells the Bubble Tea program to
/// stop reporting focus events to the program.
public func DisableReportFocus<M: Message>() -> M? {
    DisableReportFocusMsg() as? M
}

/// Creates a command to disable focus reporting
public func disableReportFocus<M: Message>() -> Command<M> {
    Command { () async -> M? in
        DisableReportFocusMsg() as? M
    }
}

// MARK: - Mouse Commands

/// Message to enable mouse cell motion tracking
public struct EnableMouseCellMotionMsg: Message {
    public init() {}
}

/// Message to enable mouse all motion tracking
public struct EnableMouseAllMotionMsg: Message {
    public init() {}
}

/// Message to disable mouse tracking
public struct DisableMouseMsg: Message {
    public init() {}
}

/// EnableMouseCellMotion is a special command that enables mouse click, release,
/// wheel, and motion events where a mouse button is pressed (i.e., drag events).
public func EnableMouseCellMotion<M: Message>() -> M? {
    EnableMouseCellMotionMsg() as? M
}

/// Creates a command to enable mouse cell motion tracking
public func enableMouseCellMotion<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableMouseCellMotionMsg() as? M
    }
}

/// EnableMouseAllMotion is a special command that enables mouse click, release,
/// wheel, and motion events, which are delivered regardless of whether a mouse
/// button is pressed, effectively enabling support for hover interactions.
///
/// Many modern terminals support this, but not all. If in doubt, use
/// EnableMouseCellMotion instead.
public func EnableMouseAllMotion<M: Message>() -> M? {
    EnableMouseAllMotionMsg() as? M
}

/// Creates a command to enable mouse all motion tracking
public func enableMouseAllMotion<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableMouseAllMotionMsg() as? M
    }
}

/// DisableMouse is a special command that stops listening for mouse events.
public func DisableMouse<M: Message>() -> M? {
    DisableMouseMsg() as? M
}

/// Creates a command to disable mouse tracking
public func disableMouse<M: Message>() -> Command<M> {
    Command { () async -> M? in
        DisableMouseMsg() as? M
    }
}

// MARK: - Paste Commands

/// Message to enable bracketed paste mode
public struct EnableBracketedPasteMsg: Message {
    public init() {}
}

/// Message to disable bracketed paste mode
public struct DisableBracketedPasteMsg: Message {
    public init() {}
}

/// EnableBracketedPaste is a special command that tells the Bubble Tea program
/// to accept bracketed paste input.
///
/// Note that bracketed paste will be automatically disabled when the
/// program quits.
public func EnableBracketedPaste<M: Message>() -> M? {
    EnableBracketedPasteMsg() as? M
}

/// Creates a command to enable bracketed paste mode
public func enableBracketedPaste<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableBracketedPasteMsg() as? M
    }
}

/// DisableBracketedPaste is a special command that tells the Bubble Tea program
/// to stop processing bracketed paste input.
///
/// Note that bracketed paste will be automatically disabled when the
/// program quits.
public func DisableBracketedPaste<M: Message>() -> M? {
    DisableBracketedPasteMsg() as? M
}

/// Creates a command to disable bracketed paste mode
public func disableBracketedPaste<M: Message>() -> Command<M> {
    Command { () async -> M? in
        DisableBracketedPasteMsg() as? M
    }
}


// MARK: - Batch Command

/// Batch performs a bunch of commands concurrently with no ordering guarantees
/// about the results. Use a Batch to return several commands.
///
/// Example:
///
///     func (m model) Init() -> Cmd {
///         return Batch(someCommand, someOtherCommand)
///     }
public func Batch<M: Message>(_ cmds: Command<M>...) -> Command<M> {
    let validCmds = cmds.filter { cmd in
        // Filter out nil operations
        return true
    }
    switch validCmds.count {
    case 0:
        return Command<M>.empty
    case 1:
        return validCmds[0]
    default:
        var batchCmd = Command<M> { nil }
        batchCmd.isBatch = true
        batchCmd.batchCommands = validCmds
        return batchCmd
    }
}

/// Batch performs a bunch of commands concurrently with no ordering guarantees
public func Batch<M: Message>(_ cmds: [Command<M>]) -> Command<M> {
    let validCmds = cmds.filter { cmd in
        // Filter out nil operations
        return true
    }
    switch validCmds.count {
    case 0:
        return Command<M>.empty
    case 1:
        return validCmds[0]
    default:
        var batchCmd = Command<M> { nil }
        batchCmd.isBatch = true
        batchCmd.batchCommands = validCmds
        return batchCmd
    }
}

/// Batches multiple commands to run concurrently.
/// Returns a command that executes all given commands and returns the first non-nil message.
public func batch<M: Message>(_ commands: [Command<M>]) -> Command<M> {
    Command<M>.batch(commands)
}

/// Convenience method for batching commands using variadic parameters
public func batch<M: Message>(_ commands: Command<M>...) -> Command<M> {
    Command<M>.batch(commands)
}

// MARK: - Sequence Command

/// Sequence runs the given commands one at a time, in order. Contrast this with
/// Batch, which runs commands concurrently.
public func Sequence<M: Message>(_ cmds: Command<M>...) -> Command<M> {
    var seqCmd = Command<M> { nil }
    seqCmd.isSequence = true
    seqCmd.sequenceCommands = cmds
    return seqCmd
}

/// Sequence runs the given commands one at a time, in order.
public func Sequence<M: Message>(_ cmds: [Command<M>]) -> Command<M> {
    var seqCmd = Command<M> { nil }
    seqCmd.isSequence = true
    seqCmd.sequenceCommands = cmds
    return seqCmd
}

/// Sequentially produces a command that sequentially executes the given
/// commands.
/// The Msg returned is the first non-nil message returned by a Cmd.
///
///     func saveStateCmd() -> M? {
///        if let error = save() {
///            return ErrorMsg(error) as? M
///        }
///        return nil
///     }
///
///     let cmd = Sequentially(saveStateCmd, quit)
///
/// Deprecated: use Sequence instead.
@available(*, deprecated, message: "Use Sequence instead")
public func Sequentially<M: Message>(_ cmds: Command<M>...) -> Command<M> {
    Command { () async -> M? in
        for cmd in cmds {
            if let message = await cmd.execute() {
                return message
            }
        }
        return nil
    }
}

// MARK: - Print Commands

/// Message to print a line to the terminal
public struct PrintLineMsg: Message {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

/// Message to print formatted text to the terminal
public struct PrintFormattedMsg: Message {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

/// Println prints a message above the Program. This output is unmanaged by the
/// program and will persist across renders by the Program.
///
/// If the altscreen is active no output will be printed.
public func Println<M: Message>(_ items: Any...) -> Command<M> {
    // Convert items to string immediately to avoid capture issues
    let output = items.map { String(describing: $0) }.joined(separator: " ")
    
    return Command { () async -> M? in
        PrintLineMsg(text: output) as? M
    }
}

/// Creates a command to print a line to the terminal
public func println<M: Message>(_ items: Any...) -> Command<M> {
    // Convert items to string immediately to avoid capture issues
    let output = items.map { String(describing: $0) }.joined(separator: " ")
    
    return Command { () async -> M? in
        PrintLineMsg(text: output) as? M
    }
}

/// Printf prints above the Program. It takes a format string and a variadic
/// list of arguments and prints the result. This output is unmanaged by the
/// program and will persist across renders by the Program.
///
/// If the altscreen is active no output will be printed.
public func Printf<M: Message>(_ format: String, _ args: CVarArg...) -> Command<M> {
    // Format the string immediately to avoid capture issues
    let formattedString = String(format: format, arguments: args)
    
    return Command { () async -> M? in
        PrintFormattedMsg(text: formattedString) as? M
    }
}

/// Creates a command to print formatted text to the terminal
public func printf<M: Message>(_ format: String, _ args: CVarArg...) -> Command<M> {
    // Format the string immediately to avoid capture issues
    let formattedString = String(format: format, arguments: args)
    
    return Command { () async -> M? in
        PrintFormattedMsg(text: formattedString) as? M
    }
}

// MARK: - Batch Message

/// BatchMsg is a message used to perform a bunch of commands concurrently with
/// no ordering guarantees. You can send a BatchMsg with Batch.
public struct BatchMsg<M: Message>: Message {
    public let commands: [Command<M>]
    
    public init(_ commands: [Command<M>]) {
        self.commands = commands
    }
}

// MARK: - Internal Messages

/// sequenceMsg is used internally to run the given commands in order.
public struct SequenceMsg<M: Message>: Message {
    public let commands: [Command<M>]
    
    public init(_ commands: [Command<M>]) {
        self.commands = commands
    }
}

/// Internal message for repaint
public struct RepaintMsg: Message {
    public init() {}
}

/// Internal message for scroll sync
struct ScrollSyncMsg: Message {
    let lines: [String]
    let topBoundary: Int
    let bottomBoundary: Int
}

/// Internal message for scroll up
struct ScrollUpMsg: Message {
    let lines: [String]
    let topBoundary: Int
    let bottomBoundary: Int
}

/// Internal message for scroll down
struct ScrollDownMsg: Message {
    let lines: [String]
    let topBoundary: Int
    let bottomBoundary: Int
}

/// Internal message to clear scroll area
struct ClearScrollAreaMsg: Message {}

// MARK: - Scroll Commands (Deprecated)

/// SyncScrollArea performs a paint of the entire region designated to be the
/// scrollable area. This is required to initialize the scrollable region and
/// should also be called on resize (WindowSizeMsg).
///
/// For high-performance, scroll-based rendering only.
///
/// Deprecated: This option will be removed in a future version of this package.
public func SyncScrollArea<M: Message>(_ lines: [String], topBoundary: Int, bottomBoundary: Int) -> Command<M> {
    Command { () async -> M? in
        ScrollSyncMsg(lines: lines, topBoundary: topBoundary, bottomBoundary: bottomBoundary) as? M
    }
}

/// ScrollUp adds lines to the top of the scrollable region, pushing existing
/// lines below down. Lines that are pushed out the scrollable region disappear
/// from view.
///
/// For high-performance, scroll-based rendering only.
///
/// Deprecated: This option will be removed in a future version of this package.
public func ScrollUp<M: Message>(_ newLines: [String], topBoundary: Int, bottomBoundary: Int) -> Command<M> {
    Command { () async -> M? in
        ScrollUpMsg(lines: newLines, topBoundary: topBoundary, bottomBoundary: bottomBoundary) as? M
    }
}

/// ScrollDown adds lines to the bottom of the scrollable region, pushing
/// existing lines above up. Lines that are pushed out of the scrollable region
/// disappear from view.
///
/// For high-performance, scroll-based rendering only.
///
/// Deprecated: This option will be removed in a future version of this package.
public func ScrollDown<M: Message>(_ newLines: [String], topBoundary: Int, bottomBoundary: Int) -> Command<M> {
    Command { () async -> M? in
        ScrollDownMsg(lines: newLines, topBoundary: topBoundary, bottomBoundary: bottomBoundary) as? M
    }
}

/// ClearScrollArea deallocates the scrollable region and returns the control of
/// those lines to the main rendering routine.
///
/// For high-performance, scroll-based rendering only.
///
/// Deprecated: This option will be removed in a future version of this package.
public func ClearScrollArea<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ClearScrollAreaMsg() as? M
    }
}
