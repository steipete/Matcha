import Foundation
import Matcha
import MatchaStyle

// MARK: - FileBrowser

/// A file browser component that allows navigating the file system
public struct FileBrowser: Sendable {
    // MARK: - Types

    /// Represents a file or directory entry
    public struct FileEntry: Sendable, Equatable {
        public let name: String
        public let path: String
        public let isDirectory: Bool
        public let size: Int64
        public let modificationDate: Date
        public let isHidden: Bool
        public let isSymlink: Bool
        public let permissions: String

        public init(
            name: String,
            path: String,
            isDirectory: Bool,
            size: Int64,
            modificationDate: Date,
            isHidden: Bool = false,
            isSymlink: Bool = false,
            permissions: String = ""
        ) {
            self.name = name
            self.path = path
            self.isDirectory = isDirectory
            self.size = size
            self.modificationDate = modificationDate
            self.isHidden = isHidden
            self.isSymlink = isSymlink
            self.permissions = permissions
        }
    }

    /// File type filters
    public enum FileFilter: Sendable {
        case all
        case directories
        case files
        case pattern(String)
        case extensions([String])
    }

    // MARK: - Properties

    /// The current directory path
    public var currentPath: String

    /// The entries in the current directory
    public var entries: [FileEntry]

    /// The currently selected index
    public var selectedIndex: Int

    /// The viewport offset for scrolling
    public var offset: Int

    /// The height of the viewport
    public var height: Int

    /// Whether the browser is focused
    public var focused: Bool

    /// File filter
    public var filter: FileFilter

    /// Whether to show hidden files
    public var showHidden: Bool

    /// Whether to show file details
    public var showDetails: Bool

    /// Whether to allow selecting directories
    public var canSelectDirectories: Bool

    /// Whether to allow selecting files
    public var canSelectFiles: Bool

    /// Style for directories
    public var directoryStyle: Style

    /// Style for files
    public var fileStyle: Style

    /// Style for selected item
    public var selectedStyle: Style

    /// Style for the cursor
    public var cursorStyle: Style

    /// Style for file details
    public var detailStyle: Style

    /// Style for symlinks
    public var symlinkStyle: Style

    /// Style for hidden files
    public var hiddenStyle: Style

    /// The cursor character
    public var cursor: String

    /// Date formatter for file dates
    private let dateFormatter: DateFormatter

    // MARK: - Initialization

    /// Creates a new file browser
    public init(path: String = FileManager.default.currentDirectoryPath) {
        self.currentPath = path
        self.entries = []
        self.selectedIndex = 0
        self.offset = 0
        self.height = 10
        self.focused = false
        self.filter = .all
        self.showHidden = false
        self.showDetails = true
        self.canSelectDirectories = true
        self.canSelectFiles = true
        self.directoryStyle = Style().foreground(.brightBlue).bold()
        self.fileStyle = Style().foreground(.white)
        self.selectedStyle = Style().reverse()
        self.cursorStyle = Style().foreground(.brightCyan)
        self.detailStyle = Style().foreground(Color(240))
        self.symlinkStyle = Style().foreground(.cyan)
        self.hiddenStyle = Style().foreground(Color(240))
        self.cursor = "▶"

        self.dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        // Load initial entries
        self.entries = Self.loadEntries(
            path: currentPath,
            filter: filter,
            showHidden: showHidden
        )
    }

    // MARK: - Builder Methods

    /// Sets the current path
    public func withPath(_ path: String) -> FileBrowser {
        var browser = self
        browser.currentPath = path
        browser.entries = Self.loadEntries(
            path: path,
            filter: browser.filter,
            showHidden: browser.showHidden
        )
        browser.selectedIndex = 0
        browser.offset = 0
        return browser
    }

    /// Sets the height
    public func withHeight(_ height: Int) -> FileBrowser {
        var browser = self
        browser.height = max(1, height)
        return browser
    }

    /// Sets the focus state
    public func withFocus(_ focused: Bool) -> FileBrowser {
        var browser = self
        browser.focused = focused
        return browser
    }

