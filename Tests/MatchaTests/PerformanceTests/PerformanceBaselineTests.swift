import Foundation
import Testing
@testable import Matcha

// MARK: - PerformanceBaselineTests

/// Tests that verify Matcha meets baseline performance requirements
@Suite("Performance Baseline Tests")
struct PerformanceBaselineTests {
    let benchmarkTester: PerformanceBenchmarkTester

    init() {
        var config = BenchmarkRunner.Configuration.default
        config.printResults = false
        self.benchmarkTester = PerformanceBenchmarkTester(configuration: config)
    }

    // MARK: - Baseline Requirements

    /// Model updates should complete in under 1ms for typical operations
    @Test("Model update baseline - under 1ms")
    func modelUpdateBaseline() throws {
        let model = TestModel(value: 0)

        try benchmarkTester.assertBenchmark(
            "Model Update Baseline",
            expectedTime: 0.001, // 1ms
            tolerance: 0.5
        ) {
            _ = model.update(.increment)
        }
    }

    /// View rendering should complete in under 5ms for moderate complexity
    @Test("View rendering baseline - under 5ms for 100 items")
    func viewRenderingBaseline() throws {
        var model = ComplexTestModel()
        model.items = (0..<100).map { "Item \($0)" }

        try benchmarkTester.assertBenchmark(
            "View Rendering Baseline (100 items)",
            expectedTime: 0.005, // 5ms
            tolerance: 0.5
        ) {
            _ = model.view()
        }
    }

    /// Input parsing should be near-instant (<0.1ms per character)
    @Test("Input parsing baseline - under 0.1ms per character")
    func inputParsingBaseline() throws {
        let parser = ANSIParser()
        let char: UInt8 = 65 // 'A'

        try benchmarkTester.assertBenchmark(
            "Character Input Baseline",
            expectedTime: 0.0001, // 0.1ms
            tolerance: 0.5
        ) {
            _ = parser.parse(char)
        }
    }

    /// Should handle 60 FPS rendering (16.67ms per frame)
    @Test("60 FPS rendering baseline")
    func renderingFPSBaseline() async throws {
        let renderer = StandardRenderer(output: TestOutputStream(), fps: 60)
        await renderer.start()

        let content = (0..<50).map { "Line \($0)" }.joined(separator: "\n")

        // Measure frame time
        let frameTime = 1.0 / 60.0 // 16.67ms

        try await benchmarkTester.assertBenchmark(
            "60 FPS Rendering",
            expectedTime: frameTime,
            tolerance: 0.2
        ) {
            await renderer.write(content)
        }

        await renderer.stop()
    }

    // MARK: - Scalability Tests

