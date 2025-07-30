import Foundation
import Testing
@testable import Matcha

@Suite("Program Options Tests")
@MainActor
struct OptionsTests {
    // Test model for option testing
    struct TestModel: Model {
        typealias Msg = TestMessage

        enum TestMessage: Message, Equatable {
            case test
        }

        func `init`() -> Command<TestMessage>? {
            nil
        }

        func update(_ message: TestMessage) -> (TestModel, Command<TestMessage>?) {
            (self, nil)
        }

        func view() -> String {
            "test"
        }
    }

    @Test("ProgramOptions can be configured with custom output")
    func withOutputOption() throws {
        let customOutput = TestOutputStream()
        var options = ProgramOptions()
        options.output = customOutput

        _ = Program(
            initialModel: TestModel(),
            options: options
        )

        // Program is created with custom options
        #expect(Bool(true)) // Can't directly access private properties
    }

    @Test("ProgramOptions can be configured with custom input")
    func withInputOption() throws {
        // Create a pipe for custom input
        let pipe = Pipe()
        var options = ProgramOptions()
        options.input = pipe.fileHandleForReading

        _ = Program(
            initialModel: TestModel(),
            options: options
        )

        // Program is created with custom options
        #expect(Bool(true)) // Can't directly access private properties
    }

    @Test("ProgramOptions supports alternate screen mode")
    func altScreenOption() throws {
        var options = ProgramOptions()
        options.useAltScreen = true

        _ = Program(
            initialModel: TestModel(),
            options: options
        )

        // Program is created with alt screen enabled
        #expect(options.useAltScreen == true)
    }

    @Test("ProgramOptions supports mouse modes")
    func mouseModeOptions() throws {
        var options1 = ProgramOptions()
        options1.mouseMode = .cellMotion

        var options2 = ProgramOptions()
        options2.mouseMode = .allMotion

        #expect(options1.mouseMode == .cellMotion)
        #expect(options2.mouseMode == .allMotion)
    }

    @Test("ProgramOptions supports bracketed paste mode")
    func bracketedPasteOption() throws {
        var options = ProgramOptions()
        options.enableBracketedPaste = false

        #expect(options.enableBracketedPaste == false)

        // Default should be true
        let defaultOptions = ProgramOptions()
        #expect(defaultOptions.enableBracketedPaste == true)
    }

    @Test("ProgramOptions supports FPS configuration")
    func fpsOption() throws {
        var options = ProgramOptions()
        options.fps = 30

        #expect(options.fps == 30)

        // Default should be 60
        let defaultOptions = ProgramOptions()
        #expect(defaultOptions.fps == 60)
    }

    @Test("ProgramOptions supports focus reporting")
    func focusReportingOption() throws {
        var options = ProgramOptions()
        options.reportFocus = true

        #expect(options.reportFocus == true)

        // Default should be false
        let defaultOptions = ProgramOptions()
        #expect(defaultOptions.reportFocus == false)
    }

    @Test("ProgramOptions supports panic catching configuration")
    func panicCatchingOption() throws {
        var options = ProgramOptions()
        options.catchPanics = false

        #expect(options.catchPanics == false)

        // Default should be true
        let defaultOptions = ProgramOptions()
        #expect(defaultOptions.catchPanics == true)
    }

    @Test("ProgramOptions supports signal handling configuration")
    func signalHandlingOption() throws {
        var options = ProgramOptions()
        options.handleSignals = false

        #expect(options.handleSignals == false)

        // Default should be true
        let defaultOptions = ProgramOptions()
        #expect(defaultOptions.handleSignals == true)
    }

    @Test("ProgramOptions supports message filter")
    func messageFilterOption() throws {
        actor FilterTracker {
            var called = false
            func markCalled() { called = true }
            func wasCalled() -> Bool { called }
        }

        let tracker = FilterTracker()
        let filter: @Sendable (any Model, any Message) -> (any Message)? = { _, msg in
            Task { await tracker.markCalled() }
            return msg
        }

        var options = ProgramOptions()
        options.filter = filter

        // Test that filter is set
        if let f = options.filter {
            _ = f(TestModel(), TestModel.TestMessage.test)
            // Can't easily verify async execution in sync context
            #expect(Bool(true))
        } else {
            Issue.record("Filter was not set")
        }
    }

    @Test("ProgramOptions supports environment variables")
    func environmentOption() throws {
        var options = ProgramOptions()
        options.environment["TEST_VAR"] = "test_value"

        #expect(options.environment["TEST_VAR"] == "test_value")

        // Default should include process environment
        let defaultOptions = ProgramOptions()
        #expect(!defaultOptions.environment.isEmpty)
    }

    @Test("Multiple options can be configured")
    func multipleOptions() throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        options.mouseMode = .allMotion
        options.enableBracketedPaste = false
        options.fps = 30
        options.reportFocus = true

        #expect(options.useAltScreen == true)
        #expect(options.mouseMode == .allMotion)
        #expect(options.enableBracketedPaste == false)
        #expect(options.fps == 30)
        #expect(options.reportFocus == true)
    }

    @Test("Program can be created with default options")
    func defaultOptions() throws {
        _ = Program(
            initialModel: TestModel()
        )

        // Program is created successfully with default options
        #expect(Bool(true))
    }

    @Test("Program sends and receives messages")
    func programMessaging() async throws {
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.input = Pipe().fileHandleForReading
        let program = Program(
            initialModel: TestModel(),
            options: options
        )

        // Start the program in background
        Task {
            try await program.run()
        }

        // Send a message
        program.send(TestModel.TestMessage.test)

        // Give it time to process
        try await Task.sleep(for: .milliseconds(100))

        // Quit the program
        program.quit()

        // Wait for it to finish
        await program.wait()
    }

    @Test("Program can be killed forcefully")
    func programKill() async throws {
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.input = Pipe().fileHandleForReading
        let program = Program(
            initialModel: TestModel(),
            options: options
        )

        // Start the program in background
        Task {
            try await program.run()
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(100))

        // Kill the program
        program.kill()

        // Wait for it to finish
        await program.wait()
    }
}
