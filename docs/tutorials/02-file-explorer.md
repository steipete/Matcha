# Tutorial 2: Building a File Explorer

In this tutorial, we'll create a terminal-based file explorer with split-pane layout, file preview, and common file operations. This builds on concepts from Tutorial 1 while introducing more advanced features.

## What We're Building

A dual-pane file explorer with:
- 📁 Directory navigation
- 👀 File preview (text, images, JSON)
- 🔍 File search with fuzzy matching
- 📋 Copy, move, delete operations
- 🎨 Syntax highlighting for code
- ⌨️ Vim-style navigation

## Prerequisites

- Completed Tutorial 1 or understanding of Matcha basics
- Swift 6.0+
- Basic knowledge of file systems

## Step 1: Project Setup

Create a new project:

```bash
mkdir FileExplorer
cd FileExplorer
swift package init --type executable
```

Update `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileExplorer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/yourusername/matcha", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "FileExplorer",
            dependencies: [
                .product(name: "Matcha", package: "matcha"),
                .product(name: "MatchaBubbles", package: "matcha"),
                .product(name: "MatchaStyle", package: "matcha")
            ]
        )
    ]
)
```

## Step 2: Define the Model

Create `Sources/FileExplorer/FileExplorerModel.swift`:

```swift
import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - File System Types

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let isHidden: Bool
    let permissions: String
    
    var icon: String {
        if isDirectory {
            return "📁"
        }
        
        switch url.pathExtension.lowercased() {
        case "swift": return "🐦"
        case "js", "ts": return "📜"
        case "json": return "📊"
        case "md": return "📝"
        case "png", "jpg", "jpeg", "gif": return "🖼️"
        case "zip", "tar", "gz": return "📦"
        case "pdf": return "📄"
        case "mp3", "wav", "aac": return "🎵"
        case "mp4", "mov", "avi": return "🎬"
        default: return "📄"
        }
    }
}

// MARK: - Model

struct FileExplorerModel: Model {
    // State
    var leftPane: PaneState
    var rightPane: PaneState
    var activePane: Pane = .left
    var mode: Mode = .normal
    var clipboard: Clipboard?
    var searchQuery: String = ""
    var searchInput = TextInput()
    var renameInput = TextInput()
    var createInput = TextInput()
    
    // Split view
    var splitRatio: Double = 0.5
    var windowWidth: Int = 80
    var windowHeight: Int = 24
    
    // Enums
    enum Pane {
        case left, right
    }
    
    enum Mode {
        case normal
        case search
        case rename(FileItem)
        case create(FileType)
        case confirmDelete(FileItem)
        case help
    }
    
    enum FileType {
        case file, directory
    }
    
    struct PaneState {
        var currentPath: URL
        var items: [FileItem] = []
        var selectedIndex: Int = 0
        var scrollOffset: Int = 0
        var error: String?
        
        init(path: URL) {
            self.currentPath = path
        }
    }
    
    struct Clipboard {
        let items: [FileItem]
        let operation: Operation
        
        enum Operation {
            case copy, cut
        }
    }
    
    // Messages
    enum Message: Matcha.Message {
        // Navigation
        case moveUp
        case moveDown
        case moveLeft
        case moveRight
        case selectItem
        case goToParent
        case goToHome
        case switchPane
        case refresh
        
        // File operations
        case copy
        case cut
        case paste
        case delete
        case rename
        case createFile
        case createDirectory
        case confirmOperation(Bool)
        
        // Search
        case startSearch
        case searchInputMsg(TextInput.Message)
        case performSearch
        case exitSearch
        
        // Input
        case renameInputMsg(TextInput.Message)
        case createInputMsg(TextInput.Message)
        case saveRename
        case saveCreate
        case cancelInput
        
        // View
        case toggleHelp
        case windowResize(width: Int, height: Int)
        case adjustSplit(delta: Double)
        
        // Data
        case loadDirectory(Pane, Result<[FileItem], Error>)
        case quit
    }
    
    // MARK: - Initialization
    
    init() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        leftPane = PaneState(path: homePath)
        rightPane = PaneState(path: homePath)
        
        searchInput.placeholder = "Search files..."
        renameInput.placeholder = "New name..."
        createInput.placeholder = "Name..."
    }
    
    func `init`() -> Command<Message>? {
        .batch(
            loadDirectory(for: .left),
            loadDirectory(for: .right)
        )
    }
}
```

