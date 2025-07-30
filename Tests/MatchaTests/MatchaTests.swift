//
//  MatchaTests.swift
//  MatchaTests
//
//  Test suite for Matcha.
//

import XCTest
@testable import Matcha
@testable import MatchaBubbles
@testable import MatchaStyle

/// Main test suite that verifies basic framework functionality
final class MatchaTests: XCTestCase {
    
    func testFrameworkImports() throws {
        // Verify all modules can be imported
        XCTAssertNotNil(Program<TestModel>.self)
        XCTAssertNotNil(TextInput.self)
        XCTAssertNotNil(Style.self)
    }
    
    func testBasicProgramCreation() async throws {
        let program = Program(initialModel: TestModel())
        XCTAssertNotNil(program)
        
        // Verify initial state
        XCTAssertEqual(program.model.value, 0)
        XCTAssertEqual(program.model.text, "")
    }
    
    func testMessageSending() async throws {
        let program = Program(initialModel: TestModel())
        
        // Send a message
        program.send(TestMessage.increment)
        
        // Allow time for processing
        try await Task.sleep(for: .milliseconds(10))
        
        // Model should be updated
        XCTAssertEqual(program.model.value, 1)
    }
    
    func testProgramOptions() async throws {
        var options = ProgramOptions.default
        options.fps = 30
        options.useAltScreen = true
        options.mouseMode = .cellMotion
        
        let program = Program(
            initialModel: TestModel(),
            options: options
        )
        
        XCTAssertNotNil(program)
    }
    
    func testQuitMessage() async throws {
        let program = Program(initialModel: TestModel())
        
        // Send quit
        program.send(TestMessage.quit)
        
        // Program should handle quit gracefully
        let expectation = XCTestExpectation(description: "Program quits")
        
        Task {
            do {
                _ = try await program.run()
                expectation.fulfill()
            } catch {
                XCTFail("Program failed with error: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

// MARK: - Integration Tests

final class MatchaIntegrationTests: XCTestCase {
    
    func testFullProgramLifecycle() async throws {
        var options = ProgramOptions.default
        options.fps = 120 // Fast for testing
        
        let tester = ProgramTester(model: TestModel(), options: options)
        
        try await tester.test {
            // Send multiple messages
            await tester.send(.increment)
            await tester.send(.increment)
            await tester.send(.setText("Integration Test"))
            
            // Verify state
            XCTAssertEqual(tester.model.value, 2)
            XCTAssertEqual(tester.model.text, "Integration Test")
            
            // Verify view
            try await tester.expectView(containing: "Value: 2")
            try await tester.expectView(containing: "Text: Integration Test")
        }
    }
    
    func testKeyboardIntegration() async throws {
        struct KeyboardModel: Model {
            typealias Msg = Message
            
            var keys: [String] = []
            
            enum Message: Matcha.Message {
                case key(String)
            }
            
            init() {}
            
            func update(_ message: Message) -> (KeyboardModel, Command<Message>?) {
                var model = self
                switch message {
                case .key(let key):
                    model.keys.append(key)
                }
                return (model, nil)
            }
            
            func view() -> String {
                return "Keys: \(keys.joined(separator: ", "))"
            }
        }
        
        var options = ProgramOptions.default
        options.onMessage = { msg in
            if let keyMsg = msg as? KeyMsg {
                return KeyboardModel.Message.key(keyMsg.description)
            }
            return nil
        }
        
        let tester = ProgramTester(model: KeyboardModel(), options: options)
        
        try await tester.test {
            await tester.sendKey("a")
            await tester.sendKey("b")
            await tester.sendKey("enter")
            
            try await tester.expectView(containing: "Keys: a, b, enter")
        }
    }
    
    func testComponentIntegration() async throws {
        struct ComponentModel: Model {
            typealias Msg = Message
            
            var textInput = TextInput()
            var showHelp = false
            
            enum Message: Matcha.Message {
                case textInputMsg(TextInputMsg)
                case toggleHelp
            }
            
            init() {
                textInput.placeholder = "Enter text..."
            }
            
            func update(_ message: Message) -> (ComponentModel, Command<Message>?) {
                var model = self
                
                switch message {
                case .textInputMsg(let msg):
                    if let key = msg as? Key {
                        model.textInput.update(key)
                    }
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
            
            // Type some text
            await tester.send(.textInputMsg(Key(description: "H")))
            await tester.send(.textInputMsg(Key(description: "i")))
            
            // Should show typed text
            try await tester.expectView(containing: "Hi")
            
            // Toggle help
            await tester.send(.toggleHelp)
            try await tester.expectView(containing: "Help:")
        }
    }
}
