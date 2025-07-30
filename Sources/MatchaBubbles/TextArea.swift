//
//  TextArea.swift
//  MatchaBubbles
//
//  A multi-line text input component for Matcha TUI applications.
//

import Foundation
import Matcha
import MatchaStyle

/// A multi-line text area component that handles user input with features like
/// cursor positioning, scrolling, line wrapping, and input validation.
public struct TextArea: Sendable {
    // MARK: - Properties
    
    /// The lines of text
    public var lines: [String]
    
    /// The cursor position (line, column)
    public var cursorLine: Int
    public var cursorColumn: Int
    
    /// The viewport dimensions
    public var width: Int
    public var height: Int
    
    /// The viewport offset (for scrolling)
    public var offsetLine: Int
    public var offsetColumn: Int
    
    /// Whether the text area is currently focused
    public var focused: Bool
    
    /// Character limit per line (0 means no limit)
    public var lineCharacterLimit: Int
    
    /// Maximum number of lines (0 means no limit)
    public var maxLines: Int
    
    /// Whether to wrap long lines
    public var wordWrap: Bool
    
    /// Whether to show line numbers
    public var showLineNumbers: Bool
    
    /// Placeholder text shown when empty
    public var placeholder: String
    
    /// Prompt shown before the text area
    public var prompt: String
    
    /// Style for the prompt
    public var promptStyle: Style
    
    /// Style for the text
    public var textStyle: Style
    
    /// Style for the placeholder
    public var placeholderStyle: Style
    
    /// Style for the cursor
    public var cursorStyle: Style
    
    /// Style for line numbers
    public var lineNumberStyle: Style
    
    /// Style for the focused border
    public var focusedBorderStyle: Style
    
    /// Style for the unfocused border
    public var unfocusedBorderStyle: Style
    
    /// Whether to show the cursor
    public var showCursor: Bool
    
    /// The cursor character
    public var cursorChar: String
    
    /// Whether to show borders
    public var showBorder: Bool
    
    /// Tab size in spaces
    public var tabSize: Int
    
    // MARK: - Initialization
    
    /// Creates a new text area with default settings
    public init() {
        self.lines = [""]
        self.cursorLine = 0
        self.cursorColumn = 0
        self.width = 40
        self.height = 10
        self.offsetLine = 0
        self.offsetColumn = 0
        self.focused = false
        self.lineCharacterLimit = 0
        self.maxLines = 0
        self.wordWrap = true
        self.showLineNumbers = false
        self.placeholder = ""
        self.prompt = ""
        self.promptStyle = Style()
        self.textStyle = Style()
        self.placeholderStyle = Style().foreground(Color(240))
        self.cursorStyle = Style().reverse()
        self.lineNumberStyle = Style().foreground(Color(240))
        self.focusedBorderStyle = Style().foreground(Color.brightBlue)
        self.unfocusedBorderStyle = Style().foreground(Color(240))
        self.showCursor = true
        self.cursorChar = " "
        self.showBorder = true
        self.tabSize = 4
    }
    
    // MARK: - Builder Methods
    
    /// Sets the content from a string
    public func withValue(_ value: String) -> TextArea {
        var area = self
        area.lines = value.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if area.lines.isEmpty {
            area.lines = [""]
        }
        // Ensure cursor is within bounds
        area.cursorLine = min(area.cursorLine, area.lines.count - 1)
        area.cursorColumn = min(area.cursorColumn, area.lines[area.cursorLine].count)
        return area
    }
    
    /// Gets the content as a string
    public var value: String {
        lines.joined(separator: "\n")
    }
    
    /// Sets the dimensions
    public func withDimensions(width: Int, height: Int) -> TextArea {
        var area = self
        area.width = max(1, width)
        area.height = max(1, height)
        return area
    }
    
    /// Sets the focus state
    public func withFocus(_ focused: Bool) -> TextArea {
        var area = self
        area.focused = focused
        return area
    }
    
    /// Sets line character limit
    public func withLineCharacterLimit(_ limit: Int) -> TextArea {
        var area = self
        area.lineCharacterLimit = limit
        return area
    }
    
