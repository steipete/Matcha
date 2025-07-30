import Foundation
import Testing
@testable import Matcha

@Suite("Scroll Region Tests")
@MainActor
struct ScrollRegionTests {
    @Test("Sync scroll area sets up region correctly")
    func testSyncScrollArea() async throws {
        let output = TestOutputStream(interpretANSI: false)
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
        let output = TestOutputStream(interpretANSI: false)
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
        let output = TestOutputStream(interpretANSI: false)
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
        let output = TestOutputStream(interpretANSI: false)
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
    func scrollRegionMessages() async throws {
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
            var counter = 0

            func `init`() -> Command<TestMsg>? {
                nil
            }

            func update(_ message: TestMsg) -> (ScrollModel, Command<TestMsg>?) {
                var model = self
                model.counter += 1

                switch message {
                case .sync:
                    model.synced = true
                    // Use the scroll region commands
                    let lines = ["Sync Line 1", "Sync Line 2", "Sync Line 3"]
                    return (model, SyncScrollArea(lines, topBoundary: 5, bottomBoundary: 10))

                case .scrollUp:
                    model.scrolledUp = true
                    // Use the scroll up command
                    let newLines = ["New Top Line \(model.counter)"]
                    return (model, ScrollUp(newLines, topBoundary: 5, bottomBoundary: 10))

                case .scrollDown:
                    model.scrolledDown = true
                    // Use the scroll down command
                    let newLines = ["New Bottom Line \(model.counter)"]
                    return (model, ScrollDown(newLines, topBoundary: 5, bottomBoundary: 10))

                case .scrollRegionProcessed:
                    // Just for tracking that the message was processed
                    return (model, nil)
                }
            }

            func view() -> String {
                """
                Scroll test view
                synced: \(synced)
                scrolledUp: \(scrolledUp)
                scrolledDown: \(scrolledDown)
                counter: \(counter)
                """
            }
        }

        let tester = ProgramTester<ScrollModel>(model: ScrollModel())

        try await tester.test {
            // Test sync - the model triggers the action, renderer handles the actual message
            await tester.send(.sync)
            try await Task.sleep(for: .milliseconds(50))
            let view1 = tester.getCurrentView()
            #expect(view1.contains("synced: true"))

            // Test scroll up
            await tester.send(.scrollUp)
            try await Task.sleep(for: .milliseconds(50))
            let view2 = tester.getCurrentView()
            #expect(view2.contains("scrolledUp: true"))

            // Test scroll down
            await tester.send(.scrollDown)
            try await Task.sleep(for: .milliseconds(50))
            let view3 = tester.getCurrentView()
            #expect(view3.contains("scrolledDown: true"))
        }
    }
    
    @Test("Mouse wheel interaction with scroll region")
    func testMouseWheelScrollRegion() async throws {
        struct ScrollableModel: Model {
            typealias Msg = ScrollTestMessage
            
            var lines: [String] = Array(0..<50).map { "Line \($0)" }
            var scrollOffset: Int = 0
            var viewportHeight: Int = 10
            var scrollRegionTop: Int = 2
            var scrollRegionBottom: Int = 12
            
            func `init`() -> Command<ScrollTestMessage>? {
                // Initialize the scroll area
                let visibleLines = Array(lines[scrollOffset..<min(scrollOffset + viewportHeight, lines.count)])
                return SyncScrollArea(visibleLines, topBoundary: scrollRegionTop, bottomBoundary: scrollRegionBottom)
            }
            
            func update(_ message: ScrollTestMessage) -> (ScrollableModel, Command<ScrollTestMessage>?) {
                var model = self
                
                switch message {
                case let .mouseWheel(event):
                    // Handle mouse wheel events inside scroll region
                    if event.y >= scrollRegionTop && event.y <= scrollRegionBottom {
                        if event.button == .wheelUp {
                            // Scroll up
                            if model.scrollOffset > 0 {
                                model.scrollOffset -= 1
                                let newLine = model.lines[model.scrollOffset]
                                return (model, ScrollUp([newLine], topBoundary: scrollRegionTop, bottomBoundary: scrollRegionBottom))
                            }
                        } else if event.button == .wheelDown {
                            // Scroll down
                            if model.scrollOffset + model.viewportHeight < model.lines.count {
                                model.scrollOffset += 1
                                let bottomIndex = model.scrollOffset + model.viewportHeight - 1
                                let newLine = model.lines[bottomIndex]
                                return (model, ScrollDown([newLine], topBoundary: scrollRegionTop, bottomBoundary: scrollRegionBottom))
                            }
                        }
                    }
                    return (model, nil)
                case .noop:
                    return (model, nil)
                }
            }
            
            func view() -> String {
                var output = "Scrollable Content (offset: \(scrollOffset))\n"
                output += String(repeating: "-", count: 40) + "\n"
                
                // Show visible lines in the viewport
                let endIndex = min(scrollOffset + viewportHeight, lines.count)
                for i in scrollOffset..<endIndex {
                    output += lines[i] + "\n"
                }
                
                output += String(repeating: "-", count: 40)
                return output
            }
        }
        
        enum ScrollTestMessage: Message {
            case mouseWheel(MouseEvent)
            case noop
        }
        
        let model = ScrollableModel()
        let tester = ProgramTester(model: model)
        
        try await tester.test {
            // Initial view should show lines 0-9
            try await tester.expectView(containing: "Line 0")
            try await tester.expectView(containing: "Line 9")
            
            // Simulate mouse wheel down inside scroll region
            let wheelDown = MouseEvent(
                x: 10, y: 5, // Inside scroll region
                action: .press,
                button: .wheelDown
            )
            await tester.send(ScrollTestMessage.mouseWheel(wheelDown))
            
            // Should have scrolled down
            try await tester.expectView(containing: "Line 1")
            try await tester.expectView(containing: "Line 10")
            
            // Simulate mouse wheel up
            let wheelUp = MouseEvent(
                x: 10, y: 5,
                action: .press,
                button: .wheelUp
            )
            await tester.send(ScrollTestMessage.mouseWheel(wheelUp))
            
            // Should have scrolled back up
            try await tester.expectView(containing: "Line 0")
            try await tester.expectView(containing: "Line 9")
            
            // Test wheel event outside scroll region (should be ignored)
            let wheelOutside = MouseEvent(
                x: 10, y: 15, // Outside scroll region
                action: .press,
                button: .wheelDown
            )
            await tester.send(ScrollTestMessage.mouseWheel(wheelOutside))
            
            // Should not have scrolled
            try await tester.expectView(containing: "Line 0")
            try await tester.expectView(containing: "Line 9")
        }
    }
}
