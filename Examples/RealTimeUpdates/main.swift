//
//  main.swift
//  Real-Time Updates Example
//
//  Demonstrates real-time data updates with smooth animations.
//

import Foundation
import Matcha
import MatchaStyle
import MatchaBubbles

/// Real-time dashboard showing live data updates
struct RealTimeModel: Model {
    typealias Msg = Message
    
    enum Message: Matcha.Message {
        case tick
        case updateMetrics(Metrics)
        case updateLogs(String)
        case clearLogs
        case togglePause
        case quit
    }
    
    struct Metrics {
        let cpu: Double
        let memory: Double
        let network: Double
        let timestamp: Date
    }
    
    // State
    var metrics: [Metrics] = []
    var logs: [String] = []
    var isPaused: Bool = false
    var tickCount: Int = 0
    
    // UI Components
    var cpuSparkline: String = ""
    var memoryBar: MatchaBubbles.Progress = {
        var p = MatchaBubbles.Progress()
        p.fullChar = "█"
        p.emptyChar = "░"
        p.width = 30
        return p
    }()
    
    init() {}
    
    func `init`() -> Command<Message>? {
        return every(.milliseconds(100)) { _ in .tick }
    }
    
    func update(_ message: Message) -> (RealTimeModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .tick:
            if !model.isPaused {
                model.tickCount += 1
                
                // Generate simulated metrics
                let newMetrics = Metrics(
                    cpu: Double.random(in: 20...80) + sin(Double(model.tickCount) * 0.1) * 10,
                    memory: Double.random(in: 40...70) + cos(Double(model.tickCount) * 0.15) * 5,
                    network: Double.random(in: 0...100),
                    timestamp: Date()
                )
                
                // Keep last 50 data points for sparkline
                model.metrics.append(newMetrics)
                if model.metrics.count > 50 {
                    model.metrics.removeFirst()
                }
                
                // Update sparkline
                model.cpuSparkline = generateSparkline(
                    data: model.metrics.map { $0.cpu },
                    width: 50
                )
                
                // Update progress bar
                model.memoryBar.percent = newMetrics.memory / 100.0
                
                // Simulate log entries
                if model.tickCount % 3 == 0 {
                    let logTypes = ["INFO", "WARN", "DEBUG", "ERROR"]
                    let logMessages = [
                        "Processing request from client",
                        "Cache hit for key: user_data",
                        "Connection established to database",
                        "Scheduled task completed",
                        "Memory threshold reached",
                        "Request timeout detected"
                    ]
                    
                    let logType = logTypes.randomElement()!
                    let logMsg = logMessages.randomElement()!
                    let timestamp = DateFormatter.localizedString(
                        from: Date(),
                        dateStyle: .none,
                        timeStyle: .medium
                    )
                    
                    return (model, .batch(
                        .pure(.updateMetrics(newMetrics)),
                        .pure(.updateLogs("[\(timestamp)] \(logType): \(logMsg)")),
                        every(.milliseconds(100)) { _ in .tick }
                    ))
                }
                
                return (model, .batch(
                    .pure(.updateMetrics(newMetrics)),
                    every(.milliseconds(100)) { _ in .tick }
                ))
            } else {
                // When paused, still schedule next tick
                return (model, every(.milliseconds(100)) { _ in .tick })
            }
            
        case .updateMetrics(let metrics):
            // Metrics already updated in tick
            return (model, nil)
            
        case .updateLogs(let log):
            model.logs.append(log)
            // Keep only last 10 logs
            if model.logs.count > 10 {
                model.logs.removeFirst()
            }
            return (model, nil)
            
        case .clearLogs:
            model.logs = []
            return (model, nil)
            
        case .togglePause:
            model.isPaused.toggle()
            return (model, nil)
            
        case .quit:
            return (model, quit())
        }
    }
    
    func view() -> String {
        var content = ""
        
        // Header
        let headerStyle = Style().bold().foreground(.cyan)
        content += headerStyle.render("Real-Time Dashboard")
        content += " - "
        content += Style().foreground(isPaused ? .red : .green).render(isPaused ? "PAUSED" : "LIVE")
        content += "\n"
        content += String(repeating: "─", count: 60)
        content += "\n\n"
        
        // Metrics Section
        if let latest = metrics.last {
            // CPU Usage with sparkline
            content += Style().bold().render("CPU Usage: ")
            content += String(format: "%.1f%%", latest.cpu)
            content += "\n"
            content += cpuSparkline
            content += "\n\n"
            
            // Memory Usage with progress bar
            content += Style().bold().render("Memory Usage: ")
            content += String(format: "%.1f%%", latest.memory)
            content += "\n"
            content += memoryBar.view()
            content += "\n\n"
            
            // Network Activity with simple meter
            content += Style().bold().render("Network I/O: ")
            let networkBar = generateMeter(value: latest.network, width: 30)
            content += networkBar
            content += String(format: " %.0f MB/s", latest.network)
            content += "\n\n"
        }
        
        // Logs Section
        content += Style().bold().underline().render("System Logs:")
        content += "\n"
        
        for log in logs {
            let logStyle: Style
            if log.contains("ERROR") {
                logStyle = Style().foreground(.red)
            } else if log.contains("WARN") {
                logStyle = Style().foreground(.yellow)
            } else if log.contains("DEBUG") {
                logStyle = Style().foreground(.brightBlack)
            } else {
                logStyle = Style().foreground(.white)
            }
            content += logStyle.render(log)
            content += "\n"
        }
        
        // Controls
        content += "\n"
        content += String(repeating: "─", count: 60)
        content += "\n"
        content += Style().faint().render("Space: Pause/Resume | c: Clear Logs | q: Quit")
        
        return content
    }
    
    private func generateSparkline(data: [Double], width: Int) -> String {
        guard !data.isEmpty else { return String(repeating: " ", count: width) }
        
        let sparkChars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 100
        let range = maxValue - minValue
        
        var result = ""
        
        // Sample or interpolate data to fit width
        let step = Swift.max(1, data.count / width)
        for i in 0..<width {
            let index = Swift.min(i * step, data.count - 1)
            let value = data[index]
            let normalized = range > 0 ? (value - minValue) / range : 0.5
            let charIndex = Int(normalized * Double(sparkChars.count - 1))
            result += sparkChars[Swift.max(0, Swift.min(charIndex, sparkChars.count - 1))]
        }
        
        return Style().foreground(.cyan).render(result)
    }
    
    private func generateMeter(value: Double, width: Int) -> String {
        let filled = Int((value / 100.0) * Double(width))
        let empty = width - filled
        
        var meter = "["
        meter += Style().foreground(.green).render(String(repeating: "=", count: filled))
        meter += String(repeating: "-", count: empty)
        meter += "]"
        
        return meter
    }
}

@main
struct RealTimeApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        options.filter = { _, message in
            if let key = message as? Key {
                switch key.description {
                case "q", "ctrl+c":
                    return QuitMsg()
                case " ":
                    return RealTimeModel.Message.togglePause
                case "c":
                    return RealTimeModel.Message.clearLogs
                default:
                    break
                }
            }
            return message
        }
        
        let program = Program(
            initialModel: RealTimeModel(),
            options: options
        )
        
        try await program.run()
    }
}