import Foundation
import Testing
@testable import Matcha

// MARK: - MatchaPerformanceTests

/// Performance tests for core Matcha components
@Suite("Matcha Performance Benchmarks")
struct MatchaPerformanceTests {
    let benchmarkTester: PerformanceBenchmarkTester

    init() {
        var config = BenchmarkRunner.Configuration.default
        config.printResults = false // Disable printing in tests
        self.benchmarkTester = PerformanceBenchmarkTester(configuration: config)
    }

    // MARK: - Model Update Performance

    @Test("Simple model update performance")
    func simpleModelUpdatePerformance() throws {
        var model = TestModel(value: 0)

        try benchmarkTester.assertBenchmark(
            "Simple Model Update",
            expectedTime: 0.00001 // 10 microseconds
        ) {
            let (newModel, _) = model.update(.increment)
            model = newModel
        }

        // Model should have been updated
        #expect(model.value > 0)
    }

    @Test("Complex model update performance with 1000 items")
    func complexModelUpdatePerformance() throws {
        var model = ComplexTestModel()
        model.items = Array(repeating: "Item", count: 1000)

        try benchmarkTester.assertBenchmark(
            "Complex Model Update (1000 items)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            let (newModel, _) = model.update(.setFilter("test"))
            model = newModel
        }
    }

    @Test("Large model update performance with 10k items")
    func largeModelUpdatePerformance() throws {
        var model = ComplexTestModel()
        model.items = Array(repeating: "Item", count: 10000)

        try benchmarkTester.assertBenchmark(
            "Large Model Update (10k items)",
            expectedTime: 0.01 // 10 milliseconds
        ) {
            let index = Int.random(in: 0..<model.items.count)
            let (newModel, _) = model.update(.selectItem(index))
            model = newModel
        }
    }

    // MARK: - View Rendering Performance

    @Test("Simple view rendering performance")
    func simpleViewRenderingPerformance() throws {
        let model = TestModel(value: 42, text: "Hello, World!")

        try benchmarkTester.assertBenchmark(
            "Simple View Rendering",
            expectedTime: 0.00001 // 10 microseconds
        ) {
            _ = model.view()
        }
    }

    @Test("Complex view rendering performance with 100 items")
    func complexViewRenderingPerformance() throws {
        var model = ComplexTestModel()
        model.items = (0..<100).map { "Item \($0)" }

        try benchmarkTester.assertBenchmark(
            "Complex View Rendering (100 items)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            _ = model.view()
        }
    }

    @Test("Large view rendering performance with 1000 items")
    func largeViewRenderingPerformance() throws {
        var model = ComplexTestModel()
        model.items = (0..<1000).map { "Item \($0)" }

        try benchmarkTester.assertBenchmark(
            "Large View Rendering (1000 items)",
            expectedTime: 0.01 // 10 milliseconds
        ) {
            _ = model.view()
        }
    }

    @Test("Filtered view rendering performance")
    func filteredViewRenderingPerformance() throws {
        var model = ComplexTestModel()
        model.items = (0..<1000).map { "Item \($0)" }
        model.filter = "5" // Will match items containing "5"

        try benchmarkTester.assertBenchmark(
            "Filtered View Rendering (1000 items)",
            expectedTime: 0.01 // 10 milliseconds
        ) {
            _ = model.view()
        }
    }

    // MARK: - String Building Performance

    @Test("String concatenation performance")
    func stringConcatenationPerformance() throws {
        let lines = Array(repeating: "This is a line of text", count: 100)

        try benchmarkTester.assertBenchmark(
            "String Concatenation (100 lines)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            var result = ""
            for line in lines {
                result += line + "\n"
            }
            _ = result
        }
    }

    @Test("String interpolation performance")
    func stringInterpolationPerformance() throws {
        let lines = Array(repeating: "This is a line of text", count: 100)

        try benchmarkTester.assertBenchmark(
            "String Interpolation (100 lines)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            var result = ""
            for (index, line) in lines.enumerated() {
                result += "\(index): \(line)\n"
            }
            _ = result
        }
    }

    @Test("String join performance")
    func stringJoinPerformance() throws {
        let lines = Array(repeating: "This is a line of text", count: 100)

        try benchmarkTester.assertBenchmark(
            "String Join (100 lines)",
            expectedTime: 0.0001 // 100 microseconds
        ) {
            let result = lines.joined(separator: "\n")
            _ = result
        }
    }

