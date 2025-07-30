import Foundation
import Matcha

// MARK: - TimerModel

// Timer model that counts seconds
public struct TimerModel: Model {
    var seconds: Int = 0
    var isRunning: Bool = false

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case tick(Date)
        case toggleTimer
        case reset
        case key(KeyMsg)
    }

    public init() {}

    // Start with a timer command
    public func `init`() -> Command<Message>? {
        // Start the timer immediately
        Tick(.seconds(1)) { Message.tick($0) }
    }

    // Update the model based on messages
    public func update(_ message: Message) -> (TimerModel, Command<Message>?) {
        var model = self

        switch message {
        case .tick:
            if model.isRunning {
                model.seconds += 1
                // Continue the timer
                return (model, Tick(.seconds(1)) { Message.tick($0) })
            } else {
                return (model, nil)
            }

        case .toggleTimer:
            model.isRunning.toggle()
            if model.isRunning {
                // Start timer
                return (model, Tick(.seconds(1)) { Message.tick($0) })
            } else {
                // Stop timer
                return (model, nil)
            }

        case .reset:
            model.seconds = 0
            model.isRunning = false
            return (model, nil)

        case let .key(key):
            switch key.description {
            case " ",
                 "space":
                return update(.toggleTimer)
            case "r":
                return update(.reset)
            default:
                return (model, nil)
            }
        }
    }

    // Render the view
    public func view() -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        let timeString = String(format: "%02d:%02d", minutes, secs)
        let status = isRunning ? "⏸  Running" : "▶️  Paused"

        return """
        ╭───────────────────────────╮
        │       Timer Example       │
        ├───────────────────────────┤
        │                           │
        │         \(timeString)            │
        │                           │
        │       \(status)        │
        │                           │
        ├───────────────────────────┤
        │  Space  Start/Stop        │
        │  r      Reset             │
        │  q      Quit              │
        ╰───────────────────────────╯
        """
    }
}

// MARK: - TimerApp

// Main entry point
@main
enum TimerApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Add a filter to intercept quit keys
        options.filter = { _, message in
            if let key = message as? KeyMsg {
                switch key.description {
                case "ctrl+c",
                     "q":
                    return QuitMsg()
                default:
                    return TimerModel.Message.key(key)
                }
            }
            return message
        }

        let program = Program(
            initialModel: TimerModel(),
            options: options
        )

        do {
            _ = try await program.run()
            print("\nTimer stopped. Goodbye! ⏰")
        } catch {
            print("\nError: \(error)")
        }
    }
}
