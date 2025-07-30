import Foundation
import Matcha

// MARK: - DashboardModel

public struct DashboardModel: Model {
    // Component states
    var selectedPanel: Panel = .metrics
    var metricsData = MetricsData()
    var logEntries: [LogEntry] = []
    var taskList: [Task] = Task.sampleTasks()
    var selectedTaskIndex: Int = 0
    var commandInput: String = ""
    var isCommandMode: Bool = false
    var lastUpdate = Date()

    // Window dimensions
    var windowWidth: Int = 80
    var windowHeight: Int = 24

    // Scroll positions
    var logScrollOffset: Int = 0
    var taskScrollOffset: Int = 0

    enum Panel {
        case metrics
        case logs
        case tasks

        var title: String {
            switch self {
            case .metrics: "System Metrics"
            case .logs: "Activity Logs"
            case .tasks: "Task Manager"
            }
        }
    }

    struct MetricsData {
        var cpuUsage: Double = 45.2
        var memoryUsage: Double = 62.8
        var diskUsage: Double = 78.1
        var networkIn: Double = 125.4 // KB/s
        var networkOut: Double = 89.2 // KB/s

        mutating func randomUpdate() {
            cpuUsage = max(0, min(100, cpuUsage + Double.random(in: -5...5)))
            memoryUsage = max(0, min(100, memoryUsage + Double.random(in: -3...3)))
            diskUsage = max(0, min(100, diskUsage + Double.random(in: -1...1)))
            networkIn = max(0, networkIn + Double.random(in: -20...20))
            networkOut = max(0, networkOut + Double.random(in: -15...15))
        }
    }

    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String

        enum LogLevel {
            case info
            case warning
            case error

            var symbol: String {
                switch self {
                case .info: "ℹ"
                case .warning: "⚠"
                case .error: "✖"
                }
            }

            var color: String {
                switch self {
                case .info: "\u{1B}[34m" // Blue
                case .warning: "\u{1B}[33m" // Yellow
                case .error: "\u{1B}[31m" // Red
                }
            }
        }