    @Test("Preallocated string performance")
    func preallocatedStringPerformance() throws {
        let lines = Array(repeating: "This is a line of text", count: 100)

        try benchmarkTester.assertBenchmark(
            "Preallocated String (100 lines)",
            expectedTime: 0.0001 // 100 microseconds
        ) {
            var result = String()
            result.reserveCapacity(lines.count * 25) // Approximate size
            for line in lines {
                result.append(line)
                result.append("\n")
            }
            _ = result
        }
    }

    // MARK: - Input Parsing Performance

    @Test("ANSI key parsing performance")
    func keyParsingPerformance() throws {
        let parser = ANSIParser()
        let keySequence: [UInt8] = [0x1B, 0x5B, 0x41] // ESC[A (Up arrow)

        try benchmarkTester.assertBenchmark(
            "ANSI Key Parsing",
            expectedTime: 0.00001 // 10 microseconds
        ) {
            for byte in keySequence {
                _ = parser.parse(byte)
            }
        }
    }

    @Test("SGR mouse parsing performance")
    func mouseParsingPerformance() throws {
        let parser = ANSIParser()
        // SGR mouse sequence: ESC[<0;10;20M
        let mouseSequence: [UInt8] = [0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]

        try benchmarkTester.assertBenchmark(
            "SGR Mouse Parsing",
            expectedTime: 0.00002 // 20 microseconds
        ) {
            for byte in mouseSequence {
                _ = parser.parse(byte)
            }
        }
    }

    @Test("Bracketed paste parsing performance")
    func pasteParsingPerformance() throws {
        let parser = ANSIParser()
        let pasteStart: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E] // ESC[200~
        let pasteContent = "This is pasted text".utf8.map { UInt8($0) }
        let pasteEnd: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E] // ESC[201~

        try benchmarkTester.assertBenchmark(
            "Bracketed Paste Parsing",
            expectedTime: 0.0001 // 100 microseconds
        ) {
            for byte in pasteStart {
                _ = parser.parse(byte)
            }
            for byte in pasteContent {
                _ = parser.parse(byte)
            }
            for byte in pasteEnd {
                _ = parser.parse(byte)
            }
        }
    }

    // MARK: - Renderer Performance

    @Test("Renderer diffing performance")
    func rendererDiffingPerformance() async throws {
        let renderer = StandardRenderer(output: TestOutputStream(), fps: 60)
        await renderer.start()

        let lines1 = (0..<50).map { "Line \($0): Original content" }
        let content1 = lines1.joined(separator: "\n")

        let lines2 = lines1
        var modifiedLines2 = lines2
        modifiedLines2[25] = "Line 25: Modified content"
        let content2 = modifiedLines2.joined(separator: "\n")

        try await benchmarkTester.assertBenchmark(
            "Renderer Diffing (50 lines, 1 change)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            await renderer.write(content1)
            await renderer.write(content2)
        }

        await renderer.stop()
    }

    @Test("Renderer full redraw performance")
    func rendererFullRedrawPerformance() async throws {
        let renderer = StandardRenderer(output: TestOutputStream(), fps: 60)
        await renderer.start()

        let lines = (0..<100).map { "Line \($0): Some content that spans multiple columns" }
        let content = lines.joined(separator: "\n")

        try await benchmarkTester.assertBenchmark(
            "Renderer Full Redraw (100 lines)",
            expectedTime: 0.002 // 2 milliseconds
        ) {
            await renderer.write(content)
            await renderer.clearScreen()
        }

        await renderer.stop()
    }

    // MARK: - Command Performance

    @Test("Sync command execution performance")
    func syncCommandPerformance() async throws {
        let command = Command<TestMessage> { () -> TestMessage? in
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.001)
            return .increment
        }

        try await benchmarkTester.assertBenchmark(
            "Sync Command Execution",
            expectedTime: 0.002 // 2 milliseconds (includes 1ms sleep)
        ) {
            _ = await command.execute()
        }
    }

    @Test("Async command execution performance")
    func asyncCommandPerformance() async throws {
        let command = Command<TestMessage> { () async -> TestMessage? in
            // Simulate async work
            try? await Task.sleep(for: .milliseconds(1))
            return .increment
        }

        try await benchmarkTester.assertBenchmark(
            "Async Command Execution",
            expectedTime: 0.002 // 2 milliseconds (includes 1ms sleep)
        ) {
            _ = await command.execute()
        }
    }

    @Test("Batch command execution performance")
    func batchCommandPerformance() async throws {
        let commands = (0..<10).map { _ in
            Command<TestMessage> { () -> TestMessage? in
                Thread.sleep(forTimeInterval: 0.0001)
                return .increment
            }
        }
        let batchCommand = batch(commands)

        try await benchmarkTester.assertBenchmark(
            "Batch Command Execution (10 commands)",
            expectedTime: 0.005 // 5 milliseconds
        ) {
            _ = await batchCommand.execute()
        }
    }

    // MARK: - Message Channel Performance

    @Test("Message channel throughput")
    func messageChannelThroughput() async throws {
        let messageCount = 1000

        try await benchmarkTester.assertBenchmark(
            "Message Channel Throughput (\(messageCount) messages)",
            expectedTime: 0.01 // 10 milliseconds
        ) {
            let channel = AsyncChannel<Int>()

            // Producer
            Task {
                for i in 0..<messageCount {
                    await channel.send(i)
                }
                await channel.finish()
            }

            // Consumer
            var count = 0
            for await _ in channel {
                count += 1
            }

            #expect(count == messageCount)
        }
    }

    // MARK: - Memory Usage Tests

    @Test("Model memory usage")
    func modelMemoryUsage() throws {
        var model = ComplexTestModel()

        try benchmarkTester.assertMemoryUsage(
            "Large Model Memory",
            maxMemory: 10 * 1024 * 1024 // 10 MB
        ) {
            model.items = (0..<10000).map { "Item \($0) with some additional text" }
            _ = model.view()
        }
    }

    @Test("Renderer memory usage")
    func rendererMemoryUsage() async throws {
        let renderer = StandardRenderer(output: TestOutputStream(), fps: 60)
        await renderer.start()

        let largeContent = String(repeating: "X", count: 100_000)

        try await benchmarkTester.assertMemoryUsage(
            "Renderer Memory",
            maxMemory: 5 * 1024 * 1024 // 5 MB
        ) {
            await renderer.write(largeContent)
        }

        await renderer.stop()
    }

    // MARK: - Real-World Scenarios

    @Test("List navigation performance")
    func listNavigationPerformance() throws {
        var model = ListTestModel()
        model.items = (0..<1000).map { ListTestModel.ListItem(id: "\($0)", title: "Item \($0)") }

        try benchmarkTester.assertBenchmark(
            "List Navigation (1000 items)",
            expectedTime: 0.001 // 1 millisecond
        ) {
            // Simulate navigating through list
            for _ in 0..<10 {
                let (newModel, _) = model.update(.moveDown)
                model = newModel
            }
            _ = model.view()
        }
    }

    @Test("Text input typing performance")
    func textInputPerformance() throws {
        var model = TextInputTestModel()
        let text = "The quick brown fox jumps over the lazy dog"

        try benchmarkTester.assertBenchmark(
            "Text Input Typing",
            expectedTime: 0.001 // 1 millisecond
        ) {
            // Simulate typing
            for char in text {
                let (newModel, _) = model.update(.typeCharacter(char))
                model = newModel
            }
            _ = model.view()
        }
    }
}

