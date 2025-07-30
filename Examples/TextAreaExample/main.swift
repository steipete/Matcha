//
//  TextAreaExample.swift
//  Matcha
//
//  Demonstrates the TextArea component for multi-line text input.
//

import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

struct TextAreaModel: Model {
    var textArea: TextArea
    var submitted: Bool = false
    var submittedText: String = ""
    
    enum Message: Matcha.Message {
        case key(Key)
        case paste(PasteMsg)
        case submit
        case quit
    }
    
    init() {
        self.textArea = TextArea()
            .withDimensions(width: 60, height: 15)
            .withPlaceholder("Enter your text here...\nSupports multiple lines!")
            .withPrompt("✏️  Text Editor: ")
            .promptStyle(Style().bold().foreground(.brightBlue))
            .withLineNumbers(true)
            .withFocus(true)
            .withTabSize(4)
            .focusedBorderStyle(Style().foreground(.brightCyan))
            .unfocusedBorderStyle(Style().foreground(Color(240)))
    }
    
    func `init`() -> Command<Message>? {
        nil
    }
    
    func update(_ message: Message) -> (TextAreaModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key.description {
            case "ctrl+c", "q":
                return (model, quit())
            case "ctrl+s":
                model.submitted = true
                model.submittedText = model.textArea.value
                model.textArea = model.textArea.withFocus(false)
            default:
                if !model.submitted {
                    model.textArea = model.textArea.update(key)
                } else if key.description == "enter" {
                    // Reset to edit mode
                    model.submitted = false
                    model.textArea = model.textArea.withFocus(true)
                }
            }
            
        case .paste(let msg):
            if !model.submitted {
                model.textArea = model.textArea.update(msg)
            }
            
        case .submit:
            model.submitted = true
            model.submittedText = model.textArea.value
            model.textArea = model.textArea.withFocus(false)
            
        case .quit:
            return (model, quit())
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        var view = ""
        
        // Title
        view += Style().bold().foreground(.brightMagenta).render("📝 TextArea Component Demo") + "\n\n"
        
        // TextArea
        view += textArea.view() + "\n\n"
        
        // Status and controls
        if submitted {
            view += Style().bold().foreground(.brightGreen).render("✅ Text Submitted!") + "\n\n"
            
            view += Style().bold().render("Submitted Content:") + "\n"
            view += Style().foreground(.brightYellow).render("─────────────────") + "\n"
            
            let lines = submittedText.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let lineNum = Style().foreground(Color(240)).render(String(format: "%3d │ ", index + 1))
                view += lineNum + Style().foreground(.white).render(String(line)) + "\n"
            }
            
            view += Style().foreground(.brightYellow).render("─────────────────") + "\n\n"
            
            view += Style().foreground(Color(240)).render("Press ") +
                    Style().bold().render("Enter") +
                    Style().foreground(Color(240)).render(" to edit again")
        } else {
            // Show current stats
            let lines = textArea.lines.count
            let chars = textArea.value.count
            let currentLine = textArea.cursorLine + 1
            let currentCol = textArea.cursorColumn + 1
            
            view += Style().foreground(Color(240)).render("Lines: ") + 
                    Style().bold().render("\(lines)") +
                    Style().foreground(Color(240)).render("  Characters: ") +
                    Style().bold().render("\(chars)") +
                    Style().foreground(Color(240)).render("  Position: ") +
                    Style().bold().render("\(currentLine):\(currentCol)") + "\n\n"
            
            // Controls
            view += Style().bold().render("Controls:") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Ctrl+S") +
                    Style().foreground(Color(240)).render(" - Submit text") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Ctrl+K") +
                    Style().foreground(Color(240)).render(" - Delete to end of line") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Ctrl+U") +
                    Style().foreground(Color(240)).render(" - Delete to start of line") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Ctrl+W") +
                    Style().foreground(Color(240)).render(" - Delete word backward") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Tab") +
                    Style().foreground(Color(240)).render(" - Insert 4 spaces") + "\n"
            view += Style().foreground(Color(240)).render("• ") +
                    Style().bold().render("Ctrl+C") +
                    Style().foreground(Color(240)).render(" or ") +
                    Style().bold().render("Q") +
                    Style().foreground(Color(240)).render(" - Quit")
        }
        
        return view
    }
}

@main
struct TextAreaExampleApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        options.mouseMode = .allMotion
        options.reportFocus = true
        
        let program = Program(
            initialModel: TextAreaModel(),
            options: options
        )
        _ = try await program.run()
    }
}