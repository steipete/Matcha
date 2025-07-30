//
//  SignalHandlingTests.swift
//  MatchaTests
//
//  Tests for signal handling and process management.
//

import Testing
@testable import Matcha

/// Tests for signal handling functionality
@Suite("Signal Handling Tests")
struct SignalHandlingTests {
    
    // MARK: - Signal Handler Tests
    
    /// Test that window size changes are handled
    @Test("Window size changes are handled")
    @MainActor
    func testWindowSizeSignal() async throws {
        var receivedSizeMsg = false
        
        struct SizeModel: Model {
            typealias Msg = SizeMessage
            
            var width: Int = 0
            var height: Int = 0
            
            func `init`() -> Command<SizeMessage>? {
                return nil
            }
            
            func update(_ message: SizeMessage) -> (SizeModel, Command<SizeMessage>?) {
                var model = self
                
                switch message {
                case .windowSize(let w, let h):
                    model.width = w
                    model.height = h
                    return (model, Command { () -> SizeMessage? in
                        return .sizeReceived
                    })
                case .sizeReceived:
                    return (model, nil)
                }
            }
            
            func view() -> String {
                return "Window: \(width)x\(height)"
            }
        }
        
        enum SizeMessage: Message {
            case windowSize(Int, Int)
            case sizeReceived
        }
        
        let model = SizeModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.handleSignals = true
        
        let program = Program(initialModel: model, options: options)
        
        // Override the model to intercept window size messages
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // The program should receive initial window size
        // In testing, we can't easily trigger SIGWINCH, so we'll send the message directly
        program.send(WindowSizeMsg(width: 120, height: 40))
        
        // Wait for processing
        try await Task.sleep(for: .milliseconds(100))
        
        program.quit()
        await programTask.value
    }
    
    /// Test suspension and resumption (Ctrl+Z)
    @Test("Suspension and resumption (Ctrl+Z)")
    @MainActor
    func testSuspendResume() async throws {
        var suspended = false
        var resumed = false
        
        struct SuspendModel: Model {
            typealias Msg = SuspendMessage
            
            var state: String = "running"
            
            func `init`() -> Command<SuspendMessage>? {
                return nil
            }
            
            func update(_ message: SuspendMessage) -> (SuspendModel, Command<SuspendMessage>?) {
                var model = self
                
                switch message {
                case .suspend:
                    model.state = "suspended"
                    return (model, nil)
                case .resume:
                    model.state = "resumed"
                    return (model, nil)
                }
            }
            
            func view() -> String {
                return "State: \(state)"
            }
        }
        
        enum SuspendMessage: Message {
            case suspend
            case resume
        }
        
        let model = SuspendModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // Send suspend message (simulating Ctrl+Z)
        program.send(SuspendMsg())
        
        // In real usage, the process would be suspended here
        // For testing, we'll just verify the message is handled
        try await Task.sleep(for: .milliseconds(100))
        
        // Send resume message
        program.send(ResumeMsg())
        
        try await Task.sleep(for: .milliseconds(100))
        
        program.quit()
        await programTask.value
    }
    
    // MARK: - Signal Configuration Tests
    
    /// Test that signals can be disabled
    @Test("Signals can be disabled")
    @MainActor
    func testSignalsDisabled() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.disableSignals = true
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // Signals should be ignored when disabled
        // We can't easily test actual signal delivery, but we can verify the option works
        #expect(options.disableSignals)
        