    /// Sets the file filter
    public func withFilter(_ filter: FileFilter) -> FileBrowser {
        var browser = self
        browser.filter = filter
        browser.entries = Self.loadEntries(
            path: browser.currentPath,
            filter: filter,
            showHidden: browser.showHidden
        )
        return browser
    }

    /// Sets whether to show hidden files
    public func withShowHidden(_ show: Bool) -> FileBrowser {
        var browser = self
        browser.showHidden = show
        browser.entries = Self.loadEntries(
            path: browser.currentPath,
            filter: browser.filter,
            showHidden: show
        )
        return browser
    }

    /// Sets whether to show details
    public func withShowDetails(_ show: Bool) -> FileBrowser {
        var browser = self
        browser.showDetails = show
        return browser
    }

    /// Sets whether directories can be selected
    public func withCanSelectDirectories(_ canSelect: Bool) -> FileBrowser {
        var browser = self
        browser.canSelectDirectories = canSelect
        return browser
    }

    /// Sets whether files can be selected
    public func withCanSelectFiles(_ canSelect: Bool) -> FileBrowser {
        var browser = self
        browser.canSelectFiles = canSelect
        return browser
    }

    // MARK: - Update Methods

    /// Updates the file browser based on a message
    public func update(_ msg: any Message) -> FileBrowser {
        guard focused else { return self }

        if let key = msg as? KeyMsg {
            return handleKey(key)
        }

        return self
    }

    private func handleKey(_ key: KeyMsg) -> FileBrowser {
        var browser = self

        switch key.type {
        case .up:
            browser = browser.moveUp()

        case .ctrlK:
            browser = browser.moveUp()

        case .down:
            browser = browser.moveDown()

        case .ctrlJ:
            browser = browser.moveDown()

        case .pageUp:
            browser = browser.pageUp()

        case .pageDown:
            browser = browser.pageDown()

        case .home:
            browser.selectedIndex = 0
            browser = browser.ensureVisible()

        case .end:
            browser.selectedIndex = max(0, entries.count - 1)
            browser = browser.ensureVisible()

        case .enter,
             .right:
            if let selected = browser.selectedEntry {
                if selected.isDirectory {
                    browser = browser.enterDirectory(selected.path)
                }
            }

        case .ctrlL:
            if let selected = browser.selectedEntry {
                if selected.isDirectory {
                    browser = browser.enterDirectory(selected.path)
                }
            }

        case .left:
            browser = browser.goUp()

        case .ctrlH:
            browser = browser.goUp()

        case .ctrlUnderscore:
            // Toggle hidden files
            browser = browser.withShowHidden(!browser.showHidden)

        case .ctrlR:
            // Refresh
            browser = browser.refresh()

        default:
            break
        }

        return browser
    }

    // MARK: - Navigation

    /// Moves selection up
    public func moveUp() -> FileBrowser {
        var browser = self
        if selectedIndex > 0 {
            browser.selectedIndex -= 1
            browser = browser.ensureVisible()
        }
        return browser
    }

    /// Moves selection down
    public func moveDown() -> FileBrowser {
        var browser = self
        if selectedIndex < entries.count - 1 {
            browser.selectedIndex += 1
            browser = browser.ensureVisible()
        }
        return browser
    }

    /// Pages up
    public func pageUp() -> FileBrowser {
        var browser = self
        browser.selectedIndex = max(0, selectedIndex - height)
        browser = browser.ensureVisible()
        return browser
    }

    /// Pages down
    public func pageDown() -> FileBrowser {
        var browser = self
        browser.selectedIndex = min(entries.count - 1, selectedIndex + height)
        browser = browser.ensureVisible()
        return browser
    }

    /// Enters a directory
    public func enterDirectory(_ path: String) -> FileBrowser {
        withPath(path)
    }

    /// Goes up to parent directory
    public func goUp() -> FileBrowser {
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty, parentPath != currentPath {
            return withPath(parentPath)
        }
        return self
    }

    /// Refreshes the current directory
    public func refresh() -> FileBrowser {
        var browser = self
        browser.entries = Self.loadEntries(
            path: currentPath,
            filter: filter,
            showHidden: showHidden
        )
        browser.selectedIndex = min(selectedIndex, max(0, entries.count - 1))
        return browser
    }

