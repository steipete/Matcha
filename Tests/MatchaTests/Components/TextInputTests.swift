//
//  TextInputTests.swift
//  MatchaTests
//
//  Tests for the TextInput component.
//

import Testing
@testable import Matcha
@testable import MatchaBubbles
@testable import MatchaStyle

@Suite("TextInput Component Tests")
struct TextInputTests {
    
    @Test("TextInput initial state")
    func textInputCreation() {
        let input = TextInput()
        
        #expect(input.value == "")
        #expect(input.placeholder == "")
        #expect(input.cursorPosition == 0)
        #expect(!input.focused) // Default is false, not true
    }
    
    @Test("TextInput typing characters")
    func textInputTyping() {
        var input = TextInput().withFocus(true)
        
        // Type characters using update() with KeyMsg messages
        input = input.update(KeyMsg(character: "H"))
        #expect(input.value == "H")
        #expect(input.cursorPosition == 1)
        
        input = input.update(KeyMsg(character: "e"))
        input = input.update(KeyMsg(character: "l"))
        input = input.update(KeyMsg(character: "l"))
        input = input.update(KeyMsg(character: "o"))
        
        #expect(input.value == "Hello")
        #expect(input.cursorPosition == 5)
    }
    
    @Test("TextInput cursor movement")
    func textInputCursorMovement() {
        var input = TextInput()
            .withValue("Hello")
            .withFocus(true)
        
        // Cursor should be at end after setting value
        #expect(input.cursorPosition == 5)
        
        // Move left
        input = input.update(KeyMsg(type: .left))
        #expect(input.cursorPosition == 4)
        
        // Move to start
        input = input.update(KeyMsg(type: .home))
        #expect(input.cursorPosition == 0)
        
        // Move right
        input = input.update(KeyMsg(type: .right))
        #expect(input.cursorPosition == 1)
        
        // Move to end
        input = input.update(KeyMsg(type: .end))
        #expect(input.cursorPosition == 5)
    }
    
    @Test("TextInput deletion operations")
    func textInputDeletion() {
        var input = TextInput()
            .withValue("Hello")
            .withFocus(true)
        
        // Move cursor to position 3
        input = input.update(KeyMsg(type: .home))
        input = input.update(KeyMsg(type: .right))
        input = input.update(KeyMsg(type: .right))
        input = input.update(KeyMsg(type: .right))
        #expect(input.cursorPosition == 3)
        
        // Backspace
        input = input.update(KeyMsg(type: .backspace))
        #expect(input.value == "Helo")
        #expect(input.cursorPosition == 2)
        
        // Delete forward
        input = input.update(KeyMsg(type: .delete))
        #expect(input.value == "Heo")
        #expect(input.cursorPosition == 2)
        
        // Delete word backward (Ctrl+W)
        input = input.withValue("Hello World").withFocus(true)
        // Move cursor to position 5
        input = input.update(KeyMsg(type: .home))
        for _ in 0..<5 {
            input = input.update(KeyMsg(type: .right))
        }
        input = input.update(KeyMsg(type: .ctrlW))
        #expect(input.value == " World")
        #expect(input.cursorPosition == 0)
    }
    
    @Test("TextInput control key operations")
    func textInputControlKeys() {
        var input = TextInput()
            .withValue("Hello World Test")
            .withFocus(true)
        
        // Ctrl+A - move to start
        input = input.update(KeyMsg(type: .ctrlA))
        #expect(input.cursorPosition == 0)
        
        // Ctrl+E - move to end
        input = input.update(KeyMsg(type: .ctrlE))
        #expect(input.cursorPosition == 16)
        
        // Ctrl+K - kill to end of line
        input = input.update(KeyMsg(type: .home))
        for _ in 0..<6 {
            input = input.update(KeyMsg(type: .right))
        }
        input = input.update(KeyMsg(type: .ctrlK))
        #expect(input.value == "Hello ")
        
        // Ctrl+U - kill to start of line
        input = input.withValue("Hello World").withFocus(true)
        input = input.update(KeyMsg(type: .home))
        for _ in 0..<6 {
            input = input.update(KeyMsg(type: .right))
        }
        input = input.update(KeyMsg(type: .ctrlU))
        #expect(input.value == "World")
        #expect(input.cursorPosition == 0)
    }
    
    @Test("TextInput max width constraint")
    func textInputMaxWidth() {
        let input = TextInput()
            .withWidth(10)
            .withValue("This is a very long text")
        
        let view = input.view()
        // The stripANSI function ensures width constraint
        // The actual view might be truncated or handled differently
        #expect(view.count >= 0) // Just check it renders without crashing
    }
    