    /// Test that performance scales linearly with data size
    @Test("Linear scalability with data size")
    func linearScalability() throws {
        let sizes = [10, 100, 1000]
        var previousTime: TimeInterval = 0
        var scalingFactors: [Double] = []

        for size in sizes {
            var model = ComplexTestModel()
            model.items = (0..<size).map { "Item \($0)" }

            benchmarkTester.benchmarkRunner.benchmark("Scalability Test (\(size) items)") {
                _ = model.view()
            }

            let result = benchmarkTester.benchmarkRunner.getResults().last!

            if previousTime > 0 {
                let scalingFactor = result.averageTime / previousTime
                scalingFactors.append(scalingFactor)

                // Check that scaling is roughly linear (within 20% of expected)
                let expectedScaling = Double(size) / Double(sizes[sizes.firstIndex(of: size)! - 1])
                #expect(
                    scalingFactor <= expectedScaling * 1.2,
                    "Non-linear scaling detected at size \(size)"
                )
            }

            previousTime = result.averageTime
        }
    }

    // MARK: - Memory Efficiency Tests

    /// Test that memory usage is reasonable for large datasets
    @Test("Memory efficiency for large datasets")
    func memoryEfficiency() throws {
        let itemCount = 10000
        var model = ComplexTestModel()

        // Each item is approximately 20 bytes
        let expectedMemory = Int64(itemCount * 20 * 2) // 2x for overhead

        try benchmarkTester.assertMemoryUsage(
            "Large Dataset Memory",
            maxMemory: expectedMemory
        ) {
            model.items = (0..<itemCount).map { "Item \($0)" }
            _ = model.view()
        }
    }

    // MARK: - Stress Tests

    /// Test rapid model updates
    @Test("Rapid model update throughput")
    func rapidUpdates() async throws {
        var model = TestModel()
        let updateCount = 1000

        let start = CFAbsoluteTimeGetCurrent()

        for i in 0..<updateCount {
            let message: TestMessage = i % 2 == 0 ? .increment : .decrement
            let (newModel, _) = model.update(message)
            model = newModel
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let updatesPerSecond = Double(updateCount) / elapsed

        #expect(
            updatesPerSecond > 10000, // Should handle at least 10k updates/second
            "Update throughput too low: \(Int(updatesPerSecond)) updates/second"
        )
    }

    /// Test concurrent command execution
    @Test("Concurrent command execution")
    func concurrentCommands() async throws {
        let commandCount = 100
        var commands: [Command<TestMessage>] = []

        for i in 0..<commandCount {
            commands.append(Command { () async -> TestMessage? in
                try? await Task.sleep(for: .milliseconds(1))
                return i % 2 == 0 ? .increment : .decrement
            })
        }

        let start = CFAbsoluteTimeGetCurrent()

        // Execute all commands concurrently
        await withTaskGroup(of: (any Message)?.self) { group in
            for command in commands {
                group.addTask {
                    await command.execute()
                }
            }

            var count = 0
            for await _ in group {
                count += 1
            }
            #expect(count == commandCount)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // Should complete in roughly the time of one command (plus overhead)
        #expect(
            elapsed < 0.1, // 100ms for 100 concurrent 1ms commands
            "Concurrent execution took too long: \(elapsed)s"
        )
    }

    // MARK: - Real-World Performance Requirements

    /// Test that a file browser can handle large directories
    @Test("File browser performance with 10k files")
    func fileBrowserPerformance() throws {
        enum FileBrowserMessage: Message {
            case noop
        }

        struct FileBrowserModel: Model {
            typealias Msg = FileBrowserMessage

            var files: [(name: String, size: Int, isDirectory: Bool)] = []
            var selectedIndex: Int = 0

            func `init`() -> Command<FileBrowserMessage>? {
                nil
            }

            func update(_ message: FileBrowserMessage) -> (FileBrowserModel, Command<FileBrowserMessage>?) {
                // No updates needed for performance test
                (self, nil)
            }

            func view() -> String {
                var output = ""
                let visibleRange = max(0, selectedIndex - 20)..<min(files.count, selectedIndex + 20)

                for i in visibleRange {
                    let file = files[i]
                    let prefix = i == selectedIndex ? "> " : "  "
                    let icon = file.isDirectory ? "📁" : "📄"
                    output += "\(prefix)\(icon) \(file.name) (\(file.size) bytes)\n"
                }

                return output
            }
        }

        var model = FileBrowserModel()
        model.files = (0..<10000).map { i in
            (
                name: "file_\(i).txt",
                size: Int.random(in: 100...100_000),
                isDirectory: i % 10 == 0
            )
        }

        try benchmarkTester.assertBenchmark(
            "File Browser (10k files)",
            expectedTime: 0.01, // 10ms
            tolerance: 0.5
        ) {
            _ = model.view()
        }
    }

    /// Test that text editing remains responsive
    @Test("Text editor responsiveness")
    func textEditorResponsiveness() throws {
        enum TextEditorMessage: Message {
            case noop
        }

        struct TextEditorModel: Model {
            typealias Msg = TextEditorMessage

            var lines: [String] = []
            var cursorLine: Int = 0
            var cursorColumn: Int = 0

            func `init`() -> Command<TextEditorMessage>? {
                nil
            }

            func update(_ message: TextEditorMessage) -> (TextEditorModel, Command<TextEditorMessage>?) {
                (self, nil)
            }

            func view() -> String {
                var output = ""
                let visibleStart = max(0, cursorLine - 15)
                let visibleEnd = min(lines.count, cursorLine + 15)

                for i in visibleStart..<visibleEnd {
                    let lineNumber = String(format: "%4d ", i + 1)
                    var line = lines[i]

                    // Insert cursor
                    if i == cursorLine {
                        let index = line.index(line.startIndex, offsetBy: min(cursorColumn, line.count))
                        line.insert("│", at: index)
                    }

                    output += "\(lineNumber)\(line)\n"
                }

                return output
            }
        }

        var model = TextEditorModel()
        model.lines = (0..<1000).map { "Line \($0): The quick brown fox jumps over the lazy dog" }
        model.cursorLine = 500
        model.cursorColumn = 20

        try benchmarkTester.assertBenchmark(
            "Text Editor View",
            expectedTime: 0.005, // 5ms for responsive editing
            tolerance: 0.5
        ) {
            _ = model.view()
        }
    }
}

// MARK: - PerformanceReportTests

@Suite("Performance Report Generation")
struct PerformanceReportTests {
    /// Generate a comprehensive performance report
    @Test("Generate comprehensive performance report", .disabled("Run manually when needed"))
    func generatePerformanceReport() async throws {
        print("\n=== Matcha Performance Report ===\n")

        // Create a new instance to run all benchmarks
        let baselineTests = PerformanceBaselineTests()

        // Run all benchmarks
        try baselineTests.testModelUpdateBaseline()
        try baselineTests.testViewRenderingBaseline()
        try baselineTests.testInputParsingBaseline()
        try await baselineTests.testRenderingFPSBaseline()
        try baselineTests.testLinearScalability()
        try baselineTests.testMemoryEfficiency()
        try await baselineTests.testRapidUpdates()
        try await baselineTests.testConcurrentCommands()
        try baselineTests.testFileBrowserPerformance()
        try baselineTests.testTextEditorResponsiveness()

        // Generate summary
        let results = baselineTests.benchmarkTester.benchmarkRunner.getResults()

        print("\nSummary:")
        print("--------")
        print("Total benchmarks: \(results.count)")
        print("Average execution time: \(formatTime(results.map(\.averageTime).reduce(0, +) / Double(results.count)))")
        print("Total memory allocated: \(formatMemory(results.map { $0.memoryAfter - $0.memoryBefore }.reduce(0, +)))")

        // Find outliers
        if !results.isEmpty {
            let slowestBenchmark = results.max { $0.averageTime < $1.averageTime }!
            let mostMemory = results.max { ($0.memoryAfter - $0.memoryBefore) < ($1.memoryAfter - $1.memoryBefore) }!

            print("\nOutliers:")
            print("---------")
            print("Slowest: \(slowestBenchmark.name) (\(formatTime(slowestBenchmark.averageTime)))")
            print("Most memory: \(mostMemory.name) (\(formatMemory(mostMemory.memoryAfter - mostMemory.memoryBefore)))")
        }

        print("\n" + baselineTests.benchmarkTester.generateReport())
    }

    private func formatTime(_ time: TimeInterval) -> String {
        if time < 0.001 {
            String(format: "%.2f µs", time * 1_000_000)
        } else if time < 1.0 {
            String(format: "%.2f ms", time * 1000)
        } else {
            String(format: "%.2f s", time)
        }
    }

    private func formatMemory(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        return String(format: "%.1f MB", mb)
    }
}
