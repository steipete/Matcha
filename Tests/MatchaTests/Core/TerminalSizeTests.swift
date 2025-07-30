import Foundation
import Testing
@testable import Matcha

@Suite("Terminal Size Tracking Tests")
@MainActor
struct TerminalSizeTests {
    
    @Test("Terminal size is tracked in renderer")
    func testTerminalSizeTracking() async throws {
        struct SizeTrackingModel: Model {
            typealias Msg = WindowSizeMsg
            
            var receivedWidth: Int = 0
            var receivedHeight: Int = 0
            
            init() {}
            
            func `init`() -> Command<WindowSizeMsg>? {
                nil
            }
            
            func update(_ message: WindowSizeMsg) -> (SizeTrackingModel, Command<WindowSizeMsg>?) {
                var model = self
                model.receivedWidth = message.width
                model.receivedHeight = message.height
                return (model, nil)
            }
            
            func view() -> String {
                "Size: \(receivedWidth)x\(receivedHeight)"
            }
        }
        
        let tester = ProgramTester<SizeTrackingModel>(model: SizeTrackingModel())
        
        try await tester.test {
            // Send a window size message
            await tester.send(WindowSizeMsg(width: 120, height: 40))
            
            // Allow time for processing
            try await Task.sleep(for: .milliseconds(50))
            
            // Check that the model received the size
            #expect(tester.model.receivedWidth == 120)
            #expect(tester.model.receivedHeight == 40)
            
            // Verify the view reflects the size
            try await tester.expectView(containing: "Size: 120x40")
        }
    }
    
    @Test("Terminal size is queried at startup")
    func testTerminalSizeInitialization() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        
        // The renderer should have queried the terminal size at startup
        let size = await renderer.terminalSize
        
        // Should have default size at minimum
        #expect(size.width > 0)
        #expect(size.height > 0)
        
        await renderer.stop()
    }
    
    @Test("Terminal size limits rendering")
    func testTerminalSizeLimitsRendering() async throws {
        let output = TestOutputStream()
        let renderer = StandardRenderer(output: output)
        
        await renderer.start()
        
        // Set a small terminal size
        await renderer.setTerminalSize(width: 80, height: 10)
        
        // Write content that exceeds terminal height
        var content = ""
        for i in 1...20 {
            content += "Line \(i)\n"
        }
        
        await renderer.enterAltScreen()
        await renderer.write(content)
        
        // Allow time for rendering
        try await Task.sleep(for: .milliseconds(50))
        
        // The output should be limited by terminal height
        let outputContent = output.content
        
        // Should not render lines beyond terminal height
        #expect(!outputContent.contains("Line 15"))
        #expect(!outputContent.contains("Line 20"))
        
        await renderer.stop()
    }
}