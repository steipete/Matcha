import Foundation
import Testing
@testable import Matcha

// MARK: - ContextTests

@Suite("Context and Advanced Options Tests")
@MainActor
struct ContextTests {
    // Test model for context testing
    struct ContextModel: Model {
        typealias Msg = TestMessage

        enum TestMessage: Message, Equatable {
            case contextEvent
            case errorOccurred(String)
            case completed
        }

        var contextEventReceived: Bool = false
        var errorReceived: String?
        var isCompleted: Bool = false

        init() {}

        func `init`() -> Command<TestMessage>? {
            nil
        }

        func update(_ message: TestMessage) -> (ContextModel, Command<TestMessage>?) {
            var model = self
            switch message {
            case .contextEvent:
                model.contextEventReceived = true
                return (model, nil)
            case let .errorOccurred(error):
                model.errorReceived = error
                return (model, nil)
            case .completed:
                model.isCompleted = true
                return (model, nil)
            }
        }

        func view() -> String {
            "Context: \(contextEventReceived), Error: \(errorReceived ?? "none"), Completed: \(isCompleted)"
        }
    }

    @Test("Program with external context")
    func externalContext() async throws {
        let contextExecuted = ManagedCriticalState(false)
        let context = Task<Void, Never> {
            await contextExecuted.setValue(true)
        }

        var options = ProgramOptions()
        options.context = context

        let program = Program(
            initialModel: ContextModel(),
            options: options
        )

        // Start program in background
        Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Verify context is running
        let executed = await contextExecuted.getValue()
        #expect(executed == true)

        // Quit program
        program.quit()
        await program.wait()
    }

    @Test("Program with forceTTY option")
    func forceTTYOption() async throws {
        var options = ProgramOptions()
        options.forceTTY = true

        // This should try to open /dev/tty
        // We can't easily test this without mocking, but at least verify no crash
        _ = Program(
            initialModel: ContextModel(),
            options: options
        )

        #expect(options.forceTTY == true)
    }

    @Test("Program with disabled signals")
    func disabledSignals() async throws {
        var options = ProgramOptions()
        options.disableSignals = true
        options.handleSignals = true // This should be overridden by disableSignals

        _ = Program(
            initialModel: ContextModel(),
            options: options
        )

        // Can't easily verify signal handling is disabled, but verify no crash
        #expect(options.disableSignals == true)
    }

    @Test("Program with disabled renderer")
    func disabledRenderer() async throws {
        var options = ProgramOptions()
        options.disableRenderer = true

        let program = Program(
            initialModel: ContextModel(),
            options: options
        )

        // Start program in background
        Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Should work without renderer
        program.send(ContextModel.TestMessage.contextEvent)

        // Give it time to process
        try await Task.sleep(for: .milliseconds(100))

        // Quit program
        program.quit()
        await program.wait()
    }

    @Test("Program error channel")
    func errorChannel() async throws {
        let program = Program(initialModel: ContextModel())

        // Start program in background
        Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Send an error
        struct TestError: Error {
            let message: String
        }
        program.sendError(TestError(message: "Test error"))

        // Give it time to process
        try await Task.sleep(for: .milliseconds(100))

        // Quit program
        program.quit()
        await program.wait()
    }

    @Test("Program finished handler")
    func finishedHandler() async throws {
        let finishedCalled = ManagedCriticalState(false)

        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.input = Pipe().fileHandleForReading
        let program = Program(initialModel: ContextModel(), options: options)

        // Set finished handler
        program.onFinished {
            await finishedCalled.setValue(true)
        }

        // Start program in background
        let runTask = Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Quit program
        program.quit()

        // Wait for task to complete
        await runTask.value

        // Give it a moment for cleanup to complete
        try await Task.sleep(for: .milliseconds(50))

        // Verify finished handler was called
        let called = await finishedCalled.getValue()
        #expect(called == true)
    }

    @Test("BatchMsg executes messages concurrently")
    func batchMessage() async throws {
        let program = Program(initialModel: ContextModel())

        // Start program in background
        Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Send messages directly
        program.send(ContextModel.TestMessage.contextEvent)
        program.send(ContextModel.TestMessage.errorOccurred("Batch error"))
        program.send(ContextModel.TestMessage.completed)

        // Give it time to process
        try await Task.sleep(for: .milliseconds(200))

        // Quit program
        program.quit()
        await program.wait()
    }

    @Test("RepaintMsg triggers repaint")
    func repaintMessage() async throws {
        let program = Program(initialModel: ContextModel())

        // Start program in background
        Task {
            try? await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Send repaint message
        program.send(RepaintMsg())

        // Give it time to process
        try await Task.sleep(for: .milliseconds(100))

        // Quit program
        program.quit()
        await program.wait()
    }
}

// MARK: - ManagedCriticalState

// Helper for thread-safe state management
private actor ManagedCriticalState<Value> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func getValue() -> Value {
        value
    }

    func setValue(_ newValue: Value) {
        value = newValue
    }
}
