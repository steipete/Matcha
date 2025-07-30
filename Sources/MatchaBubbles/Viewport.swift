import Foundation
import Matcha
import MatchaStyle

/// A scrollable viewport component for displaying content larger than the visible area.
///
/// The Viewport component provides a scrollable window into text content that exceeds
/// the available display space. It supports:
/// - Smooth scrolling with line-by-line or page-by-page navigation
/// - Configurable dimensions (width and height)
/// - Line wrapping or truncation modes
/// - High-performance rendering option for large content
/// - Scroll position tracking
///
/// Example usage:
/// ```swift
/// var viewport = Viewport(width: 60, height: 10)
/// viewport.setContent(longTextContent)
/// viewport.lineDown() // Scroll down one line
/// let rendered = viewport.view()
/// ```
public struct Viewport: Sendable {
    // MARK: - Properties

    /// Width of the viewport in characters
    public var width: Int

    /// Height of the viewport in lines
    public var height: Int

    /// The content to display in the viewport
    public var content: String = ""

    /// Current vertical scroll offset (0-based line index)
    public var yOffset: Int = 0

    /// Enables high-performance rendering mode (truncates instead of wrapping)
    public var highPerformanceRendering: Bool = false

    // MARK: - Computed Properties

    /// Content split into individual lines
    private var lines: [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Total number of lines in the content
    private var totalLines: Int {
        lines.count
    }

    /// Current scroll position as a percentage (0.0 to 1.0)
    public var scrollPercent: Double {
        guard totalLines > height else { return 0 }
        return Double(yOffset) / Double(totalLines - height)
    }

    /// Creates a new viewport with the specified dimensions
    /// - Parameters:
    ///   - width: Width in characters (default: 80)
    ///   - height: Height in lines (default: 24)
    public init(width: Int = 80, height: Int = 24) {
        self.width = width
        self.height = height
    }

    // MARK: - Configuration

    /// Sets the viewport content
    /// - Parameter content: The text content to display
    /// - Note: Automatically adjusts scroll offset if it becomes out of bounds
    public mutating func setContent(_ content: String) {
        self.content = content
        // Reset offset if it's out of bounds
        if yOffset > max(0, totalLines - height) {
            yOffset = max(0, totalLines - height)
        }
    }

    // MARK: - Navigation

    /// Scrolls up by one line
    public mutating func lineUp() {
        if yOffset > 0 {
            yOffset -= 1
        }
    }

    /// Scrolls down by one line
    public mutating func lineDown() {
        let maxOffset = max(0, totalLines - height)
        if yOffset < maxOffset {
            yOffset += 1
        }
    }

    /// Scrolls up by half the viewport height
    public mutating func halfPageUp() {
        yOffset = max(0, yOffset - height / 2)
    }

    /// Scrolls down by half the viewport height
    public mutating func halfPageDown() {
        let maxOffset = max(0, totalLines - height)
        yOffset = min(maxOffset, yOffset + height / 2)
    }

    /// Jumps to the beginning of the content
    public mutating func gotoTop() {
        yOffset = 0
    }

    /// Jumps to the end of the content
    public mutating func gotoBottom() {
        yOffset = max(0, totalLines - height)
    }

    // MARK: - Rendering

    /// Renders the visible portion of the viewport content.
    ///
    /// The rendering behavior depends on the `highPerformanceRendering` setting:
    /// - When `false` (default): Long lines are wrapped to fit within the viewport width
    /// - When `true`: Long lines are truncated for better performance with large content
    ///
    /// - Returns: A string containing exactly `height` lines of content
    public func view() -> String {
        let visibleLines = Array(lines.dropFirst(yOffset).prefix(height))

        var output: [String] = []

        for line in visibleLines {
            if highPerformanceRendering {
                // In high performance mode, just truncate
                if line.count > width {
                    output.append(String(line.prefix(width)))
                } else {
                    output.append(line)
                }
            } else {
                // Normal mode: wrap lines
                if line.isEmpty {
                    output.append("")
                } else if line.count <= width {
                    output.append(line)
                } else {
                    // Wrap long lines
                    var remaining = line
                    while !remaining.isEmpty {
                        let chunk = String(remaining.prefix(width))
                        output.append(chunk)
                        remaining = String(remaining.dropFirst(width))
                    }
                }
            }
        }

        // Pad with empty lines if needed
        while output.count < height {
            output.append("")
        }

        // Ensure we only return exactly height lines
        return output.prefix(height).joined(separator: "\n")
    }
}