        static func random() -> LogEntry {
            let messages = [
                (LogLevel.info, "System check completed successfully"),
                (LogLevel.info, "User session started"),
                (LogLevel.warning, "High memory usage detected"),
                (LogLevel.error, "Failed to connect to external service"),
                (LogLevel.info, "Background task completed"),
                (LogLevel.warning, "Disk space running low"),
                (LogLevel.info, "Configuration updated"),
                (LogLevel.error, "Network timeout occurred"),
            ]
            let (level, message) = messages.randomElement()!
            return LogEntry(timestamp: Date(), level: level, message: message)
        }
    }

    struct Task {
        let id: UUID
        var title: String
        var status: Status
        var progress: Int // 0-100

        enum Status {
            case pending
            case running
            case completed
            case failed

            var symbol: String {
                switch self {
                case .pending: "○"
                case .running: "◉"
                case .completed: "✓"
                case .failed: "✗"
                }
            }

            var color: String {
                switch self {
                case .pending: "\u{1B}[37m" // White
                case .running: "\u{1B}[36m" // Cyan
                case .completed: "\u{1B}[32m" // Green
                case .failed: "\u{1B}[31m" // Red
                }
            }
        }

        static func sampleTasks() -> [Task] {
            [
                Task(id: UUID(), title: "Initialize database", status: .completed, progress: 100),
                Task(id: UUID(), title: "Load configuration", status: .completed, progress: 100),
                Task(id: UUID(), title: "Process data batch #1", status: .running, progress: 67),
                Task(id: UUID(), title: "Process data batch #2", status: .pending, progress: 0),
                Task(id: UUID(), title: "Generate reports", status: .pending, progress: 0),
                Task(id: UUID(), title: "Send notifications", status: .pending, progress: 0),
                Task(id: UUID(), title: "Cleanup temporary files", status: .pending, progress: 0),
            ]
        }
    }

    // MARK: - Messages

    public enum Message: Matcha.Message {
        case tick
        case key(KeyMsg)
        case mouse(MouseMsg)
        case windowSize(WindowSizeMsg)
        case selectPanel(Panel)
        case scrollLogs(Int)
        case scrollTasks(Int)
        case toggleTask
        case enterCommandMode
        case exitCommandMode
        case executeCommand
        case updateCommandInput(String)
    }

    // MARK: - Model Protocol

    public init() {}

    public func `init`() -> Command<Message>? {
        // Start the tick timer for real-time updates
        tick()
    }

    public func update(_ message: Message) -> (DashboardModel, Command<Message>?) {
        var model = self

        switch message {
        case .tick:
            // Update metrics
            model.metricsData.randomUpdate()
            model.lastUpdate = Date()

            // Occasionally add a new log entry
            if Int.random(in: 0...2) == 0 {
                model.logEntries.insert(LogEntry.random(), at: 0)
                // Keep log size manageable
                if model.logEntries.count > 100 {
                    model.logEntries.removeLast()
                }
            }

            // Update running tasks
            for i in 0..<model.taskList.count {
                if model.taskList[i].status == .running {
                    model.taskList[i].progress = min(100, model.taskList[i].progress + Int.random(in: 1...5))
                    if model.taskList[i].progress >= 100 {
                        model.taskList[i].status = .completed
                        // Start the next pending task
                        if let nextIndex = model.taskList.firstIndex(where: { $0.status == .pending }) {
                            model.taskList[nextIndex].status = .running
                        }
                    }
                }
            }

            return (model, tick())

        case let .key(key):
            if model.isCommandMode {
                return handleCommandMode(model: &model, key: key)
            } else {
                return handleNormalMode(model: &model, key: key)
            }

        case let .mouse(mouse):
            return handleMouse(model: &model, mouse: mouse)

        case let .windowSize(size):
            model.windowWidth = size.width
            model.windowHeight = size.height
            return (model, nil)

        case let .selectPanel(panel):
            model.selectedPanel = panel
            return (model, nil)

        case let .scrollLogs(delta):
            let maxScroll = max(0, model.logEntries.count - 10)
            model.logScrollOffset = max(0, min(maxScroll, model.logScrollOffset + delta))
            return (model, nil)

        case let .scrollTasks(delta):
            let maxScroll = max(0, model.taskList.count - 5)
            model.taskScrollOffset = max(0, min(maxScroll, model.taskScrollOffset + delta))
            return (model, nil)

        case .toggleTask:
            if model.selectedTaskIndex < model.taskList.count {
                let task = model.taskList[model.selectedTaskIndex]
                switch task.status {
                case .pending:
                    model.taskList[model.selectedTaskIndex].status = .running
                case .running:
                    model.taskList[model.selectedTaskIndex].status = .pending
                    model.taskList[model.selectedTaskIndex].progress = 0
                case .completed,
                     .failed:
                    break // Can't toggle completed/failed tasks
                }
            }
            return (model, nil)

        case .enterCommandMode:
            model.isCommandMode = true
            model.commandInput = ""
            return (model, nil)

        case .exitCommandMode:
            model.isCommandMode = false
            model.commandInput = ""
            return (model, nil)

        case .executeCommand:
            // Execute the command
            let command = model.commandInput.trimmingCharacters(in: .whitespaces)
            model.isCommandMode = false
            model.commandInput = ""

            // Add command to logs
            model.logEntries.insert(
                LogEntry(timestamp: Date(), level: .info, message: "Command executed: \(command)"),
                at: 0
            )

            // Handle specific commands
            switch command {
            case "clear logs":
                model.logEntries = []
            case "reset tasks":
                model.taskList = Task.sampleTasks()
            case "exit",
                 "quit":
                return (model, quit())
            default:
                model.logEntries.insert(
                    LogEntry(timestamp: Date(), level: .warning, message: "Unknown command: \(command)"),
                    at: 0
                )
            }

            return (model, nil)

        case let .updateCommandInput(input):
            model.commandInput = input
            return (model, nil)
        }
    }

    public func view() -> String {
        var output = ""

        // Header
        output += renderHeader()
        output += "\n"

        // Main content area
        let contentHeight = windowHeight - 6 // Header + footer

        switch selectedPanel {
        case .metrics:
            output += renderMetrics(height: contentHeight)
        case .logs:
            output += renderLogs(height: contentHeight)
        case .tasks:
            output += renderTasks(height: contentHeight)
        }

        // Footer
        output += "\n"
        output += renderFooter()

        return output
    }
}

// MARK: - View Helpers

