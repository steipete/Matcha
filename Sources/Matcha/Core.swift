//
//  Core.swift
//  Matcha
//
//  Core protocols and types for the Matcha TUI framework.
//

import Foundation

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
        Command { () async -> M? in
            for command in commands {
                if let message = await command.execute() {
                    return message
                }
            }
            return nil
        }
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

// MARK: - Control Commands

/// Creates a command that immediately sends a quit message
public func quit<M: Message>() -> Command<M> {
    Command { () async -> M? in
        QuitMsg() as? M
    }
}

/// Creates a command that immediately sends a suspend message
public func suspend<M: Message>() -> Command<M> {
    Command { () async -> M? in
        SuspendMsg() as? M
    }
}

/// Creates a command that immediately sends an interrupt message
public func interrupt<M: Message>() -> Command<M> {
    Command { () async -> M? in
        InterruptMsg() as? M
    }
}

// MARK: - Window Commands

/// Creates a command to set the terminal window title
public func setWindowTitle<M: Message>(_ title: String) -> Command<M> {
    Command { () async -> M? in
        SetWindowTitleMsg(title: title) as? M
    }
}

/// Creates a command to get the current window size
public func windowSize<M: Message>() -> Command<M> {
    Command { () async -> M? in
        // The Program will handle this and send a WindowSizeMsg
        // For now, return nil as this is handled internally
        nil
    }
}

// MARK: - Screen Commands

/// Creates a command to clear the screen
public func clearScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ClearScreenMsg() as? M
    }
}

/// Creates a command to enter alternate screen buffer
public func enterAltScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnterAltScreenMsg() as? M
    }
}

/// Creates a command to exit alternate screen buffer
public func exitAltScreen<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ExitAltScreenMsg() as? M
    }
}

// MARK: - Cursor Commands

/// Creates a command to show the cursor
public func showCursor<M: Message>() -> Command<M> {
    Command { () async -> M? in
        ShowCursorMsg() as? M
    }
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

/// Creates a command to enable focus reporting
public func enableReportFocus<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableReportFocusMsg() as? M
    }
}

/// Creates a command to disable focus reporting
public func disableReportFocus<M: Message>() -> Command<M> {
    Command { () async -> M? in
        DisableReportFocusMsg() as? M
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

/// Creates a command to enable bracketed paste mode
public func enableBracketedPaste<M: Message>() -> Command<M> {
    Command { () async -> M? in
        EnableBracketedPasteMsg() as? M
    }
}

/// Creates a command to disable bracketed paste mode
public func disableBracketedPaste<M: Message>() -> Command<M> {
    Command { () async -> M? in
        DisableBracketedPasteMsg() as? M
    }
}

// MARK: - Batch Command

/// Batches multiple commands to run concurrently.
/// Returns a command that executes all given commands and returns the first non-nil message.
public func batch<M: Message>(_ commands: [Command<M>]) -> Command<M> {
    Command<M>.batch(commands)
}

/// Convenience method for batching commands using variadic parameters
public func batch<M: Message>(_ commands: Command<M>...) -> Command<M> {
    Command<M>.batch(commands)
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

/// Creates a command to print a line to the terminal
public func println<M: Message>(_ items: Any...) -> Command<M> {
    // Convert items to string immediately to avoid capture issues
    let output = items.map { String(describing: $0) }.joined(separator: " ")
    
    return Command { () async -> M? in
        PrintLineMsg(text: output) as? M
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