    /// Sets maximum lines
    public func withMaxLines(_ maxLines: Int) -> TextArea {
        var area = self
        area.maxLines = maxLines
        return area
    }
    
    /// Sets word wrap
    public func withWordWrap(_ wrap: Bool) -> TextArea {
        var area = self
        area.wordWrap = wrap
        return area
    }
    
    /// Sets whether to show line numbers
    public func withLineNumbers(_ show: Bool) -> TextArea {
        var area = self
        area.showLineNumbers = show
        return area
    }
    
    /// Sets the placeholder
    public func withPlaceholder(_ placeholder: String) -> TextArea {
        var area = self
        area.placeholder = placeholder
        return area
    }
    
    /// Sets the prompt
    public func withPrompt(_ prompt: String) -> TextArea {
        var area = self
        area.prompt = prompt
        return area
    }
    
    /// Sets whether to show border
    public func withBorder(_ show: Bool) -> TextArea {
        var area = self
        area.showBorder = show
        return area
    }
    
    /// Sets tab size
    public func withTabSize(_ size: Int) -> TextArea {
        var area = self
        area.tabSize = max(1, size)
        return area
    }
    
    // MARK: - Style Methods
    
    /// Sets the prompt style
    public func promptStyle(_ style: Style) -> TextArea {
        var area = self
        area.promptStyle = style
        return area
    }
    
    /// Sets the text style
    public func textStyle(_ style: Style) -> TextArea {
        var area = self
        area.textStyle = style
        return area
    }
    
    /// Sets the placeholder style
    public func placeholderStyle(_ style: Style) -> TextArea {
        var area = self
        area.placeholderStyle = style
        return area
    }
    
    /// Sets the cursor style
    public func cursorStyle(_ style: Style) -> TextArea {
        var area = self
        area.cursorStyle = style
        return area
    }
    
    /// Sets the line number style
    public func lineNumberStyle(_ style: Style) -> TextArea {
        var area = self
        area.lineNumberStyle = style
        return area
    }
    
    /// Sets the focused border style
    public func focusedBorderStyle(_ style: Style) -> TextArea {
        var area = self
        area.focusedBorderStyle = style
        return area
    }
    
    /// Sets the unfocused border style
    public func unfocusedBorderStyle(_ style: Style) -> TextArea {
        var area = self
        area.unfocusedBorderStyle = style
        return area
    }
    
    // MARK: - Update Methods
    
    /// Updates the text area based on a message
    public func update(_ msg: any Message) -> TextArea {
        guard focused else { return self }
        
        if let key = msg as? KeyMsg {
            return handleKey(key)
        } else if let paste = msg as? PasteMsg {
            return handlePaste(paste.text)
        }
        
        return self
    }
    
    private func handleKey(_ key: KeyMsg) -> TextArea {
        var area = self
        
        switch key.type {
        case .runes:
            // Insert all characters from the key
            for char in key.runes {
                area = area.insertCharacter(String(char))
            }
            
        case .tab:
            // Insert spaces for tab
            let spaces = String(repeating: " ", count: tabSize)
            area = area.insertText(spaces)
            
        case .enter:
            area = area.insertNewLine()
            
        case .backspace:
            area = area.deleteBackward()
            
        case .delete:
            area = area.deleteForward()
            
        case .left:
            area = area.moveCursorLeft()
            
        case .right:
            area = area.moveCursorRight()
            
        case .up:
            area = area.moveCursorUp()
            
        case .down:
            area = area.moveCursorDown()
            
        case .home:
            area = area.moveCursorToLineStart()
            
        case .end:
            area = area.moveCursorToLineEnd()
            
        case .pageUp:
            area = area.pageUp()
            
        case .pageDown:
            area = area.pageDown()
            
        case .ctrlA:
            // Move to start of line
            area = area.moveCursorToLineStart()
            
        case .ctrlE:
            // Move to end of line
            area = area.moveCursorToLineEnd()
            
        case .ctrlK:
            // Kill to end of line
            area = area.deleteToEndOfLine()
            
        case .ctrlU:
            // Kill to start of line
            area = area.deleteToStartOfLine()
            
        case .ctrlW:
            // Delete word backward
            area = area.deleteWordBackward()
            
        default:
            break
        }
        
        // Update viewport to follow cursor
        area = area.ensureCursorVisible()
        
        return area
    }
    
