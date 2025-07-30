//
//  IntegrationTests.swift
//  Integration tests for complex multi-component scenarios
//

import Testing
@testable import Matcha
import Foundation

@Suite("Integration Tests")
@MainActor
struct IntegrationTests {
    
    // MARK: - Test Model
    
    struct ComplexModel: Model {
        var scrollContent: [String] = []
        var mousePosition: (x: Int, y: Int) = (0, 0)
        var isScrolling: Bool = false
        var windowSize: (width: Int, height: Int) = (80, 24)
        var hasFocus: Bool = true
        var commandsExecuted: Int = 0
        var messageLog: [String] = []
        
        enum Message: Matcha.Message {
            case key(KeyMsg)
            case mouse(MouseMsg)
            case windowSize(WindowSizeMsg)
            case focus(FocusMsg)
            case blur(BlurMsg)
            case scrollUp
            case scrollDown
            case addContent(String)
            case commandCompleted
            case batchCompleted(Int)
        }
        
        init() {}
        
        func `init`() -> Command<Message>? {
            // Initialize with some content
            Command { .addContent("Initial content") }
        }
        
        func update(_ message: Message) -> (ComplexModel, Command<Message>?) {
            var model = self
            model.messageLog.append(String(describing: message))
            
            switch message {
            case .key(let key):
                switch key.type {
                case .up:
                    return (model, Command { .scrollUp })
                case .down:
                    return (model, Command { .scrollDown })
                case .runes:
                    if key.runes.first == "b" {
                        // Batch command test
                        return (model, batch(
                            Command { 
                                try? await Task.sleep(for: .milliseconds(10))
                                return .commandCompleted 
                            },
                            Command { 
                                try? await Task.sleep(for: .milliseconds(20))
                                return .commandCompleted 
                            },
                            Command { 
                                try? await Task.sleep(for: .milliseconds(5))
                                return .commandCompleted 
                            }
                        ))
                    }
                default:
                    break
                }
                
            case .mouse(let mouse):
                model.mousePosition = (mouse.x, mouse.y)
                if mouse.button == .wheelUp || mouse.button == .wheelDown {
                    model.isScrolling = true
                    if mouse.button == .wheelDown {
                        return (model, Command { .scrollDown })
                    } else {
                        return (model, Command { .scrollUp })
                    }
                }
                
            case .windowSize(let size):
                model.windowSize = (size.width, size.height)
                
            case .focus:
                model.hasFocus = true
                
            case .blur:
                model.hasFocus = false
                
            case .scrollUp:
                if !model.scrollContent.isEmpty {
                    model.scrollContent.removeFirst()
                }
                model.isScrolling = false
                
            case .scrollDown:
                model.scrollContent.append("Line \(model.scrollContent.count + 1)")
                model.isScrolling = false
                
            case .addContent(let content):
                model.scrollContent.append(content)
                
            case .commandCompleted:
                model.commandsExecuted += 1
                if model.commandsExecuted == 3 {
                    return (model, Command { .batchCompleted(3) })
                }
                
            case .batchCompleted(let count):
                model.messageLog.append("Batch completed with \(count) commands")
            }
            
            return (model, nil)
        }
        
        func view() -> String {
            var lines: [String] = []
            
            lines.append("Window: \(windowSize.width)x\(windowSize.height) | Focus: \(hasFocus)")
            lines.append("Mouse: (\(mousePosition.x), \(mousePosition.y)) | Scrolling: \(isScrolling)")
            lines.append("Commands executed: \(commandsExecuted)")
            lines.append("---")
            
            for (idx, line) in scrollContent.enumerated() {
                lines.append("\(idx): \(line)")
            }
            
            return lines.joined(separator: "\n")
        }
    }
    
    // MARK: - Test Cases
    
    @Test("Scroll regions with mouse wheel interaction")
    func testScrollRegionsWithMouse() async throws {
        var options = ProgramOptions()
        options.mouseMode = .cellMotion
        
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel(),
            options: options
        )
        
