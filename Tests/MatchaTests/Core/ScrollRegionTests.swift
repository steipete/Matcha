import Foundation
import Testing
@testable import Matcha

@Suite("Scroll Region Tests")
@MainActor
struct ScrollRegionTests {
    
    @Test("Sync scroll area sets up region correctly")
    func testSyncScrollArea() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        await renderer.enterAltScreen()
        
        // Clear output to ignore setup
        output.clear()
        
        // Sync a scroll area
        let lines = ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5"]
        await renderer.syncScrollArea(lines: lines, topBoundary: 5, bottomBoundary: 10)
        
        let content = output.content
        
        // Should set scroll region
        #expect(content.contains("\u{1B}[5;10r"))
        
        // Should move cursor to top of scroll area
        #expect(content.contains("\u{1B}[5;1H"))
        
        // Should use InsertLine like Bubble Tea
        #expect(content.contains("\u{1B}[\(lines.count)L"))
        
        // Should contain the lines
        for line in lines {
            #expect(content.contains(line))
        }
        
        // Should reset scroll region (0;height)
        #expect(content.contains("\u{1B}[0;24r"))
        
        await renderer.stop()
    }
    
    @Test("Scroll up adds lines at top")
    func testScrollUp() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        await renderer.enterAltScreen()
        
        // Clear output to ignore setup
        output.clear()
        
        // Scroll up with new lines
        let newLines = ["New Top 1", "New Top 2", "New Top 3"]
        await renderer.scrollUp(newLines: newLines, topBoundary: 5, bottomBoundary: 15)
        
        let content = output.content
        
        // Should set scroll region
        #expect(content.contains("\u{1B}[5;15r"))
        
        // Should move cursor to top of scroll area
        #expect(content.contains("\u{1B}[5;1H"))
        
        // Should use InsertLine like Bubble Tea
        #expect(content.contains("\u{1B}[\(newLines.count)L"))
        
        // Should contain the new lines
        for line in newLines {
            #expect(content.contains(line))
        }
        
        // Should reset scroll region (0;height)
        #expect(content.contains("\u{1B}[0;24r"))
        
        await renderer.stop()
    }
    
    @Test("Scroll down adds lines at bottom")
    func testScrollDown() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        await renderer.enterAltScreen()
        
        // Clear output to ignore setup
        output.clear()
        
        // Scroll down with new lines
        let newLines = ["New Bottom 1", "New Bottom 2"]
        await renderer.scrollDown(newLines: newLines, topBoundary: 5, bottomBoundary: 15)
        
        let content = output.content
        
        // Should set scroll region
        #expect(content.contains("\u{1B}[5;15r"))
        
        // Should move cursor to bottom of scroll area
        #expect(content.contains("\u{1B}[15;1H"))
        
        // Should contain carriage return and newline that triggers scrolling
        #expect(content.contains("\r\n"))
        
        // Should contain the new lines
        for line in newLines {
            #expect(content.contains(line))
        }
        
        // Should reset scroll region (0;height)
        #expect(content.contains("\u{1B}[0;24r"))
        
        await renderer.stop()
    }
    
    @Test("Clear scroll area resets region")
    func testClearScrollArea() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        await renderer.enterAltScreen()
        
        // Set up a scroll area first
        await renderer.syncScrollArea(lines: ["Test"], topBoundary: 5, bottomBoundary: 10)
        
        // Clear output
        output.clear()
        
        // Clear scroll area
        await renderer.clearScrollArea()
        
        let content = output.content
        
        // Should reset scroll region to full screen
        #expect(content.contains("\u{1B}[r"))
        
        await renderer.stop()
    }
    
    @Test("Scroll region messages via Program")
    func testScrollRegionMessages() async throws {
        enum TestMsg: Message {
            case sync
            case scrollUp  
            case scrollDown
            case scrollRegionProcessed
        }
        
        struct ScrollModel: Model {
            typealias Msg = TestMsg
            
            var synced = false
            var scrolledUp = false
            var scrolledDown = false
            
            init() {}
            
            func `init`() -> Command<TestMsg>? {
                nil
            }
            
            func update(_ message: TestMsg) -> (ScrollModel, Command<TestMsg>?) {
                var model = self
                
                switch message {
                case .sync:
                    model.synced = true
                    // The renderer will handle the ScrollSyncMsg internally
                    return (model, nil)
                    
                case .scrollUp:
                    model.scrolledUp = true
                    // The renderer will handle the ScrollUpMsg internally
                    return (model, nil)
                    
                case .scrollDown:
                    model.scrolledDown = true
                    // The renderer will handle the ScrollDownMsg internally
                    return (model, nil)
                    
                case .scrollRegionProcessed:
                    // Just for tracking that the message was processed
                    return (model, nil)
                }
            }
            
            func view() -> String {
                "Scroll test view"
            }
        }
        
        let tester = ProgramTester<ScrollModel>(model: ScrollModel())
        
        try await tester.test {
            // Test sync - the model triggers the action, renderer handles the actual message
            await tester.send(.sync)
            try await Task.sleep(for: .milliseconds(50))
            #expect(tester.model.synced)
            
            // Test scroll up
            await tester.send(.scrollUp)
            try await Task.sleep(for: .milliseconds(50))
            #expect(tester.model.scrolledUp)
            
            // Test scroll down
            await tester.send(.scrollDown)
            try await Task.sleep(for: .milliseconds(50))
            #expect(tester.model.scrolledDown)
        }
    }
}