import Foundation
import Testing
@testable import Matcha

// MARK: - BubbleteeComparisonTests

/// Performance comparison tests between Matcha and Bubbletea
@Suite("Matcha vs Bubbletea Performance Comparison")
struct BubbleteeComparisonTests {
    let benchmarkRunner: BenchmarkRunner

    init() {
        var config = BenchmarkRunner.Configuration.default
        config.warmupIterations = 20
        config.iterations = 100
        config.printResults = true
        self.benchmarkRunner = BenchmarkRunner(configuration: config)
    }

    // MARK: - Model Update Performance Comparison

    @Test("Model update performance vs Bubbletea baseline")
    func modelUpdatePerformanceComparison() throws {
        // Bubbletea baseline: ~5-10 microseconds for simple model updates
        let bubbleteeBaseline = 0.00001 // 10 microseconds

        var model = CounterModel()

        benchmarkRunner.benchmark("Matcha Model Update") {
            let (newModel, _) = model.update(CounterModel.Message.increment)
            model = newModel
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        // We expect Matcha to be within 2x of Bubbletea's performance
        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha model update is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            (Bubbletea baseline: \(bubbleteeBaseline)s)
            """
        )
    }

    @Test("Complex model update with list operations")
    func complexModelUpdateComparison() throws {
        // Bubbletea baseline: ~50-100 microseconds for list operations
        let bubbleteeBaseline = 0.0001 // 100 microseconds

        var model = ListModel()
        model.items = (0..<1000).map { "Item \($0)" }

        benchmarkRunner.benchmark("Matcha List Model Update") {
            // Simulate list navigation
            let (newModel, _) = model.update(.moveDown)
            model = newModel
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha list update is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    // MARK: - View Rendering Performance Comparison

    @Test("View rendering performance vs Bubbletea")
    func viewRenderingComparison() throws {
        // Bubbletea baseline: ~20-50 microseconds for moderate views
        let bubbleteeBaseline = 0.00005 // 50 microseconds

        let model = DashboardModel(
            title: "Performance Test Dashboard",
            items: (0..<50).map { "Dashboard Item \($0)" },
            status: "Running benchmark..."
        )

        benchmarkRunner.benchmark("Matcha View Rendering") {
            _ = model.view()
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha view rendering is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    @Test("Large view rendering with ANSI codes")
    func largeViewRenderingComparison() throws {
        // Bubbletea baseline: ~200-500 microseconds for large colored views
        let bubbleteeBaseline = 0.0005 // 500 microseconds

        var model = ColoredListModel()
        model.items = (0..<200).map { index in
            ColoredListModel.Item(
                title: "Item \(index)",
                color: index % 2 == 0 ? .blue : .green,
                selected: index == 10
            )
        }

        benchmarkRunner.benchmark("Matcha Large Colored View") {
            _ = model.view()
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha colored view rendering is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    // MARK: - Input Parsing Performance Comparison

    @Test("Keyboard input parsing vs Bubbletea")
    func keyboardParsingComparison() throws {
        // Bubbletea baseline: ~2-5 microseconds per key event
        let bubbleteeBaseline = 0.000005 // 5 microseconds

        let parser = ANSIParser()

        // Common key sequences
        let sequences: [[UInt8]] = [
            [0x1B, 0x5B, 0x41], // Up arrow
            [0x1B, 0x5B, 0x42], // Down arrow
            [0x1B, 0x5B, 0x43], // Right arrow
            [0x1B, 0x5B, 0x44], // Left arrow
            [0x1B, 0x5B, 0x48], // Home
            [0x1B, 0x5B, 0x46], // End
            [0x61], // 'a'
            [0x0D], // Enter
            [0x1B], // Escape
            [0x09], // Tab
        ]

        benchmarkRunner.benchmark("Matcha Key Parsing") {
            for sequence in sequences {
                for byte in sequence {
                    _ = parser.parse(byte)
                }
            }
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * Double(sequences.count) * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha key parsing is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    @Test("Mouse event parsing vs Bubbletea")
    func mouseParsingComparison() throws {
        // Bubbletea baseline: ~5-10 microseconds per mouse event
        let bubbleteeBaseline = 0.00001 // 10 microseconds

        let parser = ANSIParser()

        // SGR mouse sequences
        let sequences: [[UInt8]] = [
            // Click at (10, 20)
            [0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D],
            // Motion at (15, 25)
            [0x1B, 0x5B, 0x3C, 0x33, 0x32, 0x3B, 0x31, 0x35, 0x3B, 0x32, 0x35, 0x4D],
            // Release at (20, 30)
            [0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x32, 0x30, 0x3B, 0x33, 0x30, 0x6D],
            // Wheel up
            [0x1B, 0x5B, 0x3C, 0x36, 0x34, 0x3B, 0x31, 0x30, 0x3B, 0x31, 0x30, 0x4D],
            // Wheel down
            [0x1B, 0x5B, 0x3C, 0x36, 0x35, 0x3B, 0x31, 0x30, 0x3B, 0x31, 0x30, 0x4D],
        ]

        benchmarkRunner.benchmark("Matcha Mouse Parsing") {
            for sequence in sequences {
                for byte in sequence {
                    _ = parser.parse(byte)
                }
            }
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * Double(sequences.count) * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha mouse parsing is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    // MARK: - Command Execution Performance Comparison

    @Test("Command execution vs Bubbletea")
    func commandExecutionComparison() async throws {
        // Bubbletea baseline: ~50-100 microseconds for simple commands
        let bubbleteeBaseline = 0.0001 // 100 microseconds

        let command = Command<BenchmarkMessage> { () -> BenchmarkMessage? in
            // Simulate minimal work
            Thread.sleep(forTimeInterval: 0.00001)
            return .commandComplete
        }

        await benchmarkRunner.benchmark("Matcha Command Execution") {
            _ = await command.execute()
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha command execution is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    @Test("Batch command execution vs Bubbletea")
    func batchCommandComparison() async throws {
        // Bubbletea baseline: ~200-500 microseconds for batch of 10 commands
        let bubbleteeBaseline = 0.0005 // 500 microseconds

        let commands = (0..<10).map { i in
            Command<BenchmarkMessage> { () -> BenchmarkMessage? in
                Thread.sleep(forTimeInterval: 0.00001)
                return .batchItem(i)
            }
        }
        let batchCommand = Command<BenchmarkMessage>.batch(commands)

        await benchmarkRunner.benchmark("Matcha Batch Command (10)") {
            _ = await batchCommand.execute()
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha batch command execution is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    // MARK: - Renderer Performance Comparison

    @Test("Renderer frame rate capability")
    func rendererFrameRateComparison() async throws {
        // Bubbletea targets 60 FPS, which means ~16.67ms per frame
        let targetFrameTime = 1.0 / 60.0 // ~0.0167 seconds

        let renderer = StandardRenderer(output: TestOutputStream(), fps: 60)
        await renderer.start()

        let content = (0..<50).map { "Line \($0): Dynamic content that changes" }.joined(separator: "\n")

        await benchmarkRunner.benchmark("Matcha Renderer Frame") {
            await renderer.write(content)
        }

        await renderer.stop()

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        #expect(
            result.averageTime <= targetFrameTime,
            """
            Matcha renderer cannot maintain 60 FPS.
            Frame time: \(result.averageTime)s, Target: \(targetFrameTime)s
            """
        )
    }

    // MARK: - Memory Usage Comparison

    @Test("Memory usage vs Bubbletea baseline")
    func memoryUsageComparison() throws {
        // Bubbletea typical memory usage for moderate app: ~5-10 MB
        let bubbleteeMemoryBaseline: Int64 = 10 * 1024 * 1024 // 10 MB

        var model = LargeAppModel()

        benchmarkRunner.benchmark("Matcha Memory Usage") {
            // Simulate app lifecycle
            model.items = (0..<1000).map { "Item \($0)" }
            _ = model.view()

            let (newModel, _) = model.update(.refresh)
            model = newModel
            _ = model.view()
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let memoryUsed = result.memoryAfter - result.memoryBefore
        #expect(
            memoryUsed <= bubbleteeMemoryBaseline * 2,
            """
            Matcha memory usage exceeds acceptable threshold.
            Used: \(memoryUsed) bytes, Threshold: \(bubbleteeMemoryBaseline * 2) bytes
            """
        )
    }

    // MARK: - Real-World Scenario Comparison

    @Test("Full TUI app performance vs Bubbletea")
    func fullAppPerformanceComparison() async throws {
        // Bubbletea baseline for full app interaction: ~1-5ms per update cycle
        let bubbleteeBaseline = 0.005 // 5 milliseconds

        var model = FullAppModel()

        await benchmarkRunner.benchmark("Matcha Full App Cycle") {
            // Simulate user interaction cycle
            let messages: [FullAppModel.Message] = [
                .key(KeyMsg(type: .down)),
                .mouse(MouseMsg(x: 50, y: 10, action: .press, button: .left)),
                .windowSize(WindowSizeMsg(width: 100, height: 40)),
                .input("Hello"),
                .refresh,
            ]

            for msg in messages {
                let (newModel, cmd) = model.update(msg)
                model = newModel
                _ = model.view()

                if let cmd {
                    _ = await cmd.execute()
                }
            }
        }

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found")
            return
        }

        let acceptableThreshold = bubbleteeBaseline * 2
        #expect(
            result.averageTime <= acceptableThreshold,
            """
            Matcha full app cycle is slower than acceptable threshold.
            Matcha: \(result.averageTime)s, Threshold: \(acceptableThreshold)s
            """
        )
    }

    // MARK: - Performance Report

    @Test("Generate performance comparison report")
    func generatePerformanceReport() throws {
        let report = benchmarkRunner.generateReport()
        print("\n" + String(repeating: "=", count: 80))
        print("MATCHA vs BUBBLETEA PERFORMANCE COMPARISON REPORT")
        print(String(repeating: "=", count: 80))
        print(report)
        print(String(repeating: "=", count: 80) + "\n")

        // Verify all benchmarks completed
        let results = benchmarkRunner.getResults()
        #expect(results.count >= 10, "Not all benchmarks completed")
    }
}

// MARK: - CounterModel

private struct CounterModel: Model {
    var count: Int

    init() {
        self.count = 0
    }

    enum Message: Matcha.Message {
        case increment
        case decrement
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (CounterModel, Command<Message>?) {
        var model = self
        switch message {
        case .increment:
            model.count += 1
        case .decrement:
            model.count -= 1
        }
        return (model, nil)
    }

    func view() -> String {
        "Count: \(count)"
    }
}

// MARK: - ListModel

private struct ListModel: Model {
    var items: [String] = []
    var cursor: Int = 0

    init() {
        self.items = []
        self.cursor = 0
    }

    enum Message: Matcha.Message {
        case moveUp
        case moveDown
        case select
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (ListModel, Command<Message>?) {
        var model = self
        switch message {
        case .moveUp:
            model.cursor = max(0, cursor - 1)
        case .moveDown:
            model.cursor = min(items.count - 1, cursor + 1)
        case .select:
            // No-op for benchmarking
            break
        }
        return (model, nil)
    }

    func view() -> String {
        items.enumerated().map { idx, item in
            idx == cursor ? "> \(item)" : "  \(item)"
        }.joined(separator: "\n")
    }
}

// MARK: - DashboardModel

private struct DashboardModel: Model {
    let title: String
    let items: [String]
    let status: String

    init() {
        self.title = "Dashboard"
        self.items = []
        self.status = "Ready"
    }

    init(title: String, items: [String], status: String) {
        self.title = title
        self.items = items
        self.status = status
    }

    enum Message: Matcha.Message {
        case refresh
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (DashboardModel, Command<Message>?) {
        (self, nil)
    }

    func view() -> String {
        var lines: [String] = []
        lines.append(String(repeating: "═", count: 50))
        lines.append("║ \(title.padding(toLength: 46, withPad: " ", startingAt: 0)) ║")
        lines.append(String(repeating: "═", count: 50))

        for item in items.prefix(10) {
            lines.append("  • \(item)")
        }

        lines.append("")
        lines.append("Status: \(status)")

        return lines.joined(separator: "\n")
    }
}

// MARK: - ColoredListModel

private struct ColoredListModel: Model {
    struct Item {
        let title: String
        let color: ANSIColor
        let selected: Bool
    }

    enum ANSIColor: String {
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case blue = "\u{001B}[34m"
        case reset = "\u{001B}[0m"
    }

    var items: [Item] = []

    init() {
        self.items = []
    }

    enum Message: Matcha.Message {
        case refresh
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (ColoredListModel, Command<Message>?) {
        (self, nil)
    }

    func view() -> String {
        items.map { item in
            let prefix = item.selected ? "▶ " : "  "
            return "\(item.color.rawValue)\(prefix)\(item.title)\(ANSIColor.reset.rawValue)"
        }.joined(separator: "\n")
    }
}

// MARK: - LargeAppModel

private struct LargeAppModel: Model {
    var items: [String] = []
    var cache: [String: String] = [:]
    var history: [String] = []

    init() {
        self.items = []
        self.cache = [:]
        self.history = []
    }

    enum Message: Matcha.Message {
        case refresh
        case addItem(String)
        case updateCache(String, String)
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (LargeAppModel, Command<Message>?) {
        var model = self
        switch message {
        case .refresh:
            model.history.append("Refreshed at \(Date())")
        case let .addItem(item):
            model.items.append(item)
        case let .updateCache(key, value):
            model.cache[key] = value
        }
        return (model, nil)
    }

    func view() -> String {
        """
        Items: \(items.count)
        Cache entries: \(cache.count)
        History: \(history.count)

        Recent items:
        \(items.suffix(10).joined(separator: "\n"))
        """
    }
}

// MARK: - FullAppModel

private struct FullAppModel: Model {
    var selectedIndex: Int = 0
    var inputBuffer: String = ""
    var windowSize: (width: Int, height: Int) = (80, 24)
    var items: [String] = ["Home", "Browse", "Search", "Settings", "Help"]

    init() {
        self.selectedIndex = 0
        self.inputBuffer = ""
        self.windowSize = (80, 24)
        self.items = ["Home", "Browse", "Search", "Settings", "Help"]
    }

    enum Message: Matcha.Message {
        case key(KeyMsg)
        case mouse(MouseMsg)
        case windowSize(WindowSizeMsg)
        case input(String)
        case refresh
    }

    func `init`() -> Command<Message>? { nil }

    func update(_ message: Message) -> (FullAppModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.type {
            case .up:
                model.selectedIndex = max(0, selectedIndex - 1)
            case .down:
                model.selectedIndex = min(items.count - 1, selectedIndex + 1)
            default:
                break
            }
        case let .mouse(mouse):
            if mouse.y < items.count {
                model.selectedIndex = mouse.y
            }
        case let .windowSize(size):
            model.windowSize = (size.width, size.height)
        case let .input(text):
            model.inputBuffer = text
        case .refresh:
            // No-op
            break
        }

        return (model, nil)
    }

    func view() -> String {
        var lines: [String] = []

        lines.append("╔" + String(repeating: "═", count: windowSize.width - 2) + "╗")

        for (idx, item) in items.enumerated() {
            let prefix = idx == selectedIndex ? "▶ " : "  "
            let line = "\(prefix)\(item)"
            lines.append("║ \(line.padding(toLength: windowSize.width - 4, withPad: " ", startingAt: 0)) ║")
        }

        lines.append("╠" + String(repeating: "═", count: windowSize.width - 2) + "╣")
        lines.append("║ Input: \(inputBuffer.padding(toLength: windowSize.width - 11, withPad: " ", startingAt: 0)) ║")
        lines.append("╚" + String(repeating: "═", count: windowSize.width - 2) + "╝")

        return lines.joined(separator: "\n")
    }
}

// MARK: - BenchmarkMessage

private enum BenchmarkMessage: Message {
    case commandComplete
    case batchItem(Int)
}
