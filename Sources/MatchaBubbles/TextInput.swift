import Foundation
import Matcha
import MatchaStyle

// MARK: - TextInput

/// A text input field component that handles user input with features like
/// cursor positioning, selection, placeholder text, and input validation.
public struct TextInput: Sendable {
    // MARK: - Properties

    /// The current text value
    public var value: String

    /// Placeholder text shown when value is empty
    public var placeholder: String

    /// The cursor position (0-based index)
    public var cursorPosition: Int

    /// The width of the input field (0 means grow with content)
    public var width: Int

    /// Whether the input is currently focused
    public var focused: Bool

    /// Character limit (0 means no limit)
    public var characterLimit: Int

    /// Prompt shown before the input
    public var prompt: String

    /// Style for the prompt
    public var promptStyle: Style

    /// Style for the text
    public var textStyle: Style

    /// Style for the placeholder
    public var placeholderStyle: Style

    /// Style for the cursor
    public var cursorStyle: Style

    /// Whether to show the cursor
    public var showCursor: Bool

    /// The cursor character
    public var cursorChar: String

    /// Whether to mask input (for passwords)
    public var echoMode: EchoMode

    /// Echo mode for input display
    public enum EchoMode: Sendable, Equatable {
        case normal // Show input as-is
        case password // Show bullets (•)
        case passwordChar(String) // Show custom character
        case hidden // Show nothing
    }

    // MARK: - Initialization

    /// Creates a new text input with default settings
    public init() {
        self.value = ""
        self.placeholder = ""
        self.cursorPosition = 0
        self.width = 0
        self.focused = false
        self.characterLimit = 0
        self.prompt = ""
        self.promptStyle = Style()
        self.textStyle = Style()
        self.placeholderStyle = Style().foreground(Color(240))
        self.cursorStyle = Style().reverse()
        self.showCursor = true
        self.cursorChar = " "
        self.echoMode = .normal
    }

    // MARK: - Builder Methods

    /// Sets the current value
    public func withValue(_ value: String) -> TextInput {
        var input = self
        input.value = value
        // Move cursor to end when setting a new value
        input.cursorPosition = value.count
        return input
    }

    /// Sets the placeholder text
    public func withPlaceholder(_ placeholder: String) -> TextInput {
        var input = self
        input.placeholder = placeholder
        return input
    }

    /// Sets the width
    public func withWidth(_ width: Int) -> TextInput {
        var input = self
        input.width = width
        return input
    }

    /// Sets the focus state
    public func withFocus(_ focused: Bool) -> TextInput {
        var input = self
        input.focused = focused
        return input
    }

    /// Sets the character limit
    public func withCharacterLimit(_ limit: Int) -> TextInput {
        var input = self
        input.characterLimit = limit
        return input
    }

    /// Sets the prompt
    public func withPrompt(_ prompt: String) -> TextInput {
        var input = self
        input.prompt = prompt
        return input
    }

    /// Sets the echo mode
    public func withEchoMode(_ mode: EchoMode) -> TextInput {
        var input = self
        input.echoMode = mode
        return input
    }

    /// Sets the cursor character
    public func withCursorChar(_ char: String) -> TextInput {
        var input = self
        input.cursorChar = String(char.prefix(1))
        return input
    }

    /// Sets whether to show the cursor
    public func withShowCursor(_ show: Bool) -> TextInput {
        var input = self
        input.showCursor = show
        return input
    }

    // MARK: - Style Methods

    /// Sets the prompt style
    public func promptStyle(_ style: Style) -> TextInput {
        var input = self
        input.promptStyle = style
        return input
    }

    /// Sets the text style
    public func textStyle(_ style: Style) -> TextInput {
        var input = self
        input.textStyle = style
        return input
    }

    /// Sets the placeholder style
    public func placeholderStyle(_ style: Style) -> TextInput {
        var input = self
        input.placeholderStyle = style
        return input
    }

    /// Sets the cursor style
    public func cursorStyle(_ style: Style) -> TextInput {
        var input = self
        input.cursorStyle = style
        return input
    }

    // MARK: - Update Methods

    /// Updates the text input based on a message
    /// Note: This is designed to work with typed messages from your model
    public func update(_ msg: any Message) -> TextInput {
        guard focused else { return self }

        if let key = msg as? KeyMsg {
            return handleKey(key)
        } else if let paste = msg as? PasteMsg {
            return handlePaste(paste.text)
        }

        return self
    }

    private func handleKey(_ key: KeyMsg) -> TextInput {
        var input = self

        switch key.type {
        case .runes:
            // Insert all characters from the key
            for char in key.runes {
                input = input.insertCharacter(String(char))
            }

        case .backspace:
            input = input.deleteBackward()

        case .delete:
            input = input.deleteForward()

        case .left:
            input = input.moveCursorLeft()

        case .right:
            input = input.moveCursorRight()

        case .home:
            input = input.moveCursorToStart()

        case .end:
            input = input.moveCursorToEnd()

        case .ctrlA:
            // Select all (move to start)
            input = input.moveCursorToStart()

        case .ctrlE:
            // Move to end
            input = input.moveCursorToEnd()

        case .ctrlK:
            // Kill to end of line
            input = input.deleteToEnd()

        case .ctrlU:
            // Kill to start of line
            input = input.deleteToStart()

        case .ctrlW:
            // Delete word backward
            input = input.deleteWordBackward()

        default:
            break
        }

        return input
    }

