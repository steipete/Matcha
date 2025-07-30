import Testing
@testable import Matcha
@testable import MatchaBubbles
@testable import MatchaStyle

// MARK: - MatchaTests

/// Main test suite that verifies basic framework functionality
@Suite("Matcha Framework Tests")
@MainActor
struct MatchaTests {
    @Test("Framework imports work correctly")
    func frameworkImports() throws {
        // Verify all modules can be imported
        // Just verify that types exist and are accessible
        _ = Program<TestModel>.self
        _ = TextInput.self
        _ = Style.self
    }

    @Test("Basic program creation")
    func basicProgramCreation() async throws {
        let program = Program(initialModel: TestModel())
        // Program creation succeeded

        // Note: We can't access program.model directly as it's private
        // This test mainly verifies that program creation doesn't crash
    }

    @Test("Message sending to program")
    func messageSending() async throws {
        let tester = ProgramTester(model: TestModel())

        try await tester.test {
            // Send a message
            await tester.send(.increment)

            // Model should be updated - check view
            let view = tester.getCurrentView()
            #expect(view.contains("Count: 1") || view.contains("Value: 1"))
        }
    }

    @Test("Program options configuration")
    func programOptions() async throws {
        var options = ProgramOptions.default
        options.fps = 30
        options.useAltScreen = true
        options.mouseMode = .cellMotion

        let program = Program(
            initialModel: TestModel(),
            options: options
        )

        // Program creation succeeded
    }

    @Test("Quit message handling")
    func quitMessage() async throws {
        let program = Program(initialModel: TestModel())

        // Create a task to run the program
        let programTask = Task {
            try await program.run()
        }

        // Give the program time to start
        try await Task.sleep(for: .milliseconds(10))

        // Send quit
        program.quit()

        // Wait for program to finish
        await withTaskCancellationHandler {
            _ = await programTask.result
        } onCancel: {
            programTask.cancel()
        }

        // If we get here, the program quit successfully
        #expect(true)
    }
}

// MARK: - MatchaIntegrationTests

@Suite("Matcha Integration Tests")
@MainActor
struct MatchaIntegrationTests {
    @Test("Full program lifecycle")
    func fullProgramLifecycle() async throws {
        var options = ProgramOptions.default
        options.fps = 120 // Fast for testing

        let tester = ProgramTester(model: TestModel(), options: options)

        try await tester.test {
            // Send multiple messages
            await tester.send(.increment)
            await tester.send(.increment)
            await tester.send(.setText("Integration Test"))

            // Verify view
            try await tester.expectView(containing: "Value: 2")
            try await tester.expectView(containing: "Text: Integration Test")
        }
    }

    @Test("Keyboard integration")
    func keyboardIntegration() async throws {
        struct KeyboardModel: Model {
            typealias Msg = Message

            var keys: [String] = []

            enum Message: Matcha.Message {
                case key(String)
            }

            func `init`() -> Command<Message>? {
                nil
            }

            func update(_ message: Message) -> (KeyboardModel, Command<Message>?) {
                var model = self
                switch message {
                case let .key(key):
                    model.keys.append(key)
                }
                return (model, nil)
            }

            func view() -> String {
                "Keys: \(keys.joined(separator: ", "))"
            }
        }

        var options = ProgramOptions.default
        // Note: onMessage doesn't exist, we'll need to handle key input differently

        let tester = ProgramTester(model: KeyboardModel(), options: options)

        try await tester.test {
            // Send key messages directly
            await tester.send(.key("a"))
            await tester.send(.key("b"))
            await tester.send(.key("enter"))

            try await tester.expectView(containing: "Keys: a, b, enter")
        }
    }

    @Test("Component integration with TextInput")
    func componentIntegration() async throws {
        struct ComponentModel: Model {
            typealias Msg = Message

            var textInput = TextInput()
            var showHelp = false

            enum Message: Matcha.Message {
                case textInputMsg(KeyMsg)
                case toggleHelp
            }

            init() {
                self.textInput = textInput.withPlaceholder("Enter text...").withFocus(true)
            }

            func `init`() -> Command<Message>? {
                nil
            }

            func update(_ message: Message) -> (ComponentModel, Command<Message>?) {
                var model = self

                switch message {
                case let .textInputMsg(msg):
                    model.textInput = model.textInput.update(msg)
                    return (model, nil)

                case .toggleHelp:
                    model.showHelp.toggle()
                    return (model, nil)
                }
            }

            func view() -> String {
                var view = "Text Input Test\n\n"
                view += textInput.view()
                view += "\n\n"

                if showHelp {
                    view += "Help: Type to enter text, ? to toggle help"
                }

                return view
            }
        }

        let tester = ProgramTester(model: ComponentModel())

        try await tester.test {
            // Verify initial state
            try await tester.expectView(containing: "Enter text...")

            // Type some text using proper KeyMsg initialization
            await tester.send(.textInputMsg(KeyMsg(character: "H")))
            await tester.send(.textInputMsg(KeyMsg(character: "i")))

            // Should show typed text
            try await tester.expectView(containing: "Hi")

            // Toggle help
            await tester.send(.toggleHelp)
            try await tester.expectView(containing: "Help:")
        }
    }
}