    /// Ensures the selected item is visible
    private func ensureVisible() -> FileBrowser {
        var browser = self

        if selectedIndex < offset {
            browser.offset = selectedIndex
        } else if selectedIndex >= offset + height {
            browser.offset = selectedIndex - height + 1
        }

        return browser
    }

    // MARK: - Accessors

    /// Gets the currently selected entry
    public var selectedEntry: FileEntry? {
        guard selectedIndex >= 0, selectedIndex < entries.count else {
            return nil
        }
        return entries[selectedIndex]
    }

    // MARK: - Rendering

    /// Renders the file browser
    public func view() -> String {
        var lines: [String] = []

        // Calculate visible range
        let visibleRange = offset..<min(offset + height, entries.count)

        for (index, entry) in entries.enumerated() {
            guard visibleRange.contains(index) else { continue }

            var line = ""

            // Cursor
            if index == selectedIndex {
                line += cursorStyle.render(cursor + " ")
            } else {
                line += "  "
            }

            // Icon and name
            let icon = entry.isDirectory ? "📁" : "📄"
            let nameStyle: Style = if entry.isHidden {
                hiddenStyle
            } else if entry.isSymlink {
                symlinkStyle
            } else if entry.isDirectory {
                directoryStyle
            } else {
                fileStyle
            }

            let name = icon + " " + entry.name

            // Apply selection style if selected
            if index == selectedIndex {
                line += selectedStyle.render(name)
            } else {
                line += nameStyle.render(name)
            }

            // Details if enabled
            if showDetails {
                let padding = 40 - name.stripANSI().count
                if padding > 0 {
                    line += String(repeating: " ", count: padding)
                }

                // Size
                let sizeStr: String = if entry.isDirectory {
                    "     -"
                } else {
                    formatSize(entry.size)
                }

                // Date
                let dateStr = dateFormatter.string(from: entry.modificationDate)

                let details = sizeStr.padding(toLength: 10, withPad: " ", startingAt: 0) + dateStr

                if index == selectedIndex {
                    line += selectedStyle.render(details)
                } else {
                    line += detailStyle.render(details)
                }
            }

            lines.append(line)
        }

        // Fill remaining height
        while lines.count < height {
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helper Methods

    /// Loads entries from a directory
    private static func loadEntries(
        path: String,
        filter: FileFilter,
        showHidden: Bool
    ) -> [FileEntry] {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var entries: [FileEntry] = []

        for item in contents {
            // Skip hidden files if not showing them
            if !showHidden, item.hasPrefix(".") {
                continue
            }

            let itemPath = (path as NSString).appendingPathComponent(item)

            guard let attributes = try? fileManager.attributesOfItem(atPath: itemPath) else {
                continue
            }

            let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
            let size = attributes[.size] as? Int64 ?? 0
            let modDate = attributes[.modificationDate] as? Date ?? Date()
            let isSymlink = attributes[.type] as? FileAttributeType == .typeSymbolicLink

            // Apply filter
            switch filter {
            case .all:
                break
            case .directories:
                if !isDirectory { continue }
            case .files:
                if isDirectory { continue }
            case let .pattern(pattern):
                if item.range(of: pattern, options: .regularExpression) == nil {
                    continue
                }
            case let .extensions(exts):
                if isDirectory { continue }
                let ext = (item as NSString).pathExtension.lowercased()
                if !exts.contains(ext) { continue }
            }

            let entry = FileEntry(
                name: item,
                path: itemPath,
                isDirectory: isDirectory,
                size: size,
                modificationDate: modDate,
                isHidden: item.hasPrefix("."),
                isSymlink: isSymlink
            )

            entries.append(entry)
        }

        // Sort: directories first, then alphabetically
        entries.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return entries
    }

    /// Formats a file size
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - String Extensions

private extension String {
    /// Strips ANSI escape sequences from the string
    func stripANSI() -> String {
        var result = self

        // Remove CSI sequences
        result = result.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )

        return result
    }
}
