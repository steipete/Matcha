import Foundation
import Matcha
import MatchaStyle

// MARK: - Model

struct ExecModel: Model {
    // MARK: - Messages
    enum Msg: Message {
        case key(Key)
        case commandFinished(stdout: String, stderr: String, exitCode: Int32)
    }
    
    // MARK: - State
    var command: String = ""
    var output: String = ""
    var isRunning: Bool = false
    var error: String = ""
    
    // MARK: - Model Protocol
    init() {}
    
    func `init`() -> Command<Msg>? {
        nil
    }
    
    func update(_ message: Msg) -> (ExecModel, Command<Msg>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key.type {
            case .runes where key.runes.contains("q"), .control("c"):
                return (model, quit())
                
            case .runes where key.runes.contains("l"):
                // Run ls command
                model.isRunning = true
                model.output = ""
                model.error = ""
                model.command = "ls -la"
                // Create a custom command that runs a process
                let cmd = Command<Msg> { () async -> Msg? in
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/ls")
                    process.arguments = ["-la"]
                    
                    let pipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = errorPipe
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        
                        let output = String(data: data, encoding: .utf8) ?? ""
                        let error = String(data: errorData, encoding: .utf8) ?? ""
                        
                        return Msg.commandFinished(stdout: output, stderr: error, exitCode: process.terminationStatus)
                    } catch {
                        return Msg.commandFinished(stdout: "", stderr: error.localizedDescription, exitCode: -1)
                    }
                }
                return (model, cmd)
                
            case .runes where key.runes.contains("d"):
                // Run date command
                model.isRunning = true
                model.output = ""
                model.error = ""
                model.command = "date"
                let cmd = Command<Msg> { () async -> Msg? in
                    let formatter = DateFormatter()
                    formatter.dateStyle = .full
                    formatter.timeStyle = .full
                    let dateString = formatter.string(from: Date())
                    return Msg.commandFinished(stdout: dateString, stderr: "", exitCode: 0)
                }
                return (model, cmd)
                
            case .runes where key.runes.contains("p"):
                // Run pwd command
                model.isRunning = true
                model.output = ""
                model.error = ""
                model.command = "pwd"
                let cmd = Command<Msg> { () async -> Msg? in
                    let pwd = FileManager.default.currentDirectoryPath
                    return Msg.commandFinished(stdout: pwd, stderr: "", exitCode: 0)
                }
                return (model, cmd)
                
            case .runes where key.runes.contains("e"):
                // Run echo command
                model.isRunning = true
                model.output = ""
                model.error = ""
                model.command = "echo 'Hello from Matcha!'"
                let cmd = Command<Msg> { () async -> Msg? in
                    return Msg.commandFinished(stdout: "Hello from Matcha!", stderr: "", exitCode: 0)
                }
                return (model, cmd)
                
            case .runes where key.runes.contains("f"):
                // Run a failing command
                model.isRunning = true
                model.output = ""
                model.error = ""
                model.command = "false"
                let cmd = Command<Msg> { () async -> Msg? in
                    return Msg.commandFinished(stdout: "", stderr: "Command failed", exitCode: 1)
                }
                return (model, cmd)
                
            default:
                break
            }
            
        case .commandFinished(let stdout, let stderr, let exitCode):
            model.isRunning = false
            if exitCode == 0 {
                model.output = stdout
                model.error = ""
            } else {
                model.output = stdout
                model.error = "Command failed with exit code: \(exitCode)\n\(stderr)"
            }
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        var lines: [String] = []
        
        // Title
        lines.append(style.bold().render("Command Execution Example"))
        lines.append("")
        
        // Instructions
        lines.append("Press a key to run a command:")
        lines.append("  l - List files (ls -la)")
        lines.append("  d - Show date")
        lines.append("  p - Print working directory")
        lines.append("  e - Echo a message")
        lines.append("  f - Run failing command")
        lines.append("  q - Quit")
        lines.append("")
        
        // Status
        if isRunning {
            lines.append(style.foreground(.yellow).render("Running: \(command)..."))
            lines.append("")
        } else if !command.isEmpty {
            lines.append(style.foreground(.cyan).render("Last command: \(command)"))
            lines.append("")
        }
        
        // Output
        if !output.isEmpty {
            lines.append(style.foreground(.green).render("Output:"))
            lines.append(style.faint().render(String(repeating: "─", count: 50)))
            lines.append(output)
            lines.append(style.faint().render(String(repeating: "─", count: 50)))
        }
        
        // Error
        if !error.isEmpty {
            lines.append(style.foreground(.red).render("Error:"))
            lines.append(style.faint().render(String(repeating: "─", count: 50)))
            lines.append(style.foreground(.red).render(error))
            lines.append(style.faint().render(String(repeating: "─", count: 50)))
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Main

let style = Style()

@main
struct ExecExample {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        options.mouseMode = .disabled
        
        let app = Program(
            initialModel: ExecModel(),
            options: options
        )
        
        _ = try await app.run()
    }
}