import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - SplitPanesModel

/// Split panes app with vertical and horizontal splits
struct SplitPanesModel: Model {
    typealias Msg = Message

    enum Message: Matcha.Message {
        case windowSize(width: Int, height: Int)
        case focusPane(Pane)
        case resizePanes(direction: ResizeDirection)
        case switchLayout
        case quit
    }

    enum Pane {
        case left
        case right
        case top
        case bottom
    }

    enum Layout {
        case vertical // Left | Right
        case horizontal // Top / Bottom
    }

    enum ResizeDirection {
        case left
        case right
        case up
        case down
    }

    var width: Int = 80
    var height: Int = 24
    var layout: Layout = .vertical
    var splitPosition: Int = 40 // Percentage
    var focusedPane: Pane = .left

    // Content for each pane
    var leftContent: [String] = [
        "Left/Top Pane",
        "─────────────",
        "• Press Tab to switch focus",
        "• Press h/l to resize vertical split",
        "• Press j/k to resize horizontal split",
        "• Press s to switch layout",
        "",
        "This pane demonstrates how to create",
        "split pane layouts in terminal UIs.",
        "",
        "Each pane can contain independent",
        "content and maintain its own state."
    ]

    var rightContent: [String] = [
        "Right/Bottom Pane",
        "─────────────────",
        "• Active pane has cyan border",
        "• Inactive panes have gray border",
        "",
        "In a real application, each pane",
        "could be a separate component with",
        "its own model and update logic.",
        "",
        "For example:",
        "• File browser | Editor",
        "• Code | Terminal",
        "• List | Details"
    ]

    func `init`() -> Command<Message>? {
        nil
    }

    func update(_ message: Message) -> (SplitPanesModel, Command<Message>?) {
        var model = self

        switch message {
        case let .windowSize(width, height):
            model.width = width
            model.height = height
            return (model, nil)

        case let .focusPane(pane):
            model.focusedPane = pane
            return (model, nil)

        case let .resizePanes(direction):
            switch direction {
            case .left:
                model.splitPosition = max(20, model.splitPosition - 5)
            case .right:
                model.splitPosition = min(80, model.splitPosition + 5)
            case .up:
                model.splitPosition = max(20, model.splitPosition - 5)
            case .down:
                model.splitPosition = min(80, model.splitPosition + 5)
            }
            return (model, nil)

        case .switchLayout:
            model.layout = model.layout == .vertical ? .horizontal : .vertical
            model.focusedPane = model.layout == .vertical ? .left : .top
            return (model, nil)

        case .quit:
            return (model, quit())
        }
    }

    func view() -> String {
        switch layout {
        case .vertical:
            renderVerticalSplit()
        case .horizontal:
            renderHorizontalSplit()
        }
    }

    private func renderVerticalSplit() -> String {
        var lines: [String] = []

        let leftWidth = (width * splitPosition) / 100
        let rightWidth = width - leftWidth - 1 // -1 for divider

        let leftBorderStyle = focusedPane == .left
            ? Style().foreground(.cyan)
            : Style().foreground(.brightBlack)
        let rightBorderStyle = focusedPane == .right
            ? Style().foreground(.cyan)
            : Style().foreground(.brightBlack)
        let dividerStyle = Style().foreground(.brightBlack)

        // Top border
        var topLine = leftBorderStyle.render("┌" + String(repeating: "─", count: leftWidth - 2) + "┐")
        topLine += dividerStyle.render("┬")
        topLine += rightBorderStyle.render("┌" + String(repeating: "─", count: rightWidth - 2) + "┐")
        lines.append(topLine)

        // Content area
        for row in 0..<(height - 2) {
            var line = ""

            // Left pane
            line += leftBorderStyle.render("│")
            let leftText = row < leftContent.count ? leftContent[row] : ""
            line += leftText.padding(toLength: leftWidth - 2, withPad: " ", startingAt: 0)
            line += leftBorderStyle.render("│")

            // Divider
            line += dividerStyle.render("│")

            // Right pane
            line += rightBorderStyle.render("│")
            let rightText = row < rightContent.count ? rightContent[row] : ""
            line += rightText.padding(toLength: rightWidth - 2, withPad: " ", startingAt: 0)
            line += rightBorderStyle.render("│")

            lines.append(line)
        }

        // Bottom border
        var bottomLine = leftBorderStyle.render("└" + String(repeating: "─", count: leftWidth - 2) + "┘")
        bottomLine += dividerStyle.render("┴")
        bottomLine += rightBorderStyle.render("└" + String(repeating: "─", count: rightWidth - 2) + "┘")
        lines.append(bottomLine)

        return lines.joined(separator: "\n")
    }

    private func renderHorizontalSplit() -> String {
        var lines: [String] = []

        let topHeight = (height * splitPosition) / 100
        let bottomHeight = height - topHeight - 1 // -1 for divider

        let topBorderStyle = focusedPane == .top
            ? Style().foreground(.cyan)
            : Style().foreground(.brightBlack)
        let bottomBorderStyle = focusedPane == .bottom
            ? Style().foreground(.cyan)
            : Style().foreground(.brightBlack)
        let dividerStyle = Style().foreground(.brightBlack)

        // Top pane
        lines.append(topBorderStyle.render("┌" + String(repeating: "─", count: width - 2) + "┐"))

        for row in 0..<(topHeight - 2) {
            var line = topBorderStyle.render("│")
            let text = row < leftContent.count ? leftContent[row] : ""
            line += text.padding(toLength: width - 2, withPad: " ", startingAt: 0)
            line += topBorderStyle.render("│")
            lines.append(line)
        }

        lines.append(topBorderStyle.render("└" + String(repeating: "─", count: width - 2) + "┘"))

        // Divider
        lines.append(dividerStyle.render(String(repeating: "─", count: width)))

        // Bottom pane
        lines.append(bottomBorderStyle.render("┌" + String(repeating: "─", count: width - 2) + "┐"))

        for row in 0..<(bottomHeight - 2) {
            var line = bottomBorderStyle.render("│")
            let text = row < rightContent.count ? rightContent[row] : ""
            line += text.padding(toLength: width - 2, withPad: " ", startingAt: 0)
            line += bottomBorderStyle.render("│")
            lines.append(line)
        }

        lines.append(bottomBorderStyle.render("└" + String(repeating: "─", count: width - 2) + "┘"))

        return lines.joined(separator: "\n")
    }
}

// MARK: - SplitPanesApp

@main
struct SplitPanesApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        options.filter = { _, message in
            if let key = message as? KeyMsg {
                switch key.description {
                case "ctrl+c",
                     "q":
                    return QuitMsg()
                case "tab":
                    return SplitPanesModel.Message.focusPane(.left) // Simplified - will cycle in update
                case "h":
                    return SplitPanesModel.Message.resizePanes(direction: .left)
                case "l":
                    return SplitPanesModel.Message.resizePanes(direction: .right)
                case "j":
                    return SplitPanesModel.Message.resizePanes(direction: .down)
                case "k":
                    return SplitPanesModel.Message.resizePanes(direction: .up)
                case "s":
                    return SplitPanesModel.Message.switchLayout
                default:
                    break
                }
            } else if let winMsg = message as? WindowSizeMsg {
                return SplitPanesModel.Message.windowSize(width: winMsg.width, height: winMsg.height)
            }
            return message
        }

        let program = Program(
            initialModel: SplitPanesModel(),
            options: options
        )

        try await program.run()
    }
}
