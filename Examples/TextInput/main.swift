//
//  main.swift
//  TextInput Example
//
//  Demonstrates the TextInput component.
//

import Matcha
import MatchaBubbles
import MatchaStyle

// Model that uses TextInput component
public struct TextInputModel: Model {
    var nameInput: TextInput
    var passwordInput: TextInput
    var focusedField: Field = .name
    var submitted: Bool = false
    
    enum Field {
        case name
        case password
    }
    
    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(Key)
        case paste(PasteMsg)
        case switchField
    }
    
    public init() {
        // Initialize text inputs
        nameInput = TextInput()
            .withPlaceholder("Enter your name...")
            .withPrompt("Name: ")
            .withFocus(true)
            .promptStyle(Style().foreground(.cyan))
            .placeholderStyle(Style().foreground(Color(240)))
        
        passwordInput = TextInput()
            .withPlaceholder("Enter password...")
            .withPrompt("Password: ")
            .withEchoMode(.password)
            .promptStyle(Style().foreground(.cyan))
            .placeholderStyle(Style().foreground(Color(240)))
    }
    
    public func `init`() -> Command<Message>? {
        nil
    }
    
    public func update(_ message: Message) -> (TextInputModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            // Handle special keys
            switch key.type {
            case .tab:
                // Switch between fields
                model = model.switchField()
                return (model, nil)
                
            case .enter:
                // Submit form
                if !model.nameInput.value.isEmpty && !model.passwordInput.value.isEmpty {
                    model.submitted = true
                    return (model, quit())
                }
                return (model, nil)
                
            default:
                // Pass to appropriate input
                switch model.focusedField {
                case .name:
                    model.nameInput = model.nameInput.update(key)
                case .password:
                    model.passwordInput = model.passwordInput.update(key)
                }
                return (model, nil)
            }
            
        case .paste(let msg):
            // Pass to appropriate input
            switch model.focusedField {
            case .name:
                model.nameInput = model.nameInput.update(msg)
            case .password:
                model.passwordInput = model.passwordInput.update(msg)
            }
            return (model, nil)
            
        case .switchField:
            model = model.switchField()
            return (model, nil)
        }
    }
    
    private func switchField() -> TextInputModel {
        var model = self
        switch focusedField {
        case .name:
            model.focusedField = .password
            model.nameInput = nameInput.withFocus(false)
            model.passwordInput = passwordInput.withFocus(true)
        case .password:
            model.focusedField = .name
            model.nameInput = nameInput.withFocus(true)
            model.passwordInput = passwordInput.withFocus(false)
        }
        return model
    }
    
    public func view() -> String {
        let title = Style().bold().foreground(.magenta).render("✨ TextInput Example ✨")
        let help = Style().faint().render("Tab: switch fields • Enter: submit • Ctrl+C: quit")
        
        var output = """
        \(title)
        
        \(nameInput.view())
        
        \(passwordInput.view())
        
        \(help)
        """
        
        if submitted {
            let successMsg = Style().foreground(.green).render("✓ Form submitted!")
            let info = Style().foreground(.yellow).render("Name: \(nameInput.value), Password: ***")
            output += "\n\n\(successMsg)\n\(info)"
        }
        
        return output
    }
}

// Main entry point
@main
enum TextInputApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.enableBracketedPaste = true
        
        // Add a filter to convert messages
        options.filter = { _, message in
            switch message {
            case let key as Key:
                switch key.description {
                case "ctrl+c":
                    return QuitMsg()
                default:
                    return TextInputModel.Message.key(key)
                }
            case let paste as PasteMsg:
                return TextInputModel.Message.paste(paste)
            default:
                return message
            }
        }
        
        let program = Program(initialModel: TextInputModel(), options: options)
        _ = try await program.run()
    }
}