    private func handlePaste(_ text: String) -> TextArea {
        var area = self
        
        // Split paste content by newlines and insert
        let pasteLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        
        for (index, line) in pasteLines.enumerated() {
            if index > 0 {
                area = area.insertNewLine()
            }
            area = area.insertText(String(line))
        }
        
        return area
    }
    
    // MARK: - Text Manipulation
    
    private func insertCharacter(_ char: String) -> TextArea {
        guard char.count == 1 else { return self }
        
        // Check line character limit
        if lineCharacterLimit > 0 && lines[cursorLine].count >= lineCharacterLimit {
            return self
        }
        
        var area = self
        var line = lines[cursorLine]
        let index = line.index(line.startIndex, offsetBy: cursorColumn)
        line.insert(contentsOf: char, at: index)
        area.lines[cursorLine] = line
        area.cursorColumn += 1
        
        return area
    }
    
    private func insertText(_ text: String) -> TextArea {
        var area = self
        for char in text {
            area = area.insertCharacter(String(char))
        }
        return area
    }
    
    private func insertNewLine() -> TextArea {
        // Check max lines
        if maxLines > 0 && lines.count >= maxLines {
            return self
        }
        
        var area = self
        let currentLine = lines[cursorLine]
        let splitIndex = currentLine.index(currentLine.startIndex, offsetBy: cursorColumn)
        
        let beforeCursor = String(currentLine[..<splitIndex])
        let afterCursor = String(currentLine[splitIndex...])
        
        area.lines[cursorLine] = beforeCursor
        area.lines.insert(afterCursor, at: cursorLine + 1)
        area.cursorLine += 1
        area.cursorColumn = 0
        
        return area
    }
    
    private func deleteBackward() -> TextArea {
        var area = self
        
        if cursorColumn > 0 {
            // Delete character in current line
            var line = lines[cursorLine]
            let index = line.index(line.startIndex, offsetBy: cursorColumn - 1)
            line.remove(at: index)
            area.lines[cursorLine] = line
            area.cursorColumn -= 1
        } else if cursorLine > 0 {
            // Join with previous line
            let currentLine = lines[cursorLine]
            area.lines.remove(at: cursorLine)
            area.cursorLine -= 1
            area.cursorColumn = lines[cursorLine].count
            area.lines[cursorLine] += currentLine
        }
        
        return area
    }
    
    private func deleteForward() -> TextArea {
        var area = self
        
        if cursorColumn < lines[cursorLine].count {
            // Delete character in current line
            var line = lines[cursorLine]
            let index = line.index(line.startIndex, offsetBy: cursorColumn)
            line.remove(at: index)
            area.lines[cursorLine] = line
        } else if cursorLine < lines.count - 1 {
            // Join with next line
            let nextLine = lines[cursorLine + 1]
            area.lines.remove(at: cursorLine + 1)
            area.lines[cursorLine] += nextLine
        }
        
        return area
    }
    
    private func deleteToEndOfLine() -> TextArea {
        var area = self
        let line = lines[cursorLine]
        let index = line.index(line.startIndex, offsetBy: cursorColumn)
        area.lines[cursorLine] = String(line[..<index])
        return area
    }
    
    private func deleteToStartOfLine() -> TextArea {
        var area = self
        let line = lines[cursorLine]
        let index = line.index(line.startIndex, offsetBy: cursorColumn)
        area.lines[cursorLine] = String(line[index...])
        area.cursorColumn = 0
        return area
    }
    