extension DashboardModel {
    func renderHeader() -> String {
        var header = ""
        let title = "╔═ System Dashboard ═╗"
        let padding = (windowWidth - title.count) / 2
        header += String(repeating: " ", count: max(0, padding)) + title + "\n"

        // Panel tabs
        header += " "
        for panel in [Panel.metrics, Panel.logs, Panel.tasks] {
            if panel == selectedPanel {
                header += "[\u{1B}[1m\u{1B}[36m\(panel.title)\u{1B}[0m] "
            } else {
                header += " \(panel.title)  "
            }
        }

        // Last update time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: lastUpdate)
        let timeInfo = "Last update: \(timeStr)"
        let spacer = windowWidth - header.count + 1 - timeInfo.count - 2
        if spacer > 0 {
            header += String(repeating: " ", count: spacer) + timeInfo
        }

        return header
    }

    func renderMetrics(height: Int) -> String {
        var output = ""

        // CPU Usage
        output += "\n  \u{1B}[1mCPU Usage:\u{1B}[0m\n"
        output += "  " + renderProgressBar(value: metricsData.cpuUsage, width: 40) + " \(String(format: "%.1f", metricsData.cpuUsage))%\n"

        // Memory Usage
        output += "\n  \u{1B}[1mMemory Usage:\u{1B}[0m\n"
        output += "  " + renderProgressBar(value: metricsData.memoryUsage, width: 40) + " \(String(format: "%.1f", metricsData.memoryUsage))%\n"

        // Disk Usage
        output += "\n  \u{1B}[1mDisk Usage:\u{1B}[0m\n"
        output += "  " + renderProgressBar(value: metricsData.diskUsage, width: 40) + " \(String(format: "%.1f", metricsData.diskUsage))%\n"

        // Network
        output += "\n  \u{1B}[1mNetwork:\u{1B}[0m\n"
        output += "  ↓ In:  \(String(format: "%6.1f", metricsData.networkIn)) KB/s\n"
        output += "  ↑ Out: \(String(format: "%6.1f", metricsData.networkOut)) KB/s\n"

        return output
    }

    func renderLogs(height: Int) -> String {
        var output = ""

        output += "┌─ Recent Activity ─┐\n"

        let visibleLogs = min(height - 2, 10)
        let endIndex = min(logEntries.count, logScrollOffset + visibleLogs)

        for i in logScrollOffset..<endIndex {
            let entry = logEntries[i]
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: entry.timestamp)

            output += " \(time) \(entry.level.color)\(entry.level.symbol)\u{1B}[0m \(entry.message)\n"
        }

        // Fill empty space
        for _ in endIndex..<(logScrollOffset + visibleLogs) {
            output += "\n"
        }

        // Scroll indicator
        if logEntries.count > visibleLogs {
            let scrollPos = logEntries.isEmpty ? 0 : (logScrollOffset * 100) / max(1, logEntries.count - visibleLogs)
            output += " [\(scrollPos)%] Use ↑/↓ to scroll\n"
        }

        return output
    }

    func renderTasks(height: Int) -> String {
        var output = ""

        output += "┌─ Task Manager ─┐\n"

        let visibleTasks = min(height - 2, 8)
        let endIndex = min(taskList.count, taskScrollOffset + visibleTasks)

        for i in taskScrollOffset..<endIndex {
            let task = taskList[i]
            let isSelected = i == selectedTaskIndex

            if isSelected {
                output += "\u{1B}[7m" // Reverse video
            }

            output += " \(task.status.color)\(task.status.symbol)\u{1B}[0m "
            output += task.title

            // Progress bar for running tasks
            if task.status == .running {
                let barWidth = 15
                let filled = (task.progress * barWidth) / 100
                let progressBar = String(repeating: "█", count: filled) + String(
                    repeating: "░",
                    count: barWidth - filled
                )
                output += " [\(progressBar)] \(task.progress)%"
            }

            if isSelected {
                output += "\u{1B}[0m" // Reset
            }

            output += "\n"
        }

        // Fill empty space
        for _ in endIndex..<(taskScrollOffset + visibleTasks) {
            output += "\n"
        }

        return output
    }

    func renderFooter() -> String {
        if isCommandMode {
            return " Command: \(commandInput)█"
        } else {
            let shortcuts = "Tab: Switch Panel | ↑/↓: Navigate | Space: Toggle | :: Command | q: Quit"
            let padding = (windowWidth - shortcuts.count) / 2
            return String(repeating: " ", count: max(0, padding)) + shortcuts
        }
    }

    func renderProgressBar(value: Double, width: Int) -> String {
        let filled = Int((value / 100.0) * Double(width))
        let color = if value > 80 {
            "\u{1B}[31m" // Red
        } else if value > 60 {
            "\u{1B}[33m" // Yellow
        } else {
            "\u{1B}[32m" // Green
        }

        return color + String(repeating: "█", count: filled) + "\u{1B}[0m" + String(
            repeating: "░",
            count: width - filled
        )
    }
}

