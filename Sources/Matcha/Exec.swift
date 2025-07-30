import Foundation

// MARK: - ExecMsg

/// execMsg is used internally to run an ExecCommand sent with Exec.
struct ExecMsg: Message {
    let cmd: any ExecCommand
    let fn: ExecCallback?
}

/// Exec is used to perform arbitrary I/O in a blocking fashion, effectively
/// pausing the Program while execution is running and resuming it when
/// execution has completed.
///
/// Most of the time you'll want to use ExecProcess, which runs a Process.
///
/// For non-interactive i/o you should use a Cmd (that is, a tea.Cmd).
public func Exec<M: Message>(_ c: any ExecCommand, _ fn: ExecCallback? = nil) -> Command<M> {
    Command { () async -> M? in
        ExecMsg(cmd: c, fn: fn) as? M
    }
}

/// ExecProcess runs the given Process in a blocking fashion, effectively
/// pausing the Program while the command is running. After the Process exits
/// the Program resumes. It's useful for spawning other interactive applications
/// such as editors and shells from within a Program.
///
/// To produce the command, pass a Process and a function which returns
/// a message containing the error which may have occurred when running the
/// ExecCommand.
///
///     struct VimFinishedMsg: Message {
///         let err: Error?
///     }
///
///     let p = Process()
///     p.executableURL = URL(fileURLWithPath: "/usr/bin/vim")
///     p.arguments = ["file.txt"]
///
///     let cmd = ExecProcess(p) { err in
///         VimFinishedMsg(err: err)
///     }
///
/// Or, if you don't care about errors, you could simply:
///
///     let cmd = ExecProcess(myProcess, nil)
///
/// For non-interactive i/o you should use a Cmd (that is, a tea.Cmd).
public func ExecProcess<M: Message>(_ p: Process, _ fn: ExecCallback? = nil) -> Command<M> {
    Exec(ProcessCommand(p), fn)
}

/// ExecCallback is used when executing a Process to return a message
/// with an error, which may or may not be nil.
public typealias ExecCallback = @Sendable (Error?) -> any Message

// MARK: - ExecCommand

/// ExecCommand can be implemented to execute things in a blocking fashion in
/// the current terminal.
public protocol ExecCommand: Sendable {
    func run() throws
    func setStdin(_ reader: FileHandle)
    func setStdout(_ writer: FileHandle)
    func setStderr(_ writer: FileHandle)
}

// MARK: - ProcessCommand

/// ProcessCommand wraps a Process so that it satisfies the ExecCommand
/// interface so it can be used with Exec.
final class ProcessCommand: ExecCommand, @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    /// SetStdin sets stdin on underlying Process to the given FileHandle.
    func setStdin(_ reader: FileHandle) {
        // If unset, have the command use the same input as the terminal.
        if process.standardInput == nil {
            process.standardInput = reader
        }
    }

    /// SetStdout sets stdout on underlying Process to the given FileHandle.
    func setStdout(_ writer: FileHandle) {
        // If unset, have the command use the same output as the terminal.
        if process.standardOutput == nil {
            process.standardOutput = writer
        }
    }

    /// SetStderr sets stderr on the underlying Process to the given FileHandle.
    func setStderr(_ writer: FileHandle) {
        // If unset, use stderr for the command's stderr
        if process.standardError == nil {
            process.standardError = writer
        }
    }

    func run() throws {
        try process.run()
        process.waitUntilExit()

        // Check termination status
        if process.terminationStatus != 0 {
            throw ProcessError(terminationStatus: process.terminationStatus)
        }
    }
}

// MARK: - ProcessError

/// Error thrown when a process exits with non-zero status
public struct ProcessError: Error, LocalizedError {
    public let terminationStatus: Int32

    public var errorDescription: String? {
        "Process exited with status \(terminationStatus)"
    }
}
