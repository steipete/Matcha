import Testing
@testable import Matcha

// MARK: - ModelTests

@Suite("Model Tests")
@MainActor
struct ModelTests {
    @Test("Basic model update operations")
    func basicModelUpdate() async throws {
        let tester = ProgramTester(model: TestModel())

        try await tester.test {
            // Initial state
            let view1 = tester.getCurrentView()
            #expect(view1.contains("Value: 0"))
            #expect(view1.contains("Text: "))

            // Test increment
            await tester.send(.increment)
            try await Task.sleep(for: .milliseconds(50))
            let view2 = tester.getCurrentView()
            #expect(view2.contains("Value: 1"))

            // Test decrement
            await tester.send(.decrement)
            await tester.send(.decrement)
            try await Task.sleep(for: .milliseconds(50))
            let view3 = tester.getCurrentView()
            #expect(view3.contains("Value: -1"))

            // Test set text
            await tester.send(.setText("Hello"))
            try await Task.sleep(for: .milliseconds(50))
            let view4 = tester.getCurrentView()
            #expect(view4.contains("Text: Hello"))
        }
    }

    @Test("Model view rendering")
    func modelView() async throws {
        let tester = ProgramTester(model: TestModel(value: 42, text: "Test"))

        try await tester.test {
            try await tester.expectView(containing: "Value: 42")
            try await tester.expectView(containing: "Text: Test")
            try await tester.expectView(containing: "Running: false")
        }
    }

    @Test("Complex model filtering")
    func complexModelFiltering() async throws {
        var model = ComplexTestModel()
        model.items = ["Apple", "Banana", "Cherry", "Date"]

        let tester = ProgramTester(model: model)

        try await tester.test {
            // Test filtering
            await tester.send(.setFilter("a"))
            try await tester.expectView(containing: "Apple")
            try await tester.expectView(containing: "Banana")

            // Cherry and Date should not appear when filtered
            let view = tester.getCurrentView()
            #expect(!view.contains("Cherry"))
            #expect(!view.contains("Date"))
        }
    }

    @Test("Model commands trigger timers")
    func modelCommands() async throws {
        let tester = ProgramTester(model: TestModel())

        try await tester.test {
            // Start should trigger timer
            await tester.send(.start)
            try await Task.sleep(for: .milliseconds(50))
            let view1 = tester.getCurrentView()
            #expect(view1.contains("Running: true"))

            // Wait for a tick
            try await Task.sleep(for: .seconds(1.1))

            // Value should have incremented from timer
            let view2 = tester.getCurrentView()
            #expect(!view2.contains("Value: 0")) // Should be > 0

            // Stop the timer
            await tester.send(.stop)
            try await Task.sleep(for: .milliseconds(50))
            let view3 = tester.getCurrentView()
            #expect(view3.contains("Running: false"))
        }
    }

    @Test("Error handling in models")
    func errorHandling() async throws {
        let tester = ProgramTester(model: ComplexTestModel())

        try await tester.test {
            // Try to select invalid index
            await tester.send(.selectItem(10))
            try await Task.sleep(for: .milliseconds(50))

            try await tester.expectView(containing: "Error: Invalid index")

            // Clear error
            await tester.send(.clearError)
            try await Task.sleep(for: .milliseconds(50))
            let view = tester.getCurrentView()
            #expect(!view.contains("Error:"))
        }
    }
}

// MARK: - ModelProtocolTests

@Suite("Model Protocol Conformance Tests")
struct ModelProtocolTests {
    @Test("Model associated type conformance")
    func modelAssociatedType() {
        // This test ensures the Model protocol is properly defined
        struct ConcreteModel: Model {
            typealias Msg = TestMessage

            func `init`() -> Command<TestMessage>? {
                nil
            }

            func update(_ message: TestMessage) -> (ConcreteModel, Command<TestMessage>?) {
                (self, nil)
            }

            func view() -> String {
                "Test"
            }
        }

        let model = ConcreteModel()
        let (newModel, cmd) = model.update(.increment)

        // newModel is valid
        #expect(cmd == nil)
    }

    @Test("Model can be Sendable")
    func modelSendability() {
        // Ensure models can be Sendable
        struct SendableModel: Model, Sendable {
            typealias Msg = TestMessage
            let value: Int

            init() {
                self.value = 0
            }

            func `init`() -> Command<TestMessage>? {
                nil
            }

            func update(_ message: TestMessage) -> (SendableModel, Command<TestMessage>?) {
                (self, nil)
            }

            func view() -> String {
                "Value: \(value)"
            }
        }

        // This should compile without errors
        let _: any Model & Sendable = SendableModel()
    }
}
