import Foundation
import Matcha
import MatchaStyle

// MARK: - Tabs

/// A tabs component that provides horizontal tab navigation
public struct Tabs: Sendable {
    // MARK: - Properties

    /// The tab items
    public var items: [String]

    /// The currently selected tab index
    public var selectedIndex: Int

    /// The width of the tabs component (0 means use full width)
    public var width: Int

    /// Whether the tabs are currently focused
    public var focused: Bool

    /// Style for the normal (unselected) tabs
    public var normalStyle: Style

    /// Style for the selected tab
    public var selectedStyle: Style

    /// Style for the separator between tabs
    public var separatorStyle: Style

    /// The separator character between tabs
    public var separator: String

    /// Style for the underline
    public var underlineStyle: Style

    /// Whether to show an underline under the tabs
    public var showUnderline: Bool

    /// The character to use for the underline
    public var underlineChar: String

    /// Whether to use equal width for all tabs
    public var equalWidth: Bool

    /// Minimum tab width (when equalWidth is true)
    public var minTabWidth: Int

    /// Padding around tab text
    public var padding: Int

    // MARK: - Initialization

    /// Creates a new tabs component with default settings
    public init(items: [String] = []) {
        self.items = items
        self.selectedIndex = 0
        self.width = 0
        self.focused = false
        self.normalStyle = Style().foreground(Color(240))
        self.selectedStyle = Style().bold().foreground(.brightWhite).background(.blue)
        self.separatorStyle = Style().foreground(Color(240))
        self.separator = " │ "
        self.underlineStyle = Style().foreground(Color(240))
        self.showUnderline = true
        self.underlineChar = "─"
        self.equalWidth = false
        self.minTabWidth = 8
        self.padding = 1
    }

    // MARK: - Builder Methods

    /// Sets the tab items
    public func withItems(_ items: [String]) -> Tabs {
        var tabs = self
        tabs.items = items
        // Ensure selected index is within bounds
        tabs.selectedIndex = min(selectedIndex, max(0, items.count - 1))
        return tabs
    }

    /// Sets the selected index
    public func withSelectedIndex(_ index: Int) -> Tabs {
        var tabs = self
        tabs.selectedIndex = max(0, min(index, items.count - 1))
        return tabs
    }

    /// Sets the width
    public func withWidth(_ width: Int) -> Tabs {
        var tabs = self
        tabs.width = width
        return tabs
    }

    /// Sets the focus state
    public func withFocus(_ focused: Bool) -> Tabs {
        var tabs = self
        tabs.focused = focused
        return tabs
    }

    /// Sets whether to use equal width tabs
    public func withEqualWidth(_ equal: Bool) -> Tabs {
        var tabs = self
        tabs.equalWidth = equal
        return tabs
    }

    /// Sets the minimum tab width
    public func withMinTabWidth(_ width: Int) -> Tabs {
        var tabs = self
        tabs.minTabWidth = max(1, width)
        return tabs
    }

    /// Sets the padding
    public func withPadding(_ padding: Int) -> Tabs {
        var tabs = self
        tabs.padding = max(0, padding)
        return tabs
    }

    /// Sets the separator
    public func withSeparator(_ separator: String) -> Tabs {
        var tabs = self
        tabs.separator = separator
        return tabs
    }

    /// Sets whether to show underline
    public func withUnderline(_ show: Bool) -> Tabs {
        var tabs = self
        tabs.showUnderline = show
        return tabs
    }

    /// Sets the underline character
    public func withUnderlineChar(_ char: String) -> Tabs {
        var tabs = self
        tabs.underlineChar = String(char.prefix(1))
        return tabs
    }

    // MARK: - Style Methods

    /// Sets the normal tab style
    public func normalStyle(_ style: Style) -> Tabs {
        var tabs = self
        tabs.normalStyle = style
        return tabs
    }

    /// Sets the selected tab style
    public func selectedStyle(_ style: Style) -> Tabs {
        var tabs = self
        tabs.selectedStyle = style
        return tabs
    }

    /// Sets the separator style
    public func separatorStyle(_ style: Style) -> Tabs {
        var tabs = self
        tabs.separatorStyle = style
        return tabs
    }

    /// Sets the underline style
    public func underlineStyle(_ style: Style) -> Tabs {
        var tabs = self
        tabs.underlineStyle = style
        return tabs
    }

    // MARK: - Update Methods

