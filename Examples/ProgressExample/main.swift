import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - Model

public struct ProgressModel: Model {
    var progress: MatchaBubbles.Progress = MatchaBubbles.Progress()
    var downloadProgress: MatchaBubbles.Progress = MatchaBubbles.Progress()
    var animationProgress: MatchaBubbles.Progress = MatchaBubbles.Progress()
    var isRunning: Bool = false
    
    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(Key)
        case tick
        case start
        case reset
    }
    
    public init() {}
    
    public func `init`() -> Command<Message>? {
        nil
    }
    
    public func update(_ message: Message) -> (ProgressModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key.description {
            case " ", "space":
                return update(.start)
                
            case "r":
                return update(.reset)
                
            case "up":
                if model.progress.percent < 1.0 {
                    model.progress.setPercent(min(1.0, model.progress.percent + 0.1))
                }
                return (model, nil)
                
            case "down":
                if model.progress.percent > 0.0 {
                    model.progress.setPercent(max(0.0, model.progress.percent - 0.1))
                }
                return (model, nil)
                
            case "1":
                model.progress.style = .default
                return (model, nil)
                
            case "2":
                model.progress.style = .dots
                return (model, nil)
                
            case "3":
                model.progress.style = .solidBar
                return (model, nil)
                
            default:
                return (model, nil)
            }
            
        case .start:
            model.isRunning.toggle()
            if model.isRunning {
                return (model, Matcha.tick(.milliseconds(50)) { _ in Message.tick })
            }
            return (model, nil)
            
        case .reset:
            model.progress.setPercent(0)
            model.downloadProgress.setPercent(0)
            model.animationProgress.setPercent(0)
            model.isRunning = false
            return (model, nil)
            
        case .tick:
            if model.isRunning {
                // Update all progress bars
                model.downloadProgress.increment(0.015)
                model.animationProgress.increment(0.02)
                
                // Continue ticking if not complete
                if model.downloadProgress.percent < 1.0 || model.animationProgress.percent < 1.0 {
                    return (model, Matcha.tick(.milliseconds(50)) { _ in Message.tick })
                } else {
                    model.isRunning = false
                }
            }
            return (model, nil)
        }
    }
    
    public func view() -> String {
        var lines: [String] = []
        let style = Style()
        
        // Title
        lines.append(style.bold().render("Progress Bar Examples"))
        lines.append("")
        
        // Manual progress bar
        lines.append(style.foreground(.cyan).render("Manual Control (↑/↓):"))
        
        // Configure manual progress
        var manualProgress = progress
        manualProgress.width = 40
        manualProgress.showPercentage = true
        
        lines.append(manualProgress.view())
        lines.append("")
        
        // Download simulation
        lines.append(style.foreground(.green).render("Download Progress:"))
        
        var download = downloadProgress
        download.width = 40
        download.style = .solidBar
        download.fullChar = "█"
        download.emptyChar = "░"
        download.fullColor = style.foreground(.green)
        download.emptyColor = style.foreground(.brightBlack)
        download.showPercentage = true
        
        let downloadPercent = Int(download.percent * 100)
        let downloadStatus = isRunning && download.percent < 1.0 ? " Downloading..." : download.percent >= 1.0 ? " Complete!" : " Ready"
        lines.append("\(download.view())\(style.faint().render(downloadStatus))")
        lines.append("")
        
        // Animation progress
        lines.append(style.foreground(.magenta).render("Animation Progress:"))
        
        var animation = animationProgress
        animation.width = 40
        animation.style = .dots
        animation.fullColor = style.foreground(.magenta)
        animation.emptyColor = style.foreground(.brightBlack)
        animation.showPercentage = false
        
        let frames = Int(animation.percent * 60)
        let animStatus = isRunning && animation.percent < 1.0 ? " Frame \(frames)/60" : animation.percent >= 1.0 ? " Done!" : " Ready"
        lines.append("\(animation.view())\(style.faint().render(animStatus))")
        lines.append("")
        
        // Style examples
        lines.append(style.underline().render("Progress Bar Styles:"))
        
        // Default style
        var defaultBar = MatchaBubbles.Progress()
        defaultBar.setPercent(0.3)
        defaultBar.width = 30
        defaultBar.style = .default
        lines.append("Default:   \(defaultBar.view())")
        
        // Dots style
        var dotsBar = MatchaBubbles.Progress()
        dotsBar.setPercent(0.5)
        dotsBar.width = 30
        dotsBar.style = .dots
        lines.append("Dots:      \(dotsBar.view())")
        
        // Solid bar style
        var solidBar = MatchaBubbles.Progress()
        solidBar.setPercent(0.7)
        solidBar.width = 30
        solidBar.style = .solidBar
        lines.append("Solid:     \(solidBar.view())")
        
        lines.append("")
        
        // Controls
        lines.append(style.faint().render("Controls:"))
        lines.append(style.faint().render("  ↑/↓     - Adjust manual progress"))
        lines.append(style.faint().render("  1/2/3   - Change manual bar style"))
        lines.append(style.faint().render("  Space   - Start/stop animation"))
        lines.append(style.faint().render("  r       - Reset all"))
        lines.append(style.faint().render("  q       - Quit"))
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Main

@main
enum ProgressApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        
        // Add a filter to convert messages
        options.filter = { _, message in
            switch message {
            case let key as Key:
                switch key.description {
                case "q", "ctrl+c":
                    return QuitMsg()
                default:
                    return ProgressModel.Message.key(key)
                }
            default:
                return message
            }
        }
        
        let program = Program(initialModel: ProgressModel(), options: options)
        _ = try await program.run()
    }
}