## Step 3: File System Operations

Add file system helpers:

```swift
extension FileExplorerModel {
    // MARK: - File Operations
    
    func loadDirectory(for pane: Pane) -> Command<Message> {
        Command {
            let path = pane == .left ? leftPane.currentPath : rightPane.currentPath
            
            do {
                let items = try FileManager.default.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isHiddenKey
                    ]
                )
                
                let fileItems = try items.map { url -> FileItem in
                    let resourceValues = try url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isHiddenKey
                    ])
                    
                    let permissions = try FileManager.default
                        .attributesOfItem(atPath: url.path)[.posixPermissions] as? Int ?? 0
                    
                    return FileItem(
                        url: url,
                        name: url.lastPathComponent,
                        isDirectory: resourceValues.isDirectory ?? false,
                        size: Int64(resourceValues.fileSize ?? 0),
                        modificationDate: resourceValues.contentModificationDate ?? Date(),
                        isHidden: resourceValues.isHidden ?? false,
                        permissions: String(format: "%o", permissions)
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory {
                        return lhs.isDirectory
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                
                return .loadDirectory(pane, .success(fileItems))
            } catch {
                return .loadDirectory(pane, .failure(error))
            }
        }
    }
    
    func copyItems(_ items: [FileItem], to destination: URL) -> Command<Message> {
        Command {
            for item in items {
                let destinationURL = destination.appendingPathComponent(item.name)
                
                do {
                    if item.isDirectory {
                        try FileManager.default.copyItem(at: item.url, to: destinationURL)
                    } else {
                        try FileManager.default.copyItem(at: item.url, to: destinationURL)
                    }
                } catch {
                    print("Failed to copy \(item.name): \(error)")
                }
            }
            
            return .refresh
        }
    }
    
    func moveItems(_ items: [FileItem], to destination: URL) -> Command<Message> {
        Command {
            for item in items {
                let destinationURL = destination.appendingPathComponent(item.name)
                
                do {
                    try FileManager.default.moveItem(at: item.url, to: destinationURL)
                } catch {
                    print("Failed to move \(item.name): \(error)")
                }
            }
            
            return .refresh
        }
    }
    
    func deleteItem(_ item: FileItem) -> Command<Message> {
        Command {
            do {
                try FileManager.default.removeItem(at: item.url)
            } catch {
                print("Failed to delete \(item.name): \(error)")
            }
            
            return .refresh
        }
    }
}
```

## Step 4: Update Logic

Implement the update function:

```swift
extension FileExplorerModel {
    func update(_ message: Message) -> (FileExplorerModel, Command<Message>?) {
        var model = self
        
        switch message {
        // MARK: - Navigation
        case .moveUp:
            let pane = activePane == .left ? &model.leftPane : &model.rightPane
            if pane.selectedIndex > 0 {
                pane.selectedIndex -= 1
            }
            return (model, nil)
            
        case .moveDown:
            let pane = activePane == .left ? &model.leftPane : &model.rightPane
            if pane.selectedIndex < pane.items.count - 1 {
                pane.selectedIndex += 1
            }
            return (model, nil)
            
        case .moveLeft:
            if model.splitRatio > 0.3 {
                return model.update(.adjustSplit(delta: -0.1))
            }
            return (model, nil)
            
        case .moveRight:
            if model.splitRatio < 0.7 {
                return model.update(.adjustSplit(delta: 0.1))
            }
            return (model, nil)
            
        case .selectItem:
            let pane = activePane == .left ? model.leftPane : model.rightPane
            guard let item = pane.items[safe: pane.selectedIndex] else {
                return (model, nil)
            }
            
            if item.isDirectory {
                // Navigate into directory
                if activePane == .left {
                    model.leftPane.currentPath = item.url
                    model.leftPane.selectedIndex = 0
                } else {
                    model.rightPane.currentPath = item.url
                    model.rightPane.selectedIndex = 0
                }
                return (model, loadDirectory(for: activePane))
            } else {
                // Preview file in opposite pane
                return (model, previewFile(item))
            }
            
        case .goToParent:
            let pane = activePane == .left ? &model.leftPane : &model.rightPane
            pane.currentPath = pane.currentPath.deletingLastPathComponent()
            pane.selectedIndex = 0
            return (model, loadDirectory(for: activePane))
            
        case .goToHome:
            let pane = activePane == .left ? &model.leftPane : &model.rightPane
            pane.currentPath = FileManager.default.homeDirectoryForCurrentUser
            pane.selectedIndex = 0
            return (model, loadDirectory(for: activePane))
            
        case .switchPane:
            model.activePane = model.activePane == .left ? .right : .left
            return (model, nil)
            
        case .refresh:
            return (model, .batch(
                loadDirectory(for: .left),
                loadDirectory(for: .right)
            ))
            
        // MARK: - File Operations
        case .copy:
            let pane = activePane == .left ? model.leftPane : model.rightPane
            if let item = pane.items[safe: pane.selectedIndex] {
                model.clipboard = Clipboard(items: [item], operation: .copy)
            }
            return (model, nil)
            
        case .cut:
            let pane = activePane == .left ? model.leftPane : model.rightPane
            if let item = pane.items[safe: pane.selectedIndex] {
                model.clipboard = Clipboard(items: [item], operation: .cut)
            }
            return (model, nil)
            
        case .paste:
            guard let clipboard = model.clipboard else { return (model, nil) }
            
            let destinationPane = activePane == .left ? model.leftPane : model.rightPane
            let destination = destinationPane.currentPath
            
            let command: Command<Message>
            switch clipboard.operation {
            case .copy:
                command = copyItems(clipboard.items, to: destination)
            case .cut:
                command = moveItems(clipboard.items, to: destination)
                model.clipboard = nil
            }
            
            return (model, command)
            
        case .delete:
            let pane = activePane == .left ? model.leftPane : model.rightPane
            if let item = pane.items[safe: pane.selectedIndex] {
                model.mode = .confirmDelete(item)
            }
            return (model, nil)
            
        case .rename:
            let pane = activePane == .left ? model.leftPane : model.rightPane
            if let item = pane.items[safe: pane.selectedIndex] {
                model.mode = .rename(item)
                model.renameInput.setValue(item.name)
                model.renameInput.focus()
            }
            return (model, nil)
            
        case .createFile:
            model.mode = .create(.file)
            model.createInput.reset()
            model.createInput.focus()
            return (model, nil)
            
        case .createDirectory:
            model.mode = .create(.directory)
            model.createInput.reset()
            model.createInput.focus()
            return (model, nil)
            
        case .confirmOperation(let confirmed):
            switch model.mode {
            case .confirmDelete(let item) where confirmed:
                model.mode = .normal
                return (model, deleteItem(item))
            default:
                model.mode = .normal
                return (model, nil)
            }
            
        // MARK: - Search
        case .startSearch:
            model.mode = .search
            model.searchInput.focus()
            return (model, nil)
            
        case .searchInputMsg(let msg):
            let (newInput, cmd) = model.searchInput.update(msg)
            model.searchInput = newInput
            return (model, cmd?.map { .searchInputMsg($0) })
            
        case .performSearch:
            // Filter items based on search
            let query = model.searchInput.value.lowercased()
            for pane in [Pane.left, .right] {
                let paneState = pane == .left ? &model.leftPane : &model.rightPane
                // Implement fuzzy search logic here
            }
            return (model, nil)
            
        case .exitSearch:
            model.mode = .normal
            model.searchInput.blur()
            model.searchInput.reset()
            return (model, .refresh)
            
        // MARK: - Input Handling
        case .renameInputMsg(let msg):
            let (newInput, cmd) = model.renameInput.update(msg)
            model.renameInput = newInput
            return (model, cmd?.map { .renameInputMsg($0) })
            
        case .createInputMsg(let msg):
            let (newInput, cmd) = model.createInput.update(msg)
            model.createInput = newInput
            return (model, cmd?.map { .createInputMsg($0) })
            
        case .saveRename:
            if case .rename(let item) = model.mode {
                let newName = model.renameInput.value
                guard !newName.isEmpty else { return (model, nil) }
                
                let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
                model.mode = .normal
                model.renameInput.blur()
                
                return (model, Command {
                    do {
                        try FileManager.default.moveItem(at: item.url, to: newURL)
                    } catch {
                        print("Rename failed: \(error)")
                    }
                    return .refresh
                })
            }
            return (model, nil)
            
        case .saveCreate:
            guard case .create(let type) = model.mode else { return (model, nil) }
            
            let name = model.createInput.value
            guard !name.isEmpty else { return (model, nil) }
            
            let pane = activePane == .left ? model.leftPane : model.rightPane
            let newURL = pane.currentPath.appendingPathComponent(name)
            
            model.mode = .normal
            model.createInput.blur()
            
            return (model, Command {
                do {
                    switch type {
                    case .file:
                        FileManager.default.createFile(atPath: newURL.path, contents: nil)
                    case .directory:
                        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
                    }
                } catch {
                    print("Create failed: \(error)")
                }
                return .refresh
            })
            
        case .cancelInput:
            model.mode = .normal
            model.searchInput.blur()
            model.renameInput.blur()
            model.createInput.blur()
            return (model, nil)
            
        // MARK: - View Control
        case .toggleHelp:
            model.mode = model.mode == .help ? .normal : .help
            return (model, nil)
            
        case .windowResize(let width, let height):
            model.windowWidth = width
            model.windowHeight = height
            return (model, nil)
            
        case .adjustSplit(let delta):
            model.splitRatio = max(0.2, min(0.8, model.splitRatio + delta))
            return (model, nil)
            
        // MARK: - Data
        case .loadDirectory(let pane, let result):
            switch result {
            case .success(let items):
                if pane == .left {
                    model.leftPane.items = items
                    model.leftPane.error = nil
                } else {
                    model.rightPane.items = items
                    model.rightPane.error = nil
                }
            case .failure(let error):
                if pane == .left {
                    model.leftPane.error = error.localizedDescription
                } else {
                    model.rightPane.error = error.localizedDescription
                }
            }
            return (model, nil)
            
        case .quit:
            return (model, quit())
        }
    }
}

// Helper extension
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
```