    /// Updates the tabs based on a message
    public func update(_ msg: any Message) -> Tabs {
        guard focused else { return self }

        if let key = msg as? KeyMsg {
            return handleKey(key)
        }

        return self
    }

    private func handleKey(_ key: KeyMsg) -> Tabs {
        var tabs = self

        switch key.type {
        case .left:
            tabs = tabs.selectPrevious()

        case .ctrlH:
            tabs = tabs.selectPrevious()

        case .right:
            tabs = tabs.selectNext()

        case .ctrlL:
            tabs = tabs.selectNext()

        case .home:
            tabs.selectedIndex = 0

        case .ctrlA:
            tabs.selectedIndex = 0

        case .end:
            tabs.selectedIndex = max(0, items.count - 1)

        case .ctrlE:
            tabs.selectedIndex = max(0, items.count - 1)

        case .runes:
            // Check for number keys 1-9
            if let firstChar = key.runes.first,
               let number = Int(String(firstChar)),
               number >= 1, number <= 9, number <= items.count {
                tabs.selectedIndex = number - 1
            }

        default:
            break
        }

        return tabs
    }

    /// Selects the previous tab
    public func selectPrevious() -> Tabs {
        var tabs = self
        if selectedIndex > 0 {
            tabs.selectedIndex -= 1
        } else if !items.isEmpty {
            // Wrap around to the last tab
            tabs.selectedIndex = items.count - 1
        }
        return tabs
    }

    /// Selects the next tab
    public func selectNext() -> Tabs {
        var tabs = self
        if selectedIndex < items.count - 1 {
            tabs.selectedIndex += 1
        } else if !items.isEmpty {
            // Wrap around to the first tab
            tabs.selectedIndex = 0
        }
        return tabs
    }

    // MARK: - Rendering

    /// Renders the tabs as a string
    public func view() -> String {
        guard !items.isEmpty else {
            return ""
        }

        var result = ""

        // Calculate tab widths
        let tabWidths: [Int]
        if equalWidth {
            let maxWidth = items.map(\.count).max() ?? 0
            let tabWidth = max(minTabWidth, maxWidth + padding * 2)
            tabWidths = Array(repeating: tabWidth, count: items.count)
        } else {
            tabWidths = items.map { $0.count + padding * 2 }
        }

        // Render tabs
        var tabLine = ""
        var underlinePositions: [(start: Int, length: Int)] = []
        var currentPosition = 0

        for (index, item) in items.enumerated() {
            // Add separator before tab (except for the first one)
            if index > 0 {
                tabLine += separatorStyle.render(separator)
                currentPosition += separator.stripANSI().count
            }

            // Calculate padded text
            let paddingStr = String(repeating: " ", count: padding)
            let paddedText = paddingStr + item + paddingStr

            // Ensure equal width if needed
            let finalText: String
            if equalWidth {
                let targetWidth = tabWidths[index]
                let currentWidth = paddedText.count
                if currentWidth < targetWidth {
                    let extraPadding = targetWidth - currentWidth
                    let leftExtra = extraPadding / 2
                    let rightExtra = extraPadding - leftExtra
                    finalText = String(repeating: " ", count: leftExtra) + paddedText + String(
                        repeating: " ",
                        count: rightExtra
                    )
                } else {
                    finalText = paddedText
                }
            } else {
                finalText = paddedText
            }

            // Track position for underline
            let startPos = currentPosition

            // Render the tab
            if index == selectedIndex {
                tabLine += selectedStyle.render(finalText)
            } else {
                tabLine += normalStyle.render(finalText)
            }

            // Update position and track for underline
            let renderedWidth = finalText.count
            if index == selectedIndex {
                underlinePositions.append((start: startPos, length: renderedWidth))
            }
            currentPosition += renderedWidth
        }

        result += tabLine

        // Add underline if enabled
        if showUnderline {
            result += "\n"

            // Build underline
            var underline = ""
            var pos = 0

            for (start, length) in underlinePositions {
                // Add spaces to reach the start position
                while pos < start {
                    underline += " "
                    pos += 1
                }

                // Add the underline
                underline += underlineStyle.render(String(repeating: underlineChar, count: length))
                pos += length
            }

            // Pad to full width if specified
            if width > 0 {
                let currentWidth = currentPosition
                if currentWidth < width {
                    underline += underlineStyle.render(String(repeating: underlineChar, count: width - currentWidth))
                }
            }

            result += underline
        }

        return result
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
