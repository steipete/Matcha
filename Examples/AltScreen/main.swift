//
//  main.swift
//  Alt Screen Example
//
//  Demonstrates alternate screen buffer usage in Matcha.
//

import Foundation
import Matcha

// Model that demonstrates alternate screen functionality
public struct AltScreenModel: Model {
    var isAltScreen: Bool = false
    var counter: Int = 0

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case toggleScreen
        case increment
        case key(Key)
    }

    public init() {}

    // Start in normal screen
    public func `init`() -> Command<Message>? {
        nil
    }

    // Update the model based on messages
    public func update(_ message: Message) -> (AltScreenModel, Command<Message>?) {
        var model = self

        switch message {
        case .toggleScreen:
            model.isAltScreen.toggle()
            if model.isAltScreen {
                // Enter alt screen and hide cursor
                return (model, .batch(
                    enterAltScreen(),
                    hideCursor(),
                    setWindowTitle("Alt Screen Demo - Alternate Buffer")
                ))
            } else {
                // Exit alt screen and show cursor
                return (model, .batch(
                    exitAltScreen(),
                    showCursor(),
                    setWindowTitle("Alt Screen Demo - Normal Buffer")
                ))
            }

        case .increment:
            model.counter += 1
            return (model, nil)

        case let .key(key):
            switch key.description {
            case "a", " ", "space":
                return update(.toggleScreen)
            case "i", "+":
                return update(.increment)
            case "c":
                // Clear screen command
                return (model, clearScreen())
            default:
                return (model, nil)
            }
        }
    }

    // Render the view
    public func view() -> String {
        if isAltScreen {
            // Alt screen view
            """
            ╔══════════════════════════════════════╗
            ║     ALTERNATE SCREEN BUFFER          ║
            ╠══════════════════════════════════════╣
            ║                                      ║
            ║  This is the alternate screen!       ║
            ║                                      ║
            ║  Counter: \(String(format: "%03d", counter))                       ║
            ║                                      ║
            ║  Your terminal's main buffer is      ║
            ║  preserved and will be restored      ║
            ║  when you switch back.               ║
            ║                                      ║
            ╠══════════════════════════════════════╣
            ║  Space/a  Switch to normal screen    ║
            ║  i/+      Increment counter          ║
            ║  c        Clear screen               ║
            ║  q        Quit                       ║
            ╚══════════════════════════════════════╝
            """
        } else {
            // Normal screen view
            """
            ┌──────────────────────────────────────┐
            │       NORMAL SCREEN BUFFER           │
            ├──────────────────────────────────────┤
            │                                      │
            │  This is the normal screen buffer.   │
            │                                      │
            │  Counter: \(String(format: "%03d", counter))                       │
            │                                      │
            │  Press Space to switch to the        │
            │  alternate screen buffer. Your       │
            │  terminal history will be preserved! │
            │                                      │
            ├──────────────────────────────────────┤
            │  Space/a  Switch to alt screen       │
            │  i/+      Increment counter          │
            │  c        Clear screen               │
            │  q        Quit                       │
            └──────────────────────────────────────┘
            """
        }
    }
}

// Main entry point
@main
enum AltScreenApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Add a filter to intercept quit keys
        options.filter = { _, message in
            if let key = message as? Key {
                switch key.description {
                case "q", "ctrl+c":
                    return QuitMsg()
                default:
                    return AltScreenModel.Message.key(key)
                }
            }
            return message
        }

        let program = Program(
            initialModel: AltScreenModel(),
            options: options
        )

        // Set initial window title
        program.send(SetWindowTitleMsg(title: "Alt Screen Demo - Normal Buffer"))

        do {
            _ = try await program.run()
            print("\nExited alt screen demo. Notice your terminal history is preserved! 📺")
        } catch {
            print("\nError: \(error)")
        }
    }
}