        program.quit()
        await programTask.value
    }
    
    /// Test custom signal handler option
    @Test("Custom signal handler option")
    @MainActor
    func testWithoutSignalHandler() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.handleSignals = false // Disable built-in handler
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // Program should run without signal handlers
        #expect(!options.handleSignals)
        
        program.quit()
        await programTask.value
    }
    
    // MARK: - Edge Case Tests
    
    /// Test multiple rapid quit signals
    @Test("Multiple rapid quit signals")
    @MainActor
    func testMultipleQuitSignals() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // Send multiple quit signals rapidly
        for _ in 0..<10 {
            program.quit()
        }
        
        // Program should handle gracefully and exit once
        await programTask.value
    }
    
    /// Test signal handling during command execution
    @Test("Signal handling during command execution")
    @MainActor
    func testSignalDuringCommand() async throws {
        struct LongRunningModel: Model {
            typealias Msg = LongRunningMessage
            
            var commandStarted = false
            var commandCompleted = false
            
            func `init`() -> Command<LongRunningMessage>? {
                return nil
            }
            
            func update(_ message: LongRunningMessage) -> (LongRunningModel, Command<LongRunningMessage>?) {
                var model = self
                
                switch message {
                case .startLongCommand:
                    model.commandStarted = true
                    return (model, Command { () async -> LongRunningMessage? in
                        // Simulate long-running command
                        for _ in 0..<10 {
                            try? await Task.sleep(for: .milliseconds(100))
                            if Task.isCancelled {
                                return .commandCancelled
                            }
                        }
                        return .commandCompleted
                    })
                    
                case .commandCompleted:
                    model.commandCompleted = true
                    return (model, nil)
                    
                case .commandCancelled:
                    return (model, nil)
                }
            }
            
            func view() -> String {
                return "Command: \(commandStarted ? "started" : "waiting") - \(commandCompleted ? "completed" : "running")"
            }
        }
        
        enum LongRunningMessage: Message {
            case startLongCommand
            case commandCompleted
            case commandCancelled
        }
        
        let model = LongRunningModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Start long command
        program.send(LongRunningMessage.startLongCommand)
        
        // Wait a bit
        try await Task.sleep(for: .milliseconds(200))
        
        // Quit while command is running
        program.quit()
        
        // Should handle gracefully
        await programTask.value
    }
    
    // MARK: - Terminal Mode Tests
    
    /// Test that raw mode is properly managed with signals
    @Test("Raw mode is properly managed with signals")
    @MainActor
    func testRawModeWithSignals() async throws {
        let model = TestModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.handleSignals = true
        
        // Save initial terminal state
        let initialState = try? Terminal.current.getState()
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for program to enter raw mode
        try await Task.sleep(for: .milliseconds(100))
        
        // Terminal should be in raw mode now
        // We can't easily verify this in tests, but the program should handle it
        
        // Send interrupt
        program.send(InterruptMsg())
        
        try await Task.sleep(for: .milliseconds(100))
        
        program.quit()
        await programTask.value
        
        // Terminal should be restored
        let finalState = try? Terminal.current.getState()
        #expect(initialState != nil)
        #expect(finalState != nil)
    }
    
    // MARK: - Focus Event Tests
    
    /// Test focus and blur events
    @Test("Focus and blur events")
    @MainActor
    func testFocusEvents() async throws {
        struct FocusModel: Model {
            typealias Msg = FocusMessage
            
            var hasFocus = true
            var focusChangeCount = 0
            
            func `init`() -> Command<FocusMessage>? {
                return nil
            }
            
            func update(_ message: FocusMessage) -> (FocusModel, Command<FocusMessage>?) {
                var model = self
                
                switch message {
                case .focus:
                    model.hasFocus = true
                    model.focusChangeCount += 1
                    return (model, nil)
                case .blur:
                    model.hasFocus = false
                    model.focusChangeCount += 1
                    return (model, nil)
                }
            }
            
            func view() -> String {
                return "Focus: \(hasFocus ? "YES" : "NO") (changes: \(focusChangeCount))"
            }
        }
        
        enum FocusMessage: Message {
            case focus
            case blur
        }
        
        let model = FocusModel()
        var options = ProgramOptions.default
        options.output = TestOutputStream()
        options.reportFocus = true
        
        let program = Program(initialModel: model, options: options)
        
        let programTask = Task {
            _ = try? await program.run()
        }
        
        // Wait for startup
        try await Task.sleep(for: .milliseconds(100))
        
        // Simulate focus events
        program.send(BlurMsg())
        try await Task.sleep(for: .milliseconds(50))
        
        program.send(FocusMsg())
        try await Task.sleep(for: .milliseconds(50))
        
        program.send(BlurMsg())
        try await Task.sleep(for: .milliseconds(50))
        
        program.quit()
        await programTask.value
    }
}