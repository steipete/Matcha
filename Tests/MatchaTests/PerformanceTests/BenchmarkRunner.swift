import Foundation
import Testing
@testable import Matcha

// MARK: - BenchmarkRunner

/// A benchmark runner that measures performance of Matcha components
public class BenchmarkRunner {
    /// Result of a benchmark run
    public struct BenchmarkResult {
        public let name: String
        public let iterations: Int
        public let totalTime: TimeInterval
        public let averageTime: TimeInterval
        public let minTime: TimeInterval
        public let maxTime: TimeInterval
        public let standardDeviation: TimeInterval
        public let memoryBefore: Int64
        public let memoryAfter: Int64
        public let memoryPeak: Int64

        public var summary: String {
            """
            Benchmark: \(name)
            Iterations: \(iterations)
            Average: \(formatTime(averageTime))
            Min: \(formatTime(minTime))
            Max: \(formatTime(maxTime))
            Std Dev: \(formatTime(standardDeviation))
            Memory: \(formatMemory(memoryAfter - memoryBefore)) (Peak: \(formatMemory(memoryPeak)))
            """
        }

        private func formatTime(_ time: TimeInterval) -> String {
            if time < 0.001 {
                String(format: "%.2f µs", time * 1_000_000)
            } else if time < 1.0 {
                String(format: "%.2f ms", time * 1_000)
            } else {
                String(format: "%.2f s", time)
            }
        }

        private func formatMemory(_ bytes: Int64) -> String {
            let mb = Double(bytes) / 1_024.0 / 1_024.0
            return String(format: "%.1f MB", mb)
        }
    }

    /// Configuration for benchmarks
    public struct Configuration: Sendable {
        /// Number of warmup iterations before measurement
        public var warmupIterations: Int = 10

        /// Number of measured iterations
        public var iterations: Int = 100

        /// Maximum time to run benchmark (seconds)
        public var maxDuration: TimeInterval = 30.0

        /// Whether to measure memory usage
        public var measureMemory: Bool = true

        /// Whether to print results
        public var printResults: Bool = true

        public static let `default` = Configuration()
    }

    private var results: [BenchmarkResult] = []
    private let configuration: Configuration

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Run a benchmark
    public func benchmark(
        _ name: String,
        operation: () throws -> Void
    ) rethrows {
        let result = try measure(name: name, operation: operation)
        results.append(result)

        if configuration.printResults {
            print(result.summary)
            print(String(repeating: "-", count: 60))
        }
    }

    /// Run an async benchmark
    public func benchmark(
        _ name: String,
        operation: () async throws -> Void
    ) async rethrows {
        let result = try await measureAsync(name: name, operation: operation)
        results.append(result)

        if configuration.printResults {
            print(result.summary)
            print(String(repeating: "-", count: 60))
        }
    }

    /// Get all benchmark results
    public func getResults() -> [BenchmarkResult] {
        results
    }

    /// Generate a report of all benchmarks
    public func generateReport() -> String {
        var report = """
        Benchmark Report
        ================
        Date: \(Date())
        Configuration:
        - Warmup iterations: \(configuration.warmupIterations)
        - Measured iterations: \(configuration.iterations)
        - Max duration: \(configuration.maxDuration)s

        Results:
        --------

        """

        for result in results {
            report += result.summary + "\n\n"
        }

        return report
    }

    // MARK: - Private Methods

    private func measure(
        name: String,
        operation: () throws -> Void
    ) rethrows -> BenchmarkResult {
        // Warmup
        for _ in 0..<configuration.warmupIterations {
            try operation()
        }

        var times: [TimeInterval] = []
        let memoryBefore = configuration.measureMemory ? currentMemoryUsage() : 0
        var memoryPeak: Int64 = memoryBefore

        let startTime = CFAbsoluteTimeGetCurrent()

        // Measure
        for _ in 0..<configuration.iterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            try operation()
            let iterationTime = CFAbsoluteTimeGetCurrent() - iterationStart
            times.append(iterationTime)

            if configuration.measureMemory {
                memoryPeak = max(memoryPeak, currentMemoryUsage())
            }

            // Check timeout
            if CFAbsoluteTimeGetCurrent() - startTime > configuration.maxDuration {
                break
            }
        }

        let memoryAfter = configuration.measureMemory ? currentMemoryUsage() : 0

