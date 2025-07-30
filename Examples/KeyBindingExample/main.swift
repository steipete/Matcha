//
//  KeyBindingExample.swift
//  Matcha
//
//  Demonstrates the KeyBinding system for managing keyboard shortcuts.
//

import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

struct KeyBindingModel: Model, KeyBindable {
    var keyMap: KeyMap
    var lastAction: String = "No action yet"
    var showHelp: Bool = false
    var selectedMode: Mode = .normal
    var helpComponent: Help
    
    enum Mode: String, CaseIterable {
        case normal = "Normal"
        case edit = "Edit"
        case command = "Command"
    }
    
    enum Message: Matcha.Message {
        case key(KeyMsg)
        case action(String)
        case toggleHelp
        case switchMode(Mode)
        case quit
    }
    
    init() {
        // Build the key map based on the current mode
        self.keyMap = Self.buildKeyMap(for: .normal)
        
        // Initialize help component
        self.helpComponent = Help(groups: keyMap.helpGroups())
        self.helpComponent.displayStyle = .full
        self.helpComponent.showTitle = false  // We'll show our own title
    }
    
    static func buildKeyMap(for mode: Mode) -> KeyMap {
        let builder = KeyMapBuilder()
        
        switch mode {
        case .normal:
            return builder
                .category("Navigation")
                .bind("up", "k", help: "Move up")
                .bind("down", "j", help: "Move down")
                .bind("left", "h", help: "Move left")
                .bind("right", "l", help: "Move right")
                .bind("g", help: KeyHelp(key: "g", desc: "Go to top"))
                .bind("G", help: KeyHelp(key: "G", desc: "Go to bottom"))
                .separator()
                .bind("pgup", "ctrl+u", help: KeyHelp(key: "PgUp/Ctrl+U", desc: "Page up"))
                .bind("pgdown", "ctrl+d", help: KeyHelp(key: "PgDn/Ctrl+D", desc: "Page down"))
                .category("Actions")
                .bind("enter", " ", help: KeyHelp(key: "Enter/Space", desc: "Select item"))
                .bind("d", help: "Delete item")
                .bind("a", help: "Add new item")
                .bind("e", help: "Edit item")
                .bind("r", help: "Refresh")
                .separator()
                .bind("u", help: "Undo last action")
                .bind("ctrl+r", help: KeyHelp(key: "Ctrl+R", desc: "Redo"))
                .category("Modes")
                .bind("i", help: "Enter edit mode")
                .bind(":", help: "Enter command mode")
                .bind("esc", help: "Return to normal mode")
                .category("Application")
                .bind("?", help: "Toggle help")
                .bind("ctrl+c", "q", help: KeyHelp(key: "Ctrl+C/Q", desc: "Quit"))
                .build()
                
        case .edit:
            return builder
                .category("Editing")
                .bind("ctrl+a", help: KeyHelp(key: "Ctrl+A", desc: "Move to start"))
                .bind("ctrl+e", help: KeyHelp(key: "Ctrl+E", desc: "Move to end"))
                .bind("ctrl+k", help: KeyHelp(key: "Ctrl+K", desc: "Delete to end"))
                .bind("ctrl+u", help: KeyHelp(key: "Ctrl+U", desc: "Delete to start"))
                .bind("ctrl+w", help: KeyHelp(key: "Ctrl+W", desc: "Delete word"))
                .separator()
                .bind("tab", help: "Autocomplete")
                .bind("ctrl+n", help: KeyHelp(key: "Ctrl+N", desc: "Next suggestion"))
                .bind("ctrl+p", help: KeyHelp(key: "Ctrl+P", desc: "Previous suggestion"))
                .category("Navigation")
                .bind("left", help: "Move cursor left")
                .bind("right", help: "Move cursor right")
                .bind("ctrl+b", help: KeyHelp(key: "Ctrl+B", desc: "Move word left"))
                .bind("ctrl+f", help: KeyHelp(key: "Ctrl+F", desc: "Move word right"))
                .category("Modes")
                .bind("esc", help: "Return to normal mode")
                .bind("ctrl+c", help: KeyHelp(key: "Ctrl+C", desc: "Cancel & return"))
                .category("Application")
                .bind("?", help: "Toggle help")
                .build()
                
        case .command:
            return builder
                .category("Commands")
                .bind("w", help: "Write/Save")
                .bind("q", help: "Quit")
                .bind("wq", help: "Write and quit")
                .bind("e", help: "Edit file")
                .bind("!", help: "Force command")
                .separator()
                .bind("s", help: "Search")
                .bind("r", help: "Replace")
                .bind("g", help: "Go to line")
                .category("Navigation")
                .bind("up", help: "Previous command")
                .bind("down", help: "Next command")
                .bind("tab", help: "Autocomplete")
                .category("Modes")
                .bind("esc", help: "Return to normal mode")
                .bind("enter", help: "Execute command")
                .category("Application")
                .bind("?", help: "Toggle help")
                .bind("ctrl+c", help: KeyHelp(key: "Ctrl+C", desc: "Cancel"))
                .build()
        }
    }
    
