import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - TabsModel

struct TabsModel: Model {
    var tabs: Tabs
    var tabContent: [String]
    var equalWidth: Bool = false
    var showUnderline: Bool = true

    enum Message: Matcha.Message {
        case key(KeyMsg)
        case selectTab(Int)
        case toggleEqualWidth
        case toggleUnderline
        case quit
    }

    init() {
        let tabItems = ["Overview", "Files", "Settings", "Help", "About"]

        self.tabs = Tabs(items: tabItems)
            .withFocus(true)
            .withPadding(2)
            .normalStyle(Style().foreground(Color(240)))
            .selectedStyle(Style().bold().foreground(.black).background(.brightCyan))
            .separatorStyle(Style().foreground(Color(236)))
            .underlineStyle(Style().foreground(.brightCyan))

        self.tabContent = [
            """
            📊 Overview Tab

            Welcome to the Tabs component demo! This shows how to create
            horizontal tab navigation in your TUI applications.

            Features:
            • Keyboard navigation (arrow keys or h/l)
            • Number key shortcuts (1-5)
            • Customizable styles
            • Optional equal-width tabs
            • Underline indicator
            """,

            """
            📁 Files Tab

            File listing would go here...

            Documents/
            ├── report.txt
            ├── data.csv
            └── notes.md

            Downloads/
            ├── image.png
            └── archive.zip
            """,

            """
            ⚙️  Settings Tab

            Application Settings:

            [x] Enable notifications
            [x] Auto-save documents
            [ ] Dark mode
            [x] Show line numbers
            [ ] Word wrap

            Language: English
            Theme: Default
            """,

            """
            ❓ Help Tab

            Keyboard Shortcuts:

            Navigation:
            • ← / → or h/l - Switch tabs
            • Home / Ctrl+A - Go to first tab
            • End / Ctrl+E - Go to last tab
            • 1-5 - Jump to specific tab

            Options:
            • e - Toggle equal width
            • u - Toggle underline
            • q - Quit
            """,

            """
            ℹ️  About Tab

            Tabs Component v1.0

            A flexible tab navigation component for Matcha TUI applications.

            Part of the MatchaBubbles component library.

            Created with 🍵 and Swift
            """,
        ]
    }

    func `init`() -> Command<Message>? {
        nil
    }

    func update(_ message: Message) -> (TabsModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.description {
            case "ctrl+c",
                 "q":
                return (model, quit())
            case "e":
                return model.update(.toggleEqualWidth)
            case "u":
                return model.update(.toggleUnderline)
            default:
                model.tabs = model.tabs.update(key)
            }

        case let .selectTab(index):
            model.tabs = model.tabs.withSelectedIndex(index)

        case .toggleEqualWidth:
            model.equalWidth.toggle()
            model.tabs = model.tabs.withEqualWidth(model.equalWidth)

        case .toggleUnderline:
            model.showUnderline.toggle()
            model.tabs = model.tabs.withUnderline(model.showUnderline)

        case .quit:
            return (model, quit())
        }

        return (model, nil)
    }

    func view() -> String {
        var view = ""

        // Title
        view += Style().bold().foreground(.brightMagenta).render("📑 Tabs Component Demo") + "\n\n"

        // Tabs
        view += tabs.view() + "\n\n"

        // Tab content
        if tabs.selectedIndex < tabContent.count {
            let content = tabContent[tabs.selectedIndex]
            let contentBox = drawBox(content, width: 60)
            view += contentBox + "\n\n"
        }

        // Status
        view += Style().foreground(Color(240)).render("Selected: ") +
            Style().bold().render("\(tabs.items[tabs.selectedIndex])") +
            Style().foreground(Color(240)).render(" (Tab \(tabs.selectedIndex + 1) of \(tabs.items.count))") + "\n"

        view += Style().foreground(Color(240)).render("Equal Width: ") +
            (equalWidth
                ? Style().foreground(.brightGreen).render("ON")
                : Style().foreground(Color(240))
                    .render("OFF")
            ) +
            "  " +
            Style().foreground(Color(240)).render("Underline: ") +
            (showUnderline
                ? Style().foreground(.brightGreen).render("ON")
                : Style().foreground(Color(240)).render("OFF")
            ) + "\n\n"

        // Controls
        view += Style().bold().render("Controls:") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("←/→") +
            Style().foreground(Color(240)).render(" or ") +
            Style().bold().render("h/l") +
            Style().foreground(Color(240)).render(" - Navigate tabs") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("1-5") +
            Style().foreground(Color(240)).render(" - Jump to tab") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("e") +
            Style().foreground(Color(240)).render(" - Toggle equal width") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("u") +
            Style().foreground(Color(240)).render(" - Toggle underline") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("q") +
            Style().foreground(Color(240)).render(" - Quit")

        return view
    }

    private func drawBox(_ content: String, width: Int) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let boxStyle = Style().foreground(Color(236))

        var result = ""

        // Top border
        result += boxStyle.render("┌" + String(repeating: "─", count: width - 2) + "┐") + "\n"

        // Content with side borders
        for line in lines {
            let paddedLine = line.padding(toLength: width - 4, withPad: " ", startingAt: 0)
            result += boxStyle.render("│ ") + paddedLine + boxStyle.render(" │") + "\n"
        }

        // Bottom border
        result += boxStyle.render("└" + String(repeating: "─", count: width - 2) + "┘")

        return result
    }
}

// MARK: - TabsExampleApp

@main
struct TabsExampleApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true

        let program = Program(
            initialModel: TabsModel(),
            options: options
        )
        _ = try await program.run()
    }
}
