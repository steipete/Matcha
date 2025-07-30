import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - HelpModel

public struct HelpModel: Model {
    var help: Help
    var displayStyle: Help.DisplayStyle = .full
    var showDisabled: Bool = true
    var customBindings: [Help.Binding] = []

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(KeyMsg)
        case toggleStyle
        case toggleDisabled
        case nextStyle
    }

    public init() {
        // Create custom bindings for this app
        let customBindings = [
            Help.Binding(key: "a", description: "Add new item"),
            Help.Binding(key: "d", description: "Delete item"),
            Help.Binding(key: "e", description: "Edit item"),
            Help.Binding(key: "s", description: "Save changes"),
            Help.Binding(key: "u", description: "Undo last action", disabled: true),
            Help.Binding(keys: ["Ctrl+r"], description: "Redo action", disabled: true)
        ]

        // Create help with multiple groups
        let groups = [
            Help.Group(title: "Navigation", bindings: Help.navigationBindings),
            Help.Group(title: "File Operations", bindings: customBindings),
            Help.Group(title: "Application", bindings: Help.appBindings)
        ]

        self.help = Help(groups: groups)
        self.customBindings = customBindings
    }

    public func `init`() -> Command<Message>? {
        nil
    }

    public func update(_ message: Message) -> (HelpModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.type {
            case .tab:
                return update(.nextStyle)
            default:
                switch key.description {
                case "s":
                    return update(.toggleStyle)
                case "d":
                    return update(.toggleDisabled)
                default:
                    return (model, nil)
                }
            }

        case .toggleStyle:
            // Cycle through display styles
            switch model.help.displayStyle {
            case .full:
                model.help.displayStyle = .short
            case .short:
                model.help.displayStyle = .inline
            case .inline:
                model.help.displayStyle = .full
            }
            return (model, nil)

        case .toggleDisabled:
            model.showDisabled.toggle()
            model.help.showDisabled = model.showDisabled
            return (model, nil)

        case .nextStyle:
            // Change visual styling
            // Toggle between two different styles
            if model.help.keyStyle.bold {
                model.help.keyStyle = Style().foreground(.cyan)
            } else {
                model.help.keyStyle = Style().bold().foreground(.magenta)
            }
            return (model, nil)
        }
    }

    public func view() -> String {
        var lines: [String] = []
        let style = Style()

        // Title
        lines.append(style.bold().render("Help Component Demo"))
        lines.append("")

        // Current settings
        let styleText = switch help.displayStyle {
        case .full: "Full"
        case .short: "Short"
        case .inline: "Inline"
        }

        lines.append("Display Style: \(style.foreground(.green).render(styleText))")
        lines
            .append(
                "Show Disabled: \(style.foreground(showDisabled ? .green : .red).render(showDisabled ? "Yes" : "No"))"
            )
        lines.append("")

        // Separator
        lines.append(String(repeating: "─", count: 50))
        lines.append("")

        // Help component
        lines.append(help.view())

        // Controls
        lines.append("")
        lines.append(String(repeating: "─", count: 50))
        lines.append("")
        lines.append("Controls:")
        lines.append("  s     - Toggle display style")
        lines.append("  d     - Toggle show disabled")
        lines.append("  Tab   - Change key styling")
        lines.append("  q     - Quit")

        return lines.joined(separator: "\n")
    }
}

// MARK: - HelpApp

@main
enum HelpApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true

        // Add a filter to convert messages
        options.filter = { _, message in
            switch message {
            case let key as KeyMsg:
                switch key.description {
                case "ctrl+c",
                     "q":
                    QuitMsg()
                default:
                    HelpModel.Message.key(key)
                }
            default:
                message
            }
        }

        let program = Program(initialModel: HelpModel(), options: options)
        _ = try await program.run()
    }
}
