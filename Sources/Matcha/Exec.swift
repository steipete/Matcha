import Foundation

/// Error thrown when a process execution fails
public struct ExecProcessError: Error, LocalizedError {
    public let status: Int
    
    public init(status: Int) {
        self.status = status
    }
    
    public var errorDescription: String? {
        "Process exited with non-zero status: \(status)"
    }
}

/// Protocol for commands that can be executed in a blocking fashion
public protocol ExecCommand: Sendable {
    func run() throws
    func setStdin(_ reader: FileHandle?)
    func setStdout(_ writer: FileHandle?)
    func setStderr(_ writer: FileHandle?)
}

/// Callback type for execution completion
public typealias ExecCallback = @Sendable (Error?) -> Message

/// Internal message for running exec commands
struct ExecMessage: Message {
    let command: ExecCommand
    let callback: ExecCallback?
    let stdin: FileHandle?
    let stdout: FileHandle?
    let stderr: FileHandle?
    
    init(command: ExecCommand, callback: ExecCallback?, stdin: FileHandle? = nil, stdout: FileHandle? = nil, stderr: FileHandle? = nil) {
        self.command = command
        self.callback = callback
        self.stdin = stdin
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Message type for exec command completion
public struct ExecFinishedMessage: Message {
    public let error: Error?
    
    public init(error: Error? = nil) {
        self.error = error
    }
}

/// Execute a command in a blocking fashion, pausing the program while execution runs
public func exec<M: Message>(_ command: ExecCommand, callback: ExecCallback? = nil) -> Command<M> {
    return Command<M> { () -> M? in
        ExecMessage(
            command: command, 
            callback: callback,
            stdin: FileHandle.standardInput,
            stdout: FileHandle.standardOutput,
            stderr: FileHandle.standardError
        ) as? M
    }
}

/// Execute a Process in a blocking fashion
public func execProcess<M: Message>(_ process: Process, callback: ExecCallback? = nil) -> Command<M> {
    let command = ProcessExecCommand(process: process)
    return exec(command, callback: callback)
}

/// Wrapper around Process to implement ExecCommand
public final class ProcessExecCommand: ExecCommand {
    private let process: Process
    
    public init(process: Process) {
        self.process = process
    }
    
    public func run() throws {
        try process.run()
        process.waitUntilExit()
        
        // Check if the process exited with an error
        if process.terminationStatus != 0 {
            throw ExecProcessError(status: Int(process.terminationStatus))
        }
    }
    
    public func setStdin(_ reader: FileHandle?) {
        if process.standardInput == nil {
            process.standardInput = reader
        }
    }
    
    public func setStdout(_ writer: FileHandle?) {
        if process.standardOutput == nil {
            process.standardOutput = writer
        }
    }
    
    public func setStderr(_ writer: FileHandle?) {
        if process.standardError == nil {
            process.standardError = writer
        }
    }
}

// MARK: - Program Extension
extension Program {
    func executeCommand(_ command: ExecCommand, callback: ExecCallback?, stdin: FileHandle?, stdout: FileHandle?, stderr: FileHandle?) {
        Task { @MainActor in
            // Release terminal before executing
            do {
                try await releaseTerminal()
            } catch {
                if let callback = callback {
                    send(callback(error))
                }
                return
            }
            
            // Set up I/O
            command.setStdin(stdin ?? FileHandle.standardInput)
            command.setStdout(stdout ?? FileHandle.standardOutput)
            command.setStderr(stderr ?? FileHandle.standardError)
            
            // Execute the command
            do {
                try command.run()
                
                // Restore terminal
                do {
                    try await restoreTerminal()
                    if let callback = callback {
                        send(callback(nil))
                    }
                } catch {
                    if let callback = callback {
                        send(callback(error))
                    }
                }
            } catch {
                // Try to restore terminal even on error
                _ = try? await restoreTerminal()
                
                if let callback = callback {
                    send(callback(error))
                }
            }
        }
    }
}