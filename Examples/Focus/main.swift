import Matcha

// MARK: - FocusModel

// Model that tracks focus state
public struct FocusModel: Model {
    var hasFocus: Bool = true
    var focusChanges: Int = 0

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case gainedFocus
        case lostFocus
        case key(KeyMsg)
    }

    public init() {}

    // Enable focus reporting when starting
    public func `init`() -> Command<Message>? {
        enableReportFocus()
    }

    // Update the model based on messages
    public func update(_ message: Message) -> (FocusModel, Command<Message>?) {
        var model = self

        switch message {
        case .gainedFocus:
            model.hasFocus = true
            model.focusChanges += 1
            return (model, nil)

        case .lostFocus:
            model.hasFocus = false
            model.focusChanges += 1
            return (model, nil)

        case .key:
            // Quit keys are handled by the program filter
            return (model, nil)
        }
    }

    // Render the view
    public func view() -> String {
        let focusIndicator = hasFocus ? "✅" : "❌"
        let focusText = hasFocus ? "HAS FOCUS" : "NO FOCUS"
        let focusColor = hasFocus ? "\u{1B}[32m" : "\u{1B}[31m" // Green or Red
        let reset = "\u{1B}[0m"

        return """
        ╭─────────────────────────────────────╮
        │        Focus Event Example          │
        ├─────────────────────────────────────┤
        │                                     │
        │   Window Focus: \(focusIndicator) \(focusColor)\(focusText)\(reset)   │
        │                                     │
        │   Focus Changes: \(focusChanges)                  │
        │                                     │
        ├─────────────────────────────────────┤
        │  Click outside this window to       │
        │  lose focus, click back to regain   │
        │                                     │
        │  Press 'q' to quit                  │
        ╰─────────────────────────────────────╯
        """
    }
}

// MARK: - FocusApp

// Main entry point
@main
enum FocusApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.reportFocus = true // Enable focus reporting

        // Add a filter to intercept messages
        options.filter = { _, message in
            switch message {
            case is FocusMsg:
                FocusModel.Message.gainedFocus
            case is BlurMsg:
                FocusModel.Message.lostFocus
            case let key as KeyMsg:
                switch key.description {
                case "ctrl+c",
                     "q":
                    QuitMsg()
                default:
                    FocusModel.Message.key(key)
                }
            default:
                message
            }
        }

        let program = Program(initialModel: FocusModel(), options: options)
        _ = try await program.run()
    }
}
