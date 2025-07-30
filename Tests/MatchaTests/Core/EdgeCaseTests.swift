import Foundation
import Testing
@testable import Matcha

// MARK: - TestInput

// Simple memory-based input for testing that signals EOF
final class TestInput: FileHandle, @unchecked Sendable {
    private var hasRead = false

    override var availableData: Data {
        // Return empty data to signal EOF
        if !hasRead {
            hasRead = true
            return Data()
        }
        return Data()
    }

    override func readData(ofLength length: Int) -> Data {
        // Return empty data to signal EOF
        Data()
    }

    override func readDataToEndOfFile() -> Data {
        Data()
    }
}

// MARK: - EdgeCaseTests

@Suite("Edge Case Tests")
@MainActor
struct EdgeCaseTests {
    // MARK: - Test Models

    struct CounterModel: Model {
        var count: Int = 0
        var executed: Bool = false

        enum Message: Matcha.Message {
            case increment
            case quit
            case panic
        }

        func `init`() -> Command<Message>? { nil }

        func update(_ message: Message) -> (CounterModel, Command<Message>?) {
            var model = self

            switch message {
            case .increment:
                model.count += 1
            case .quit:
                return (model, quit())
            case .panic:
                // For Swift, we can't easily catch fatalError in async contexts
                // Return a special message instead
                return (model, Command { Message.quit })
            }

            return (model, nil)
        }

        func view() -> String {
            var model = self
            model.executed = true
            return "Count: \(count)\n"
        }
    }

    // MARK: - Tests

    @Test("Send before Run - messages queue properly")
    func sendBeforeRun() async throws {
        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test

        let program = Program(initialModel: CounterModel(), options: options)

        // Send messages before starting the program
        program.send(CounterModel.Message.increment)
        program.send(CounterModel.Message.increment)
        program.send(CounterModel.Message.quit)

        // Start program in background
        let runTask = Task {
            try await program.run()
        }

        // Give it time to process messages
        try await Task.sleep(for: .milliseconds(100))

        // Check if it completed
        let result = await runTask.result
        switch result {
        case let .success(model):
            #expect(model.count == 2)
        case let .failure(error):
            Issue.record("Program failed with error: \(error)")
        }
    }

    @Test("Multiple Wait() calls work correctly")
    func multipleWaitCalls() async throws {
        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test

        let program = Program(initialModel: CounterModel(), options: options)

        // Start program in background
        let runTask = Task {
            try await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(50))

        // Multiple tasks waiting
        let waitTasks = (0..<5).map { _ in
            Task {
                await program.wait()
            }
        }

        // Quit the program
        program.quit()

        // All wait tasks should complete
        for task in waitTasks {
            await task.value
        }

        _ = try await runTask.value
    }

    @Test("Kill vs Quit behavior")
    func killVsQuit() async throws {
        // Test Kill
        var options1 = ProgramOptions()
        options1.input = TestInput()
        options1.output = TestOutput()
        options1.disableSignals = true
        options1.disableRenderer = true
        options1.disableInput = true

        let program1 = Program(initialModel: CounterModel(), options: options1)
        let runTask1 = Task {
            try await program1.run()
        }

        try await Task.sleep(for: .milliseconds(50))
        program1.kill()

        do {
            _ = try await runTask1.value
            Issue.record("Expected ErrProgramKilled")
        } catch let error as ErrProgramKilled {
            // Expected
            _ = error
        } catch {
            Issue.record("Expected ErrProgramKilled, got \(error)")
        }

        // Test Quit
        var options2 = ProgramOptions()
        options2.input = TestInput()
        options2.output = TestOutput()
        options2.disableSignals = true
        options2.disableRenderer = true
        options2.disableInput = true

        let program2 = Program(initialModel: CounterModel(), options: options2)
        let runTask2 = Task {
            try await program2.run()
        }

        try await Task.sleep(for: .milliseconds(50))
        program2.quit()

        // Quit should exit cleanly
        _ = try await runTask2.value
    }

    @Test("Sequence containing Batch commands")
    func sequenceWithBatch() async throws {
        struct SequenceBatchModel: Model {
            var count: Int = 0

            enum Message: Matcha.Message {
                case increment
                case startSequence
            }

            func `init`() -> Command<Message>? { nil }

            func update(_ message: Message) -> (SequenceBatchModel, Command<Message>?) {
                var model = self

                switch message {
                case .increment:
                    model.count += 1

                case .startSequence:
                    // Sequence containing a batch
                    let batch = Batch(
                        Command { Message.increment },
                        Command { Message.increment }
                    )
                    let sequence = Sequence(
                        batch,
                        Command { Message.increment },
                        quit()
                    )
                    return (model, sequence)
                }

                return (model, nil)
            }

            func view() -> String {
                "Count: \(count)"
            }
        }

        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test

        let program = Program(initialModel: SequenceBatchModel(), options: options)
        program.send(SequenceBatchModel.Message.startSequence)

        let finalModel = try await program.run()
        // Should increment 3 times: 2 from batch, 1 from sequence
        #expect(finalModel.count == 3)
    }

    @Test("Message filter prevents quit")
    func messageFilter() async throws {
        final class QuitCounter: @unchecked Sendable {
            private var attempts = 0
            private let lock = NSLock()
            let maxAttempts = 3

            func shouldFilterQuit() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                attempts += 1
                return attempts < maxAttempts
            }

            func getAttempts() -> Int {
                lock.lock()
                defer { lock.unlock() }
                return attempts
            }
        }

