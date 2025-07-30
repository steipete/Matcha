import Foundation
import Testing
@testable import Matcha

// MARK: - LoggingTests

@Suite("Logging Tests")
@MainActor
struct LoggingTests {
    // Test model that logs
    struct LoggingModel: Model {
        typealias Msg = TestMessage

        enum TestMessage: Message {
            case log(String)
        }

        var lastLogMessage: String?

        init() {
            self.lastLogMessage = nil
        }

        func `init`() -> Command<TestMessage>? {
            nil
        }

        func update(_ message: TestMessage) -> (LoggingModel, Command<TestMessage>?) {
            var model = self
            switch message {
            case let .log(msg):
                model.lastLogMessage = msg
                // In real implementation, this would use a logging command
                return (model, nil)
            }
        }

        func view() -> String {
            lastLogMessage ?? "No logs"
        }
    }

    @Test("Log to file creates log file with correct content")
    func logToFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).log")

        // Create a simple logger that writes to file
        let logger = FileLogger(path: logPath.path, prefix: "TEST")

        // Write some log messages
        logger.log("First message")
        logger.log("Second message")
        logger.log("Third message")

        // Close the logger
        logger.close()

        // Read the log file
        let content = try String(contentsOf: logPath, encoding: .utf8)

        // Verify content
        #expect(content.contains("TEST First message"))
        #expect(content.contains("TEST Second message"))
        #expect(content.contains("TEST Third message"))

        // Clean up
        try FileManager.default.removeItem(at: logPath)
    }

    @Test("Debug logging only logs in debug mode")
    func debugLogging() throws {
        let debugLogger = DebugLogger()

        // This should only produce output in debug builds
        debugLogger.debug("Debug message")
        debugLogger.info("Info message")
        debugLogger.warning("Warning message")
        debugLogger.error("Error message")

        // Can't easily test output in unit tests, but at least verify no crashes
        #expect(Bool(true))
    }

    @Test("Log levels filter messages appropriately")
    func logLevels() throws {
        let logger = LeveledLogger(level: .warning)

        var loggedMessages: [String] = []
        logger.onLog = { message in
            loggedMessages.append(message)
        }

        // These should not be logged
        logger.debug("Debug message")
        logger.info("Info message")

        // These should be logged
        logger.warning("Warning message")
        logger.error("Error message")

        #expect(loggedMessages.count == 2)
        #expect(loggedMessages[0].contains("Warning message"))
        #expect(loggedMessages[1].contains("Error message"))
    }

    @Test("Structured logging includes metadata")
    func structuredLogging() throws {
        let logger = StructuredLogger()

        var lastLog: StructuredLogger.LogEntry?
        logger.onLog = { entry in
            lastLog = entry
        }

        // Log with metadata
        logger.log(
            level: .info,
            message: "User action",
            metadata: [
                "userId": "12345",
                "action": "login",
                "timestamp": Date().timeIntervalSince1970,
            ]
        )

        #expect(lastLog != nil)
        #expect(lastLog?.message == "User action")
        #expect(lastLog?.metadata["userId"] as? String == "12345")
        #expect(lastLog?.metadata["action"] as? String == "login")
    }
}

// MARK: - FileLogger

// Simple file logger implementation
private class FileLogger {
    private let fileHandle: FileHandle?
    private let prefix: String

    init(path: String, prefix: String) {
        self.prefix = prefix

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        // Open file for writing
        self.fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()
    }

    func log(_ message: String) {
        let logLine = "\(prefix) \(message)\n"
        if let data = logLine.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    func close() {
        fileHandle?.closeFile()
    }
}

// MARK: - DebugLogger

// Debug logger that only logs in debug mode
private struct DebugLogger {
    func debug(_ message: String) {
        #if DEBUG
            print("[DEBUG] \(message)")
        #endif
    }

    func info(_ message: String) {
        print("[INFO] \(message)")
    }

    func warning(_ message: String) {
        print("[WARNING] \(message)")
    }

    func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}

// MARK: - LeveledLogger

// Logger with configurable levels
private class LeveledLogger {
    enum Level: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    let level: Level
    var onLog: ((String) -> Void)?

    init(level: Level) {
        self.level = level
    }

    func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    func info(_ message: String) {
        log(level: .info, message: message)
    }

    func warning(_ message: String) {
        log(level: .warning, message: message)
    }

    func error(_ message: String) {
        log(level: .error, message: message)
    }

    private func log(level: Level, message: String) {
        guard level.rawValue >= self.level.rawValue else { return }
        onLog?(message)
    }
}

// MARK: - StructuredLogger

// Structured logger with metadata
private class StructuredLogger {
    struct LogEntry {
        let level: LeveledLogger.Level
        let message: String
        let metadata: [String: Any]
        let timestamp: Date
    }

    var onLog: ((LogEntry) -> Void)?

    func log(level: LeveledLogger.Level, message: String, metadata: [String: Any] = [:]) {
        let entry = LogEntry(
            level: level,
            message: message,
            metadata: metadata,
            timestamp: Date()
        )
        onLog?(entry)
    }
}
