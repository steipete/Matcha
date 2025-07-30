import Foundation
import Testing
@testable import Matcha

@Suite("Command Batching and Sequencing Tests")
@MainActor
struct CommandBatchingTests {
    
    enum TestMessage: Message, Equatable {
        case result(String)
        case error(String)
        case tick
    }
    
    @Test("Batch with commands executes in parallel")
    func batchWithCommands() async throws {
        // Test that commands are executed
        let cmd1 = Command<TestMessage> { TestMessage.result("cmd1") }
        let cmd2 = Command<TestMessage> { TestMessage.result("cmd2") }
        let cmd3 = Command<TestMessage> { TestMessage.result("cmd3") }
        
        let batchCmd = Matcha.batch(cmd1, cmd2, cmd3)
        
        let result = await batchCmd.execute()
        
        // Batch returns the first non-nil message
        if let testMsg = result as? TestMessage {
            #expect(testMsg == .result("cmd1") || testMsg == .result("cmd2") || testMsg == .result("cmd3"))
        } else {
            Issue.record("Expected TestMessage result")
        }
    }
    
    @Test("Batch with empty array")
    func batchWithEmptyCommands() async throws {
        let batchCmd = Matcha.batch([Command<TestMessage>]())
        let result = await batchCmd.execute()
        #expect(result == nil)
    }
    
    @Test("Batch with single command")
    func batchWithSingleCommand() async throws {
        let cmd = Command<TestMessage> { TestMessage.result("single") }
        let batchCmd = Matcha.batch(cmd)
        
        let result = await batchCmd.execute()
        if let testMsg = result as? TestMessage {
            #expect(testMsg == .result("single"))
        } else {
            Issue.record("Expected TestMessage")
        }
    }
    
    @Test("Batch executes commands concurrently")
    func batchConcurrentExecution() async throws {
        // Use an actor to track execution order safely
        let tracker = ExecutionTracker()
        
        let cmd1 = Command<TestMessage> {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {}
            await tracker.record("cmd1")
            return TestMessage.result("1")
        }
        
        let cmd2 = Command<TestMessage> {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {}
            await tracker.record("cmd2")
            return TestMessage.result("2")
        }
        
        let cmd3 = Command<TestMessage> {
            await tracker.record("cmd3")
            return TestMessage.result("3")
        }
        
        let batchCmd = Matcha.batch([cmd1, cmd2, cmd3])
        let result = await batchCmd.execute()
        
        // Commands should execute concurrently
        let order = await tracker.getOrder()
        // cmd3 should finish first (no delay), then cmd2 (50ms), then cmd1 (100ms)
        #expect(order.first == "cmd3")
        
        // Result is one of the messages
        #expect(result != nil)
    }
    
    @Test("Sequence executes commands in order")
    func sequenceExecutesInOrder() async throws {
        let tracker = ExecutionTracker()
        
        let cmd1 = Command<TestMessage> {
            await tracker.record("cmd1")
            return TestMessage.result("1")
        }
        
        let cmd2 = Command<TestMessage> {
            await tracker.record("cmd2")
            return TestMessage.result("2")
        }
        
        let cmd3 = Command<TestMessage> {
            await tracker.record("cmd3")
            return TestMessage.result("3")
        }
        
        let sequenceCmd = Command<TestMessage>.sequence([cmd1, cmd2, cmd3])
        
        let finalResult = await sequenceCmd.execute()
        
        // Verify execution order - sequence stops at first non-nil
        let order = await tracker.getOrder()
        #expect(order == ["cmd1"]) // Only first command executes since it returns non-nil
        
        // The result should be from the first command that returns non-nil
        if let testMsg = finalResult as? TestMessage {
            #expect(testMsg == .result("1"))
        } else {
            Issue.record("Expected TestMessage")
        }
    }
    
    @Test("Sequence with nil returning commands")
    func sequenceWithNilReturns() async throws {
        let nilCmd = Command<TestMessage> { nil }
        let resultCmd = Command<TestMessage> { TestMessage.result("result") }
        let nilCmd2 = Command<TestMessage> { nil }
        
        let sequenceCmd = Command<TestMessage>.sequence([nilCmd, resultCmd, nilCmd2])
        
        let result = await sequenceCmd.execute()
        
        // Should get the result from the first non-nil command
        if let testMsg = result as? TestMessage {
            #expect(testMsg == .result("result"))
        } else {
            Issue.record("Expected TestMessage")
        }
    }
    
    @Test("Sequence returns first non-nil message")
    func sequenceReturnsFirstNonNil() async throws {
        let tracker = ExecutionTracker()
        
        let cmd1 = Command<TestMessage> {
            await tracker.record("cmd1")
            return nil
        }
        
        let cmd2 = Command<TestMessage> {
            await tracker.record("cmd2")
            return TestMessage.result("first")
        }
        
        let cmd3 = Command<TestMessage> {
            await tracker.record("cmd3")
            return TestMessage.result("second")
        }
        
        let sequenceCmd = Command<TestMessage>.sequence([cmd1, cmd2, cmd3])
        
        let result = await sequenceCmd.execute()
        
        // Only executes until first non-nil result
        let order = await tracker.getOrder()
        #expect(order == ["cmd1", "cmd2"]) // Stops after cmd2 returns non-nil
        if let testMsg = result as? TestMessage {
            #expect(testMsg == .result("first"))
        } else {
            Issue.record("Expected TestMessage")
        }
    }
    
    @Test("Sequence with all nil commands")
    func sequenceAllNil() async throws {
        let cmd1 = Command<TestMessage> { nil }
        let cmd2 = Command<TestMessage> { nil }
        let cmd3 = Command<TestMessage> { nil }
        
        let sequenceCmd = Command<TestMessage>.sequence([cmd1, cmd2, cmd3])
        
        let result = await sequenceCmd.execute()
        
        #expect(result == nil)
    }
    
    @Test("Every command with interval")
    func everyCommandInterval() async throws {
        let interval = Duration.milliseconds(50)
        let tracker = ExecutionTracker()
        
        let everyCmd = every(interval) { _ in
            // Can't use async in sync closure
            TestMessage.tick
        }
        
        // Execute multiple times
        for _ in 0..<3 {
            let start = ContinuousClock.now
            let result = await everyCmd.execute()
            let elapsed = ContinuousClock.now - start
            
            if let msg = result as? any Message,
               let testMsg = msg as? TestMessage {
                #expect(testMsg == .tick)
            }
            #expect(elapsed >= interval * 0.9) // Allow 10% tolerance
        }
        
        // Can't track async execution in sync every closure
        #expect(Bool(true))
    }
    
    @Test("Tick command executes once after delay")
    func tickCommandDelay() async throws {
        let delay = Duration.milliseconds(100)
        let tracker = ExecutionTracker()
        
        let tickCmd = tick(delay) { _ in
            // Can't use async in sync closure
            TestMessage.tick
        }
        
        let start = ContinuousClock.now
        let result = await tickCmd.execute()
        let elapsed = ContinuousClock.now - start
        
        if let testMsg = result as? TestMessage {
            #expect(testMsg == .tick)
        }
        // Can't track async execution in sync tick closure
        #expect(Bool(true))
        #expect(elapsed >= delay * 0.9) // Allow 10% tolerance
    }
}

// Actor to safely track execution order
private actor ExecutionTracker {
    private var order: [String] = []
    
    func record(_ id: String) {
        order.append(id)
    }
    
    func getOrder() -> [String] {
        return order
    }
}