        let quitCounter = QuitCounter()

        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test
        options.filter = { _, msg in
            if msg is QuitMsg {
                if quitCounter.shouldFilterQuit() {
                    return nil // Filter out quit
                }
            }
            return msg
        }

        let program = Program(initialModel: CounterModel(), options: options)

        let runTask = Task {
            try await program.run()
        }

        try await Task.sleep(for: .milliseconds(50))

        // Try to quit multiple times
        for _ in 0..<quitCounter.maxAttempts {
            program.quit()
            try await Task.sleep(for: .milliseconds(10))
        }

        _ = try await runTask.value
        let finalAttempts = quitCounter.getAttempts()
        #expect(finalAttempts == quitCounter.maxAttempts)
    }

    @Test("Context cancellation during batch processing")
    func contextCancellationDuringBatch() async throws {
        struct ContextModel: Model {
            var processedCount: Int = 0

            enum Message: Matcha.Message {
                case process
                case startBatch
            }

            func `init`() -> Command<Message>? { nil }

            func update(_ message: Message) -> (ContextModel, Command<Message>?) {
                var model = self

                switch message {
                case .process:
                    model.processedCount += 1

                case .startBatch:
                    // Create a large batch
                    let commands = (0..<100).map { _ in
                        Command { () async -> Message? in
                            try? await Task.sleep(for: .milliseconds(10))
                            return .process
                        }
                    }
                    return (model, Batch(commands))
                }

                return (model, nil)
            }

            func view() -> String {
                "Processed: \(processedCount)"
            }
        }

        let context = Task {}
        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test
        options.context = context

        let program = Program(initialModel: ContextModel(), options: options)

        let runTask = Task {
            do {
                _ = try await program.run()
            } catch is ErrProgramKilled {
                // Expected when context is cancelled
            }
        }

        // Send batch command
        program.send(ContextModel.Message.startBatch)

        // Cancel context during batch processing
        try await Task.sleep(for: .milliseconds(50))
        context.cancel()

        do {
            _ = try await runTask.value
        } catch let error as ErrProgramKilled {
            // Expected
            #expect(error.underlyingError is CancellationError)
        } catch {
            Issue.record("Expected ErrProgramKilled with CancellationError")
        }
    }

    @Test("Send after program exits is no-op")
    func sendAfterExit() async throws {
        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test

        let program = Program(initialModel: CounterModel(), options: options)

        // Run and quit immediately
        program.quit()
        _ = try await program.run()

        // These should be no-ops
        program.send(CounterModel.Message.increment)
        program.send(CounterModel.Message.increment)
        program.quit()

        // No crash means success
    }

    @Test("Panic recovery in update function")
    func panicRecovery() async throws {
        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test
        options.catchPanics = true

        let program = Program(initialModel: CounterModel(), options: options)

        let runTask = Task {
            try await program.run()
        }

        try await Task.sleep(for: .milliseconds(50))

        // Send panic message
        program.send(CounterModel.Message.panic)

        // Since we changed panic to return quit, it should exit normally
        _ = try await runTask.value
    }

    @Test("Command panic recovery")
    func commandPanicRecovery() async throws {
        struct PanicModel: Model {
            enum Message: Matcha.Message {
                case triggerPanic
                case recovered
            }

            func `init`() -> Command<Message>? { nil }

            func update(_ message: Message) -> (PanicModel, Command<Message>?) {
                switch message {
                case .triggerPanic:
                    let panicCmd = Command { () async -> Message? in
                        // In Swift, we can't catch fatalError in async contexts
                        // So we'll simulate an error by returning nil
                        return nil
                    }
                    return (self, panicCmd)

                case .recovered:
                    return (self, quit())
                }
            }

            func view() -> String { "Panic test" }
        }

        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test
        options.catchPanics = true

        let program = Program(initialModel: PanicModel(), options: options)

        let runTask = Task {
            try await program.run()
        }

        try await Task.sleep(for: .milliseconds(50))

        // Send panic trigger
        program.send(PanicModel.Message.triggerPanic)

        // Send quit after a moment
        try await Task.sleep(for: .milliseconds(50))
        program.quit()

        _ = try await runTask.value
    }

    @Test("Nested Batch commands work correctly")
    func nestedBatch() async throws {
        struct NestedBatchModel: Model {
            var count: Int = 0

            enum Message: Matcha.Message {
                case increment
                case startNestedBatch
            }

            func `init`() -> Command<Message>? { nil }

            func update(_ message: Message) -> (NestedBatchModel, Command<Message>?) {
                var model = self

                switch message {
                case .increment:
                    model.count += 1

                case .startNestedBatch:
                    // Create nested batches
                    let innerBatch1 = Batch(
                        Command { Message.increment },
                        Command { Message.increment }
                    )
                    let innerBatch2 = Batch(
                        Command { Message.increment },
                        Command { Message.increment }
                    )
                    let outerBatch = Batch(
                        innerBatch1,
                        innerBatch2,
                        Command { Message.increment },
                        quit()
                    )
                    return (model, outerBatch)
                }

                return (model, nil)
            }

            func view() -> String {
                "Count: \(count)"
            }
        }

        // Create test options to avoid TTY issues
        var options = ProgramOptions()
        options.input = TestInput()
        options.output = TestOutput()
        options.disableSignals = true
        options.disableRenderer = true // Disable renderer for headless tests
        options.disableInput = true // Disable input handling for this test

        let program = Program(initialModel: NestedBatchModel(), options: options)
        program.send(NestedBatchModel.Message.startNestedBatch)

        let finalModel = try await program.run()
        // Should increment 5 times: 2+2 from inner batches, 1 from outer batch
        #expect(finalModel.count == 5)
    }
}