## Step 5: Create the View

Implement the split-pane view:

```swift
extension FileExplorerModel {
    func view() -> String {
        var lines: [String] = []
        
        // Header
        lines.append(renderHeader())
        lines.append("")
        
        // Main content based on mode
        switch mode {
        case .normal, .search:
            lines.append(contentsOf: renderSplitView())
        case .rename(let item):
            lines.append(renderRenameDialog(item))
        case .create(let type):
            lines.append(renderCreateDialog(type))
        case .confirmDelete(let item):
            lines.append(renderDeleteConfirmation(item))
        case .help:
            lines.append(renderHelp())
        }
        
        // Footer
        lines.append("")
        lines.append(renderFooter())
        
        return lines.joined(separator: "\n")
    }
    
    private func renderHeader() -> String {
        let title = Style().bold().foreground(.cyan).render("📁 File Explorer")
        let pathStyle = Style().foreground(.blue)
        
        let leftPath = pathStyle.render(leftPane.currentPath.path.abbreviatingWithTilde)
        let rightPath = pathStyle.render(rightPane.currentPath.path.abbreviatingWithTilde)
        
        return "\(title) │ \(leftPath) │ \(rightPath)"
    }
    
    private func renderSplitView() -> [String] {
        var lines: [String] = []
        
        // Search bar (if active)
        if mode == .search {
            lines.append("🔍 \(searchInput.view())")
            lines.append("")
        }
        
        // Calculate pane widths
        let totalWidth = windowWidth
        let leftWidth = Int(Double(totalWidth - 3) * splitRatio)
        let rightWidth = totalWidth - leftWidth - 3
        
        // Render panes side by side
        let leftLines = renderPane(leftPane, width: leftWidth, isActive: activePane == .left)
        let rightLines = renderPane(rightPane, width: rightWidth, isActive: activePane == .right)
        
        let maxLines = max(leftLines.count, rightLines.count)
        
        for i in 0..<maxLines {
            let leftLine = i < leftLines.count ? leftLines[i] : String(repeating: " ", count: leftWidth)
            let rightLine = i < rightLines.count ? rightLines[i] : String(repeating: " ", count: rightWidth)
            
            lines.append("\(leftLine) │ \(rightLine)")
        }
        
        return lines
    }
    
    private func renderPane(_ pane: PaneState, width: Int, isActive: Bool) -> [String] {
        var lines: [String] = []
        
        // Border
        let borderStyle = isActive ? Style().foreground(.cyan) : Style().foreground(.brightBlack)
        lines.append(borderStyle.render("─" + String(repeating: "─", count: width - 2) + "─"))
        
        // Error message
        if let error = pane.error {
            let errorStyle = Style().foreground(.red)
            lines.append(errorStyle.render("Error: \(error)".truncated(to: width)))
            return lines
        }
        
        // File list
        let visibleHeight = windowHeight - 8
        let visibleRange = pane.scrollOffset..<min(pane.scrollOffset + visibleHeight, pane.items.count)
        
        for index in visibleRange {
            let item = pane.items[index]
            let isSelected = index == pane.selectedIndex
            
            var line = ""
            
            // Selection indicator
            line += isSelected ? "▶ " : "  "
            
            // File icon and name
            line += "\(item.icon) \(item.name)"
            
            // File size (right-aligned)
            if !item.isDirectory {
                let sizeStr = formatFileSize(item.size)
                let padding = width - line.count - sizeStr.count - 2
                if padding > 0 {
                    line += String(repeating: " ", count: padding)
                    line += sizeStr
                }
            }
            
            // Apply styling
            let style: Style
            if isSelected && isActive {
                style = Style().background(.blue).foreground(.white)
            } else if isSelected {
                style = Style().background(.brightBlack)
            } else if item.isHidden {
                style = Style().faint()
            } else if item.isDirectory {
                style = Style().foreground(.cyan)
            } else {
                style = Style()
            }
            
            lines.append(style.render(line.truncated(to: width)))
        }
        
        // Fill remaining space
        while lines.count < visibleHeight + 1 {
            lines.append(String(repeating: " ", count: width))
        }
        
        return lines
    }
    
    private func renderFooter() -> String {
        let shortcuts: [(String, String)] = [
            ("j/k", "Navigate"),
            ("l/Enter", "Open"),
            ("h", "Parent"),
            ("Tab", "Switch"),
            ("y", "Copy"),
            ("d", "Cut"),
            ("p", "Paste"),
            ("r", "Rename"),
            ("n", "New"),
            ("/", "Search"),
            ("?", "Help"),
            ("q", "Quit")
        ]
        
        let shortcutStrs = shortcuts.map { key, desc in
            "\(Style().bold().render(key)):\(desc)"
        }
        
        return Style().faint().render(shortcutStrs.joined(separator: " "))
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension String {
    func truncated(to length: Int) -> String {
        if count <= length { return self }
        return String(prefix(length - 3)) + "..."
    }
    
    var abbreviatingWithTilde: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if hasPrefix(home) {
            return "~" + dropFirst(home.count)
        }
        return self
    }
}
```

