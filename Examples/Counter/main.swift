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
        case key(Key)
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
        let width = 60
        let border = "─"
        let topBorder = "┌" + String(repeating: border, count: width - 2) + "┐"
        let bottomBorder = "└" + String(repeating: border, count: width - 2) + "┘"
        let divider = "├" + String(repeating: border, count: width - 2) + "┤"
        
        let title = "Counter Example"
        let titlePadding = (width - 2 - title.count) / 2
        let titleLine = "│" + String(repeating: " ", count: titlePadding) + title + String(repeating: " ", count: width - 2 - titlePadding - title.count) + "│"
        
        let countText = "Count: \(count)"
        let countPadding = (width - 2 - countText.count) / 2
        let countLine = "│" + String(repeating: " ", count: countPadding) + countText + String(repeating: " ", count: width - 2 - countPadding - countText.count) + "│"
        
        let emptyLine = "│" + String(repeating: " ", count: width - 2) + "│"
        
        // Controls on single lines
        let controls1 = "↑/+  Increment          ↓/-  Decrement"
        let controls1Padding = (width - 2 - controls1.count) / 2
        let controlsLine1 = "│" + String(repeating: " ", count: controls1Padding) + controls1 + String(repeating: " ", count: width - 2 - controls1Padding - controls1.count) + "│"
        
        let controls2 = "0/r  Reset              q    Quit"
        let controls2Padding = (width - 2 - controls2.count) / 2
        let controlsLine2 = "│" + String(repeating: " ", count: controls2Padding) + controls2 + String(repeating: " ", count: width - 2 - controls2Padding - controls2.count) + "│"
        
        return [
            topBorder,
            titleLine,
            divider,
            emptyLine,
            countLine,
            emptyLine,
            divider,
            controlsLine1,
            controlsLine2,
            bottomBorder
        ].joined(separator: "\n")
    }
}

// Main entry point
@main
enum CounterApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Add a filter to intercept quit keys
        options.filter = { _, message in
            if let key = message as? Key {
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
