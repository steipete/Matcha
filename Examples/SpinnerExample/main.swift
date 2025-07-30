import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - SpinnerModel

// Model that showcases different spinner styles
public struct SpinnerModel: Model {
    var spinners: [Spinner]
    var selectedIndex: Int = 0
    var showAll: Bool = false
    var isLoading: Bool = true
    var loadingText: String = "Loading..."

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(KeyMsg)
        case spinnerTick(SpinnerTickMsg)
        case loadComplete
        case toggleShowAll
    }

    public init() {
        // Create one spinner for each style
        self.spinners = Spinner.Style.allCases.map { style in
            var spinner = Spinner(style: style)
            spinner.text = style.rawValue.capitalized
            spinner.spinnerStyle = Style().foreground(.blue)
            spinner.textStyle = Style().foreground(Color(240))
            return spinner
        }
    }

    public func `init`() -> Command<Message>? {
        // Start the selected spinner
        var initialModel = self
        initialModel.spinners[initialModel.selectedIndex].start()

        // Start spinner animation and schedule load completion
        let tickCmd: Command<Message> = initialModel.spinners[0].tick()
        let completeCmd: Command<Message> = Tick(.seconds(5)) { _ in Message.loadComplete }
        return Matcha.batch([tickCmd, completeCmd])
    }

    public func update(_ message: Message) -> (SpinnerModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.type {
            case .up:
                if model.selectedIndex > 0 {
                    model.selectedIndex -= 1
                }
                return (model, nil)

            case .down:
                if model.selectedIndex < model.spinners.count - 1 {
                    model.selectedIndex += 1
                }
                return (model, nil)

            default:
                switch key.description {
                case " ",
                     "space":
                    return update(.toggleShowAll)
                default:
                    return (model, nil)
                }
            }

        case let .spinnerTick(msg):
            // Update all active spinners
            var commands: [Command<Message>] = []

            if model.showAll {
                for i in 0..<model.spinners.count {
                    let cmd: Command<Message>? = model.spinners[i].update(msg: msg)
                    if let cmd {
                        commands.append(cmd)
                    }
                }
            } else {
                let cmd: Command<Message>? = model.spinners[model.selectedIndex].update(msg: msg)
                if let cmd {
                    commands.append(cmd)
                }
            }

            return (model, commands.isEmpty ? nil : Matcha.batch(commands))

        case .toggleShowAll:
            model.showAll.toggle()

            // Start or stop spinners based on mode
            if model.showAll {
                // Start all spinners
                for i in 0..<model.spinners.count {
                    model.spinners[i].start()
                }
            } else {
                // Stop all and start only selected
                for i in 0..<model.spinners.count {
                    if i == model.selectedIndex {
                        model.spinners[i].start()
                    } else {
                        model.spinners[i].stop()
                    }
                }
            }

            // Return initial tick command
            if model.showAll || model.selectedIndex < model.spinners.count {
                let tickCmd: Command<Message> = model.spinners[0].tick()
                return (model, tickCmd)
            }
            return (model, nil)

        case .loadComplete:
            model.isLoading = false
            return (model, nil)
        }
    }

    public func view() -> String {
        var lines: [String] = []
        let style = Style()

        // Title
        lines.append(style.bold().render("Spinner Gallery"))
        lines.append("")

        // Instructions
        lines.append("↑/↓: Select spinner • Space: Toggle show all • q: Quit")
        lines.append("")

        if showAll {
            // Show all spinners
            lines.append(style.foreground(.green).render("Showing all spinners:"))
            lines.append("")

            for spinner in spinners {
                lines.append("  \(spinner.view())")
            }
        } else {
            // Show spinner selection list
            lines.append("Select a spinner style:")
            lines.append("")

            for (index, spinner) in spinners.enumerated() {
                let cursor = index == selectedIndex ? "→" : " "
                let styleName = spinner.style.rawValue.capitalized
                let isActive = index == selectedIndex

                var line = "\(cursor) \(styleName)"
                if isActive {
                    line += " \(spinner.view())"
                }

                if index == selectedIndex {
                    line = style.foreground(.cyan).render(line)
                }

                lines.append(line)
            }
        }

        // Loading demo
        if isLoading {
            lines.append("")
            lines.append("")
            var loadingSpinner = Spinner(style: .dots)
            loadingSpinner.text = loadingText
            loadingSpinner.spinnerStyle = Style().foreground(.yellow)
            loadingSpinner.textStyle = Style().faint()
            loadingSpinner.start()
            loadingSpinner.frameIndex = spinners[0].frameIndex // Sync with main spinner
            lines.append(loadingSpinner.view())
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - SpinnerApp

// Main entry point
@main
enum SpinnerApp {
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
                    SpinnerModel.Message.key(key)
                }
            case let tick as SpinnerTickMsg:
                SpinnerModel.Message.spinnerTick(tick)
            default:
                message
            }
        }

        let program = Program(initialModel: SpinnerModel(), options: options)
        _ = try await program.run()
    }
}