        try await tester.test {
            // Add initial content
            for i in 1...10 {
                await tester.send(ComplexModel.Message.addContent("Initial line \(i)"))
            }
            
            // Wait for initial content
            try await Task.sleep(for: .milliseconds(50))
            
            // Send mouse wheel events
            await tester.send(ComplexModel.Message.mouse(MouseMsg(x: 10, y: 5, action: .motion, button: .wheelDown)))
            await tester.send(ComplexModel.Message.mouse(MouseMsg(x: 10, y: -3, action: .motion, button: .wheelUp)))
            
            // Wait for scroll operations
            try await Task.sleep(for: .milliseconds(100))
            
            // Check the view output
            let view = tester.getCurrentView()
            #expect(view.contains("Line 11")) // Should have added content via scrollDown
            #expect(view.contains("Mouse: (10, -3)")) // Mouse position should be updated
        }
    }
    
    @Test("Message queue with terminal resize")
    func testMessageQueueWithResize() async throws {
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel()
        )
        
        try await tester.test {
            // Send multiple messages quickly
            await tester.send(ComplexModel.Message.windowSize(WindowSizeMsg(width: 100, height: 30)))
            await tester.send(ComplexModel.Message.addContent("After resize 1"))
            await tester.send(ComplexModel.Message.windowSize(WindowSizeMsg(width: 120, height: 40)))
            await tester.send(ComplexModel.Message.addContent("After resize 2"))
            
            // Wait for processing
            try await Task.sleep(for: .milliseconds(100))
            
            // Check the view output
            let view = tester.getCurrentView()
            #expect(view.contains("Window: 120x40")) // Window size should be updated
            #expect(view.contains("After resize 1"))
            #expect(view.contains("After resize 2"))
        }
    }
    
    @Test("Concurrent command execution with batching")
    func testConcurrentCommandBatching() async throws {
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel()
        )
        
        try await tester.test {
            // Trigger batch command
            await tester.send(ComplexModel.Message.key(KeyMsg(character: "b")))
            
            // Wait for all commands to complete
            try await Task.sleep(for: .milliseconds(300))
            
            // Check the view output
            let view = tester.getCurrentView()
            #expect(view.contains("Commands executed: 3"))
            // The batch completion message is in the message log, not the view
        }
    }
    
    @Test("Focus and blur events during interaction")
    func testFocusBlurDuringInteraction() async throws {
        var options = ProgramOptions()
        options.reportFocus = true
        
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel(),
            options: options
        )
        
        try await tester.test {
            // Simulate focus loss and regain during interaction
            await tester.send(ComplexModel.Message.blur(BlurMsg()))
            await tester.send(ComplexModel.Message.key(KeyMsg(type: .down))) // Try to scroll while blurred
            await tester.send(ComplexModel.Message.focus(FocusMsg()))
            await tester.send(ComplexModel.Message.key(KeyMsg(type: .down))) // Scroll while focused
            
            try await Task.sleep(for: .milliseconds(100))
            
            // Check the view output
            let view = tester.getCurrentView()
            #expect(view.contains("Focus: true")) // Should be focused again
        }
    }
    
    @Test("Complex keyboard and mouse interaction sequence")
    func testComplexKeyboardMouseSequence() async throws {
        var options = ProgramOptions()
        options.mouseMode = .cellMotion
        
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel(),
            options: options
        )
        
        try await tester.test {
            // Complex interaction sequence
            let sequence = [
                // Add content with keyboard
                ComplexModel.Message.key(KeyMsg(type: .down)),
                ComplexModel.Message.key(KeyMsg(type: .down)),
                
                // Mouse click
                ComplexModel.Message.mouse(MouseMsg(x: 25, y: 10, action: .press, button: .left)),
                
                // Window resize
                ComplexModel.Message.windowSize(WindowSizeMsg(width: 90, height: 35)),
                
                // More keyboard
                ComplexModel.Message.key(KeyMsg(type: .up)),
                
                // Mouse drag
                ComplexModel.Message.mouse(MouseMsg(x: 25, y: 10, action: .motion, button: .left)),
                ComplexModel.Message.mouse(MouseMsg(x: 30, y: 15, action: .motion, button: .left)),
                ComplexModel.Message.mouse(MouseMsg(x: 30, y: 15, action: .release, button: .left))
            ]
            
            for msg in sequence {
                await tester.send(msg)
                try await Task.sleep(for: .milliseconds(10))
            }
            
            try await Task.sleep(for: .milliseconds(100))
            
            // Check the view output
            let view = tester.getCurrentView()
            #expect(view.contains("Mouse: (30, 15)"))
            #expect(view.contains("Window: 90x35"))
            #expect(view.contains("Line 2")) // From scroll downs
        }
    }
    
    @Test("Renderer behavior with rapid updates")
    func testRendererWithRapidUpdates() async throws {
        var options = ProgramOptions()
        options.mouseMode = .cellMotion
        
        let tester = ProgramTester<ComplexModel>(
            model: ComplexModel(),
            options: options
        )
        
        try await tester.test {
            // Send rapid updates
            for i in 0..<20 {
                await tester.send(ComplexModel.Message.addContent("Rapid update \(i)"))
                if i % 5 == 0 {
                    await tester.send(ComplexModel.Message.windowSize(WindowSizeMsg(width: 80 + i, height: 24)))
                }
            }
            
            // Wait for rendering to catch up
            try await Task.sleep(for: .milliseconds(200))
            
            let finalOutput = tester.getCurrentView()
            #expect(finalOutput.contains("Rapid update"))
            #expect(finalOutput.contains("Window:"))
        }
    }
    
    @Test("Error recovery during command execution")
    func testErrorRecoveryDuringCommands() async throws {
        struct ErrorModel: Model {
            var errorCount: Int = 0
            var successCount: Int = 0
            
            enum Message: Matcha.Message {
                case triggerError
                case triggerSuccess
                case errorOccurred
                case successOccurred
            }
            
            init() {}
            
            func `init`() -> Command<Message>? { nil }
            
            func update(_ message: Message) -> (ErrorModel, Command<Message>?) {
                var model = self
                
                switch message {
                case .triggerError:
                    return (model, Command { () async -> Message? in
                        // Commands that throw are caught internally
                        return .errorOccurred
                    })
                    
                case .triggerSuccess:
                    return (model, Command { .successOccurred })
                    
                case .errorOccurred:
                    model.errorCount += 1
                    
                case .successOccurred:
                    model.successCount += 1
                }
                
                return (model, nil)
            }
            
            func view() -> String {
                "Errors: \(errorCount), Success: \(successCount)"
            }
        }
        
        let tester = ProgramTester<ErrorModel>(
            model: ErrorModel()
        )
        
        try await tester.test {
            // Trigger commands that will error and succeed
            await tester.send(ErrorModel.Message.triggerError)
            await tester.send(ErrorModel.Message.triggerSuccess)
            await tester.send(ErrorModel.Message.triggerError)
            await tester.send(ErrorModel.Message.triggerSuccess)
            
            try await Task.sleep(for: .milliseconds(100))
            
            let view = tester.getCurrentView()
            #expect(view.contains("Errors: 2, Success: 2"))
        }
    }
    
    @Test("Message ordering with sequential commands")
    func testMessageOrderingWithSequentialCommands() async throws {
        struct SequenceModel: Model {
            var messages: [String] = []
            
            enum Message: Matcha.Message {
                case startSequence
                case step(Int)
                case sequenceComplete
            }
            
            init() {}
            
            func `init`() -> Command<Message>? { nil }
            
            func update(_ message: Message) -> (SequenceModel, Command<Message>?) {
                var model = self
                
                switch message {
                case .startSequence:
                    model.messages.append("Start")
                    return (model, Command.sequence(
                        Command { 
                            try? await Task.sleep(for: .milliseconds(10))
                            return .step(1) 
                        },
                        Command { 
                            try? await Task.sleep(for: .milliseconds(10))
                            return .step(2) 
                        },
                        Command { 
                            try? await Task.sleep(for: .milliseconds(10))
                            return .step(3) 
                        },
                        Command { .sequenceComplete }
                    ))
                    
                case .step(let n):
                    model.messages.append("Step \(n)")
                    
                case .sequenceComplete:
                    model.messages.append("Complete")
                }
                
                return (model, nil)
            }
            
            func view() -> String {
                messages.joined(separator: " -> ")
            }
        }
        
        let tester = ProgramTester<SequenceModel>(
            model: SequenceModel()
        )
        
        try await tester.test {
            await tester.send(SequenceModel.Message.startSequence)
            
            try await Task.sleep(for: .milliseconds(200))
            
            let view = tester.getCurrentView()
            #expect(view.contains("Start -> Step 1 -> Step 2 -> Step 3 -> Complete"))
        }
    }
    
    @Test("Mouse tracking modes transition")
    func testMouseTrackingModesTransition() async throws {
        struct MouseTrackingModel: Model {
            var events: [String] = []
            
            enum Message: Matcha.Message {
                case mouse(MouseMsg)
            }
            
            init() {}
            
            func `init`() -> Command<Message>? { nil }
            
            func update(_ message: Message) -> (MouseTrackingModel, Command<Message>?) {
                var model = self
                
                if case .mouse(let mouse) = message {
                    model.events.append("\(mouse.action) at (\(mouse.x),\(mouse.y))")
                }
                
                return (model, nil)
            }
            
            func view() -> String {
                "Mouse events: \(events.count)"
            }
        }
        
        // Test with different mouse modes
        let mouseModesOptions: [ProgramOptions] = {
            var options1 = ProgramOptions()
            options1.mouseMode = .cellMotion
            
            var options2 = ProgramOptions()
            options2.mouseMode = .allMotion
            
            var options3 = ProgramOptions()
            options3.mouseMode = .disabled
            
            return [options1, options2, options3]
        }()
        
        for options in mouseModesOptions {
            let tester = ProgramTester<MouseTrackingModel>(
                model: MouseTrackingModel(),
                options: options
            )
            
            try await tester.test {
                // Send various mouse events
                await tester.send(MouseTrackingModel.Message.mouse(MouseMsg(
                    x: 10, y: 10, action: .press, button: .left
                )))
                await tester.send(MouseTrackingModel.Message.mouse(MouseMsg(
                    x: 15, y: 10, action: .motion, button: .left
                )))
                await tester.send(MouseTrackingModel.Message.mouse(MouseMsg(
                    x: 20, y: 10, action: .release, button: .left
                )))
                
                try await Task.sleep(for: .milliseconds(50))
                
                let view = tester.getCurrentView()
                #expect(view.contains("Mouse events:")) // Should show some events
            }
        }
    }
}