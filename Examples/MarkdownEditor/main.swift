//
//  main.swift
//  Markdown Editor Example
//
//  A markdown editor demonstrating:
//  - Multi-line text editing
//  - Syntax highlighting
//  - File operations
//  - Split-pane preview
//  - Vim-style keybindings
//

import Foundation
import Matcha

// MARK: - Markdown Editor Model

public struct MarkdownEditorModel: Model {
    var content: [String] = ["# Welcome to Matcha Markdown Editor", "", "Start typing to begin..."]
    var cursorLine: Int = 2
    var cursorColumn: Int = 23
    var mode: EditorMode = .normal
    var filename: String? = nil
    var showPreview: Bool = true
    var statusMessage: String = "Ready"
    var isDirty: Bool = false
    var yankBuffer: String = ""
    
    // Visual mode selection
    var visualStart: (line: Int, column: Int)? = nil
    
    // Window dimensions
    var windowWidth: Int = 80
    var windowHeight: Int = 24
    
    enum EditorMode {
        case normal
        case insert
        case visual
        case command(String)
        
        var indicator: String {
            switch self {
            case .normal: return "NORMAL"
            case .insert: return "INSERT"
            case .visual: return "VISUAL"
            case .command: return "COMMAND"
            }
        }
        
        var color: String {
            switch self {
            case .normal: return "\u{1B}[34m"      // Blue
            case .insert: return "\u{1B}[32m"      // Green
            case .visual: return "\u{1B}[33m"      // Yellow
            case .command: return "\u{1B}[35m"     // Magenta
            }
        }
    }
    
    // MARK: - Messages
    
    public enum Message: Matcha.Message {
        case key(KeyMsg)
        case windowSize(WindowSizeMsg)
        case fileLoaded(String)
        case fileSaved
        case error(String)
    }
    
    // MARK: - Model Protocol
    
    public init() {}
    
    public func `init`() -> Command<Message>? {
        nil
    }
    
    public func update(_ message: Message) -> (MarkdownEditorModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch model.mode {
            case .normal:
                return handleNormalMode(model: &model, key: key)
            case .insert:
                return handleInsertMode(model: &model, key: key)
            case .visual:
                return handleVisualMode(model: &model, key: key)
            case .command(let partial):
                return handleCommandMode(model: &model, key: key, partial: partial)
            }
            
        case .windowSize(let size):
            model.windowWidth = size.width
            model.windowHeight = size.height
            return (model, nil)
            
        case .fileLoaded(let content):
            model.content = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if model.content.isEmpty {
                model.content = [""]
            }
            model.cursorLine = 0
            model.cursorColumn = 0
            model.isDirty = false
            model.statusMessage = "File loaded"
            return (model, nil)
            
        case .fileSaved:
            model.isDirty = false
            model.statusMessage = "File saved"
            return (model, nil)
            
        case .error(let message):
            model.statusMessage = "Error: \(message)"
            return (model, nil)
        }
    }
    
    public func view() -> String {
        var output = ""
        
        // Calculate dimensions
        let statusHeight = 2
        let editorHeight = windowHeight - statusHeight
        let editorWidth = showPreview ? windowWidth / 2 : windowWidth
        
        // Main content area
        if showPreview {
            let editor = renderEditor(width: editorWidth, height: editorHeight)
            let preview = renderPreview(width: windowWidth - editorWidth, height: editorHeight)
            
            // Combine side by side
            let editorLines = editor.split(separator: "\n", omittingEmptySubsequences: false)
            let previewLines = preview.split(separator: "\n", omittingEmptySubsequences: false)
            
            for i in 0..<editorHeight {
                if i < editorLines.count {
                    output += String(editorLines[i])
                }
                output += "\u{1B}[0m" // Reset colors
                if i < previewLines.count {
                    output += String(previewLines[i])
                }
                output += "\n"
            }
        } else {
            output += renderEditor(width: windowWidth, height: editorHeight)
        }
        
        // Status line
        output += renderStatusLine()
        
        return output
    }
}

