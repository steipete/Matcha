//
//  Confirmation.swift
//  MatchaBubbles
//
//  A confirmation dialog component for Matcha TUI applications.
//

import Foundation
import Matcha
import MatchaStyle

/// A confirmation dialog component for yes/no prompts
public struct Confirmation: Sendable {
    // MARK: - Types
    
    /// The selected option
    public enum Choice: Sendable {
        case yes
        case no
        case none
    }
    
    // MARK: - Properties
    
    /// The title of the confirmation dialog
    public var title: String
    
    /// The message to display
    public var message: String
    
    /// The currently selected choice
    public var selected: Choice
    
    /// Whether the dialog is active
    public var active: Bool
    
    /// Text for the yes button
    public var yesText: String
    
    /// Text for the no button
    public var noText: String
    
    /// Style for the dialog box
    public var boxStyle: Style
    
    /// Style for the title
    public var titleStyle: Style
    
    /// Style for the message
    public var messageStyle: Style
    
    /// Style for selected button
    public var selectedStyle: Style
    
    /// Style for unselected button
    public var unselectedStyle: Style
    
    /// Style for button brackets
    public var bracketStyle: Style
    
    /// Whether to show border
    public var showBorder: Bool
    
    /// Border style
    public var borderStyle: BorderStyle
    
    /// Width of the dialog (0 for auto)
    public var width: Int
    
    /// Padding around content
    public var padding: Int
    
    // MARK: - Initialization
    
    /// Creates a new confirmation dialog
    public init(
        title: String = "",
        message: String = "Are you sure?"
    ) {
        self.title = title
        self.message = message
        self.selected = .yes
        self.active = true
        self.yesText = "Yes"
        self.noText = "No"
        self.boxStyle = Style().background(Color(236))
        self.titleStyle = Style().bold().foreground(.brightWhite)
        self.messageStyle = Style().foreground(.white)
        self.selectedStyle = Style().reverse().bold()
        self.unselectedStyle = Style().foreground(Color(240))
        self.bracketStyle = Style().foreground(Color(240))
        self.showBorder = true
        self.borderStyle = .rounded
        self.width = 0
        self.padding = 1
    }
    
    // MARK: - Builder Methods
    
    /// Sets the title
    public func withTitle(_ title: String) -> Confirmation {
        var confirmation = self
        confirmation.title = title
        return confirmation
    }
    
    /// Sets the message
    public func withMessage(_ message: String) -> Confirmation {
        var confirmation = self
        confirmation.message = message
        return confirmation
    }
    
    /// Sets the selected choice
    public func withSelected(_ selected: Choice) -> Confirmation {
        var confirmation = self
        confirmation.selected = selected
        return confirmation
    }
    
    /// Sets whether the dialog is active
    public func withActive(_ active: Bool) -> Confirmation {
        var confirmation = self
        confirmation.active = active
        return confirmation
    }
    
    /// Sets the yes button text
    public func withYesText(_ text: String) -> Confirmation {
        var confirmation = self
        confirmation.yesText = text
        return confirmation
    }
    
    /// Sets the no button text
    public func withNoText(_ text: String) -> Confirmation {
        var confirmation = self
        confirmation.noText = text
        return confirmation
    }
    
    /// Sets the width
    public func withWidth(_ width: Int) -> Confirmation {
        var confirmation = self
        confirmation.width = max(0, width)
        return confirmation
    }
    
    /// Sets the padding
    public func withPadding(_ padding: Int) -> Confirmation {
        var confirmation = self
        confirmation.padding = max(0, padding)
        return confirmation
    }
    
    /// Sets whether to show border
    public func withBorder(_ show: Bool) -> Confirmation {
        var confirmation = self
        confirmation.showBorder = show
        return confirmation
    }
    
    /// Sets the border style
    public func withBorderStyle(_ style: BorderStyle) -> Confirmation {
        var confirmation = self
        confirmation.borderStyle = style
        return confirmation
    }
    
    // MARK: - Style Builder Methods
    
