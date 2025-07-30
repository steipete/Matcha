//
//  ProgramTester.swift
//  MatchaTests
//
//  Test utilities for testing Matcha programs.
//

import Foundation
import Testing
@testable import Matcha

/// A test harness for running and testing Matcha programs
@MainActor
public class ProgramTester<M: Model> {
    private let program: Program<M>
    private let outputCapture: OutputCapture
    private var messages: [M.Msg] = []
    private var expectationQueue: [() async throws -> Void] = []
    
    /// Creates a new program tester
    public init(model: M, options: ProgramOptions = .default) {
        // Create custom output stream to capture rendering
        let outputCapture = OutputCapture()
        
        // Create a pipe for test input
        let inputPipe = Pipe()
        
        var testOptions = options
        testOptions.output = outputCapture
        testOptions.input = inputPipe.fileHandleForReading
        testOptions.fps = 120 // High FPS for faster testing
        testOptions.disableSignals = true // Disable signal handling in tests
        
        self.outputCapture = outputCapture
        self.program = Program(initialModel: model, options: testOptions)
    }
    
    /// Sends a message to the program
    public func send(_ message: M.Msg) async {
        messages.append(message)
        program.send(message)
        
        // Allow message to be processed
        try? await Task.sleep(for: .milliseconds(10))
    }
    
    /// Sends a key press event
    public func sendKey(_ key: String) async {
        let keyMsg: KeyMsg
        if key.count == 1 {
            keyMsg = KeyMsg(character: Character(key))
        } else {
            // Handle special keys
            switch key {
            case "enter": keyMsg = KeyMsg(type: .enter)
            case "escape": keyMsg = KeyMsg(type: .escape)
            case "up": keyMsg = KeyMsg(type: .up)
            case "down": keyMsg = KeyMsg(type: .down)
            case "left": keyMsg = KeyMsg(type: .left)
            case "right": keyMsg = KeyMsg(type: .right)
            default: keyMsg = KeyMsg(character: "?")
            }
        }
        if let msg = keyMsg as? M.Msg {
            await send(msg)
        }
    }
    
    /// Sends a mouse event
    public func sendMouse(x: Int, y: Int, action: MouseAction, button: MouseButton = .left) async {
        let mouseEvent = MouseEvent(
            x: x,
            y: y,
            shift: false,
            alt: false,
            ctrl: false,
            action: action,
            button: button
        )
        let mouseMsg = MouseMsg(mouseEvent)
        if let msg = mouseMsg as? M.Msg {
            await send(msg)
        }
    }
    
    /// Gets the current rendered view
    public func getCurrentView() -> String {
        return outputCapture.getBuffer()
    }
    
    /// Clears the captured output
    public func clearOutput() {
        outputCapture.clear()
    }
    
    /// Expects the view to contain a specific string
    public func expectView(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        
        #expect(
            view.contains(text),
            "Expected view to contain '\(text)' but got:\n\(view)",
            sourceLocation: sourceLocation
        )
    }
    
    /// Expects the view to match exactly
    public func expectView(equalTo expected: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        
        #expect(
            view.trimmingCharacters(in: .whitespacesAndNewlines) == expected.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceLocation: sourceLocation
        )
    }
    
    /// Expects the view to match a regex pattern
    public func expectView(matching pattern: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: view.utf16.count)
        
        #expect(
            regex.firstMatch(in: view, range: range) != nil,
            "Expected view to match pattern '\(pattern)' but got:\n\(view)",
            sourceLocation: sourceLocation
        )
    }
    
    /// Runs the program for a specific duration
    public func run(for duration: Duration) async throws {
        let task = Task { @MainActor in
            try await program.run()
        }
        
        try await Task.sleep(for: duration)
        program.quit()
        
        _ = try await task.value
    }
    
    /// Runs a test scenario with automatic cleanup
    public func test(_ scenario: () async throws -> Void) async throws {
        // Start the program in the background
        let programTask = Task { @MainActor in
            try await program.run()
        }
        
        // Give the program time to start and render initial view
        try await Task.sleep(for: .milliseconds(100))
        
        do {
            try await scenario()
        } catch {
            program.quit()
            _ = try? await programTask.value
            throw error
        }
        
        program.quit()
        _ = try? await programTask.value
    }
}

/// Output capture stream for testing
public class OutputCapture: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: String = ""
    public var onWrite: ((String) -> Void)?
    
    public init() {}
    
    public func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer += string
        onWrite?(string)
    }
    
    public func getBuffer() -> String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = ""
    }
}

// MARK: - Test Helpers

/// Creates a mock key event
public func mockKey(_ key: String, alt: Bool = false) -> KeyMsg {
    if key.count == 1 {
        return KeyMsg(character: Character(key), alt: alt)
    } else {
        // Handle special keys
        switch key {
        case "enter": return KeyMsg(type: .enter, alt: alt)
        case "escape": return KeyMsg(type: .escape, alt: alt)
        case "up": return KeyMsg(type: .up, alt: alt)
        case "down": return KeyMsg(type: .down, alt: alt)
        case "left": return KeyMsg(type: .left, alt: alt)
        case "right": return KeyMsg(type: .right, alt: alt)
        default: return KeyMsg(character: "?", alt: alt)
        }
    }
}

/// Creates a mock window size message
public func mockWindowSize(width: Int, height: Int) -> WindowSizeMsg {
    return WindowSizeMsg(width: width, height: height)
}

/// Asserts that a closure throws a specific error type
public func assertThrows<T, E: Error>(
    _ expression: () async throws -> T,
    errorType: E.Type,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        _ = try await expression()
        Issue.record("Expected error of type \(errorType) but no error was thrown", sourceLocation: sourceLocation)
    } catch let error as E {
        // Success - got expected error type
        _ = error
    } catch {
        Issue.record("Expected error of type \(errorType) but got \(type(of: error))", sourceLocation: sourceLocation)
    }
}