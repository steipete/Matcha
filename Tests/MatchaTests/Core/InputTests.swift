//
//  InputTests.swift
//  MatchaTests
//
//  Tests for keyboard and mouse input handling.
//

import XCTest
@testable import Matcha

final class KeyboardInputTests: XCTestCase {
    
    func testKeyCreation() {
        // Test character keys
        let charKey = Key(description: "a")
        XCTAssertEqual(charKey.description, "a")
        
        // Test special keys
        let enterKey = Key(description: "enter")
        XCTAssertEqual(enterKey.description, "enter")
        
        let escKey = Key(description: "esc")
        XCTAssertEqual(escKey.description, "esc")
        
        // Test arrow keys
        let upKey = Key(description: "up")
        XCTAssertEqual(upKey.description, "up")
    }
    
    func testKeyEquality() {
        let key1 = Key(description: "a")
        let key2 = Key(description: "a")
        let key3 = Key(description: "b")
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testKeyModifiers() {
        // Test control combinations
        let ctrlC = Key(description: "ctrl+c")
        XCTAssertEqual(ctrlC.description, "ctrl+c")
        
        let ctrlA = Key(description: "ctrl+a")
        XCTAssertEqual(ctrlA.description, "ctrl+a")
    }
    
    func testFunctionKeys() {
        let f1 = Key(description: "f1")
        let f12 = Key(description: "f12")
        
        XCTAssertEqual(f1.description, "f1")
        XCTAssertEqual(f12.description, "f12")
    }
    
    func testKeyPatternMatching() {
        let key = Key(description: "q")
        
        // Test pattern matching with switch
        var matched = false
        switch key.description {
        case "q":
            matched = true
        default:
            break
        }
        
        XCTAssertTrue(matched)
    }
    
    func testSpecialKeys() {
        let keys = [
            "backspace",
            "delete",
            "tab",
            "home",
            "end",
            "pgup",
            "pgdown",
            "insert"
        ]
        
        for keyName in keys {
            let key = Key(description: keyName)
            XCTAssertEqual(key.description, keyName)
        }
    }
}

final class MouseInputTests: XCTestCase {
    
    func testMouseEventCreation() {
        let event = MouseEvent(
            x: 10,
            y: 20,
            action: .press,
            button: .left,
            shift: false,
            alt: false,
            ctrl: false
        )
        
        XCTAssertEqual(event.x, 10)
        XCTAssertEqual(event.y, 20)
        XCTAssertEqual(event.action, .press)
        XCTAssertEqual(event.button, .left)
        XCTAssertFalse(event.shift)
        XCTAssertFalse(event.alt)
        XCTAssertFalse(event.ctrl)
    }
    
    func testMouseActions() {
        let actions: [MouseAction] = [.press, .release, .motion]
        
        for action in actions {
            let event = MouseEvent(
                x: 0,
                y: 0,
                action: action,
                button: .left,
                shift: false,
                alt: false,
                ctrl: false
            )
            XCTAssertEqual(event.action, action)
        }
    }
    
    func testMouseButtons() {
        let buttons: [MouseButton] = [
            .none,
            .left,
            .middle,
            .right,
            .wheelUp,
            .wheelDown,
            .wheelLeft,
            .wheelRight
        ]
        
        for button in buttons {
            let event = MouseEvent(
                x: 0,
                y: 0,
                action: .press,
                button: button,
                shift: false,
                alt: false,
                ctrl: false
            )
            XCTAssertEqual(event.button, button)
        }
    }
    
    func testMouseModifiers() {
        let event = MouseEvent(
            x: 5,
            y: 10,
            action: .press,
            button: .left,
            shift: true,
            alt: true,
            ctrl: true
        )
        
        XCTAssertTrue(event.shift)
        XCTAssertTrue(event.alt)
        XCTAssertTrue(event.ctrl)
    }
    
    func testMouseWheel() {
        let wheelUp = MouseEvent(
            x: 50,
            y: 50,
            action: .motion,
            button: .wheelUp,
            shift: false,
            alt: false,
            ctrl: false
        )
        
        XCTAssertEqual(wheelUp.button, .wheelUp)
        XCTAssertEqual(wheelUp.action, .motion)
    }
    
    func testMouseEventEquality() {
        let event1 = MouseEvent(
            x: 10,
            y: 20,
            action: .press,
            button: .left,
            shift: false,
            alt: false,
            ctrl: false
        )
        
        let event2 = MouseEvent(
            x: 10,
            y: 20,
            action: .press,
            button: .left,
            shift: false,
            alt: false,
            ctrl: false
        )
        
        let event3 = MouseEvent(
            x: 15,
            y: 20,
            action: .press,
            button: .left,
            shift: false,
            alt: false,
            ctrl: false
        )
        
        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }
}

// MARK: - Input Integration Tests

final class InputIntegrationTests: XCTestCase {
    
    func testKeyboardInputInProgram() async throws {
        struct KeyTestModel: Model {
            typealias Msg = Message
            
            var lastKey: String = ""
            
            enum Message: Matcha.Message {
                case keyPressed(String)
            }
            
            init() {}
            
            func update(_ message: Message) -> (KeyTestModel, Command<Message>?) {
                var model = self
                switch message {
                case .keyPressed(let key):
                    model.lastKey = key
                }
                return (model, nil)
            }
            
            func view() -> String {
                return "Last key: \(lastKey)"
            }
        }
        
        var options = ProgramOptions.default
        options.onMessage = { msg in
            if let keyMsg = msg as? KeyMsg {
                return KeyTestModel.Message.keyPressed(keyMsg.description)
            }
            return nil
        }
        
        let tester = ProgramTester(model: KeyTestModel(), options: options)
        
        try await tester.test {
            await tester.sendKey("a")
            try await tester.expectView(containing: "Last key: a")
            
            await tester.sendKey("enter")
            try await tester.expectView(containing: "Last key: enter")
        }
    }
    
    func testMouseInputInProgram() async throws {
        struct MouseTestModel: Model {
            typealias Msg = Message
            
            var lastClick: (x: Int, y: Int) = (0, 0)
            
            enum Message: Matcha.Message {
                case mouseClick(x: Int, y: Int)
            }
            
            init() {}
            
            func update(_ message: Message) -> (MouseTestModel, Command<Message>?) {
                var model = self
                switch message {
                case .mouseClick(let x, let y):
                    model.lastClick = (x, y)
                }
                return (model, nil)
            }
            
            func view() -> String {
                return "Last click: (\(lastClick.x), \(lastClick.y))"
            }
        }
        
        var options = ProgramOptions.default
        options.mouseMode = .cellMotion
        options.onMessage = { msg in
            if let mouseMsg = msg as? MouseMsg {
                if mouseMsg.action == .press {
                    return MouseTestModel.Message.mouseClick(x: mouseMsg.x, y: mouseMsg.y)
                }
            }
            return nil
        }
        
        let tester = ProgramTester(model: MouseTestModel(), options: options)
        
        try await tester.test {
            await tester.sendMouse(x: 10, y: 20, action: .press)
            try await tester.expectView(containing: "Last click: (10, 20)")
            
            await tester.sendMouse(x: 50, y: 75, action: .press)
            try await tester.expectView(containing: "Last click: (50, 75)")
        }
    }
}