// MARK: - ListTestModel

struct ListTestModel: Model {
    typealias Msg = ListMessage

    struct ListItem {
        let id: String
        let title: String
    }

    var items: [ListItem] = []
    var selectedIndex: Int = 0

    func `init`() -> Command<ListMessage>? {
        nil
    }

    func update(_ message: ListMessage) -> (ListTestModel, Command<ListMessage>?) {
        var model = self

        switch message {
        case .moveUp:
            model.selectedIndex = max(0, selectedIndex - 1)
        case .moveDown:
            model.selectedIndex = min(items.count - 1, selectedIndex + 1)
        }

        return (model, nil)
    }

    func view() -> String {
        var output = ""
        let visibleRange = max(0, selectedIndex - 10)..<min(items.count, selectedIndex + 10)

        for i in visibleRange {
            let prefix = i == selectedIndex ? "> " : "  "
            output += "\(prefix)\(items[i].title)\n"
        }

        return output
    }
}

// MARK: - ListMessage

enum ListMessage: Message {
    case moveUp
    case moveDown
}

// MARK: - TextInputTestModel

struct TextInputTestModel: Model {
    typealias Msg = TextInputMessage

    var text: String = ""
    var cursorPosition: Int = 0

    func `init`() -> Command<TextInputMessage>? {
        nil
    }

    func update(_ message: TextInputMessage) -> (TextInputTestModel, Command<TextInputMessage>?) {
        var model = self

        switch message {
        case let .typeCharacter(char):
            model.text.insert(char, at: text.index(text.startIndex, offsetBy: cursorPosition))
            model.cursorPosition += 1
        case .backspace:
            if cursorPosition > 0 {
                let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
                model.text.remove(at: index)
                model.cursorPosition -= 1
            }
        }

        return (model, nil)
    }

    func view() -> String {
        "Input: \(text)│"
    }
}

// MARK: - TextInputMessage

enum TextInputMessage: Message {
    case typeCharacter(Character)
    case backspace
}