    private func handlePaste(_ text: String) -> TextInput {
        var input = self
        input = input.insertText(text)
        return input
    }

    // MARK: - Text Manipulation

    private func insertCharacter(_ char: String) -> TextInput {
        guard char.count == 1 else { return self }

        // Check character limit
        if characterLimit > 0, value.count >= characterLimit {
            return self
        }

        var newValue = value
        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        newValue.insert(contentsOf: char, at: index)

        return withValue(newValue).moveCursorRight()
    }

    private func insertText(_ text: String) -> TextInput {
        var input = self
        for char in text {
            input = input.insertCharacter(String(char))
        }
        return input
    }

    private func deleteBackward() -> TextInput {
        guard cursorPosition > 0 else { return self }

        var newValue = value
        let index = value.index(value.startIndex, offsetBy: cursorPosition - 1)
        newValue.remove(at: index)

        var input = withValue(newValue)
        input.cursorPosition = cursorPosition - 1
        return input
    }

    private func deleteForward() -> TextInput {
        guard cursorPosition < value.count else { return self }

        var newValue = value
        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        newValue.remove(at: index)

        return withValue(newValue)
    }

    private func deleteToEnd() -> TextInput {
        guard cursorPosition < value.count else { return self }

        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        let newValue = String(value[..<index])

        return withValue(newValue)
    }

    private func deleteToStart() -> TextInput {
        guard cursorPosition > 0 else { return self }

        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        let newValue = String(value[index...])

        var input = withValue(newValue)
        input.cursorPosition = 0
        return input
    }

    private func deleteWordBackward() -> TextInput {
        guard cursorPosition > 0 else { return self }

        // Find the start of the previous word
        var pos = cursorPosition - 1
        let chars = Array(value)

        // Skip trailing spaces
        while pos > 0, chars[pos] == " " {
            pos -= 1
        }

        // Skip word characters
        while pos > 0, chars[pos] != " " {
            pos -= 1
        }

        // If we stopped at a space, move forward one
        if pos > 0, chars[pos] == " " {
            pos += 1
        }

        // Delete from pos to cursorPosition
        let startIndex = value.index(value.startIndex, offsetBy: pos)
        let endIndex = value.index(value.startIndex, offsetBy: cursorPosition)
        var newValue = value
        newValue.removeSubrange(startIndex..<endIndex)

        var input = withValue(newValue)
        input.cursorPosition = pos
        return input
    }

    // MARK: - Cursor Movement

    private func moveCursorLeft() -> TextInput {
        var input = self
        input.cursorPosition = max(0, cursorPosition - 1)
        return input
    }

    private func moveCursorRight() -> TextInput {
        var input = self
        input.cursorPosition = min(value.count, cursorPosition + 1)
        return input
    }

    private func moveCursorToStart() -> TextInput {
        var input = self
        input.cursorPosition = 0
        return input
    }

    private func moveCursorToEnd() -> TextInput {
        var input = self
        input.cursorPosition = value.count
        return input
    }

    // MARK: - Rendering

    /// Renders the text input as a string
    public func view() -> String {
        var result = ""

        // Add prompt if present
        if !prompt.isEmpty {
            result += promptStyle.render(prompt)
        }

        // Determine display value based on echo mode
        let displayValue: String = switch echoMode {
        case .normal:
            value
        case .password:
            String(repeating: "•", count: value.count)
        case let .passwordChar(char):
            String(repeating: char, count: value.count)
        case .hidden:
            ""
        }

        // Show placeholder if empty and not hidden
        if displayValue.isEmpty, !placeholder.isEmpty, echoMode != .hidden {
            result += placeholderStyle.render(placeholder)
        } else {
            // Render the text with cursor
            if showCursor, focused, cursorPosition <= displayValue.count {
                let chars = Array(displayValue)

                // Text before cursor
                if cursorPosition > 0 {
                    let before = String(chars[0..<cursorPosition])
                    result += textStyle.render(before)
                }

                // Cursor
                if cursorPosition < chars.count {
                    let cursorText = String(chars[cursorPosition])
                    result += cursorStyle.render(cursorText)
                } else {
                    // Cursor at end
                    result += cursorStyle.render(cursorChar)
                }

                // Text after cursor
                if cursorPosition < chars.count - 1 {
                    let after = String(chars[(cursorPosition + 1)...])
                    result += textStyle.render(after)
                }
            } else {
                // No cursor or not focused
                result += textStyle.render(displayValue)
            }
        }

        // Apply width if specified
        if width > 0 {
            let currentWidth = result.stripANSI().count
            if currentWidth < width {
                result += String(repeating: " ", count: width - currentWidth)
            } else if currentWidth > width {
                // TODO: Handle scrolling for long content
                result = String(result.prefix(width))
            }
        }

        return result
    }
}

// MARK: - String Extensions

private extension String {
    /// Strips ANSI escape sequences from the string
    func stripANSI() -> String {
        // Simple implementation - could be improved
        var result = self

        // Remove CSI sequences
        result = result.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )

        return result
    }
}