    private func deleteWordBackward() -> TextArea {
        var area = self
        
        // If at start of line, delete backward like normal
        if cursorColumn == 0 {
            return deleteBackward()
        }
        
        let line = lines[cursorLine]
        var pos = cursorColumn - 1
        let chars = Array(line)
        
        // Skip trailing spaces
        while pos > 0 && chars[pos] == " " {
            pos -= 1
        }
        
        // Skip word characters
        while pos > 0 && chars[pos] != " " {
            pos -= 1
        }
        
        // If we stopped at a space, move forward one
        if pos > 0 && chars[pos] == " " {
            pos += 1
        }
        
        // Delete from pos to cursorColumn
        let startIndex = line.index(line.startIndex, offsetBy: pos)
        let endIndex = line.index(line.startIndex, offsetBy: cursorColumn)
        var newLine = line
        newLine.removeSubrange(startIndex..<endIndex)
        area.lines[cursorLine] = newLine
        area.cursorColumn = pos
        
        return area
    }
    
    // MARK: - Cursor Movement
    
    private func moveCursorLeft() -> TextArea {
        var area = self
        
        if cursorColumn > 0 {
            area.cursorColumn -= 1
        } else if cursorLine > 0 {
            area.cursorLine -= 1
            area.cursorColumn = lines[cursorLine - 1].count
        }
        
        return area
    }
    
    private func moveCursorRight() -> TextArea {
        var area = self
        
        if cursorColumn < lines[cursorLine].count {
            area.cursorColumn += 1
        } else if cursorLine < lines.count - 1 {
            area.cursorLine += 1
            area.cursorColumn = 0
        }
        
        return area
    }
    
    private func moveCursorUp() -> TextArea {
        guard cursorLine > 0 else { return self }
        
        var area = self
        area.cursorLine -= 1
        area.cursorColumn = min(cursorColumn, lines[area.cursorLine].count)
        
        return area
    }
    
    private func moveCursorDown() -> TextArea {
        guard cursorLine < lines.count - 1 else { return self }
        
        var area = self
        area.cursorLine += 1
        area.cursorColumn = min(cursorColumn, lines[area.cursorLine].count)
        
        return area
    }
    
    private func moveCursorToLineStart() -> TextArea {
        var area = self
        area.cursorColumn = 0
        return area
    }
    
    private func moveCursorToLineEnd() -> TextArea {
        var area = self
        area.cursorColumn = lines[cursorLine].count
        return area
    }
    
    private func pageUp() -> TextArea {
        var area = self
        let pageSize = height - 2 // Account for border
        area.cursorLine = max(0, cursorLine - pageSize)
        area.cursorColumn = min(cursorColumn, lines[area.cursorLine].count)
        return area
    }
    
    private func pageDown() -> TextArea {
        var area = self
        let pageSize = height - 2 // Account for border
        area.cursorLine = min(lines.count - 1, cursorLine + pageSize)
        area.cursorColumn = min(cursorColumn, lines[area.cursorLine].count)
        return area
    }
    
    // MARK: - Viewport Management
    
    private func ensureCursorVisible() -> TextArea {
        var area = self
        
        // Vertical scrolling
        let viewportHeight = showBorder ? height - 2 : height
        
        if cursorLine < offsetLine {
            area.offsetLine = cursorLine
        } else if cursorLine >= offsetLine + viewportHeight {
            area.offsetLine = cursorLine - viewportHeight + 1
        }
        
        // Horizontal scrolling (if not word wrapping)
        if !wordWrap {
            let viewportWidth = effectiveWidth
            
            if cursorColumn < offsetColumn {
                area.offsetColumn = cursorColumn
            } else if cursorColumn >= offsetColumn + viewportWidth {
                area.offsetColumn = cursorColumn - viewportWidth + 1
            }
        }
        
        return area
    }
    
    private var effectiveWidth: Int {
        var w = width
        if showBorder {
            w -= 2
        }
        if showLineNumbers {
            w -= lineNumberWidth + 1 // +1 for separator
        }
        return max(1, w)
    }
    
    private var lineNumberWidth: Int {
        String(lines.count).count + 1 // +1 for padding
    }
    
    // MARK: - Rendering
    
