//
//  main.swift
//  Counter Example
//
//  A simple counter application demonstrating Matcha basics.
//

import Matcha

// Define our model
public struct CounterModel: Model {
    var count: Int = 0

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case increment
        case decrement
        case reset
        case key(KeyMsg)
    }

    // Initialize with default values
    public init() {}

    // No initial command needed
    public func `init`() -> Command<Message>? {
        nil
    }

    // Update the model based on messages
    public func update(_ message: Message) -> (CounterModel, Command<Message>?) {
        var model = self

        switch message {
        case .increment:
            model.count += 1
            return (model, nil)

        case .decrement:
            model.count -= 1
            return (model, nil)

        case .reset:
            model.count = 0
            return (model, nil)

        case let .key(key):
            // Handle keyboard input
            switch key.description {
            case "up", "+", "=":
                return update(.increment)
            case "down", "-", "_":
                return update(.decrement)
            case "0", "r":
                return update(.reset)
            default:
                // Quit keys are handled by the program filter
                return (model, nil)
            }
        }
    }

    // Render the view
    public func view() -> String {
        // Step 1: Start with the simplest possible box
        var lines: [String] = []
        
        // Step 2: Define consistent width
        let innerWidth = 40
        
        // Step 3: Build top border
        lines.append("┌" + String(repeating: "─", count: innerWidth) + "┐")
        
        // Step 4: Add title
        let title = "Counter Example"
        let titlePadding = (innerWidth - title.count) / 2
        let titleLine = String(repeating: " ", count: titlePadding) + title + String(repeating: " ", count: innerWidth - titlePadding - title.count)
        lines.append("│" + titleLine + "│")
        
        // Step 5: Add divider
        lines.append("├" + String(repeating: "─", count: innerWidth) + "┤")
        
        // Step 6: Add empty line
        lines.append("│" + String(repeating: " ", count: innerWidth) + "│")
        
        // Step 7: Add count
        let countText = "Count: \(count)"
        let countPadding = (innerWidth - countText.count) / 2
        let countLine = String(repeating: " ", count: countPadding) + countText + String(repeating: " ", count: innerWidth - countPadding - countText.count)
        lines.append("│" + countLine + "│")
        
        // Step 8: Add another empty line
        lines.append("│" + String(repeating: " ", count: innerWidth) + "│")
        
        // Step 9: Add second divider
        lines.append("├" + String(repeating: "─", count: innerWidth) + "┤")
        
        // Step 10: Add controls - first row
        let ctrl1 = "↑/+  Increment"
        let ctrl2 = "↓/-  Decrement"
        let spacing1 = innerWidth - ctrl1.count - ctrl2.count - 4 // 4 for padding
        let controlLine1 = "  " + ctrl1 + String(repeating: " ", count: spacing1) + ctrl2 + "  "
        lines.append("│" + controlLine1 + "│")
        
        // Step 11: Add controls - second row
        let ctrl3 = "0/r  Reset"
        let ctrl4 = "q    Quit"
        let spacing2 = innerWidth - ctrl3.count - ctrl4.count - 4 // 4 for padding
        let controlLine2 = "  " + ctrl3 + String(repeating: " ", count: spacing2) + ctrl4 + "  "
        lines.append("│" + controlLine2 + "│")
        
        // Step 12: Add bottom border
        lines.append("└" + String(repeating: "─", count: innerWidth) + "┘")
        
        // Step 13: Join all lines
        return lines.joined(separator: "\n")
    }
}

// Main entry point
@main
enum CounterApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Add a filter to intercept quit keys
        options.filter = { _, message in
            if let key = message as? KeyMsg {
                switch key.description {
                case "q", "ctrl+c":
                    // Convert quit keys to QuitMsg
                    return QuitMsg()
                default:
                    // Convert other keys to model messages
                    return CounterModel.Message.key(key)
                }
            }
            return message
        }

        let program = Program(
            initialModel: CounterModel(),
            options: options
        )

        do {
            _ = try await program.run()
            print("\nGoodbye! 👋")
        } catch {
            print("\nError: \(error)")
        }
    }
}
