import Testing
@testable import Matcha

// Test output stream
private class TestOutputStream: TextOutputStream, @unchecked Sendable {
    var content = ""
    
    func write(_ string: String) {
        content += string
    }
}

@Suite("Exec Command Tests")
struct ExecTests {
    
    // Test model for exec functionality
    struct TestExecModel: Model {
        typealias Msg = TestExecMessage
        
        enum TestExecMessage: Message {
            case execFinished(Error?)
        }
        
        let command: String
        var error: Error?
        var completed = false
        
        init() {
            self.command = ""
            self.error = nil
            self.completed = false
        }
        
        init(command: String) {
            self.command = command
            self.error = nil
            self.completed = false
        }
        
        func `init`() -> Command<TestExecMessage>? {
            let process = Process()
            
            #if os(Windows)
            // Windows specific command setup
            process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
            process.arguments = ["/c", command]
            #else
            // Unix-like systems
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            #endif
            
            return execProcess(process) { error in
                TestExecMessage.execFinished(error)
            }
        }
        
        func update(_ message: TestExecMessage) -> (TestExecModel, Command<TestExecMessage>?) {
            switch message {
            case .execFinished(let err):
                var model = self
                model.error = err
                model.completed = true
                return (model, quit())
            }
        }
        
        func view() -> String {
            if completed {
                if let error = error {
                    return "Error: \(error.localizedDescription)"
                } else {
                    return "Success"
                }
            } else {
                return "Running..."
            }
        }
    }
    
    @Test("Executing a valid command succeeds")
    func execValidCommand() async throws {
        #if os(Windows)
        let model = TestExecModel(command: "echo test")
        #else
        let model = TestExecModel(command: "true")
        #endif
        
        var options = ProgramOptions()
        options.input = FileHandle.nullDevice
        options.output = TestOutputStream()
        
        let program = Program(
            initialModel: model,
            options: options
        )
        
        let result = try await program.run()
        
        #expect(result.completed)
        #expect(result.error == nil)
    }
    
    @Test("Executing an invalid command fails")
    func execInvalidCommand() async throws {
        let model = TestExecModel(command: "invalid_command_that_does_not_exist")
        
        var options = ProgramOptions()
        options.input = FileHandle.nullDevice
        options.output = TestOutputStream()
        
        let program = Program(
            initialModel: model,
            options: options
        )
        
        let result = try await program.run()
        
        #expect(result.completed)
        #expect(result.error != nil)
    }
    
    @Test("Executing a command with non-zero exit status fails")
    func execCommandWithNonZeroExit() async throws {
        #if os(Windows)
        let model = TestExecModel(command: "exit 1")
        #else
        let model = TestExecModel(command: "false")
        #endif
        
        var options = ProgramOptions()
        options.input = FileHandle.nullDevice
        options.output = TestOutputStream()
        
        let program = Program(
            initialModel: model,
            options: options
        )
        
        let result = try await program.run()
        
        #expect(result.completed)
        #expect(result.error != nil)
        
        if let error = result.error as? ExecProcessError {
            #expect(error.status != 0)
        } else {
            Issue.record("Expected ExecProcessError")
        }
    }
    
    // Test custom ExecCommand implementation
    final class TestExecCommand: ExecCommand, @unchecked Sendable {
        var didRun = false
        var stdin: FileHandle?
        var stdout: FileHandle?
        var stderr: FileHandle?
        let shouldFail: Bool
        
        init(shouldFail: Bool = false) {
            self.shouldFail = shouldFail
        }
        
        func run() throws {
            didRun = true
            if shouldFail {
                throw ExecProcessError(status: 42)
            }
        }
        
        func setStdin(_ reader: FileHandle?) {
            stdin = reader
        }
        
        func setStdout(_ writer: FileHandle?) {
            stdout = writer
        }
        
        func setStderr(_ writer: FileHandle?) {
            stderr = writer
        }
    }
    
    @Test("Custom ExecCommand implementation succeeds")
    func customExecCommand() async throws {
        final class CustomCommandModel: Model {
            typealias Msg = TestMessage
            
            enum TestMessage: Message {
                case execFinished(Error?)
            }
            
            let command: TestExecCommand
            var error: Error?
            var completed = false
            
            init(command: TestExecCommand) {
                self.command = command
            }
            
            func `init`() -> Command<TestMessage>? {
                exec(command) { error in
                    TestMessage.execFinished(error)
                }
            }
            
            func update(_ message: TestMessage) -> (CustomCommandModel, Command<TestMessage>?) {
                switch message {
                case .execFinished(let err):
                    var newModel = self
                    newModel.error = err
                    newModel.completed = true
                    return (newModel, quit())
                }
            }
            
            func view() -> String {
                "Test"
            }
        }
        
        let testCommand = TestExecCommand(shouldFail: false)
        let model = CustomCommandModel(command: testCommand)
        
        var options = ProgramOptions()
        options.input = FileHandle.nullDevice
        options.output = TestOutputStream()
        
        let program = Program(
            initialModel: model,
            options: options
        )
        
        let result = try await program.run()
        
        await MainActor.run {
            #expect(testCommand.didRun)
            #expect(result.completed)
            #expect(result.error == nil)
            
            // Verify I/O was set up
            #expect(testCommand.stdin != nil)
            #expect(testCommand.stdout != nil)
            #expect(testCommand.stderr != nil)
        }
    }
    
    @Test("Custom ExecCommand implementation handles failure")
    func customExecCommandFailure() async throws {
        final class CustomCommandModel: Model {
            typealias Msg = TestMessage
            
            enum TestMessage: Message {
                case execFinished(Error?)
            }
            
            let command: TestExecCommand
            var error: Error?
            var completed = false
            
            init(command: TestExecCommand) {
                self.command = command
            }
            
            func `init`() -> Command<TestMessage>? {
                exec(command) { error in
                    TestMessage.execFinished(error)
                }
            }
            
            func update(_ message: TestMessage) -> (CustomCommandModel, Command<TestMessage>?) {
                switch message {
                case .execFinished(let err):
                    var newModel = self
                    newModel.error = err
                    newModel.completed = true
                    return (newModel, quit())
                }
            }
            
            func view() -> String {
                "Test"
            }
        }
        
        let testCommand = TestExecCommand(shouldFail: true)
        let model = CustomCommandModel(command: testCommand)
        
        var options = ProgramOptions()
        options.input = FileHandle.nullDevice
        options.output = TestOutputStream()
        
        let program = Program(
            initialModel: model,
            options: options
        )
        
        let result = try await program.run()
        
        await MainActor.run {
            #expect(testCommand.didRun)
            #expect(result.completed)
            #expect(result.error != nil)
            
            if let error = result.error as? ExecProcessError {
                #expect(error.status == 42)
            } else {
                Issue.record("Expected ExecProcessError with status 42")
            }
        }
    }
}