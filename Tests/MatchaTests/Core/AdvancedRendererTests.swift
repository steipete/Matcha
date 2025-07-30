import Foundation
import Testing
@testable import Matcha

// MARK: - AdvancedRendererTests

/// Advanced tests for the renderer
@Suite("Advanced Renderer Tests")
struct AdvancedRendererTests {
    // MARK: - Ignored Lines Tests

    /// Test renderer with ignored lines functionality
    @Test("Ignored lines rendering optimization")
    func ignoredLinesRendering() async throws {
        // Note: ignoredLines functionality needs to be implemented in the renderer
        // This test documents the expected behavior

        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Render content with some lines that should be ignored
        let content = """
        Line 1: Normal content
        Line 2: Normal content
        [IGNORE] This line should not cause re-render
        Line 4: Normal content
        [IGNORE] Another ignored line
        Line 6: Normal content
        """

        await renderer.write(content)
        let firstOutput = outputBuffer.content

        // Modify only ignored lines
        let modifiedContent = """
        Line 1: Normal content
        Line 2: Normal content
        [IGNORE] This line has changed but should not trigger re-render
        Line 4: Normal content
        [IGNORE] This ignored line also changed
        Line 6: Normal content
        """

        outputBuffer.clear()
        await renderer.write(modifiedContent)
        let secondOutput = outputBuffer.content

        // The renderer should optimize and not re-render unchanged normal lines
        // when only ignored lines change

        await renderer.stop()
    }

    // MARK: - Scroll Area Tests

    /// Test scroll area boundaries
    @Test("Scroll area boundary handling")
    func scrollAreaBoundaries() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Test edge cases for scroll areas
        let lines = (1...20).map { "Line \($0)" }

        // Test with boundaries at edges
        await renderer.syncScrollArea(lines: Array(lines[0..<5]), topBoundary: 1, bottomBoundary: 5)
        outputBuffer.clear()

        // Test with invalid boundaries (should handle gracefully)
        await renderer.syncScrollArea(lines: lines, topBoundary: 10, bottomBoundary: 5) // bottom < top

        // Test with out-of-bounds values
        await renderer.syncScrollArea(lines: lines, topBoundary: -5, bottomBoundary: 100)

