import Foundation
import Matcha
import MatchaStyle

// MARK: - Help

/// A help component that displays keybindings in various formatted layouts.
///
/// The Help component provides a flexible way to display keyboard shortcuts and
/// their descriptions. It supports:
/// - Multiple display styles (full table, short keys, inline format)
/// - Grouping of related keybindings
/// - Customizable styling for keys, descriptions, and disabled items
/// - Built-in common keybinding sets
/// - Automatic column width calculation
///
/// Example usage:
/// ```swift
/// let help = Help(bindings: [
///     ("↑/k", "Move up"),
///     ("↓/j", "Move down"),
///     ("q", "Quit")
/// ])
/// help.displayStyle = .full
/// let rendered = help.view()
/// ```
public struct Help: Sendable {
    /// Represents a single keybinding with its description and state.
    ///
    /// A binding can have multiple key combinations that perform the same action,
    /// and can be marked as disabled to show unavailable commands.
    public struct Binding: Sendable {
        public let keys: [String]
        public let description: String
        public let disabled: Bool

        public init(keys: [String], description: String, disabled: Bool = false) {
            self.keys = keys
            self.description = description
            self.disabled = disabled
        }

        public init(key: String, description: String, disabled: Bool = false) {
            self.init(keys: [key], description: description, disabled: disabled)
        }
    }

    /// Determines how the help information is formatted and displayed
    public enum DisplayStyle: Sendable {
        /// Full table format with aligned columns showing keys and descriptions
        case full
        /// Compact format showing only the key names separated by bullets
        case short
        /// Single-line format with keys and descriptions inline
        case inline
    }

    /// Represents a logical grouping of related keybindings.
    ///
    /// Groups help organize keybindings into sections like "Navigation",
    /// "Actions", etc., making the help more readable.
    public struct Group: Sendable {
        public let title: String
        public let bindings: [Binding]

        public init(title: String, bindings: [Binding]) {
            self.title = title
            self.bindings = bindings
        }
    }

    /// Collection of keybinding groups to display.
    /// Groups are rendered in order with optional titles.
    public var groups: [Group]

    /// Controls the visual layout of the help component
    public var displayStyle: DisplayStyle = .full

    /// Determines whether to display the main help title
    public var showTitle: Bool = true

    /// Main title text displayed at the top of the help (when showTitle is true)
    public var title: String = "Help"

    /// String used to separate key column from description column in full style
    public var separator: String = "  "

    /// Style applied to keyboard shortcut text
    public var keyStyle = Style().foreground(.cyan)

    /// Style applied to keybinding descriptions
    public var descriptionStyle: Style = .defaultStyle()

    /// Style applied to disabled keybindings
    public var disabledStyle = Style().faint()

    /// Style applied to the main help title
    public var titleStyle = Style().bold()

    /// Style applied to group section titles
    public var groupTitleStyle = Style().underline()

    /// Controls visibility of disabled keybindings.
    /// When false, disabled bindings are hidden from display.
    public var showDisabled: Bool = true

    /// Optional maximum width constraint for rendering.
    /// Currently unused but reserved for future layout constraints.
    public var maxWidth: Int?

    /// Creates a help component with multiple keybinding groups.
    /// - Parameter groups: Array of keybinding groups to display
    public init(groups: [Group]) {
        self.groups = groups
    }

    /// Creates a help component with a single unnamed group.
    /// - Parameter bindings: Array of keybindings to display
    public init(bindings: [Binding]) {
        self.groups = [Group(title: "", bindings: bindings)]
    }

    /// Creates a help component from key-description pairs.
    /// - Parameter bindings: Array of tuples containing key and description
    public init(bindings: [(String, String)]) {
        let bindingsList = bindings.map { Binding(key: $0.0, description: $0.1) }
        self.init(bindings: bindingsList)
    }

    /// Renders the help component according to the current display style.
    /// - Returns: Formatted string representation of the help
    public func view() -> String {
        switch displayStyle {
        case .full:
            renderFull()
        case .short:
            renderShort()
        case .inline:
            renderInline()
        }
    }

