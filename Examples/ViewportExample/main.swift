import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - ViewportModel

public struct ViewportModel: Model {
    var viewport: Viewport
    var content: String

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(KeyMsg)
    }

    public init() {
        // Create viewport
        self.viewport = Viewport(width: 60, height: 10)

        // Generate content
        var lines: [String] = []
        lines.append("Welcome to the Viewport Example!")
        lines.append("")
        lines.append("This is a scrollable area that can display content")
        lines.append("larger than the visible window.")
        lines.append("")

        // Add some Lorem Ipsum
        let lorem = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris
        nisi ut aliquip ex ea commodo consequat.

        Duis aute irure dolor in reprehenderit in voluptate velit esse
        cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
        cupidatat non proident, sunt in culpa qui officia deserunt mollit
        anim id est laborum.

        Sed ut perspiciatis unde omnis iste natus error sit voluptatem
        accusantium doloremque laudantium, totam rem aperiam, eaque ipsa
        quae ab illo inventore veritatis et quasi architecto beatae vitae
        dicta sunt explicabo.
        """

        lines.append(contentsOf: lorem.split(separator: "\n").map(String.init))
        lines.append("")

        // Add numbered lines
        for i in 1...30 {
            lines.append("Line \(i): This is line number \(i) of the content")
        }

        self.content = lines.joined(separator: "\n")
        viewport.setContent(content)
    }

    public func `init`() -> Command<Message>? {
        nil
    }

    public func update(_ message: Message) -> (ViewportModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.type {
            case .up:
                model.viewport.lineUp()

            case .down:
                model.viewport.lineDown()

            case .pageUp:
                model.viewport.halfPageUp()

            case .pageDown:
                model.viewport.halfPageDown()

            case .home:
                model.viewport.gotoTop()

            case .end:
                model.viewport.gotoBottom()

            default:
                switch key.description {
                case "k":
                    model.viewport.lineUp()
                case "j":
                    model.viewport.lineDown()
                case "b":
                    model.viewport.halfPageUp()
                case "f":
                    model.viewport.halfPageDown()
                case "g":
                    model.viewport.gotoTop()
                case "G":
                    model.viewport.gotoBottom()
                case "h":
                    // Toggle high performance rendering
                    model.viewport.highPerformanceRendering.toggle()
                case "+":
                    // Increase height
                    if model.viewport.height < 20 {
                        model.viewport.height += 1
                    }
                case "-":
                    // Decrease height
                    if model.viewport.height > 5 {
                        model.viewport.height -= 1
                    }
                default:
                    break
                }
            }
        }

        return (model, nil)
    }

    public func view() -> String {
        var lines: [String] = []
        let style = Style()

        // Title
        lines.append(style.bold().render("Viewport Example"))
        lines.append("")

        // Info bar
        let scrollPercent = viewport.scrollPercent
        let scrollInfo = String(format: "%.0f%%", scrollPercent * 100)
        let perfMode = viewport.highPerformanceRendering ? "High Perf" : "Normal"

        lines
            .append(style.foreground(.cyan)
                .render("Position: \(scrollInfo) | Mode: \(perfMode) | Height: \(viewport.height)")
            )
        lines.append("")

        // Viewport with border
        let viewportContent = viewport.view()
        let viewportLines = viewportContent.split(separator: "\n").map(String.init)

        // Add top border
        lines.append("┌" + String(repeating: "─", count: viewport.width) + "┐")

        // Add viewport content with side borders
        for line in viewportLines {
            let paddedLine = line.padding(toLength: viewport.width, withPad: " ", startingAt: 0)
            lines.append("│\(paddedLine)│")
        }

        // Add bottom border
        lines.append("└" + String(repeating: "─", count: viewport.width) + "┘")

        lines.append("")

        // Controls
        lines.append(style.faint().render("Navigation:"))
        lines.append(style.faint().render("  ↑/k       - Scroll up"))
        lines.append(style.faint().render("  ↓/j       - Scroll down"))
        lines.append(style.faint().render("  PgUp/b    - Half page up"))
        lines.append(style.faint().render("  PgDn/f    - Half page down"))
        lines.append(style.faint().render("  Home/g    - Go to top"))
        lines.append(style.faint().render("  End/G     - Go to bottom"))
        lines.append(style.faint().render("  h         - Toggle high performance"))
        lines.append(style.faint().render("  +/-       - Adjust viewport height"))
        lines.append(style.faint().render("  q         - Quit"))

        return lines.joined(separator: "\n")
    }
}

// MARK: - ViewportApp

@main
enum ViewportApp {
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
                    ViewportModel.Message.key(key)
                }
            default:
                message
            }
        }

        let program = Program(initialModel: ViewportModel(), options: options)
        _ = try await program.run()
    }
}