    /// Renders the text area as a string
    public func view() -> String {
        var result = [String]()
        
        // Add prompt if present
        if !prompt.isEmpty {
            result.append(promptStyle.render(prompt))
        }
        
        // Calculate viewport
        let viewportHeight = showBorder ? height - 2 : height
        let viewportWidth = effectiveWidth
        
        // Prepare lines to display
        var displayLines = [String]()
        
        if lines.isEmpty || (lines.count == 1 && lines[0].isEmpty) {
            // Show placeholder
            if !placeholder.isEmpty {
                let placeholderLines = placeholder.split(separator: "\n")
                for line in placeholderLines.prefix(viewportHeight) {
                    displayLines.append(placeholderStyle.render(String(line)))
                }
            }
        } else {
            // Show actual content
            let endLine = min(offsetLine + viewportHeight, lines.count)
            
            for lineIndex in offsetLine..<endLine {
                let line = lines[lineIndex]
                var displayLine = ""
                
                // Add line number if enabled
                if showLineNumbers {
                    let lineNum = String(lineIndex + 1).padding(toLength: lineNumberWidth - 1, withPad: " ", startingAt: 0)
                    displayLine += lineNumberStyle.render(lineNum + " ")
                }
                
                // Process the line content
                var lineContent = line
                
                // Handle horizontal scrolling if not word wrapping
                if !wordWrap && offsetColumn > 0 {
                    if offsetColumn < lineContent.count {
                        let startIndex = lineContent.index(lineContent.startIndex, offsetBy: offsetColumn)
                        lineContent = String(lineContent[startIndex...])
                    } else {
                        lineContent = ""
                    }
                }
                
                // Apply cursor if on this line
                if showCursor && focused && lineIndex == cursorLine {
                    let adjustedCursorColumn = cursorColumn - offsetColumn
                    
                    if adjustedCursorColumn >= 0 && adjustedCursorColumn <= lineContent.count {
                        let chars = Array(lineContent)
                        
                        // Text before cursor
                        if adjustedCursorColumn > 0 {
                            let before = String(chars[0..<adjustedCursorColumn])
                            displayLine += textStyle.render(before)
                        }
                        
                        // Cursor
                        if adjustedCursorColumn < chars.count {
                            let cursorText = String(chars[adjustedCursorColumn])
                            displayLine += cursorStyle.render(cursorText)
                        } else {
                            // Cursor at end
                            displayLine += cursorStyle.render(cursorChar)
                        }
                        
                        // Text after cursor
                        if adjustedCursorColumn < chars.count - 1 {
                            let after = String(chars[(adjustedCursorColumn + 1)...])
                            displayLine += textStyle.render(after)
                        }
                    } else {
                        // Cursor is off screen
                        displayLine += textStyle.render(lineContent)
                    }
                } else {
                    // No cursor on this line
                    displayLine += textStyle.render(lineContent)
                }
                
                // Truncate or pad to viewport width
                let currentWidth = displayLine.stripANSI().count
                if currentWidth > viewportWidth {
                    // TODO: Better truncation that preserves ANSI codes
                    displayLine = String(displayLine.prefix(viewportWidth))
                } else if currentWidth < viewportWidth {
                    displayLine += String(repeating: " ", count: viewportWidth - currentWidth)
                }
                
                displayLines.append(displayLine)
            }
        }
        
        // Pad with empty lines if needed
        while displayLines.count < viewportHeight {
            var emptyLine = ""
            if showLineNumbers {
                emptyLine += String(repeating: " ", count: lineNumberWidth)
            }
            emptyLine += String(repeating: " ", count: viewportWidth)
            displayLines.append(emptyLine)
        }
        
        // Apply border if enabled
        if showBorder {
            let borderStyle = focused ? focusedBorderStyle : unfocusedBorderStyle
            let borderWidth = width
            
            // Top border
            result.append(borderStyle.render("┌" + String(repeating: "─", count: borderWidth - 2) + "┐"))
            
            // Content with side borders
            for line in displayLines {
                result.append(borderStyle.render("│") + line + borderStyle.render("│"))
            }
            
            // Bottom border
            result.append(borderStyle.render("└" + String(repeating: "─", count: borderWidth - 2) + "┘"))
        } else {
            result.append(contentsOf: displayLines)
        }
        
        return result.joined(separator: "\n")
    }
}

// MARK: - String Extensions

private extension String {
    /// Strips ANSI escape sequences from the string
    func stripANSI() -> String {
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