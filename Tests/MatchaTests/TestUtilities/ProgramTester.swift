//
//  ProgramTester.swift
//  MatchaTests
//
//  Test utilities for testing Matcha programs.
//

import Foundation
import XCTest
@testable import Matcha

/// A test harness for running and testing Matcha programs
public class ProgramTester<M: Model> {
    private let program: Program<M>
    private var capturedOutput: String = ""
    private var messages: [M.Msg] = []
    private var expectationQueue: [() async throws -> Void] = []
    
    /// Creates a new program tester
    public init(model: M, options: ProgramOptions = .default) {
        // Create custom output stream to capture rendering
        let outputCapture = OutputCapture()
        
        var testOptions = options
        testOptions.output = outputCapture
        testOptions.fps = 120 // High FPS for faster testing
        
        self.program = Program(initialModel: model, options: testOptions)
        
        // Set up output capture callback
        outputCapture.onWrite = { [weak self] content in
            self?.capturedOutput += content
        }
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
        let keyMsg = Key(description: key)
        if let msg = keyMsg as? M.Msg {
            await send(msg)
        }
    }
    
    /// Sends a mouse event
    public func sendMouse(x: Int, y: Int, action: MouseAction, button: MouseButton = .left) async {
        let mouseEvent = MouseEvent(
            x: x,
            y: y,
            action: action,
            button: button,
            shift: false,
            alt: false,
            ctrl: false
        )
        if let msg = mouseEvent as? M.Msg {
            await send(msg)
        }
    }
    
    /// Gets the current rendered view
    public func getCurrentView() -> String {
        return capturedOutput
    }
    
    /// Clears the captured output
    public func clearOutput() {
        capturedOutput = ""
    }
    
    /// Expects the view to contain a specific string
    public func expectView(containing text: String, file: StaticString = #file, line: UInt = #line) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        XCTAssertTrue(
            view.contains(text),
            "Expected view to contain '\(text)' but got:\n\(view)",
            file: file,
            line: line
        )
    }
    
    /// Expects the view to match exactly
    public func expectView(equalTo expected: String, file: StaticString = #file, line: UInt = #line) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        XCTAssertEqual(
            view.trimmingCharacters(in: .whitespacesAndNewlines),
            expected.trimmingCharacters(in: .whitespacesAndNewlines),
            file: file,
            line: line
        )
    }
    
    /// Expects the view to match a regex pattern
    public func expectView(matching pattern: String, file: StaticString = #file, line: UInt = #line) async throws {
        // Allow rendering to complete
        try await Task.sleep(for: .milliseconds(50))
        
        let view = getCurrentView()
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: view.utf16.count)
        
        XCTAssertTrue(
            regex.firstMatch(in: view, range: range) != nil,
            "Expected view to match pattern '\(pattern)' but got:\n\(view)",
            file: file,
            line: line
        )
    }
    
    /// Gets the current model state
    public var model: M {
        return program.model
    }
    
    /// Runs the program for a specific duration
    public func run(for duration: Duration) async throws {
        let task = Task {
            try await program.run()
        }
        
        try await Task.sleep(for: duration)
        program.quit()
        
        _ = try await task.value
    }
    
    /// Runs a test scenario with automatic cleanup
    public func test(_ scenario: () async throws -> Void) async throws {
        defer {
            program.quit()
        }
        
        try await scenario()
    }
}

/// Output capture stream for testing
private class OutputCapture: TextOutputStream, @unchecked Sendable {
    var onWrite: ((String) -> Void)?
    
    func write(_ string: String) {
        onWrite?(string)
    }
}

// MARK: - Test Helpers

/// Creates a mock key event
public func mockKey(_ key: String, alt: Bool = false, ctrl: Bool = false) -> Key {
    return Key(description: key)
}

/// Creates a mock window size message
public func mockWindowSize(width: Int, height: Int) -> WindowSizeMsg {
    return WindowSizeMsg(width: width, height: height)
}

/// Asserts that a closure throws a specific error type
public func assertThrows<T, E: Error>(
    _ expression: () async throws -> T,
    errorType: E.Type,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error of type \(errorType) but no error was thrown", file: file, line: line)
    } catch let error as E {
        // Success - got expected error type
        _ = error
    } catch {
        XCTFail("Expected error of type \(errorType) but got \(type(of: error))", file: file, line: line)
    }
}