    private func renderFull() -> String {
        var lines: [String] = []

        // Title
        if showTitle {
            lines.append(titleStyle.render(title))
            lines.append("")
        }

        // Calculate column widths
        let maxKeyWidth = calculateMaxKeyWidth()

        // Render each group
        for (index, group) in groups.enumerated() {
            // Group title
            if !group.title.isEmpty {
                if index > 0 {
                    lines.append("")
                }
                lines.append(groupTitleStyle.render(group.title))
            }

            // Bindings
            for binding in group.bindings {
                if !showDisabled, binding.disabled {
                    continue
                }

                let keysText = binding.keys.joined(separator: "/")
                let paddedKeys = keysText.padding(toLength: maxKeyWidth, withPad: " ", startingAt: 0)

                if binding.disabled {
                    let line = "\(paddedKeys)\(separator)\(binding.description)"
                    lines.append(disabledStyle.render(line))
                } else {
                    let styledKeys = keyStyle.render(paddedKeys)
                    let styledDesc = descriptionStyle.render(binding.description)
                    lines.append("\(styledKeys)\(separator)\(styledDesc)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func renderShort() -> String {
        var allBindings: [Binding] = []
        for group in groups {
            allBindings.append(contentsOf: group.bindings)
        }

        let enabledBindings = showDisabled ? allBindings : allBindings.filter { !$0.disabled }
        let keys = enabledBindings.map { binding in
            let keysText = binding.keys.joined(separator: "/")
            return binding.disabled ? disabledStyle.render(keysText) : keyStyle.render(keysText)
        }

        return keys.joined(separator: " • ")
    }

    private func renderInline() -> String {
        var parts: [String] = []

        for group in groups {
            for binding in group.bindings {
                if !showDisabled, binding.disabled {
                    continue
                }

                let keysText = binding.keys.joined(separator: "/")
                let part = binding.disabled
                    ? disabledStyle.render("\(keysText): \(binding.description)")
                    : "\(keyStyle.render(keysText)): \(descriptionStyle.render(binding.description))"
                parts.append(part)
            }
        }

        return parts.joined(separator: " • ")
    }

    private func calculateMaxKeyWidth() -> Int {
        var maxWidth = 0

        for group in groups {
            for binding in group.bindings {
                if !showDisabled, binding.disabled {
                    continue
                }
                let keysText = binding.keys.joined(separator: "/")
                maxWidth = max(maxWidth, keysText.count)
            }
        }

        return maxWidth
    }
}

// MARK: - Common Keybindings

public extension Help {
    /// Predefined set of common navigation keybindings.
    /// Includes arrow keys, vim-style navigation, and page movement.
    static let navigationBindings = [
        Binding(keys: ["↑", "k"], description: "Move up"),
        Binding(keys: ["↓", "j"], description: "Move down"),
        Binding(keys: ["←", "h"], description: "Move left"),
        Binding(keys: ["→", "l"], description: "Move right"),
        Binding(keys: ["PgUp", "b"], description: "Page up"),
        Binding(keys: ["PgDn", "f"], description: "Page down"),
        Binding(keys: ["Home", "g"], description: "Go to start"),
        Binding(keys: ["End", "G"], description: "Go to end")
    ]

    /// Predefined set of common action keybindings.
    /// Includes selection, toggling, and field navigation.
    static let actionBindings = [
        Binding(key: "Enter", description: "Select/Confirm"),
        Binding(key: "Space", description: "Toggle/Select"),
        Binding(key: "Tab", description: "Next field"),
        Binding(keys: ["Shift+Tab"], description: "Previous field"),
        Binding(key: "Esc", description: "Cancel/Back")
    ]

    /// Predefined set of common application keybindings.
    /// Includes quit, help toggle, and screen management.
    static let appBindings = [
        Binding(keys: ["q", "Ctrl+c"], description: "Quit"),
        Binding(key: "?", description: "Toggle help"),
        Binding(key: "r", description: "Refresh"),
        Binding(keys: ["Ctrl+l"], description: "Clear screen")
    ]

    /// Creates a help component with standard keybinding groups.
    ///
    /// This factory method provides a convenient way to create a help component
    /// with commonly used keybinding sections, plus any custom bindings.
    ///
    /// - Parameters:
    ///   - navigation: Include navigation keybindings (arrows, vim keys)
    ///   - actions: Include action keybindings (enter, space, tab)
    ///   - app: Include application keybindings (quit, help)
    ///   - custom: Additional custom keybindings to include
    /// - Returns: Configured Help component with selected groups
    static func standard(
        navigation: Bool = true,
        actions: Bool = true,
        app: Bool = true,
        custom: [Binding] = []
    ) -> Help {
        var groups: [Group] = []

        if navigation {
            groups.append(Group(title: "Navigation", bindings: navigationBindings))
        }

        if actions {
            groups.append(Group(title: "Actions", bindings: actionBindings))
        }

        if !custom.isEmpty {
            groups.append(Group(title: "Commands", bindings: custom))
        }

        if app {
            groups.append(Group(title: "Application", bindings: appBindings))
        }

        return Help(groups: groups)
    }
}
