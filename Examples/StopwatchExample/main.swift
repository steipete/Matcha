import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - StopwatchModel

// Model that uses Stopwatch component
public struct StopwatchModel: Model {
    var mainStopwatch = Stopwatch()
    var lapStopwatch = Stopwatch()
    var laps: [TimeInterval] = []
    var showHelp: Bool = false

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(KeyMsg)
        case stopwatchTick(StopwatchTickMsg)
        case addLap
        case toggleHelp
    }

    public init() {}

    public func `init`() -> Command<Message>? {
        nil
    }

    public func update(_ message: Message) -> (StopwatchModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.description {
            case " ",
                 "space":
                // Start/stop main stopwatch
                model.mainStopwatch.toggle()

                // If starting, also start/restart lap stopwatch
                if model.mainStopwatch.isRunning {
                    if !model.lapStopwatch.isRunning {
                        model.lapStopwatch.start()
                    }
                    let mainCmd: Command<Message> = model.mainStopwatch.tick()
                    let lapCmd: Command<Message> = model.lapStopwatch.tick()
                    return (model, Matcha.batch([mainCmd, lapCmd]))
                } else {
                    // Pausing everything
                    model.lapStopwatch.pause()
                    return (model, nil)
                }

            case "l":
                // Add lap time if running
                if model.mainStopwatch.isRunning {
                    return update(.addLap)
                }
                return (model, nil)

            case "r":
                // Reset everything
                model.mainStopwatch.reset()
                model.lapStopwatch.reset()
                model.laps.removeAll()
                return (model, nil)

            case "?",
                 "h":
                return update(.toggleHelp)

            default:
                return (model, nil)
            }

        case let .stopwatchTick(msg):
            var commands: [Command<Message>] = []

            let mainCmd: Command<Message>? = model.mainStopwatch.update(msg: msg)
            if let cmd = mainCmd {
                commands.append(cmd)
            }
            let lapCmd: Command<Message>? = model.lapStopwatch.update(msg: msg)
            if let cmd = lapCmd {
                commands.append(cmd)
            }

            return (model, commands.isEmpty ? nil : Matcha.batch(commands))

        case .addLap:
            // Record lap time and reset lap stopwatch
            model.laps.append(model.lapStopwatch.elapsed)
            model.lapStopwatch.reset()
            model.lapStopwatch.start()
            let tickCmd: Command<Message> = model.lapStopwatch.tick()
            return (model, tickCmd)

        case .toggleHelp:
            model.showHelp.toggle()
            return (model, nil)
        }
    }

    public func view() -> String {
        var lines: [String] = []
        let style = Style()

        // Title
        lines.append(style.bold().render("⏱  Stopwatch"))
        lines.append("")

        // Main stopwatch display
        let mainTime = mainStopwatch.format()
        let mainDisplay = style.bold().foreground(mainStopwatch.isRunning ? .green : .yellow).render(mainTime)
        lines.append("Total: \(mainDisplay)")

        // Lap stopwatch display
        if mainStopwatch.isRunning || lapStopwatch.elapsed > 0 {
            let lapTime = lapStopwatch.format()
            let lapDisplay = style.foreground(.cyan).render(lapTime)
            lines.append("Lap:   \(lapDisplay)")
        }

        lines.append("")

        // Status
        let status = mainStopwatch.isRunning ? "▶ Running" : "⏸ Paused"
        lines.append(style.foreground(mainStopwatch.isRunning ? .green : Color(240)).render(status))
        lines.append("")

        // Laps
        if !laps.isEmpty {
            lines.append(style.underline().render("Laps:"))
            for (index, lapTime) in laps.enumerated().reversed() {
                let lapNumber = laps.count - index
                let formattedTime = formatTimeInterval(lapTime)
                lines.append(String(format: "  Lap %2d: %@", lapNumber, formattedTime))
            }
            lines.append("")
        }

        // Help
        if showHelp {
            lines.append(style.foreground(Color(240)).render("Controls:"))
            lines.append(style.foreground(Color(240)).render("  Space - Start/Stop"))
            lines.append(style.foreground(Color(240)).render("  l     - Lap (while running)"))
            lines.append(style.foreground(Color(240)).render("  r     - Reset"))
            lines.append(style.foreground(Color(240)).render("  ?/h   - Toggle help"))
            lines.append(style.foreground(Color(240)).render("  q     - Quit"))
        } else {
            lines.append(style.faint().render("Press ? for help"))
        }

        return lines.joined(separator: "\n")
    }
}

// Helper function to format time interval
func formatTimeInterval(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)

    if hours > 0 {
        return String(format: "%02d:%02d:%02d.%d", hours, minutes, seconds, milliseconds)
    } else {
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - StopwatchApp

// Main entry point
@main
enum StopwatchApp {
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
                    StopwatchModel.Message.key(key)
                }
            case let tick as StopwatchTickMsg:
                StopwatchModel.Message.stopwatchTick(tick)
            default:
                message
            }
        }

        let program = Program(initialModel: StopwatchModel(), options: options)
        _ = try await program.run()
    }
}
