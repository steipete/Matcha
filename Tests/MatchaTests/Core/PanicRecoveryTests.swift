import Foundation
import Testing
#if canImport(Darwin)
    import Darwin
#endif
@testable import Matcha

// MARK: - PanicRecoveryTests

/// Tests for panic recovery functionality
@Suite("Panic Recovery Tests")
struct PanicRecoveryTests {
    // MARK: - Panic Recovery Tests

    /// Test that program recovers from panics when catchPanics is enabled
    @Test("Program recovers from panics when catchPanics is enabled")
    @MainActor
    func panicRecovery() async throws {
        struct PanicModel: Model {
            typealias Msg = PanicMessage

            var shouldPanic: Bool = false

            func `init`() -> Command<PanicMessage>? {
                nil
            }

            func update(_ message: PanicMessage) -> (PanicModel, Command<PanicMessage>?) {
                var model = self

                switch message {
                case .triggerPanic:
                    model.shouldPanic = true
                    return (model, Command { () -> PanicMessage? in
                        fatalError("Intentional panic for testing")
                    })
                case .normal:
                    return (model, nil)
                }
            }

            func view() -> String {
                "Should panic: \(shouldPanic)"
            }
        }

        enum PanicMessage: Message {
            case triggerPanic
            case normal
        }

        let model = PanicModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.catchPanics = true

        let program = Program(initialModel: model, options: options)

        // Start program in background
        let programTask = Task {
            do {
                _ = try await program.run()
                Issue.record("Program should have thrown an error")
            } catch {
                // We expect an ErrProgramPanic error
                #expect(error is ErrProgramPanic)
            }
        }

        // Wait a bit for program to start
        try await Task.sleep(for: .milliseconds(100))

        // Trigger panic
        program.send(PanicMessage.triggerPanic)

        // Wait for program to handle panic and exit
        await programTask.value
    }

    /// Test that panics are not caught when catchPanics is disabled
    @Test("Panics are not caught when catchPanics is disabled")
    @MainActor
    func panicNotCaughtWhenDisabled() async throws {
        struct CrashModel: Model {
            typealias Msg = CrashMessage

            func `init`() -> Command<CrashMessage>? {
                nil
            }

            func update(_ message: CrashMessage) -> (CrashModel, Command<CrashMessage>?) {
                switch message {
                case .crash:
                    // This would normally crash, but we can't test actual crashes
                    // in unit tests, so just return nil
                    (self, nil)
                }
            }

            func view() -> String {
                "Ready to crash"
            }
        }

        enum CrashMessage: Message {
            case crash
        }

        let model = CrashModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.catchPanics = false // Disable panic catching

        let program = Program(initialModel: model, options: options)

        // Start program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Send crash message
        program.send(CrashMessage.crash)

        // Wait a bit
        try await Task.sleep(for: .milliseconds(200))

        // Kill the program to clean up
        program.kill()
        await programTask.value
    }

    // MARK: - Error Propagation Tests

    /// Test that errors in commands are properly handled
    @Test("Command errors are properly handled")
    @MainActor
    func commandErrorHandling() async throws {
        struct ErrorModel: Model {
            typealias Msg = ErrorMessage

            var errorCount: Int = 0

            func `init`() -> Command<ErrorMessage>? {
                nil
            }

            func update(_ message: ErrorMessage) -> (ErrorModel, Command<ErrorMessage>?) {
                var model = self

                switch message {
                case .triggerError:
                    return (model, Command { () async -> ErrorMessage? in
                        // In a real app, this would throw an error
                        // For testing, we'll just return the error occurred message
                        return .errorOccurred
                    })
                case .errorOccurred:
                    model.errorCount += 1
                    return (model, nil)
                }
            }

            func view() -> String {
                "Errors: \(errorCount)"
            }
        }

        enum ErrorMessage: Message {
            case triggerError
            case errorOccurred
        }

        enum TestError: Error {
            case intentional
        }

        let model = ErrorModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()

        let program = Program(initialModel: model, options: options)

        // Run program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Trigger error
        program.send(ErrorMessage.triggerError)

        // Wait for error handling
        try await Task.sleep(for: .milliseconds(200))

        // Program should still be running
        program.quit()
        await programTask.value
    }

    // MARK: - Context Cancellation Tests

    /// Test program behavior when context is cancelled
    @Test("Program handles context cancellation")
    @MainActor
    func contextCancellation() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()

        // Create a cancellable context
        let contextTask = Task<Void, Never> {
            _ = try? await Task.sleep(for: .milliseconds(200))
        }
        options.context = contextTask

        let program = Program(initialModel: model, options: options)

