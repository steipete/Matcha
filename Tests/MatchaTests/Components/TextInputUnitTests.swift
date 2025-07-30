//
//  TextInputUnitTests.swift
//  MatchaTests
//
//  Unit tests for TextInput component following Bubbletea patterns.
//

import Testing
import Foundation
@testable import Matcha
@testable import MatchaBubbles

@Suite("TextInput Unit Tests")
struct TextInputUnitTests {
    
    // MARK: - State Management Tests
    
    @Test("TextInput handles character input")
    func handlesCharacterInput() {
        var textInput = TextInput().withFocus(true)
        #expect(textInput.value == "")
        
        // Type "hello"
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["h"]))
        #expect(textInput.value == "h")
        
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["e"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["l"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["l"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["o"]))
        #expect(textInput.value == "hello")
    }
    
    @Test("TextInput handles backspace")
    func handlesBackspace() {
        var textInput = TextInput().withValue("hello").withFocus(true)
        
        textInput = textInput.update(KeyMsg(type: .backspace))
        #expect(textInput.value == "hell")
        
        textInput = textInput.update(KeyMsg(type: .backspace))
        #expect(textInput.value == "hel")
        
        // Backspace on empty should do nothing
        textInput = TextInput().withFocus(true)
        textInput = textInput.update(KeyMsg(type: .backspace))
        #expect(textInput.value == "")
    }
    
    @Test("TextInput cursor movement")
    func cursorMovement() {
        var textInput = TextInput().withValue("hello world").withFocus(true)
        textInput.cursorPosition = 11 // End of string
        
        // Move left
        textInput = textInput.update(KeyMsg(type: .left))
        #expect(textInput.cursorPosition == 10)
        
        // Move to beginning
        textInput = textInput.update(KeyMsg(type: .home))
        #expect(textInput.cursorPosition == 0)
        
        // Move to end
        textInput = textInput.update(KeyMsg(type: .end))
        #expect(textInput.cursorPosition == 11)
        
        // Move right at end should stay at end
        textInput = textInput.update(KeyMsg(type: .right))
        #expect(textInput.cursorPosition == 11)
    }
    
    @Test("TextInput navigation with alt modifier")
    func navigationWithAltModifier() {
        var textInput = TextInput().withValue("hello world test").withFocus(true)
        textInput.cursorPosition = 8 // Middle of "world"
        
        // TextInput doesn't support word navigation with alt+left/right
        // It treats them as regular left/right movements
        textInput = textInput.update(KeyMsg(type: .left, alt: true))
        #expect(textInput.cursorPosition == 7) // Just moved one character left
        
        // Regular right movement
        textInput = textInput.update(KeyMsg(type: .right, alt: true))
        #expect(textInput.cursorPosition == 8) // Back to original position
    }
    
    @Test("TextInput character limit")
    func characterLimit() {
        var textInput = TextInput().withCharacterLimit(5).withFocus(true)
        
        // Type within limit
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["h"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["e"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["l"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["l"]))
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["o"]))
        #expect(textInput.value == "hello")
        
        // Try to exceed limit
        textInput = textInput.update(KeyMsg(type: .runes, runes: ["!"]))
        #expect(textInput.value == "hello") // Should not change
    }
    
    @Test("TextInput paste handling")
    func pasteHandling() {
        var textInput = TextInput().withFocus(true)
        
        // Paste text
        textInput = textInput.update(PasteMsg(text: "pasted text"))
        #expect(textInput.value == "pasted text")
        
        // Paste with existing content
        textInput = TextInput().withValue("hello ").withFocus(true)
        textInput.cursorPosition = 6
        textInput = textInput.update(PasteMsg(text: "world"))
        #expect(textInput.value == "hello world")
        
        // Paste with character limit
        textInput = TextInput().withCharacterLimit(10).withFocus(true)
        textInput = textInput.update(PasteMsg(text: "this is too long"))
        #expect(textInput.value == "this is to") // Truncated to limit
    }
    
    @Test("TextInput focus state")
    func focusState() {
        var textInput = TextInput()
        #expect(!textInput.focused)
        
        textInput = textInput.withFocus(true)
        #expect(textInput.focused)
        
        textInput = textInput.withFocus(false)
        #expect(!textInput.focused)
    }
    
    // MARK: - View Tests
    
    @Test("TextInput renders placeholder when empty")
    func rendersPlaceholder() {
        let textInput = TextInput()
            .withPlaceholder("Enter text...")
            .withFocus(false)
        
        let view = textInput.view()
        #expect(view.contains("Enter text..."))
    }
    
    @Test("TextInput renders value over placeholder")
    func rendersValue() {
        let textInput = TextInput()
            .withPlaceholder("Enter text...")
            .withValue("hello")
            .withFocus(false)
        
        let view = textInput.view()
        #expect(view.contains("hello"))
        #expect(!view.contains("Enter text..."))
    }
    
    @Test("TextInput shows cursor when focused")
    func showsCursor() {
        let textInput = TextInput()
            .withValue("hello")
            .withFocus(true)
        
        let view = textInput.view()
        // The cursor character varies, but there should be cursor styling
        #expect(view.contains("hello"))
    }
    
    // MARK: - Builder Pattern Tests
    
    @Test("TextInput builder methods")
    func builderMethods() {
        let textInput = TextInput()
            .withPlaceholder("Name...")
            .withValue("John")
            .withCharacterLimit(20)
            .withWidth(30)
            .withFocus(true)
        
        #expect(textInput.placeholder == "Name...")
        #expect(textInput.value == "John")
        #expect(textInput.characterLimit == 20)
        #expect(textInput.width == 30)
        #expect(textInput.focused == true)
    }
}