// MARK: - Rendering

extension MarkdownEditorModel {
    func renderEditor(width: Int, height: Int) -> String {
        var output = ""
        
        // Calculate visible range
        let scrollOffset = max(0, cursorLine - height / 2)
        let visibleLines = scrollOffset..<min(content.count, scrollOffset + height)
        
        for (idx, lineIdx) in visibleLines.enumerated() {
            let line = content[lineIdx]
            
            // Line number
            output += String(format: "\u{1B}[90m%3d \u{1B}[0m", lineIdx + 1)
            
            // Highlight current line in visual mode
            if mode.isVisual && isLineSelected(lineIdx) {
                output += "\u{1B}[44m" // Blue background
            }
            
            // Apply syntax highlighting
            let highlighted = applySyntaxHighlighting(to: line)
            output += highlighted
            
            // Clear to end of line
            let lineLength = 4 + stripAnsi(line).count
            if lineLength < width {
                output += String(repeating: " ", count: width - lineLength)
            }
            
            output += "\u{1B}[0m" // Reset
            
            if idx < height - 1 {
                output += "\n"
            }
        }
        
        // Fill remaining space
        for i in visibleLines.count..<height {
            output += "\u{1B}[90m~\u{1B}[0m"
            output += String(repeating: " ", count: width - 1)
            if i < height - 1 {
                output += "\n"
            }
        }
        
        // Show cursor
        if case .insert = mode {
            let cursorY = cursorLine - scrollOffset + 1
            let cursorX = 5 + cursorColumn // 4 for line number + 1 space
            if cursorY > 0 && cursorY <= height {
                output = insertCursor(in: output, at: cursorX, line: cursorY)
            }
        }
        
        return output
    }
    
    func renderPreview(width: Int, height: Int) -> String {
        var output = ""
        
        // Simple markdown rendering
        let rendered = renderMarkdown(content.joined(separator: "\n"))
        let lines = rendered.split(separator: "\n", omittingEmptySubsequences: false)
        
        output += "│ \u{1B}[1mPreview\u{1B}[0m\n"
        
        for i in 1..<height {
            output += "│ "
            if i - 1 < lines.count {
                let line = String(lines[i - 1])
                output += line
                let lineLength = stripAnsi(line).count
                if lineLength < width - 2 {
                    output += String(repeating: " ", count: width - 2 - lineLength)
                }
            } else {
                output += String(repeating: " ", count: width - 2)
            }
            if i < height - 1 {
                output += "\n"
            }
        }
        
        return output
    }
    
    func renderStatusLine() -> String {
        var status = ""
        
        // Mode indicator
        status += " \(mode.color)■ \(mode.indicator)\u{1B}[0m "
        
        // File info
        if let filename = filename {
            status += " \(filename)"
        } else {
            status += " [No Name]"
        }
        
        if isDirty {
            status += " [+]"
        }
        
        // Position
        let position = " \(cursorLine + 1):\(cursorColumn + 1) "
        
        // Status message
        let messageSpace = windowWidth - status.count - position.count - 2
        if messageSpace > 0 {
            status += " │ \(statusMessage)"
            let padding = messageSpace - statusMessage.count - 3
            if padding > 0 {
                status += String(repeating: " ", count: padding)
            }
        }
        
        status += position
        
        // Command line
        if case .command(let partial) = mode {
            return " :\(partial)█"
        }
        
        return status
    }
    