    func `init`() -> Command<Message>? {
        nil
    }
    
    func update(_ message: Message) -> (KeyBindingModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            // Check for mode-specific bindings first
            if let binding = model.keyMap.binding(for: key.description) {
                if binding.enabled {
                    // Handle the key based on its binding
                    switch key.description {
                    case "?":
                        return model.update(.toggleHelp)
                    case "ctrl+c", "q":
                        if model.selectedMode == .normal {
                            return model.update(.quit)
                        }
                    case "i":
                        if model.selectedMode == .normal {
                            return model.update(.switchMode(.edit))
                        }
                    case ":":
                        if model.selectedMode == .normal {
                            return model.update(.switchMode(.command))
                        }
                    case "esc":
                        if model.selectedMode != .normal {
                            return model.update(.switchMode(.normal))
                        }
                    default:
                        model.lastAction = "Executed: \(binding.help.desc) [\(key.description)]"
                    }
                }
            } else {
                model.lastAction = "Unbound key: \(key.description)"
            }
            
        case .action(let action):
            model.lastAction = action
            
        case .toggleHelp:
            model.showHelp.toggle()
            
        case .switchMode(let mode):
            model.selectedMode = mode
            model.keyMap = Self.buildKeyMap(for: mode)
            model.lastAction = "Switched to \(mode.rawValue) mode"
            
            // Update help component with new bindings
            model.helpComponent = Help(groups: model.keyMap.helpGroups())
            model.helpComponent.displayStyle = .full
            model.helpComponent.showTitle = false  // We'll show our own title
            
        case .quit:
            return (model, quit())
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        var view = ""
        
        // Title and mode indicator
        let modeStyle: Style
        switch selectedMode {
        case .normal:
            modeStyle = Style().bold().foreground(.brightGreen)
        case .edit:
            modeStyle = Style().bold().foreground(.brightYellow)
        case .command:
            modeStyle = Style().bold().foreground(.brightCyan)
        }
        
        view += Style().bold().foreground(.brightMagenta).render("⌨️  KeyBinding System Demo") + "\n"
        view += "Mode: " + modeStyle.render("[\(selectedMode.rawValue)]") + "\n\n"
        
        // Last action
        view += Style().bold().render("Last Action:") + " "
        view += Style().foreground(.brightBlue).render(lastAction) + "\n\n"
        
        // Mode-specific content
        switch selectedMode {
        case .normal:
            view += Style().foreground(Color(240)).render("You are in Normal mode. Available actions:") + "\n"
            view += Style().foreground(Color(240)).render("• Navigate with arrow keys or hjkl") + "\n"
            view += Style().foreground(Color(240)).render("• Press 'i' for Edit mode, ':' for Command mode") + "\n"
            view += Style().foreground(Color(240)).render("• Try various action keys (a, d, e, r, u)") + "\n"
            
        case .edit:
            view += Style().foreground(.brightYellow).render("📝 Edit Mode Active") + "\n"
            view += Style().foreground(Color(240)).render("• Use Ctrl+A/E to move to start/end") + "\n"
            view += Style().foreground(Color(240)).render("• Use Ctrl+K/U to delete text") + "\n"
            view += Style().foreground(Color(240)).render("• Press ESC to return to Normal mode") + "\n"
            
        case .command:
            view += Style().foreground(.brightCyan).render("⚡ Command Mode Active") + "\n"
            view += Style().foreground(Color(240)).render("• Type commands: w, q, wq, s, r, g") + "\n"
            view += Style().foreground(Color(240)).render("• Use Tab for autocomplete") + "\n"
            view += Style().foreground(Color(240)).render("• Press ESC to return to Normal mode") + "\n"
        }
        
        view += "\n"
        
        // Key binding status
        let totalBindings = keyMap.allBindings.count
        let enabledBindings = keyMap.allBindings.filter { $0.enabled }.count
        view += Style().foreground(Color(240)).render("Active Bindings: ") +
                Style().bold().render("\(enabledBindings)/\(totalBindings)") + "\n\n"
        
        // Help section or prompt
        if showHelp {
            view += Style().bold().render("Key Bindings for \(selectedMode.rawValue) Mode:") + "\n"
            view += Style().foreground(Color(240)).render(String(repeating: "─", count: 40)) + "\n\n"
            view += helpComponent.view() + "\n"
        } else {
            view += Style().foreground(Color(240)).render("Press ") +
                    Style().bold().render("?") +
                    Style().foreground(Color(240)).render(" to toggle help") + "\n"
        }
        
        view += "\n"
        view += Style().foreground(Color(240)).render("Press ") +
                Style().bold().render("Ctrl+C") +
                Style().foreground(Color(240)).render(" or ") +
                Style().bold().render("Q") +
                Style().foreground(Color(240)).render(" (in Normal mode) to quit")
        
        return view
    }
}

@main
struct KeyBindingExampleApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        
        let program = Program(
            initialModel: KeyBindingModel(),
            options: options
        )
        _ = try await program.run()
    }
}