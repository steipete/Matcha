import Foundation
import Testing
@testable import Matcha

@Suite("Message Queue Rendering Tests")
@MainActor
struct MessageQueueTests {
    
    @Test("PrintLineMsg messages are queued and flushed")
    func testPrintLineMessageQueueing() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        
        // Queue some messages
        await renderer.queueMessageLine("First message")
        await renderer.queueMessageLine("Second message")
        await renderer.queueMessageLine("Multi\nLine\nMessage")
        
        // Allow time for rendering
        try await Task.sleep(for: .milliseconds(50))
        
        // The output should contain all queued messages
        let outputContent = output.content
        #expect(outputContent.contains("First message"))
        #expect(outputContent.contains("Second message"))
        #expect(outputContent.contains("Multi"))
        #expect(outputContent.contains("Line"))
        #expect(outputContent.contains("Message"))
        
        // Messages should be followed by carriage return and newline
        #expect(outputContent.contains("\r\n"))
        
        await renderer.stop()
    }
    
    @Test("PrintLineMsg messages are not queued in alt screen mode")
    func testNoQueueingInAltScreen() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        await renderer.enterAltScreen()
        
        // Clear output to ignore alt screen setup
        output.clear()
        
        // Try to queue messages while in alt screen
        await renderer.queueMessageLine("Should not appear")
        await renderer.queueMessageLine("Another message")
        
        // Allow time for rendering
        try await Task.sleep(for: .milliseconds(50))
        
        // The output should NOT contain the queued messages
        let outputContent = output.content
        #expect(!outputContent.contains("Should not appear"))
        #expect(!outputContent.contains("Another message"))
        
        await renderer.exitAltScreen()
        await renderer.stop()
    }
    
    @Test("Messages are flushed before regular content")
    func testMessageFlushOrder() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        
        // Queue a message
        await renderer.queueMessageLine("Queued message")
        
        // Write regular content
        await renderer.write("Regular content line 1\nRegular content line 2")
        
        // Allow time for rendering
        try await Task.sleep(for: .milliseconds(50))
        
        // The queued message should appear before regular content
        let outputContent = output.content
        let queuedIndex = outputContent.range(of: "Queued message")?.lowerBound
        let regularIndex = outputContent.range(of: "Regular content")?.lowerBound
        
        if let queuedIndex = queuedIndex, let regularIndex = regularIndex {
            #expect(queuedIndex < regularIndex)
        } else {
            Issue.record("Expected both queued and regular content in output")
        }
        
        await renderer.stop()
    }
    
    @Test("Queued messages trigger immediate repaint")
    func testQueuedMessageTriggersRepaint() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output, fps: 1) // Low FPS to test immediate repaint
        
        await renderer.start()
        
        // Clear initial output
        output.clear()
        
        // Queue a message
        await renderer.queueMessageLine("Immediate message")
        
        // Wait a short time (less than 1 second frame time)
        try await Task.sleep(for: .milliseconds(100))
        
        // The message should already be rendered despite low FPS
        let outputContent = output.content
        #expect(outputContent.contains("Immediate message"))
        
        await renderer.stop()
    }
    
    @Test("PrintLineMsg via Program")
    func testPrintLineMsgViaProgram() async throws {
        struct PrintLineModel: Model {
            typealias Msg = TestMessage
            
            enum TestMessage: Message {
                case print(String)
            }
            
            var printed: [String] = []
            
            init() {}
            
            func `init`() -> Command<TestMessage>? {
                nil
            }
            
            func update(_ message: TestMessage) -> (PrintLineModel, Command<TestMessage>?) {
                switch message {
                case .print(let text):
                    var model = self
                    model.printed.append(text)
                    // Return a PrintLineMsg command
                    return (model, Command { () async -> TestMessage? in
                        PrintLineMsg(text: text) as? TestMessage
                    })
                }
            }
            
            func view() -> String {
                "View content"
            }
        }
        
        let tester = ProgramTester<PrintLineModel>(model: PrintLineModel())
        
        try await tester.test {
            // Send print messages
            await tester.send(.print("Test message 1"))
            await tester.send(.print("Test message 2"))
            
            // Allow time for processing
            try await Task.sleep(for: .milliseconds(100))
            
            // Verify the model tracked the messages
            #expect(tester.model.printed.contains("Test message 1"))
            #expect(tester.model.printed.contains("Test message 2"))
        }
    }
}