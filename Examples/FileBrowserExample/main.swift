import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - FileBrowserModel

struct FileBrowserModel: Model {
    var browser: FileBrowser
    var selectedPath: String?
    var showHidden: Bool = false
    var showDetails: Bool = true
    var filter: FileBrowser.FileFilter = .all

    enum Message: Matcha.Message {
        case key(KeyMsg)
        case selectFile(String)
        case toggleHidden
        case toggleDetails
        case changeFilter(FileBrowser.FileFilter)
        case quit
    }

    init() {
        // Start in the user's home directory
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        self.browser = FileBrowser(path: homePath)
            .withHeight(20)
            .withFocus(true)
            .withShowDetails(true)

        // Apply custom styles
        browser.directoryStyle = Style().foreground(.brightBlue).bold()
        browser.fileStyle = Style().foreground(.white)
        browser.selectedStyle = Style().background(Color(238))
        browser.detailStyle = Style().foreground(Color(244))
        browser.symlinkStyle = Style().foreground(.cyan).italic()
        browser.hiddenStyle = Style().foreground(Color(240))
    }

    func `init`() -> Command<Message>? {
        nil
    }

    func update(_ message: Message) -> (FileBrowserModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.description {
            case "ctrl+c",
                 "q":
                return (model, quit())
            case ".":
                return model.update(.toggleHidden)
            case "d":
                return model.update(.toggleDetails)
            case "f":
                // Cycle through filters
                let nextFilter: FileBrowser.FileFilter = switch model.filter {
                case .all:
                    .directories
                case .directories:
                    .files
                case .files:
                    .all
                default:
                    .all
                }
                return model.update(.changeFilter(nextFilter))
            case " ":
                // Select current file/directory
                if let entry = model.browser.selectedEntry {
                    if model.browser.canSelectFiles, !entry.isDirectory {
                        model.selectedPath = entry.path
                    } else if model.browser.canSelectDirectories, entry.isDirectory {
                        model.selectedPath = entry.path
                    }
                }
            default:
                model.browser = model.browser.update(key)
            }

        case let .selectFile(path):
            model.selectedPath = path

        case .toggleHidden:
            model.showHidden.toggle()
            model.browser = model.browser.withShowHidden(model.showHidden)

        case .toggleDetails:
            model.showDetails.toggle()
            model.browser = model.browser.withShowDetails(model.showDetails)

        case let .changeFilter(filter):
            model.filter = filter
            model.browser = model.browser.withFilter(filter)

        case .quit:
            return (model, quit())
        }

        return (model, nil)
    }

    func view() -> String {
        var view = ""

        // Title
        view += Style().bold().foreground(.brightMagenta).render("📂 FileBrowser Component Demo") + "\n\n"

        // Current path
        view += Style().bold().render("Current Directory:") + "\n"
        view += Style().foreground(.brightCyan).render(browser.currentPath) + "\n\n"

        // File browser
        view += drawBox(browser.view(), width: 80, height: browser.height + 2) + "\n\n"

        // Selected file info
        if let selectedPath {
            view += Style().bold().foreground(.brightGreen).render("✓ Selected: ") +
                Style().foreground(.white).render(selectedPath) + "\n\n"
        } else if let entry = browser.selectedEntry {
            view += Style().bold().render("Current Selection:") + " "
            view += Style().foreground(.brightYellow).render(entry.name)

            if entry.isDirectory {
                view += Style().foreground(Color(240)).render(" (directory)")
            } else {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let sizeStr = formatter.string(fromByteCount: entry.size)
                view += Style().foreground(Color(240)).render(" (\(sizeStr))")
            }
            view += "\n\n"
        }

        // Status
        let entryCount = browser.entries.count
        let dirCount = browser.entries.count(where: { $0.isDirectory })
        let fileCount = entryCount - dirCount

        view += Style().foreground(Color(240)).render("Items: ") +
            Style().bold().render("\(entryCount)") +
            Style().foreground(Color(240)).render(" (\(dirCount) directories, \(fileCount) files)") + "\n"

        view += Style().foreground(Color(240)).render("Filter: ") +
            Style().bold().render(filterDescription(filter)) + "  "
        view += Style().foreground(Color(240)).render("Hidden: ") +
            (showHidden
                ? Style().foreground(.brightGreen).render("SHOW")
                : Style().foreground(Color(240)).render("HIDE")
            ) + "  "
        view += Style().foreground(Color(240)).render("Details: ") +
            (showDetails
                ? Style().foreground(.brightGreen).render("ON")
                : Style().foreground(Color(240))
                    .render("OFF")
            ) + "\n\n"

        // Controls
        view += Style().bold().render("Controls:") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("↑/↓") +
            Style().foreground(Color(240)).render(" or ") +
            Style().bold().render("j/k") +
            Style().foreground(Color(240)).render(" - Navigate") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("Enter/→") +
            Style().foreground(Color(240)).render(" or ") +
            Style().bold().render("l") +
            Style().foreground(Color(240)).render(" - Enter directory") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("←") +
            Style().foreground(Color(240)).render(" or ") +
            Style().bold().render("h") +
            Style().foreground(Color(240)).render(" - Go to parent") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("Space") +
            Style().foreground(Color(240)).render(" - Select file/directory") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render(".") +
            Style().foreground(Color(240)).render(" - Toggle hidden files") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("d") +
            Style().foreground(Color(240)).render(" - Toggle details") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("f") +
            Style().foreground(Color(240)).render(" - Cycle filters") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("Ctrl+R") +
            Style().foreground(Color(240)).render(" - Refresh") + "\n"
        view += Style().foreground(Color(240)).render("• ") +
            Style().bold().render("q") +
            Style().foreground(Color(240)).render(" - Quit")

        return view
    }

    private func drawBox(_ content: String, width: Int, height: Int) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let boxStyle = Style().foreground(Color(236))

        var result = ""

        // Top border
        result += boxStyle.render("┌" + String(repeating: "─", count: width - 2) + "┐") + "\n"

        // Content with side borders
        for i in 0..<height {
            if i < lines.count {
                let line = lines[i]
                let paddedLine = line.padding(toLength: width - 2, withPad: " ", startingAt: 0)
                result += boxStyle.render("│") + paddedLine + boxStyle.render("│") + "\n"
            } else {
                result += boxStyle.render("│") + String(repeating: " ", count: width - 2) + boxStyle.render("│") + "\n"
            }
        }

        // Bottom border
        result += boxStyle.render("└" + String(repeating: "─", count: width - 2) + "┘")

        return result
    }

    private func filterDescription(_ filter: FileBrowser.FileFilter) -> String {
        switch filter {
        case .all:
            "All"
        case .directories:
            "Directories"
        case .files:
            "Files"
        case let .pattern(pattern):
            "Pattern: \(pattern)"
        case let .extensions(exts):
            "Extensions: \(exts.joined(separator: ", "))"
        }
    }
}

// MARK: - FileBrowserExampleApp

@main
struct FileBrowserExampleApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true

        let program = Program(
            initialModel: FileBrowserModel(),
            options: options
        )
        _ = try await program.run()
    }
}