        return calculateResult(
            name: name,
            times: times,
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter,
            memoryPeak: memoryPeak
        )
    }

    private func measureAsync(
        name: String,
        operation: () async throws -> Void
    ) async rethrows -> BenchmarkResult {
        // Warmup
        for _ in 0..<configuration.warmupIterations {
            try await operation()
        }

        var times: [TimeInterval] = []
        let memoryBefore = configuration.measureMemory ? currentMemoryUsage() : 0
        var memoryPeak: Int64 = memoryBefore

        let startTime = CFAbsoluteTimeGetCurrent()

        // Measure
        for _ in 0..<configuration.iterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            try await operation()
            let iterationTime = CFAbsoluteTimeGetCurrent() - iterationStart
            times.append(iterationTime)

            if configuration.measureMemory {
                memoryPeak = max(memoryPeak, currentMemoryUsage())
            }

            // Check timeout
            if CFAbsoluteTimeGetCurrent() - startTime > configuration.maxDuration {
                break
            }
        }

        let memoryAfter = configuration.measureMemory ? currentMemoryUsage() : 0

        return calculateResult(
            name: name,
            times: times,
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter,
            memoryPeak: memoryPeak
        )
    }

    private func calculateResult(
        name: String,
        times: [TimeInterval],
        memoryBefore: Int64,
        memoryAfter: Int64,
        memoryPeak: Int64
    ) -> BenchmarkResult {
        let totalTime = times.reduce(0, +)
        let averageTime = totalTime / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0

        // Calculate standard deviation
        let variance = times.reduce(0) { sum, time in
            let diff = time - averageTime
            return sum + (diff * diff)
        } / Double(times.count)
        let standardDeviation = sqrt(variance)

        return BenchmarkResult(
            name: name,
            iterations: times.count,
            totalTime: totalTime,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            standardDeviation: standardDeviation,
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter,
            memoryPeak: memoryPeak
        )
    }

    private func currentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - PerformanceBenchmarkTester

/// Helper for performance benchmarks in Swift Testing
public struct PerformanceBenchmarkTester {
    public let benchmarkRunner: BenchmarkRunner

    public init(configuration: BenchmarkRunner.Configuration = .default) {
        self.benchmarkRunner = BenchmarkRunner(configuration: configuration)
    }

    /// Assert that a benchmark completes within expected time
    public func assertBenchmark(
        _ name: String,
        expectedTime: TimeInterval,
        tolerance: Double = 0.2,
        operation: () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try benchmarkRunner.benchmark(name, operation: operation)

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found", sourceLocation: sourceLocation)
            return
        }

        let allowedTime = expectedTime * (1 + tolerance)
        #expect(
            result.averageTime <= allowedTime,
            "Benchmark '\(name)' exceeded expected time. Average: \(result.averageTime)s, Expected: <\(allowedTime)s",
            sourceLocation: sourceLocation
        )
    }

    /// Assert that an async benchmark completes within expected time
    public func assertBenchmark(
        _ name: String,
        expectedTime: TimeInterval,
        tolerance: Double = 0.2,
        operation: () async throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await benchmarkRunner.benchmark(name, operation: operation)

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found", sourceLocation: sourceLocation)
            return
        }

        let allowedTime = expectedTime * (1 + tolerance)
        #expect(
            result.averageTime <= allowedTime,
            "Benchmark '\(name)' exceeded expected time. Average: \(result.averageTime)s, Expected: <\(allowedTime)s",
            sourceLocation: sourceLocation
        )
    }

    /// Assert that a benchmark uses less than expected memory
    public func assertMemoryUsage(
        _ name: String,
        maxMemory: Int64,
        operation: () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try benchmarkRunner.benchmark(name, operation: operation)

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found", sourceLocation: sourceLocation)
            return
        }

        let memoryUsed = result.memoryAfter - result.memoryBefore
        #expect(
            memoryUsed <= maxMemory,
            "Benchmark '\(name)' exceeded memory limit. Used: \(memoryUsed) bytes, Expected: <\(maxMemory) bytes",
            sourceLocation: sourceLocation
        )
    }

    /// Assert that an async benchmark uses less than expected memory
    public func assertMemoryUsage(
        _ name: String,
        maxMemory: Int64,
        operation: () async throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await benchmarkRunner.benchmark(name, operation: operation)

        let results = benchmarkRunner.getResults()
        guard let result = results.last else {
            Issue.record("No benchmark result found", sourceLocation: sourceLocation)
            return
        }

        let memoryUsed = result.memoryAfter - result.memoryBefore
        #expect(
            memoryUsed <= maxMemory,
            "Benchmark '\(name)' exceeded memory limit. Used: \(memoryUsed) bytes, Expected: <\(maxMemory) bytes",
            sourceLocation: sourceLocation
        )
    }

    /// Generate a performance report
    public func generateReport() -> String {
        benchmarkRunner.generateReport()
    }
}