    func applySyntaxHighlighting(to line: String) -> String {
        var highlighted = line
        
        // Headers
        if line.starts(with: "#") {
            let level = line.prefix(while: { $0 == "#" }).count
            let color = level == 1 ? "\u{1B}[1;35m" : "\u{1B}[1;36m" // Magenta/Cyan
            highlighted = color + line + "\u{1B}[0m"
        }
        // Bold
        else if line.contains("**") {
            highlighted = line.replacingOccurrences(of: "**", with: "\u{1B}[1m")
                + "\u{1B}[0m"
        }
        // Italic
        else if line.contains("*") || line.contains("_") {
            highlighted = "\u{1B}[3m" + line + "\u{1B}[0m"
        }
        // Code blocks
        else if line.starts(with: "```") {
            highlighted = "\u{1B}[90m" + line + "\u{1B}[0m"
        }
        // Lists
        else if line.starts(with: "- ") || line.starts(with: "* ") || line.starts(with: "+ ") {
            highlighted = "\u{1B}[33m" + String(line.prefix(2)) + "\u{1B}[0m" + String(line.dropFirst(2))
        }
        // Numbered lists
        else if let match = line.firstMatch(of: /^\d+\. /) {
            let prefix = String(line[match.range])
            highlighted = "\u{1B}[33m" + prefix + "\u{1B}[0m" + String(line.dropFirst(prefix.count))
        }
        // Links
        else if line.contains("[") && line.contains("](") && line.contains(")") {
            highlighted = "\u{1B}[34m" + line + "\u{1B}[0m"
        }
        
        return highlighted
    }
    
