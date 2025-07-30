//
//  Progress.swift
//  MatchaBubbles
//
//  A progress bar component.
//

import Foundation
import Matcha
import MatchaStyle

/// A progress bar component for displaying task completion status.
///
/// The Progress component provides visual feedback for long-running operations,
/// with multiple display styles and customizable appearance. It supports:
/// - Multiple progress bar styles (default bar, dots, solid bar)
/// - Customizable colors for filled and empty sections
/// - Configurable width and appearance
/// - Percentage display options
///
/// Example usage:
/// ```swift
/// var progress = Progress()
/// progress.setPercent(0.75)
/// progress.width = 40
/// progress.style = .dots
/// progress.showPercentage = true
/// ```
public struct Progress: Sendable {
    /// Available progress bar display styles
    public enum ProgressStyle: Sendable {
        /// Default style using block characters (█░)
        case `default`
        /// Animated dots style (●○)
        case dots
        /// Solid bar with partial blocks for smooth progress
        case solidBar
    }
    
    // MARK: - Properties
    
    /// Current progress percentage (0.0 to 1.0)
    public var percent: Double = 0
    
    /// Width of the progress bar in characters
    public var width: Int = 40
    
    /// Visual style of the progress bar
    public var style: ProgressStyle = .default
    
    /// Whether to display percentage text after the bar
    public var showPercentage: Bool = false
    
    // MARK: - Appearance
    
    /// Character used for filled portion (default style)
    public var fullChar: String = "█"
    
    /// Character used for empty portion (default style)
    public var emptyChar: String = "░"
    
    // MARK: - Styling
    
    /// Style applied to filled portion of the bar
    public var fullColor: Style = Style().foreground(.white)
    
    /// Style applied to empty portion of the bar
    public var emptyColor: Style = Style().foreground(.brightBlack)
    
    /// Creates a new progress bar with default settings
    public init() {}
    
    // MARK: - Configuration
    
    /// Sets the progress percentage
    /// - Parameter percent: Progress value between 0.0 and 1.0 (clamped to valid range)
    public mutating func setPercent(_ percent: Double) {
        self.percent = max(0, min(1, percent))
    }
    
    /// Increments the current progress by the specified amount
    /// - Parameter amount: Amount to add to current progress (can be negative)
    public mutating func increment(_ amount: Double) {
        setPercent(percent + amount)
    }
    
    // MARK: - Builder Methods
    
    /// Returns a new progress bar with the specified percentage
    public func withPercent(_ percent: Double) -> Progress {
        var progress = self
        progress.setPercent(percent)
        return progress
    }
    
    /// Returns a new progress bar with the specified width
    public func withWidth(_ width: Int) -> Progress {
        var progress = self
        progress.width = width
        return progress
    }
    
    /// Returns a new progress bar with the specified style
    public func withProgressStyle(_ style: ProgressStyle) -> Progress {
        var progress = self
        progress.style = style
        return progress
    }
    
    /// Returns a new progress bar with percentage display enabled/disabled
    public func withShowPercentage(_ show: Bool) -> Progress {
        var progress = self
        progress.showPercentage = show
        return progress
    }
    
    /// Returns a new progress bar with the specified full character
    public func withFullChar(_ char: String) -> Progress {
        var progress = self
        progress.fullChar = char
        return progress
    }
    
    /// Returns a new progress bar with the specified empty character
    public func withEmptyChar(_ char: String) -> Progress {
        var progress = self
        progress.emptyChar = char
        return progress
    }
    
    /// Sets the style for the filled portion of the progress bar
    public func fullColor(_ style: Style) -> Progress {
        var progress = self
        progress.fullColor = style
        return progress
    }
    
    /// Sets the style for the empty portion of the progress bar
    public func emptyColor(_ style: Style) -> Progress {
        var progress = self
        progress.emptyColor = style
        return progress
    }
    
    // MARK: - Rendering
    
    /// Renders the progress bar as a string.
    ///
    /// The rendering behavior depends on the selected style:
    /// - `.default`: Uses fullChar and emptyChar characters
    /// - `.dots`: Shows filled dots (●) and empty dots (○) with animation
    /// - `.solidBar`: Uses Unicode block characters for smooth partial progress
    ///
    /// When `showPercentage` is true, the percentage is displayed after the bar.
    public func view() -> String {
        let barWidth = showPercentage ? width - 5 : width
        let filled = Int(Double(barWidth) * percent)
        let empty = barWidth - filled
        
        var output = ""
        
        switch style {
        case .default:
            output += fullColor.render(String(repeating: fullChar, count: filled))
            output += emptyColor.render(String(repeating: emptyChar, count: empty))
            
        case .dots:
            let dots = "⣾⣽⣻⢿⡿⣟⣯⣷"
            let dotIndex = Int(percent * Double(dots.count - 1))
            let dot = String(dots[dots.index(dots.startIndex, offsetBy: dotIndex)])
            
            if filled > 0 {
                output += fullColor.render(String(repeating: "●", count: filled - 1))
                if filled < barWidth {
                    output += fullColor.render(dot)
                    output += emptyColor.render(String(repeating: "○", count: empty - 1))
                } else {
                    output += fullColor.render("●")
                }
            } else {
                output += emptyColor.render(String(repeating: "○", count: empty))
            }
            
        case .solidBar:
            let blocks = " ▏▎▍▌▋▊▉█"
            let fullBlocks = filled
            let partialBlock = (percent * Double(barWidth)) - Double(filled)
            let blockIndex = Int(partialBlock * Double(blocks.count - 1))
            
            output += fullColor.render(String(repeating: "█", count: fullBlocks))
            if fullBlocks < barWidth && blockIndex > 0 {
                let block = String(blocks[blocks.index(blocks.startIndex, offsetBy: blockIndex)])
                output += fullColor.render(block)
                output += emptyColor.render(String(repeating: " ", count: empty - 1))
            } else {
                output += emptyColor.render(String(repeating: " ", count: empty))
            }
        }
        
        if showPercentage {
            let percentText = String(format: " %3.0f%%", percent * 100)
            output += percentText
        }
        
        return output
    }
}