// MARK: - Input Handling

func handleNormalMode(model: inout DashboardModel, key: KeyMsg) -> (DashboardModel, Command<DashboardModel.Message>?) {
    switch key.type {
    case let .character(char):
        switch char {
        case "q",
             "Q":
            return (model, quit())
        case ":":
            return (model, Command { .enterCommandMode })
        case " ":
            if model.selectedPanel == .tasks {
                return (model, Command { .toggleTask })
            }
        default:
            break
        }

    case .tab:
        // Cycle through panels
        switch model.selectedPanel {
        case .metrics:
            model.selectedPanel = .logs
        case .logs:
            model.selectedPanel = .tasks
        case .tasks:
            model.selectedPanel = .metrics
        }

    case .up:
        switch model.selectedPanel {
        case .logs:
            return (model, Command { .scrollLogs(-1) })
        case .tasks:
            if model.selectedTaskIndex > 0 {
                model.selectedTaskIndex -= 1
                // Adjust scroll if needed
                if model.selectedTaskIndex < model.taskScrollOffset {
                    model.taskScrollOffset = model.selectedTaskIndex
                }
            }
        default:
            break
        }

    case .down:
        switch model.selectedPanel {
        case .logs:
            return (model, Command { .scrollLogs(1) })
        case .tasks:
            if model.selectedTaskIndex < model.taskList.count - 1 {
                model.selectedTaskIndex += 1
                // Adjust scroll if needed
                let visibleTasks = 8
                if model.selectedTaskIndex >= model.taskScrollOffset + visibleTasks {
                    model.taskScrollOffset = model.selectedTaskIndex - visibleTasks + 1
                }
            }
        default:
            break
        }

    case .ctrlC,
         .escape:
        return (model, quit())

    default:
        break
    }

    return (model, nil)
}

func handleCommandMode(model: inout DashboardModel, key: KeyMsg) -> (DashboardModel, Command<DashboardModel.Message>?) {
    switch key.type {
    case let .character(char):
        model.commandInput.append(char)

    case .backspace:
        _ = model.commandInput.popLast()

    case .enter:
        return (model, Command { .executeCommand })

    case .escape:
        return (model, Command { .exitCommandMode })

    default:
        break
    }

    return (model, nil)
}

func handleMouse(model: inout DashboardModel, mouse: MouseMsg) -> (DashboardModel, Command<DashboardModel.Message>?) {
    // Handle panel selection by clicking on tabs
    if mouse.y == 2, mouse.action == .press, mouse.type == .left {
        if mouse.x < 20 {
            model.selectedPanel = .metrics
        } else if mouse.x < 35 {
            model.selectedPanel = .logs
        } else if mouse.x < 50 {
            model.selectedPanel = .tasks
        }
    }

    // Handle scrolling
    if mouse.action == .wheel {
        switch model.selectedPanel {
        case .logs:
            let delta = mouse.y > 0 ? 3 : -3
            return (model, Command { .scrollLogs(delta) })
        case .tasks:
            let delta = mouse.y > 0 ? 1 : -1
            return (model, Command { .scrollTasks(delta) })
        default:
            break
        }
    }

    return (model, nil)
}

// MARK: - Commands

func tick() -> Command<DashboardModel.Message> {
    Command { () async -> DashboardModel.Message? in
        try? await Task.sleep(for: .seconds(1))
        return .tick
    }
}

// MARK: - Main

let options = ProgramOptions(
    altScreen: true,
    mouseEnabled: true,
    mouseAllMotion: false,
    reportFocus: true
)

let program = Program(
    initialModel: DashboardModel(),
    options: options
)

do {
    try await program.run()
} catch {
    print("Error: \(error)")
    exit(1)
}
