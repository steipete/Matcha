import Foundation
import Matcha
import MatchaStyle

// MARK: - FullScreenModel

/// A full screen app that fills the terminal with content
struct FullScreenModel: Model {
    typealias Msg = Message

    enum Message: Matcha.Message {
        case windowSize(width: Int, height: Int)
        case tick
        case quit
    }

    var width: Int = 80
    var height: Int = 24
    var ticks: Int = 0

    func `init`() -> Command<Message>? {
        every(.seconds(1)) { _ in .tick }
    }

    func update(_ message: Message) -> (FullScreenModel, Command<Message>?) {
        var model = self

        switch message {
        case let .windowSize(width, height):
            model.width = width
            model.height = height
            return (model, nil)

        case .tick:
            model.ticks += 1
            return (model, every(.seconds(1)) { _ in .tick })

        case .quit:
            return (model, quit())
        }
    }

    func view() -> String {
        var content = ""

        // Header
        let header = "Full Screen Example - Terminal Size: \(width)x\(height) - Ticks: \(ticks)"
        let headerStyle = Style()
            .background(.blue)
            .foreground(.white)
            .bold()
        content += headerStyle.render(header.padding(toLength: width, withPad: " ", startingAt: 0))
        content += "\n"

        // Main content area with border
        let contentHeight = height - 4 // Header + footer + borders
        let borderStyle = Style().foreground(.cyan)

        // Top border
        content += borderStyle.render("┌" + String(repeating: "─", count: width - 2) + "┐")
        content += "\n"

        // Content with side borders
        for row in 0..<contentHeight {
            content += borderStyle.render("│")

            // Create some visual pattern
            let y = row
            var line = ""
            for x in 0..<(width - 2) {
                let char = if (x + y + ticks) % 10 == 0 {
                    "◆"
                } else if (x + y + ticks) % 5 == 0 {
                    "•"
                } else {
                    " "
                }
                line += char
            }

            // Apply gradient-like coloring
            let intensity = Double(row) / Double(contentHeight)
            let color: Color = if intensity < 0.33 {
                .green
            } else if intensity < 0.66 {
                .yellow
            } else {
                .red
            }

            content += Style().foreground(color).render(line)
            content += borderStyle.render("│")
            content += "\n"
        }

        // Bottom border
        content += borderStyle.render("└" + String(repeating: "─", count: width - 2) + "┘")
        content += "\n"

        // Footer
        let footer = "Press 'q' to quit | Arrow keys to explore (in a real app)"
        let footerStyle = Style()
            .background(.brightBlack)
            .foreground(.white)
        content += footerStyle.render(footer.padding(toLength: width, withPad: " ", startingAt: 0))

        return content
    }
}

// MARK: - FullScreenApp

@main
struct FullScreenApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        options.mouseMode = .disabled
        options.filter = { _, message in
            if let key = message as? KeyMsg {
                switch key.description {
                case "ctrl+c",
                     "q":
                    return QuitMsg()
                default:
                    break
                }
            } else if let winMsg = message as? WindowSizeMsg {
                return FullScreenModel.Message.windowSize(width: winMsg.width, height: winMsg.height)
            }
            return message
        }

        let program = Program(
            initialModel: FullScreenModel(),
            options: options
        )

        try await program.run()
    }
}