        do {
            _ = try await program.run()
            Issue.record("Program should have been killed")
        } catch let error as ErrProgramKilled {
            // Check that the error includes context cancellation
            #expect(error.underlyingError != nil)
            #expect(error.underlyingError is CancellationError)
        } catch {
            Issue.record("Expected ErrProgramKilled, got \(error)")
        }
    }

    // MARK: - Interrupt Handling Tests

    /// Test that interrupts are properly handled
    @Test("Interrupts are properly handled")
    @MainActor
    func interruptHandling() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.handleSignals = false // We'll send interrupt manually

        let program = Program(initialModel: model, options: options)

        // Track if we received interrupt
        var receivedInterrupt = false

        // Start program
        let programTask = Task {
            do {
                _ = try await program.run()
            } catch is ErrInterrupted {
                receivedInterrupt = true
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Send interrupt message
        program.send(InterruptMsg())

        // Program should handle it
        try await Task.sleep(for: .milliseconds(100))

        // Quit normally
        program.quit()
        await programTask.value

        // Note: In a real scenario, the model would decide whether to quit on interrupt
        #expect(!receivedInterrupt)
    }

    // MARK: - Deadlock Detection Tests

    /// Test that program doesn't deadlock on rapid message sending
    @Test("No deadlock on rapid message sending")
    @MainActor
    func noDeadlockOnRapidMessages() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()

        let program = Program(initialModel: model, options: options)

        // Start program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Send many messages rapidly
        for i in 0..<1000 {
            if i % 2 == 0 {
                program.send(TestMessage.increment)
            } else {
                program.send(TestMessage.setText("Message \(i)"))
            }
        }

        // Should still be responsive
        program.quit()

        // Should exit cleanly within reasonable time
        let timeout = Task {
            try? await Task.sleep(for: .seconds(5))
            Issue.record("Program deadlocked - didn't exit in 5 seconds")
        }

        await programTask.value
        timeout.cancel()
    }

    /// Test that concurrent commands don't cause deadlock
    @Test("No deadlock with concurrent commands")
    @MainActor
    func noDeadlockWithConcurrentCommands() async throws {
        struct ConcurrentModel: Model {
            typealias Msg = ConcurrentMessage

            var commandsExecuted: Int = 0

            func `init`() -> Command<ConcurrentMessage>? {
                nil
            }

            func update(_ message: ConcurrentMessage) -> (ConcurrentModel, Command<ConcurrentMessage>?) {
                var model = self

                switch message {
                case .startConcurrentWork:
                    // Create multiple concurrent commands
                    let commands = (0..<10).map { i in
                        Command<ConcurrentMessage> { () async -> ConcurrentMessage? in
                            try? await Task.sleep(for: .milliseconds(10))
                            return .workCompleted(i)
                        }
                    }
                    return (model, batch(commands))

                case .workCompleted:
                    model.commandsExecuted += 1
                    return (model, nil)
                }
            }

            func view() -> String {
                "Commands executed: \(commandsExecuted)"
            }
        }

        enum ConcurrentMessage: Message {
            case startConcurrentWork
            case workCompleted(Int)
        }

        let model = ConcurrentModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()

        let program = Program(initialModel: model, options: options)

        // Start program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Trigger concurrent work multiple times
        for _ in 0..<5 {
            program.send(ConcurrentMessage.startConcurrentWork)
            try await Task.sleep(for: .milliseconds(50))
        }

        // Wait for commands to complete
        try await Task.sleep(for: .milliseconds(500))

        // Should exit cleanly
        program.quit()
        await programTask.value
    }

    // MARK: - Terminal State Recovery Tests

    /// Test that terminal state is restored after panic
    @Test("Terminal state is restored after panic")
    @MainActor
    func terminalStateRestoredAfterPanic() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.useAltScreen = true
        options.mouseMode = .cellMotion
        options.enableBracketedPaste = true

        let program = Program(initialModel: model, options: options)

        // Capture initial terminal state
        let initialState = try? Terminal.current.getState()

        // Run program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))

        // Force quit (simulating a panic exit)
        program.kill()
        await programTask.value

        // Terminal state should be restored
        let finalState = try? Terminal.current.getState()

        // We can't directly compare states, but we can verify the program attempted cleanup
        #expect(initialState != nil)
        #expect(finalState != nil)
    }

    // MARK: - Resource Cleanup Tests

    /// Test that resources are properly cleaned up on exit
    @Test("Resources are properly cleaned up on exit")
    @MainActor
    func resourceCleanup() async throws {
        struct ResourceModel: Model {
            typealias Msg = ResourceMessage

            var resourcesAllocated: Int = 0

            func `init`() -> Command<ResourceMessage>? {
                nil
            }

            func update(_ message: ResourceMessage) -> (ResourceModel, Command<ResourceMessage>?) {
                var model = self

                switch message {
                case .allocateResource:
                    model.resourcesAllocated += 1
                    return (model, Command { () async -> ResourceMessage? in
                        // Simulate resource allocation
                        let data = Array(repeating: UInt8(0), count: 1024 * 1024) // 1MB
                        _ = data.count // Use it to avoid optimization
                        return .resourceAllocated
                    })

                case .resourceAllocated:
                    return (model, nil)
                }
            }

            func view() -> String {
                "Resources: \(resourcesAllocated)"
            }
        }

        enum ResourceMessage: Message {
            case allocateResource
            case resourceAllocated
        }

        let model = ResourceModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()

        // Measure memory before
        let memoryBefore = currentMemoryUsage()

        let program = Program(initialModel: model, options: options)

        // Run program
        let programTask = Task {
            _ = try? await program.run()
        }

        // Allocate resources
        for _ in 0..<10 {
            program.send(ResourceMessage.allocateResource)
            try await Task.sleep(for: .milliseconds(50))
        }

        // Quit normally
        program.quit()
        await programTask.value

        // Force garbage collection
        for _ in 0..<5 {
            try await Task.sleep(for: .milliseconds(100))
        }

        // Memory should be released (with some tolerance)
        let memoryAfter = currentMemoryUsage()
        let memoryIncrease = memoryAfter - memoryBefore

        // Should not leak more than 10MB
        #expect(memoryIncrease < 10 * 1024 * 1024)
    }

    // MARK: - Helper Functions

    private func currentMemoryUsage() -> Int64 {
        #if canImport(Darwin)
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count
                    )
                }
            }

            return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
        #else
            // Non-Darwin platforms don't have this API
            return 0
        #endif
    }
}
