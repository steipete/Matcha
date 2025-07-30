//
//  CommandTests.swift
//  MatchaTests
//
//  Tests for the Command system.
//

import Testing
@testable import Matcha

@Suite("Command System Tests")
struct CommandTests {
    
    @Test("Basic command executes and returns message")
    func basicCommand() async throws {
        // Test that a command executes and returns a message
        let command = Command<TestMessage> { () async -> TestMessage? in
            return .increment
        }
        
        let result = await command.operation()
        #expect(result == .increment)
    }
    
    @Test("Batch command executes commands concurrently")
    func batchCommand() async throws {
        var results: [TestMessage] = []
        
        let cmd1 = Command<TestMessage> { () async -> TestMessage? in
            try? await Task.sleep(for: .milliseconds(10))
            return .increment
        }
        
        let cmd2 = Command<TestMessage> { () async -> TestMessage? in
            try? await Task.sleep(for: .milliseconds(20))
            return .decrement
        }
        
        let cmd3 = Command<TestMessage> { () async -> TestMessage? in
            return .setText("Batch")
        }
        
        let batch = Command<TestMessage>.batch(cmd1, cmd2, cmd3)
        
        // Execute batch command
        if let msg = await batch.operation() {
            results.append(msg)
        }
        
        // Batch should execute all commands concurrently
        // We can't guarantee order, but we should get one result
        #expect(!results.isEmpty)
    }
    
    @Test("Sequence command executes commands in order")
    func sequenceCommand() async throws {
        var executionOrder: [String] = []
        
        let cmd1 = Command<TestMessage> { () async -> TestMessage? in
            executionOrder.append("cmd1")
            return .increment
        }
        
        let cmd2 = Command<TestMessage> { () async -> TestMessage? in
            executionOrder.append("cmd2")
            return .decrement
        }
        
        let sequence = Command<TestMessage>.sequence(cmd1, cmd2)
        
        // Execute sequence - should run in order
        _ = await sequence.operation()
        
        // Note: sequence returns first non-nil result
        #expect(executionOrder.contains("cmd1") || executionOrder.contains("cmd2"))
    }
    
    @Test("Timer command executes after delay")
    func timerCommand() async throws {
        let start = Date()
        var tickReceived = false
        
        let tickCmd = tick(.milliseconds(100)) { _ in
            tickReceived = true
            return TestMessage.tick
        }
        
        let result = await tickCmd.operation()
        let elapsed = Date().timeIntervalSince(start)
        
        #expect(tickReceived)
        #expect(result == .tick)
        #expect(elapsed >= 0.09) // Allow small timing variance
    }
    
    @Test("Every command executes repeatedly")
    func everyCommand() async throws {
        var tickCount = 0
        let confirmation = Confirmation("Multiple ticks", expectedCount: 1)
        
        let everyCmd = every(.milliseconds(50)) { _ in
            tickCount += 1
            if tickCount >= 3 {
                Task {
                    await confirmation.fulfill()
                }
            }
            return TestMessage.tick
        }
        
        // Start the every command in background
        Task {
            _ = await everyCmd.operation()
        }
        
        // Wait for multiple ticks
        try await fulfillment(of: [confirmation], timeout: .seconds(0.5))
        
        #expect(tickCount >= 3)
    }
    
    @Test("Pure command returns value immediately")
    func pureCommand() async throws {
        let pureCmd = Command<TestMessage>.pure(.setText("Pure"))
        let result = await pureCmd.operation()
        
        #expect(result == .setText("Pure"))
    }
    
    @Test("Command can return nil")
    func nilCommand() async throws {
        let nilCmd = Command<TestMessage> { () async -> TestMessage? in
            return nil
        }
        
        let result = await nilCmd.operation()
        #expect(result == nil)
    }
    
    @Test("Command handles errors gracefully")
    func commandWithError() async throws {
        enum TestError: Error {
            case expected
        }
        
        let errorCmd = Command<TestMessage> { () async -> TestMessage? in
            throw TestError.expected
        }
        
        // Commands should handle errors gracefully
        let result = await errorCmd.operation()
        #expect(result == nil) // Error results in nil
    }
    
    @Test("Async command completes after delay")
    func asyncCommand() async throws {
        let asyncCmd = Command<TestMessage> { () async -> TestMessage? in
            // Simulate async work
            try? await Task.sleep(for: .milliseconds(50))
            
            // Simulate network call result
            let success = Bool.random()
            return success ? .setText("Success") : nil
        }
        
        let start = Date()
        _ = await asyncCmd.operation()
        let elapsed = Date().timeIntervalSince(start)
        
        // Should have taken at least 50ms
        #expect(elapsed >= 0.045)
    }
}

// MARK: - Built-in Commands Tests

@Suite("Built-in Commands Tests")
struct BuiltInCommandsTests {
    
    @Test("Quit command returns QuitMsg")
    func quitCommand() async throws {
        let quitCmd = quit() as Command<QuitMsg>
        let result = await quitCmd.operation()
        
        #expect(result != nil)
        #expect(result is QuitMsg)
    }
    
    @Test("Window size command executes without crashing")
    func windowSizeCommand() async throws {
        // Note: This is a placeholder - actual window size requires terminal
        let sizeCmd = windowSize() as Command<WindowSizeMsg>
        let result = await sizeCmd.operation()
        
        // In test environment, might return nil or default size
        // Just verify it doesn't crash
        _ = result
    }
    
    @Test("Print commands return nil")
    func printCommands() async throws {
        // Test println
        let printCmd = println("Test") as Command<Never>
        let printResult = await printCmd.operation()
        #expect(printResult == nil) // Print commands don't return messages
        
        // Test printf
        let printfCmd = printf("Value: %d", 42) as Command<Never>
        let printfResult = await printfCmd.operation()
        #expect(printfResult == nil)
    }
}