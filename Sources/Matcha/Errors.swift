//
//  Errors.swift
//  Matcha
//
//  Error types for program lifecycle and execution.
//

import Foundation

/// Error thrown when the program encounters a panic condition.
/// 
/// This error represents an unrecoverable state in the program execution,
/// similar to a runtime exception. It may contain information about what
/// caused the panic.
public struct ProgramPanicError: Error, LocalizedError, Sendable {
    /// A description of what caused the panic
    public let reason: String
    
    /// The source location where the panic occurred, if available
    public let file: String?
    
    /// The line number where the panic occurred, if available
    public let line: Int?
    
    /// The underlying error that caused the panic, if any
    public let underlyingError: Error?
    
    /// Creates a new program panic error.
    /// - Parameters:
    ///   - reason: Description of what caused the panic
    ///   - file: Source file where the panic occurred
    ///   - line: Line number where the panic occurred
    ///   - underlyingError: The original error that triggered the panic
    public init(
        reason: String,
        file: String? = #file,
        line: Int? = #line,
        underlyingError: Error? = nil
    ) {
        self.reason = reason
        self.file = file
        self.line = line
        self.underlyingError = underlyingError
    }
    
    public var errorDescription: String? {
        var description = "Program panic: \(reason)"
        if let file = file, let line = line {
            description += " at \(file):\(line)"
        }
        if let underlyingError = underlyingError {
            description += " (underlying: \(underlyingError))"
        }
        return description
    }
}

/// Error thrown when the program is forcefully terminated.
///
/// This error indicates that the program was killed, either by user action
/// (like calling kill()) or by the system. It differs from a normal quit
/// in that it represents an abnormal termination.
public struct ProgramKilledError: Error, LocalizedError, Sendable {
    /// The reason for the termination, if known
    public let reason: String?
    
    /// The signal that caused the termination, if applicable
    public let signal: Int32?
    
    /// Creates a new program killed error.
    /// - Parameters:
    ///   - reason: Optional description of why the program was killed
    ///   - signal: The signal number that caused termination (e.g., SIGKILL)
    public init(reason: String? = nil, signal: Int32? = nil) {
        self.reason = reason
        self.signal = signal
    }
    
    public var errorDescription: String? {
        var description = "Program killed"
        if let reason = reason {
            description += ": \(reason)"
        }
        if let signal = signal {
            description += " (signal: \(signal))"
        }
        return description
    }
}

/// Error thrown when an operation is interrupted.
///
/// This error indicates that an operation was interrupted before completion,
/// typically by user action (like pressing Ctrl+C) or by receiving an
/// interrupt signal. The operation can potentially be retried.
public struct InterruptedError: Error, LocalizedError, Sendable {
    /// The operation that was interrupted
    public let operation: String
    
    /// Whether the interruption was caused by user action
    public let userInitiated: Bool
    
    /// Additional context about the interruption
    public let context: String?
    
    /// Creates a new interrupted error.
    /// - Parameters:
    ///   - operation: Description of the operation that was interrupted
    ///   - userInitiated: Whether the user initiated the interruption
    ///   - context: Additional context about the interruption
    public init(
        operation: String,
        userInitiated: Bool = true,
        context: String? = nil
    ) {
        self.operation = operation
        self.userInitiated = userInitiated
        self.context = context
    }
    
    public var errorDescription: String? {
        var description = "Operation interrupted: \(operation)"
        if userInitiated {
            description += " (user initiated)"
        }
        if let context = context {
            description += " - \(context)"
        }
        return description
    }
}

// MARK: - Error Helpers

public extension ProgramPanicError {
    /// Creates a panic error for an assertion failure.
    /// - Parameters:
    ///   - condition: The condition that failed
    ///   - message: Optional message describing the failure
    /// - Returns: A configured panic error
    static func assertionFailure(
        _ condition: String,
        message: String? = nil,
        file: String = #file,
        line: Int = #line
    ) -> ProgramPanicError {
        let reason = message ?? "Assertion failed: \(condition)"
        return ProgramPanicError(reason: reason, file: file, line: line)
    }
    
    /// Creates a panic error for an unexpected nil value.
    /// - Parameters:
    ///   - name: Name of the value that was unexpectedly nil
    ///   - context: Additional context about where this occurred
    /// - Returns: A configured panic error
    static func unexpectedNil(
        _ name: String,
        context: String? = nil,
        file: String = #file,
        line: Int = #line
    ) -> ProgramPanicError {
        var reason = "Unexpected nil value: \(name)"
        if let context = context {
            reason += " in \(context)"
        }
        return ProgramPanicError(reason: reason, file: file, line: line)
    }
}

public extension InterruptedError {
    /// Common interrupted error for input operations
    static let inputInterrupted = InterruptedError(
        operation: "Input reading",
        userInitiated: true
    )
    
    /// Common interrupted error for rendering operations
    static let renderInterrupted = InterruptedError(
        operation: "Rendering",
        userInitiated: false
    )
    
    /// Common interrupted error for command execution
    static let commandInterrupted = InterruptedError(
        operation: "Command execution",
        userInitiated: true
    )
}