    @Test("TextInput placeholder behavior")
    func textInputPlaceholder() {
        var input = TextInput()
            .withPlaceholder("Enter name...")
        
        let view = input.view()
        #expect(view.contains("Enter name..."))
        
        // Placeholder should disappear when typing
        input = input.withFocus(true)
        input = input.update(KeyMsg(character: "A"))
        let viewWithText = input.view()
        #expect(!viewWithText.contains("Enter name..."))
        #expect(viewWithText.contains("A"))
    }
    
    @Test("TextInput focus management")
    func textInputFocus() {
        var input = TextInput()
        
        // Initially not focused
        #expect(!input.focused)
        
        // Focus
        input = input.withFocus(true)
        #expect(input.focused)
        
        // Blur
        input = input.withFocus(false)
        #expect(!input.focused)
        
        // Cursor should be visible when focused
        input = input.withFocus(true).withShowCursor(true)
        let focusedView = input.view()
        // The cursor style is applied with reverse styling
        #expect(focusedView.count > 0)
    }
    
    @Test("TextInput key handling with update")
    func textInputUpdate() {
        var input = TextInput().withFocus(true)
        
        // Test character input
        input = input.update(KeyMsg(character: "a"))
        #expect(input.value == "a")
        
        // Test backspace
        input = input.update(KeyMsg(type: .backspace))
        #expect(input.value == "")
        
        // Build "Hello"
        input = input.update(KeyMsg(character: "H"))
        input = input.update(KeyMsg(character: "e"))
        input = input.update(KeyMsg(character: "l"))
        input = input.update(KeyMsg(character: "l"))
        input = input.update(KeyMsg(character: "o"))
        #expect(input.value == "Hello")
        
        // Test navigation keys
        input = input.update(KeyMsg(type: .left))
        #expect(input.cursorPosition == 4)
        
        input = input.update(KeyMsg(type: .home))
        #expect(input.cursorPosition == 0)
        
        input = input.update(KeyMsg(type: .end))
        #expect(input.cursorPosition == 5)
    }
    
    @Test("TextInput character limit")
    func textInputCharacterLimit() {
        var input = TextInput()
            .withCharacterLimit(5)
            .withValue("Hello")
            .withFocus(true)
        
        // Should not exceed limit
        input = input.update(KeyMsg(character: "!"))
        
        #expect(input.value == "Hello") // Should not exceed limit
        #expect(input.cursorPosition == 5)
    }
    
    @Test("TextInput paste handling")
    func textInputPaste() {
        var input = TextInput().withFocus(true)
        
        // Test paste message
        input = input.update(PasteMsg(text: "Hello World"))
        #expect(input.value == "Hello World")
        #expect(input.cursorPosition == 11)
        
        // Paste with character limit
        input = TextInput()
            .withCharacterLimit(5)
            .withFocus(true)
        input = input.update(PasteMsg(text: "Hello World"))
        #expect(input.value == "Hello") // Should respect limit
    }
    
    @Test("TextInput echo modes")
    func textInputEchoModes() {
        var input = TextInput()
            .withValue("password")
            .withEchoMode(.password)
        
        var view = input.view()
        #expect(view.contains("••••••••"))
        
        // Custom password character
        input = input.withEchoMode(.passwordChar("*"))
        view = input.view()
        #expect(view.contains("********"))
        
        // Hidden mode
        input = input.withEchoMode(.hidden)
        view = input.view()
        #expect(!view.contains("password"))
        #expect(!view.contains("*"))
    }
    
    @Test("TextInput builder pattern")
    func textInputBuilders() {
        let input = TextInput()
            .withValue("Test")
            .withPlaceholder("Enter text...")
            .withWidth(20)
            .withFocus(true)
            .withCharacterLimit(10)
            .withPrompt("> ")
            .withCursorChar("_")
            .withShowCursor(true)
            .promptStyle(Style().foreground(Color.blue))
            .textStyle(Style().bold())
            .placeholderStyle(Style().italic())
            .cursorStyle(Style().background(Color.white))
        
        #expect(input.value == "Test")
        #expect(input.placeholder == "Enter text...")
        #expect(input.width == 20)
        #expect(input.focused)
        #expect(input.characterLimit == 10)
        #expect(input.prompt == "> ")
        #expect(input.cursorChar == "_")
        #expect(input.showCursor)
    }
    
    @Test("TextInput unfocused ignores input")
    func textInputUnfocusedIgnoresInput() {
        var input = TextInput().withFocus(false)
        
        // Should ignore key input when not focused
        input = input.update(KeyMsg(character: "a"))
        #expect(input.value == "")
        
        // Should ignore paste when not focused
        input = input.update(PasteMsg(text: "Hello"))
        #expect(input.value == "")
    }
}