        await renderer.stop()
    }

    /// Test scroll operations
    @Test("Scroll up and down operations")
    func scrollOperations() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Set up initial scroll area
        let initialLines = (1...10).map { "Initial Line \($0)" }
        await renderer.syncScrollArea(lines: initialLines, topBoundary: 5, bottomBoundary: 15)

        // Test scroll up
        let newTopLines = ["New Top 1", "New Top 2", "New Top 3"]
        await renderer.scrollUp(newLines: newTopLines, topBoundary: 5, bottomBoundary: 15)

        // Test scroll down
        let newBottomLines = ["New Bottom 1", "New Bottom 2"]
        await renderer.scrollDown(newLines: newBottomLines, topBoundary: 5, bottomBoundary: 15)

        // Clear scroll area
        await renderer.clearScrollArea()

        await renderer.stop()
    }

    // MARK: - Performance Edge Cases

    /// Test renderer with very large content
    @Test("Large content rendering performance")
    func largeContentRendering() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Generate large content
        let lines = (1...1_000).map { "Line \($0): " + String(repeating: "X", count: 200) }
        let largeContent = lines.joined(separator: "\n")

        // Measure rendering time
        let start = CFAbsoluteTimeGetCurrent()
        await renderer.write(largeContent)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // Should complete in reasonable time
        #expect(elapsed < 1.0)

        await renderer.stop()
    }

    /// Test rapid content updates
    @Test("Rapid content update handling")
    func rapidContentUpdates() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Rapidly update content
        for i in 0..<100 {
            let content = "Update \(i): " + String(repeating: "\(i % 10)", count: 50)
            await renderer.write(content)
        }

        // Renderer should handle rapid updates without issues
        await renderer.stop()
    }

    // MARK: - Special Character Tests

    /// Test rendering with unicode and special characters
    @Test("Unicode and special character rendering")
    func unicodeRendering() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        let unicodeContent = """
        Emoji: 😀 🎉 🚀 ❤️
        CJK: 你好世界 こんにちは 안녕하세요
        Math: ∑ ∏ ∫ ∞ √ π
        Symbols: ♠ ♣ ♥ ♦ ★ ☆
        Combining: é ñ ü ö
        RTL: العربية עברית
        """

        await renderer.write(unicodeContent)

        // Allow time for rendering
        try await Task.sleep(for: .milliseconds(50))

        let output = outputBuffer.content

        // Output should contain the unicode content (with ANSI codes)
        #expect(output.contains("😀"))
        #expect(output.contains("你好世界"))

        await renderer.stop()
    }

    /// Test rendering with ANSI escape sequences in content
    @Test("ANSI escape sequences in content")
    func aNSIInContent() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Content that includes ANSI sequences
        let ansiContent = """
        Normal text
        \u{1B}[31mRed text\u{1B}[0m
        \u{1B}[1mBold text\u{1B}[0m
        \u{1B}[4mUnderlined text\u{1B}[0m
        """

        await renderer.write(ansiContent)

        // Renderer should handle ANSI sequences in content
        await renderer.stop()
    }

    // MARK: - State Management Tests

    /// Test renderer state persistence across operations
    @Test("Renderer state persistence")
    func rendererStatePersistence() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)

        // Test multiple start/stop cycles
        for i in 0..<3 {
            await renderer.start()

            // Enter alt screen
            await renderer.enterAltScreen()
            #expect(await renderer.altScreenActive)

            // Enable mouse
            await renderer.enableMouseAllMotion()

            // Write content
            await renderer.write("Cycle \(i)")

            // Exit alt screen
            await renderer.exitAltScreen()
            #expect(await !(renderer.altScreenActive))

            await renderer.stop()
        }
    }

    /// Test concurrent renderer operations
    @Test("Concurrent renderer operations")
    func concurrentOperations() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Perform multiple operations concurrently
        await withTaskGroup(of: Void.self) { group in
            // Write operations
            for i in 0..<10 {
                group.addTask {
                    await renderer.write("Concurrent write \(i)")
                }
            }

            // State changes
            group.addTask {
                await renderer.showCursor()
            }

            group.addTask {
                await renderer.hideCursor()
            }

            group.addTask {
                await renderer.setWindowTitle("Concurrent Test")
            }

            // Wait for all to complete
            await group.waitForAll()
        }

        await renderer.stop()
    }

    // MARK: - Edge Case Tests

    /// Test renderer with empty content
    @Test("Empty content rendering")
    func emptyContent() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Write empty content
        await renderer.write("")

        // Write content with only newlines
        await renderer.write("\n\n\n")

        // Write content with only spaces
        await renderer.write("   ")

        await renderer.stop()
    }

    /// Test renderer kill vs stop
    @Test("Renderer kill vs stop behavior")
    func rendererKillVsStop() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)

        // Test normal stop
        await renderer.start()
        await renderer.write("Before stop")
        await renderer.stop()

        // Test kill
        await renderer.start()
        await renderer.write("Before kill")
        await renderer.kill()

        // Both should cleanly terminate the renderer
    }

    /// Test window title edge cases
    @Test("Window title edge cases")
    func windowTitleEdgeCases() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Empty title
        await renderer.setWindowTitle("")

        // Very long title
        let longTitle = String(repeating: "X", count: 1_000)
        await renderer.setWindowTitle(longTitle)

        // Title with special characters
        await renderer.setWindowTitle("Title with 🎉 emoji and \n newline")

        // Title with control characters
        await renderer.setWindowTitle("Title\u{0007}with\u{001B}control")

        await renderer.stop()
    }

    // MARK: - Line Update Optimization Tests

    /// Test renderer's line diffing algorithm
    @Test("Line diffing optimization")
    func lineDiffingOptimization() async throws {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        // Enter alt screen for better diffing
        await renderer.enterAltScreen()

        // Initial content
        let lines = (1...50).map { "Line \($0): Initial content that is fairly long" }
        await renderer.write(lines.joined(separator: "\n"))

        // Clear output to measure next render
        outputBuffer.clear()

        // Update only a few lines
        var modifiedLines = lines
        modifiedLines[10] = "Line 11: MODIFIED content that is fairly long"
        modifiedLines[20] = "Line 21: MODIFIED content that is fairly long"
        modifiedLines[30] = "Line 31: MODIFIED content that is fairly long"

        await renderer.write(modifiedLines.joined(separator: "\n"))

        let output = outputBuffer.content

        // The output should contain position commands for the modified lines
        // rather than redrawing everything
        #expect(output.contains("\u{1B}[11;1H")) // Position to line 11
        #expect(output.contains("\u{1B}[21;1H")) // Position to line 21
        #expect(output.contains("\u{1B}[31;1H")) // Position to line 31

        await renderer.exitAltScreen()
        await renderer.stop()
    }
}

// MARK: - Test Helpers

extension AdvancedRendererTests {
    /// Helper to measure rendering performance
    func measureRenderingTime(
        content: String,
        iterations: Int = 100
    ) async throws -> TimeInterval {
        let outputBuffer = TestOutputStream()
        let renderer = StandardRenderer(output: outputBuffer, fps: 60)
        await renderer.start()

        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            await renderer.write(content)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        await renderer.stop()

        return elapsed / Double(iterations)
    }
}
