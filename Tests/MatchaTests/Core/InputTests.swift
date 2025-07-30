//
//  InputTests.swift
//  MatchaTests
//
//  Tests for keyboard and mouse input handling.
//

import Testing
@testable import Matcha

@Suite("Keyboard Input Tests")
struct KeyboardInputTests {
    
    @Test("Key creation with different types")
    func keyCreation() {
        // Test character keys
        let charKey = KeyMsg(character: "a")
        #expect(charKey.description == "a")
        
        // Test special keys
        let enterKey = KeyMsg(type: .enter)
        #expect(enterKey.description == "enter")
        
        let escKey = KeyMsg(type: .escape)
        #expect(escKey.description == "esc")
        
        // Test arrow keys
        let upKey = KeyMsg(type: .up)
        #expect(upKey.description == "up")
    }
    
    @Test("Key equality comparison")
    func keyEquality() {
        let key1 = KeyMsg(character: "a")
        let key2 = KeyMsg(character: "a")
        let key3 = KeyMsg(character: "b")
        
        #expect(key1 == key2)
        #expect(key1 != key3)
    }
    
    @Test("Key modifiers")
    func keyModifiers() {
        // Test alt modifier
        let altA = KeyMsg(character: "a", alt: true)
        #expect(altA.description == "alt+a")
        
        let altQ = KeyMsg(character: "q", alt: true)
        #expect(altQ.description == "alt+q")
    }
    
    @Test("Function keys")
    func functionKeys() {
        let f1 = KeyMsg(type: .f1)
        let f12 = KeyMsg(type: .f12)
        
        #expect(f1.description == "f1")
        #expect(f12.description == "f12")
    }
    
    @Test("Key pattern matching")
    func keyPatternMatching() {
        let key = KeyMsg(character: "q")
        
        // Test pattern matching with switch
        var matched = false
        switch key.description {
        case "q":
            matched = true
        default:
            break
        }
        
        #expect(matched)
    }
    
    @Test("Special keys descriptions")
    func specialKeys() {
        let keyTests: [(KeyType, String)] = [
            (.backspace, "backspace"),
            (.delete, "delete"),
            (.tab, "tab"),
            (.home, "home"),
            (.end, "end"),
            (.pageUp, "pgup"),
            (.pageDown, "pgdown"),
            (.insert, "insert")
        ]
        
        for (keyType, expectedDesc) in keyTests {
            let key = KeyMsg(type: keyType)
            #expect(key.description == expectedDesc)
        }
    }
}

@Suite("Mouse Input Tests")
struct MouseInputTests {
    
    @Test("Mouse event creation with properties")
    func mouseEventCreation() {
        let event = MouseEvent(
            x: 10,
            y: 20,
            shift: false,
            alt: false,
            ctrl: false,
            action: .press,
            button: .left
        )
        
        #expect(event.x == 10)
        #expect(event.y == 20)
        #expect(event.action == .press)
        #expect(event.button == .left)
        #expect(!event.shift)
        #expect(!event.alt)
        #expect(!event.ctrl)
    }
    
    @Test("Mouse action types")
    func mouseActions() {
        let actions: [MouseAction] = [.press, .release, .motion]
        
        for action in actions {
            let event = MouseEvent(
                x: 0,
                y: 0,
                shift: false,
                alt: false,
                ctrl: false,
                action: action,
                button: .left
            )
            #expect(event.action == action)
        }
    }
    
    @Test("Mouse button types")
    func mouseButtons() {
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
                shift: false,
                alt: false,
                ctrl: false,
                action: .press,
                button: button
            )
            #expect(event.button == button)
        }
    }
    
    @Test("Mouse modifiers")
    func mouseModifiers() {
        let event = MouseEvent(
            x: 5,
            y: 10,
            shift: true,
            alt: true,
            ctrl: true,
            action: .press,
            button: .left
        )
        
        #expect(event.shift)
        #expect(event.alt)
        #expect(event.ctrl)
    }
    
    @Test("Mouse wheel events")
    func mouseWheel() {
        let wheelUp = MouseEvent(
            x: 50,
            y: 50,
            shift: false,
            alt: false,
            ctrl: false,
            action: .motion,
            button: .wheelUp
        )
        
        #expect(wheelUp.button == .wheelUp)
        #expect(wheelUp.action == .motion)
    }
    
    @Test("Mouse event equality")
    func mouseEventEquality() {
        let event1 = MouseEvent(
            x: 10,
            y: 20,
            shift: false,
            alt: false,
            ctrl: false,
            action: .press,
            button: .left
        )
        
        let event2 = MouseEvent(
            x: 10,
            y: 20,
            shift: false,
            alt: false,
            ctrl: false,
            action: .press,
            button: .left
        )
        
        let event3 = MouseEvent(
            x: 15,
            y: 20,
            shift: false,
            alt: false,
            ctrl: false,
            action: .press,
            button: .left
        )
        
        #expect(event1 == event2)
        #expect(event1 != event3)
    }
}

// MARK: - Input Integration Tests

@Suite("Input Integration Tests")
@MainActor
struct InputIntegrationTests {
    
    @Test("Keyboard input in program")
    func keyboardInputInProgram() async throws {
        struct KeyTestModel: Model {
            typealias Msg = KeyMsg
            
            var lastKey: String = ""
            
            init() {}
            
            func `init`() -> Command<KeyMsg>? {
                return nil
            }
            
            func update(_ message: KeyMsg) -> (KeyTestModel, Command<KeyMsg>?) {
                var model = self
                model.lastKey = message.description
                return (model, nil)
            }
            
            func view() -> String {
                return "Last key: \(lastKey)"
            }
        }
        
        let tester = ProgramTester(model: KeyTestModel())
        
        try await tester.test {
            await tester.send(KeyMsg(character: "a"))
            try await tester.expectView(containing: "Last key: a")
            
            await tester.send(KeyMsg(type: .enter))
            try await tester.expectView(containing: "Last key: enter")
        }
    }
    
    @Test("Mouse input in program")
    func mouseInputInProgram() async throws {
        struct MouseTestModel: Model {
            typealias Msg = MouseMsg
            
            var lastClick: (x: Int, y: Int) = (0, 0)
            
            init() {}
            
            func `init`() -> Command<MouseMsg>? {
                return nil
            }
            
            func update(_ message: MouseMsg) -> (MouseTestModel, Command<MouseMsg>?) {
                var model = self
                if message.action == .press {
                    model.lastClick = (message.x, message.y)
                }
                return (model, nil)
            }
            
            func view() -> String {
                return "Last click: (\(lastClick.x), \(lastClick.y))"
            }
        }
        
        var options = ProgramOptions.default
        options.mouseMode = .cellMotion
        
        let tester = ProgramTester(model: MouseTestModel(), options: options)
        
        try await tester.test {
            await tester.sendMouse(x: 10, y: 20, action: .press)
            try await tester.expectView(containing: "Last click: (10, 20)")
            
            await tester.sendMouse(x: 50, y: 75, action: .press)
            try await tester.expectView(containing: "Last click: (50, 75)")
        }
    }
}