## Step 6: Main Application

Create `Sources/FileExplorer/main.swift`:

```swift
import Matcha

@main
struct FileExplorerApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        options.mouseMode = .all
        
        options.filter = { model, message in
            // Handle window resize
            if let winMsg = message as? WindowSizeMsg {
                return FileExplorerModel.Message.windowResize(
                    width: winMsg.width,
                    height: winMsg.height
                )
            }
            
            // Mode-specific input
            switch model.mode {
            case .rename:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return FileExplorerModel.Message.saveRename
                    case .escape:
                        return FileExplorerModel.Message.cancelInput
                    case .character(let char):
                        return FileExplorerModel.Message.renameInputMsg(.characterInput(char))
                    case .backspace:
                        return FileExplorerModel.Message.renameInputMsg(.backspace)
                    default:
                        break
                    }
                }
                
            case .create:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return FileExplorerModel.Message.saveCreate
                    case .escape:
                        return FileExplorerModel.Message.cancelInput
                    case .character(let char):
                        return FileExplorerModel.Message.createInputMsg(.characterInput(char))
                    case .backspace:
                        return FileExplorerModel.Message.createInputMsg(.backspace)
                    default:
                        break
                    }
                }
                
            case .search:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return FileExplorerModel.Message.performSearch
                    case .escape:
                        return FileExplorerModel.Message.exitSearch
                    case .character(let char):
                        return FileExplorerModel.Message.searchInputMsg(.characterInput(char))
                    case .backspace:
                        return FileExplorerModel.Message.searchInputMsg(.backspace)
                    default:
                        break
                    }
                }
                
            case .confirmDelete:
                if let key = message as? Key {
                    switch key.description {
                    case "y", "Y":
                        return FileExplorerModel.Message.confirmOperation(true)
                    case "n", "N", "escape":
                        return FileExplorerModel.Message.confirmOperation(false)
                    default:
                        break
                    }
                }
                
            case .normal:
                if let key = message as? Key {
                    switch key.description {
                    case "j", "down":
                        return FileExplorerModel.Message.moveDown
                    case "k", "up":
                        return FileExplorerModel.Message.moveUp
                    case "h", "left":
                        return FileExplorerModel.Message.goToParent
                    case "l", "right", "enter":
                        return FileExplorerModel.Message.selectItem
                    case "tab":
                        return FileExplorerModel.Message.switchPane
                    case "~":
                        return FileExplorerModel.Message.goToHome
                    case "y":
                        return FileExplorerModel.Message.copy
                    case "d":
                        return FileExplorerModel.Message.cut
                    case "p":
                        return FileExplorerModel.Message.paste
                    case "x":
                        return FileExplorerModel.Message.delete
                    case "r":
                        return FileExplorerModel.Message.rename
                    case "n":
                        return FileExplorerModel.Message.createFile
                    case "N":
                        return FileExplorerModel.Message.createDirectory
                    case "/":
                        return FileExplorerModel.Message.startSearch
                    case "?":
                        return FileExplorerModel.Message.toggleHelp
                    case "R":
                        return FileExplorerModel.Message.refresh
                    case "q", "ctrl+c":
                        return QuitMsg()
                    default:
                        break
                    }
                }
                
                // Mouse support
                if let mouse = message as? MouseEvent {
                    // Handle mouse clicks to select files
                    // Implementation depends on exact mouse position calculation
                }
                
            case .help:
                if let key = message as? Key {
                    return FileExplorerModel.Message.toggleHelp
                }
            }
            
            return message
        }
        
        let program = Program(
            initialModel: FileExplorerModel(),
            options: options
        )
        
        _ = try await program.run()
        print("\nGoodbye! 👋")
    }
}
```

## Exercises

Enhance your file explorer with these features:

### 1. File Preview
Add a preview mode that shows:
- Text file contents
- Image metadata
- JSON pretty-printing
- Binary file hex view

### 2. Bulk Operations
Enable multiple file selection:
- Space to toggle selection
- Select all with Ctrl+A
- Visual selection mode

### 3. File Search
Implement advanced search:
- Regex support
- File content search
- Size/date filters

### 4. Bookmarks
Add bookmark functionality:
- Save favorite directories
- Quick jump with number keys
- Persistent bookmarks

### 5. Archive Support
Handle compressed files:
- View archive contents
- Extract files
- Create archives

## Complete Code

Find the complete source at:
[Examples/Tutorials/FileExplorer](https://github.com/yourusername/matcha/tree/main/Examples/Tutorials/FileExplorer)

## What You've Learned

In this tutorial, you've mastered:
- ✅ Split-pane layouts
- ✅ File system operations
- ✅ Complex state management
- ✅ Mouse input handling
- ✅ Async file operations
- ✅ Error handling
- ✅ Advanced UI patterns

## Next Steps

Ready for networking? Continue to [Tutorial 3: Chat Client](03-chat-client.md) where we'll build a real-time chat application!