    func renderMarkdown(_ markdown: String) -> String {
        var rendered = ""
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        
        for line in lines {
            var processedLine = String(line)
            
            // Headers
            if processedLine.starts(with: "#") {
                let level = processedLine.prefix(while: { $0 == "#" }).count
                processedLine = String(processedLine.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                processedLine = "\u{1B}[1m" + processedLine + "\u{1B}[0m" // Bold
            }
            // Bold
            else {
                processedLine = processedLine.replacingOccurrences(of: "**", with: "\u{1B}[1m")
            }
            
            rendered += processedLine + "\n"
        }
        
        return rendered
    }
    
    func insertCursor(in text: String, at column: Int, line: Int) -> String {
        // This is a simplified cursor insertion
        return text
    }
    
    func stripAnsi(_ text: String) -> String {
        // Remove ANSI escape sequences
        let pattern = "\u{1B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    
    func isLineSelected(_ line: Int) -> Bool {
        guard let start = visualStart else { return false }
        return line >= min(start.line, cursorLine) && line <= max(start.line, cursorLine)
    }
}

// MARK: - Mode Extensions

extension MarkdownEditorModel.EditorMode {
    var isVisual: Bool {
        if case .visual = self { return true }
        return false
    }
}

// MARK: - Input Handling

func handleNormalMode(model: inout MarkdownEditorModel, key: KeyMsg) -> (MarkdownEditorModel, Command<MarkdownEditorModel.Message>?) {
    switch key.type {
    case .character(let char):
        switch char {
        // Movement
        case "h":
            if model.cursorColumn > 0 {
                model.cursorColumn -= 1
            }
        case "j":
            if model.cursorLine < model.content.count - 1 {
                model.cursorLine += 1
                let lineLength = model.content[model.cursorLine].count
                model.cursorColumn = min(model.cursorColumn, lineLength)
            }
        case "k":
            if model.cursorLine > 0 {
                model.cursorLine -= 1
                let lineLength = model.content[model.cursorLine].count
                model.cursorColumn = min(model.cursorColumn, lineLength)
            }
        case "l":
            let lineLength = model.content[model.cursorLine].count
            if model.cursorColumn < lineLength {
                model.cursorColumn += 1
            }
            
        // Mode changes
        case "i":
            model.mode = .insert
            model.statusMessage = "-- INSERT --"
        case "a":
            model.mode = .insert
            let lineLength = model.content[model.cursorLine].count
            if model.cursorColumn < lineLength {
                model.cursorColumn += 1
            }
            model.statusMessage = "-- INSERT --"
        case "o":
            model.mode = .insert
            model.content.insert("", at: model.cursorLine + 1)
            model.cursorLine += 1
            model.cursorColumn = 0
            model.isDirty = true
            model.statusMessage = "-- INSERT --"
        case "v":
            model.mode = .visual
            model.visualStart = (line: model.cursorLine, column: model.cursorColumn)
            model.statusMessage = "-- VISUAL --"
            
        // Edit commands
        case "d":
            // dd - delete line
            if !model.content.isEmpty {
                model.yankBuffer = model.content[model.cursorLine]
                model.content.remove(at: model.cursorLine)
                if model.content.isEmpty {
                    model.content = [""]
                }
                if model.cursorLine >= model.content.count {
                    model.cursorLine = model.content.count - 1
                }
                model.cursorColumn = 0
                model.isDirty = true
                model.statusMessage = "Line deleted"
            }
        case "y":
            // yy - yank line
            model.yankBuffer = model.content[model.cursorLine]
            model.statusMessage = "Line yanked"
        case "p":
            // Paste
            if !model.yankBuffer.isEmpty {
                model.content.insert(model.yankBuffer, at: model.cursorLine + 1)
                model.cursorLine += 1
                model.cursorColumn = 0
                model.isDirty = true
                model.statusMessage = "Pasted"
            }
            
        // Commands
        case ":":
            model.mode = .command("")
            
        // Other
        case "P":
            model.showPreview.toggle()
            
        default:
            break
        }
        
    case .escape:
        // Already in normal mode
        break
        
    case .ctrlC:
        return (model, quit())
        
    default:
        break
    }
    
    return (model, nil)
}

func handleInsertMode(model: inout MarkdownEditorModel, key: KeyMsg) -> (MarkdownEditorModel, Command<MarkdownEditorModel.Message>?) {
    switch key.type {
    case .character(let char):
        let line = model.content[model.cursorLine]
        let index = line.index(line.startIndex, offsetBy: model.cursorColumn)
        model.content[model.cursorLine] = String(line.prefix(upTo: index)) + String(char) + String(line.suffix(from: index))
        model.cursorColumn += 1
        model.isDirty = true
        
    case .backspace:
        if model.cursorColumn > 0 {
            let line = model.content[model.cursorLine]
            let index = line.index(line.startIndex, offsetBy: model.cursorColumn - 1)
            let endIndex = line.index(line.startIndex, offsetBy: model.cursorColumn)
            model.content[model.cursorLine] = String(line.prefix(upTo: index)) + String(line.suffix(from: endIndex))
            model.cursorColumn -= 1
            model.isDirty = true
        } else if model.cursorLine > 0 {
            // Join with previous line
            let currentLine = model.content.remove(at: model.cursorLine)
            model.cursorLine -= 1
            model.cursorColumn = model.content[model.cursorLine].count
            model.content[model.cursorLine] += currentLine
            model.isDirty = true
        }
        
    case .enter:
        let line = model.content[model.cursorLine]
        let index = line.index(line.startIndex, offsetBy: model.cursorColumn)
        let before = String(line.prefix(upTo: index))
        let after = String(line.suffix(from: index))
        model.content[model.cursorLine] = before
        model.content.insert(after, at: model.cursorLine + 1)
        model.cursorLine += 1
        model.cursorColumn = 0
        model.isDirty = true
        
    case .escape:
        model.mode = .normal
        model.statusMessage = "Ready"
        if model.cursorColumn > 0 {
            model.cursorColumn -= 1
        }
        
    default:
        break
    }
    
    return (model, nil)
}

func handleVisualMode(model: inout MarkdownEditorModel, key: KeyMsg) -> (MarkdownEditorModel, Command<MarkdownEditorModel.Message>?) {
    switch key.type {
    case .character(let char):
        switch char {
        // Movement (same as normal)
        case "h", "j", "k", "l":
            return handleNormalMode(model: &model, key: key)
            
        // Operations
        case "d":
            // Delete selected lines
            if let start = model.visualStart {
                let startLine = min(start.line, model.cursorLine)
                let endLine = max(start.line, model.cursorLine)
                let deleted = model.content[startLine...endLine]
                model.yankBuffer = deleted.joined(separator: "\n")
                model.content.removeSubrange(startLine...endLine)
                if model.content.isEmpty {
                    model.content = [""]
                }
                model.cursorLine = min(startLine, model.content.count - 1)
                model.cursorColumn = 0
                model.mode = .normal
                model.visualStart = nil
                model.isDirty = true
                model.statusMessage = "\(endLine - startLine + 1) lines deleted"
            }
            
        case "y":
            // Yank selected lines
            if let start = model.visualStart {
                let startLine = min(start.line, model.cursorLine)
                let endLine = max(start.line, model.cursorLine)
                let yanked = model.content[startLine...endLine]
                model.yankBuffer = yanked.joined(separator: "\n")
                model.mode = .normal
                model.visualStart = nil
                model.statusMessage = "\(endLine - startLine + 1) lines yanked"
            }
            
        default:
            break
        }
        
    case .escape:
        model.mode = .normal
        model.visualStart = nil
        model.statusMessage = "Ready"
        
    default:
        break
    }
    
    return (model, nil)
}

func handleCommandMode(model: inout MarkdownEditorModel, key: KeyMsg, partial: String) -> (MarkdownEditorModel, Command<MarkdownEditorModel.Message>?) {
    var newPartial = partial
    
    switch key.type {
    case .character(let char):
        newPartial.append(char)
        model.mode = .command(newPartial)
        
    case .backspace:
        if !newPartial.isEmpty {
            newPartial.removeLast()
            model.mode = .command(newPartial)
        } else {
            model.mode = .normal
            model.statusMessage = "Ready"
        }
        
    case .enter:
        model.mode = .normal
        
        // Execute command
        let parts = newPartial.split(separator: " ")
        if let cmd = parts.first {
            switch cmd {
            case "w", "write":
                if parts.count > 1 {
                    model.filename = String(parts[1])
                }
                if let filename = model.filename {
                    return (model, saveFile(filename: filename, content: model.content.joined(separator: "\n")))
                } else {
                    model.statusMessage = "No filename"
                }
                
            case "q", "quit":
                if model.isDirty {
                    model.statusMessage = "Unsaved changes! Use :q! to force quit"
                } else {
                    return (model, quit())
                }
                
            case "q!":
                return (model, quit())
                
            case "wq":
                if let filename = model.filename {
                    // Save then quit
                    return (model, batch(
                        saveFile(filename: filename, content: model.content.joined(separator: "\n")),
                        quit()
                    ))
                } else {
                    model.statusMessage = "No filename"
                }
                
            case "e", "edit":
                if parts.count > 1 {
                    let filename = String(parts[1])
                    model.filename = filename
                    return (model, loadFile(filename: filename))
                } else {
                    model.statusMessage = "Usage: :e filename"
                }
                
            default:
                model.statusMessage = "Unknown command: \(cmd)"
            }
        }
        
    case .escape:
        model.mode = .normal
        model.statusMessage = "Ready"
        
    default:
        break
    }
    
    return (model, nil)
}

// MARK: - Commands

func saveFile(filename: String, content: String) -> Command<MarkdownEditorModel.Message> {
    Command { () async -> MarkdownEditorModel.Message? in
        do {
            try content.write(toFile: filename, atomically: true, encoding: .utf8)
            return .fileSaved
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

func loadFile(filename: String) -> Command<MarkdownEditorModel.Message> {
    Command { () async -> MarkdownEditorModel.Message? in
        do {
            let content = try String(contentsOfFile: filename)
            return .fileLoaded(content)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

// MARK: - Main

let options = ProgramOptions(
    altScreen: true,
    mouseEnabled: false
)

let program = Program(
    initialModel: MarkdownEditorModel(),
    options: options
)

do {
    try await program.run()
} catch {
    print("Error: \(error)")
    exit(1)
}