    /// Sets the box style
    public func boxStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.boxStyle = style
        return confirmation
    }
    
    /// Sets the title style
    public func titleStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.titleStyle = style
        return confirmation
    }
    
    /// Sets the message style
    public func messageStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.messageStyle = style
        return confirmation
    }
    
    /// Sets the selected button style
    public func selectedStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.selectedStyle = style
        return confirmation
    }
    
    /// Sets the unselected button style
    public func unselectedStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.unselectedStyle = style
        return confirmation
    }
    
    /// Sets the bracket style
    public func bracketStyle(_ style: Style) -> Confirmation {
        var confirmation = self
        confirmation.bracketStyle = style
        return confirmation
    }
    
    // MARK: - Update Methods
    
    /// Updates the confirmation dialog based on a message
    public func update(_ msg: any Message) -> Confirmation {
        guard active else { return self }
        
        if let key = msg as? KeyMsg {
            return handleKey(key)
        }
        
        return self
    }
    
    private func handleKey(_ key: KeyMsg) -> Confirmation {
        var confirmation = self
        
        switch key.type {
        case .left:
            confirmation.selected = .yes
            
        case .ctrlH:
            confirmation.selected = .yes
            
        case .right, .tab:
            confirmation.selected = .no
            
        case .ctrlL:
            confirmation.selected = .no
            
        case .enter, .space:
            confirmation.active = false
            
        case .escape:
            confirmation.selected = .none
            confirmation.active = false
            
        case .runes:
            let char = String(key.runes).lowercased()
            if char == "y" {
                confirmation.selected = .yes
                confirmation.active = false
            } else if char == "n" {
                confirmation.selected = .no
                confirmation.active = false
            }
            
        default:
            break
        }
        
        return confirmation
    }
    
    // MARK: - Accessors
    
    /// Returns true if the user selected yes
    public var isConfirmed: Bool {
        selected == .yes && !active
    }
    
    /// Returns true if the user made a choice
    public var hasChoice: Bool {
        !active && selected != .none
    }
    
    // MARK: - Rendering
    
    /// Renders the confirmation dialog
    public func view() -> String {
        var lines: [String] = []
        
        // Calculate content width
        let titleWidth = title.stripANSI().count
        let messageWidth = message.stripANSI().count
        let buttonsWidth = yesText.count + noText.count + 10 // Extra space for brackets and spacing
        
        let contentWidth = max(titleWidth, messageWidth, buttonsWidth) + (padding * 2)
        let boxWidth = width > 0 ? width : contentWidth + 2
        
        // Build content
        var content: [String] = []
        
        // Add padding line if needed
        if padding > 0 {
            content.append("")
        }
        
        // Add title if present
        if !title.isEmpty {
            let centeredTitle = center(title, width: boxWidth - 2)
            content.append(titleStyle.render(centeredTitle))
            if !message.isEmpty || padding > 0 {
                content.append("")
            }
        }
        
        // Add message
        if !message.isEmpty {
            let centeredMessage = center(message, width: boxWidth - 2)
            content.append(messageStyle.render(centeredMessage))
            content.append("")
        }
        
        // Add buttons
        let yesButton = bracketStyle.render("[") +
                       (selected == .yes ? selectedStyle : unselectedStyle).render(yesText) +
                       bracketStyle.render("]")
        
        let noButton = bracketStyle.render("[") +
                      (selected == .no ? selectedStyle : unselectedStyle).render(noText) +
                      bracketStyle.render("]")
        
        let buttons = yesButton + "  " + noButton
        let centeredButtons = center(buttons, width: boxWidth - 2)
        content.append(centeredButtons)
        
        // Add padding line if needed
        if padding > 0 {
            content.append("")
        }
        
        // Apply box style and border
        if showBorder {
            lines = applyBorder(content, style: borderStyle, width: boxWidth)
        } else {
            // Just apply padding
            for line in content {
                let paddedLine = " " + line.padding(toLength: boxWidth - 2, withPad: " ", startingAt: 0) + " "
                lines.append(boxStyle.render(paddedLine))
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Helper Methods
    
    /// Centers text within a given width
    private func center(_ text: String, width: Int) -> String {
        let textWidth = text.stripANSI().count
        if textWidth >= width {
            return text
        }
        
        let totalPadding = width - textWidth
        let leftPadding = totalPadding / 2
        let rightPadding = totalPadding - leftPadding
        
        return String(repeating: " ", count: leftPadding) + text + String(repeating: " ", count: rightPadding)
    }
    
    /// Applies a border to content
    private func applyBorder(_ content: [String], style: BorderStyle, width: Int) -> [String] {
        var lines: [String] = []
        let chars = style.characters
        
        // Top border
        lines.append(boxStyle.render(chars.topLeft + String(repeating: chars.horizontal, count: width - 2) + chars.topRight))
        
        // Content with side borders
        for line in content {
            let paddedLine = line.padding(toLength: width - 2, withPad: " ", startingAt: 0)
            lines.append(boxStyle.render(chars.vertical) + paddedLine + boxStyle.render(chars.vertical))
        }
        
        // Bottom border
        lines.append(boxStyle.render(chars.bottomLeft + String(repeating: chars.horizontal, count: width - 2) + chars.bottomRight))
        
        return lines
    }
}

// MARK: - Border Style

/// Border style for the confirmation dialog
public enum BorderStyle: Sendable {
    case single
    case double
    case rounded
    case thick
    case none
    
    var characters: BorderCharacters {
        switch self {
        case .single:
            return BorderCharacters(
                horizontal: "─", vertical: "│",
                topLeft: "┌", topRight: "┐",
                bottomLeft: "└", bottomRight: "┘"
            )
        case .double:
            return BorderCharacters(
                horizontal: "═", vertical: "║",
                topLeft: "╔", topRight: "╗",
                bottomLeft: "╚", bottomRight: "╝"
            )
        case .rounded:
            return BorderCharacters(
                horizontal: "─", vertical: "│",
                topLeft: "╭", topRight: "╮",
                bottomLeft: "╰", bottomRight: "╯"
            )
        case .thick:
            return BorderCharacters(
                horizontal: "━", vertical: "┃",
                topLeft: "┏", topRight: "┓",
                bottomLeft: "┗", bottomRight: "┛"
            )
        case .none:
            return BorderCharacters(
                horizontal: " ", vertical: " ",
                topLeft: " ", topRight: " ",
                bottomLeft: " ", bottomRight: " "
            )
        }
    }
}

struct BorderCharacters {
    let horizontal: String
    let vertical: String
    let topLeft: String
    let topRight: String
    let bottomLeft: String
    let bottomRight: String
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