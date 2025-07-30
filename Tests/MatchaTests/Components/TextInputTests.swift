//
//  TextInputTests.swift
//  MatchaTests
//
//  Tests for the TextInput component.
//

import XCTest
@testable import Matcha
@testable import MatchaBubbles

final class TextInputTests: XCTestCase {
    
    func testTextInputCreation() {
        var input = TextInput()
        
        XCTAssertEqual(input.value, "")
        XCTAssertEqual(input.placeholder, "")
        XCTAssertEqual(input.cursor, 0)
        XCTAssertTrue(input.focus)
    }
    
    func testTextInputTyping() {
        var input = TextInput()
        
        // Type characters
        input.insertRune("H")
        XCTAssertEqual(input.value, "H")
        XCTAssertEqual(input.cursor, 1)
        
        input.insertRune("e")
        input.insertRune("l")
        input.insertRune("l")
        input.insertRune("o")
        
        XCTAssertEqual(input.value, "Hello")
        XCTAssertEqual(input.cursor, 5)
    }
    
    func testTextInputCursorMovement() {
        var input = TextInput()
        input.value = "Hello"
        input.cursor = 5
        
        // Move left
        input.cursorLeft()
        XCTAssertEqual(input.cursor, 4)
        
        // Move to start
        input.cursorStart()
        XCTAssertEqual(input.cursor, 0)
        
        // Move right
        input.cursorRight()
        XCTAssertEqual(input.cursor, 1)
        
        // Move to end
        input.cursorEnd()
        XCTAssertEqual(input.cursor, 5)
    }
    
    func testTextInputDeletion() {
        var input = TextInput()
        input.value = "Hello"
        input.cursor = 3
        
        // Backspace
        input.backspace()
        XCTAssertEqual(input.value, "Helo")
        XCTAssertEqual(input.cursor, 2)
        
        // Delete forward
        input.delete()
        XCTAssertEqual(input.value, "Heo")
        XCTAssertEqual(input.cursor, 2)
        
        // Delete word
        input.value = "Hello World"
        input.cursor = 5
        input.deleteWordBackward()
        XCTAssertEqual(input.value, " World")
        XCTAssertEqual(input.cursor, 0)
    }
    
    func testTextInputWordNavigation() {
        var input = TextInput()
        input.value = "Hello World Test"
        input.cursor = 8
        
        // Word backward
        input.wordBackward()
        XCTAssertEqual(input.cursor, 6)
        
        // Word forward
        input.wordForward()
        XCTAssertEqual(input.cursor, 11)
    }
    
    func testTextInputMaxWidth() {
        var input = TextInput()
        input.width = 10
        
        let view = input.view()
        // View should not exceed specified width
        let lines = view.split(separator: "\n")
        for line in lines {
            XCTAssertLessThanOrEqual(line.count, 10)
        }
    }
    
    func testTextInputPlaceholder() {
        var input = TextInput()
        input.placeholder = "Enter name..."
        
        let view = input.view()
        XCTAssertTrue(view.contains("Enter name..."))
        
        // Placeholder should disappear when typing
        input.insertRune("A")
        let viewWithText = input.view()
        XCTAssertFalse(viewWithText.contains("Enter name..."))
        XCTAssertTrue(viewWithText.contains("A"))
    }
    
    func testTextInputFocus() {
        var input = TextInput()
        
        // Initially focused
        XCTAssertTrue(input.focus)
        
        // Blur
        input.blur()
        XCTAssertFalse(input.focus)
        
        // Focus
        input.focus()
        XCTAssertTrue(input.focus)
        
        // Cursor should be visible when focused
        let focusedView = input.view()
        XCTAssertTrue(focusedView.contains("│") || focusedView.contains("|"))
    }
    
    func testTextInputUpdate() {
        var input = TextInput()
        
        // Test various key inputs
        let keys = [
            ("a", "a"),
            ("backspace", ""),
            ("H", "H"),
            ("e", "He"),
            ("l", "Hel"),
            ("l", "Hell"),
            ("o", "Hello"),
            ("left", "Hello"),
            ("home", "Hello"),
            ("end", "Hello"),
        ]
        
        for (key, expected) in keys {
            _ = input.update(Key(description: key))
            if !expected.isEmpty {
                XCTAssertEqual(input.value, expected)
            }
        }
    }
    
    func testTextInputCharLimit() {
        var input = TextInput()
        input.charLimit = 5
        
        // Should limit input
        input.value = "Hello"
        input.cursor = 5
        input.insertRune("!")
        
        XCTAssertEqual(input.value, "Hello") // Should not exceed limit
        XCTAssertEqual(input.cursor, 5)
    }
    
    func testTextInputValidation() {
        var input = TextInput()
        
        // Add validation function
        input.validate = { value in
            // Only allow alphanumeric
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        }
        
        // Valid input
        input.insertRune("A")
        XCTAssertEqual(input.value, "A")
        
        // Invalid input should be rejected
        input.insertRune("!")
        XCTAssertEqual(input.value, "A") // Should not change
    }
}