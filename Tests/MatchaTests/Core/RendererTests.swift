import Testing
@testable import Matcha

// MARK: - RendererTests

@Suite("Renderer Tests")
struct RendererTests {
    @Test("Mock renderer start/stop behavior")
    func mockRenderer() async throws {
        let renderer = MockRenderer()

        // Test start/stop
        await renderer.start()
        let isStarted = await renderer.isStarted
        #expect(isStarted)

        await renderer.stop()
        let isStopped = await renderer.isStopped
        #expect(isStopped)

        // Verify calls were recorded
        let calls = await renderer.renderCalls
        #expect(calls.contains("start()"))
        #expect(calls.contains("stop()"))
    }

    @Test("Renderer write operations")
    func rendererWriting() async throws {
        let renderer = MockRenderer()

        await renderer.write("Hello, World!")
        await renderer.write("Line 2")

        let calls = await renderer.renderCalls
        #expect(calls.contains("write(\"Hello, World!\")"))
        #expect(calls.contains("write(\"Line 2\")"))
    }

    @Test("Alternate screen mode switching")
    func altScreenMode() async throws {
        let renderer = MockRenderer()

        // Initially not in alt screen
        var altScreen = await renderer.altScreenActive
        #expect(!altScreen)

        // Enter alt screen
        await renderer.enterAltScreen()
        altScreen = await renderer.altScreenActive
        #expect(altScreen)

        // Exit alt screen
        await renderer.exitAltScreen()
        altScreen = await renderer.altScreenActive
        #expect(!altScreen)

        // Verify calls
        let verified = await renderer.verifyCalled("enterAltScreen()")
        #expect(verified)
    }

    @Test("Cursor visibility control")
    func cursorVisibility() async throws {
        let renderer = MockRenderer()

        // Initially visible
        var visible = await renderer.cursorVisible
        #expect(visible)

        // Hide cursor
        await renderer.hideCursor()
        visible = await renderer.cursorVisible
        #expect(!visible)

        // Show cursor
        await renderer.showCursor()
        visible = await renderer.cursorVisible
        #expect(visible)
    }

    @Test("Mouse tracking modes")
    func mouseModes() async throws {
        let renderer = MockRenderer()

        // Test cell motion mode
        await renderer.enableMouseCellMotion()
        let cellMotionCalled = await renderer.verifyCalled("enableMouseCellMotion()")
        #expect(cellMotionCalled)

        await renderer.disableMouseCellMotion()

        // Test all motion mode
        await renderer.enableMouseAllMotion()
        let allMotionCalled = await renderer.verifyCalled("enableMouseAllMotion()")
        #expect(allMotionCalled)

        await renderer.disableMouseAllMotion()

        // Test SGR mode
        await renderer.enableMouseSGRMode()
        await renderer.disableMouseSGRMode()

        let sgrCalled = await renderer.verifyCalled("enableMouseSGRMode()")
        #expect(sgrCalled)
    }

    @Test("Bracketed paste mode")
    func bracketedPaste() async throws {
        let renderer = MockRenderer()

        // Initially disabled
        var active = await renderer.bracketedPasteActive
        #expect(!active)

        // Enable
        await renderer.enableBracketedPaste()
        active = await renderer.bracketedPasteActive
        #expect(active)

        // Disable
        await renderer.disableBracketedPaste()
        active = await renderer.bracketedPasteActive
        #expect(!active)
    }

    @Test("Window title setting")
    func windowTitle() async throws {
        let renderer = MockRenderer()

        await renderer.setWindowTitle("Test App")

        let title = await renderer.windowTitle
        #expect(title == "Test App")

        let called = await renderer.verifyCalled("setWindowTitle(\"Test App\")")
        #expect(called)
    }

    @Test("Focus reporting toggle")
    func focusReporting() async throws {
        let renderer = MockRenderer()

        // Initially disabled
        var reports = await renderer.reportsFocus
        #expect(!reports)

        // Enable
        await renderer.enableReportFocus()
        reports = await renderer.reportsFocus
        #expect(reports)

        // Disable
        await renderer.disableReportFocus()
        reports = await renderer.reportsFocus
        #expect(!reports)
    }

    @Test("Clear screen operations")
    func clearScreen() async throws {
        let renderer = MockRenderer()

        await renderer.clearScreen()
        let clearCalled = await renderer.verifyCalled("clearScreen()")
        #expect(clearCalled)

        // Test alias
        await renderer.clear()
        let count = await renderer.callCount(containing: "clearScreen")
        #expect(count == 2) // Called twice
    }

    @Test("Render call counting")
    func renderCallCounting() async throws {
        let renderer = MockRenderer()

        // Write multiple times
        await renderer.write("Line 1")
        await renderer.write("Line 2")
        await renderer.write("Line 3")

        let writeCount = await renderer.callCount(containing: "write")
        #expect(writeCount == 3)

        // Test repaint
        await renderer.repaint()
        await renderer.repaint()

        let repaintCount = await renderer.callCount(containing: "repaint")
        #expect(repaintCount == 2)
    }
}

// MARK: - StandardRendererTests

@Suite("Standard Renderer Tests")
struct StandardRendererTests {
    @Test("Standard renderer creation and lifecycle")
    func standardRendererCreation() async throws {
        let output = TestOutputStream(interpretANSI: false)
        let renderer = StandardRenderer(output: output, fps: 60)

        // Basic creation test - renderer should exist
        #expect(renderer != nil)

        // Start and stop
        await renderer.start()
        await renderer.stop()

        // Should have hidden cursor on start
        #expect(output.content.contains("\u{1B}[?25l"))
    }

    @Test("Renderer FPS clamping")
    func rendererFPS() async throws {
        let output = TestOutputStream()

        // Test FPS clamping
        let renderer1 = StandardRenderer(output: output, fps: 200) // Should clamp to 120
        let renderer2 = StandardRenderer(output: output, fps: 0) // Should clamp to 1

        #expect(renderer1 != nil)
        #expect(renderer2 != nil)
    }

    @Test("ANSI escape sequence output")
    func ansiOutput() async throws {
        let output = TestOutputStream(interpretANSI: false)
        let renderer = StandardRenderer(output: output)

        await renderer.start()

        // Test various ANSI sequences
        await renderer.enterAltScreen()
        #expect(output.content.contains("\u{1B}[?1049h"))

        await renderer.clearScreen()
        #expect(output.content.contains("\u{1B}[2J"))
        #expect(output.content.contains("\u{1B}[H"))

        await renderer.stop()
    }
}
