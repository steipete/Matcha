import Foundation
import Matcha
import MatchaStyle

// MARK: - Stopwatch

/// A stopwatch component for tracking elapsed time.
///
/// The Stopwatch component provides functionality for measuring time intervals
/// with start, pause, resume, and reset capabilities. It includes:
/// - Precise time tracking using Date and TimeInterval
/// - Start/pause/resume/reset controls
/// - Formatted time display with hours, minutes, seconds, and tenths
/// - Integration with the Matcha update cycle via tick messages
/// - Helper methods for time component extraction
///
/// Example usage:
/// ```swift
/// var stopwatch = Stopwatch()
/// stopwatch.start()
/// // ... later in update function ...
/// if let cmd = stopwatch.update(msg: tickMsg) {
///     return (model, cmd)
/// }
/// let formatted = stopwatch.format() // "01:23.4"
/// ```
public struct Stopwatch: Sendable {
    /// The timestamp when the stopwatch was last started.
    /// Nil when the stopwatch is paused or stopped.
    private var startTime: Date?

    /// Accumulated elapsed time from previous sessions.
    /// Preserved when pausing and resuming.
    private var pausedElapsed: TimeInterval = 0

    /// Indicates whether the stopwatch is currently running.
    /// Read-only to ensure state consistency.
    public private(set) var isRunning: Bool = false

    /// The total elapsed time in seconds.
    ///
    /// This computed property returns:
    /// - When running: Time since start + previously accumulated time
    /// - When paused: Only the previously accumulated time
    public var elapsed: TimeInterval {
        if let startTime {
            if isRunning {
                return Date().timeIntervalSince(startTime) + pausedElapsed
            } else {
                return pausedElapsed
            }
        }
        return pausedElapsed
    }

    /// Creates a new stopwatch in the stopped state
    public init() {}

    /// Starts or resumes the stopwatch.
    ///
    /// If the stopwatch is already running, this has no effect.
    /// If paused, resumes from the accumulated elapsed time.
    public mutating func start() {
        if !isRunning {
            startTime = Date()
            isRunning = true
        }
    }

    /// Pauses the stopwatch.
    ///
    /// The elapsed time is preserved and can be resumed later.
    /// If already paused or stopped, this has no effect.
    public mutating func pause() {
        if isRunning, let startTime {
            pausedElapsed += Date().timeIntervalSince(startTime)
            self.startTime = nil
            isRunning = false
        }
    }

    /// Stops and resets the stopwatch to zero.
    ///
    /// All elapsed time is cleared and the stopwatch returns to its initial state.
    public mutating func reset() {
        startTime = nil
        pausedElapsed = 0
        isRunning = false
    }

    /// Toggles between running and paused states.
    ///
    /// Convenience method that starts the stopwatch if stopped/paused,
    /// or pauses it if running.
    public mutating func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    /// Updates the stopwatch in response to tick messages.
    ///
    /// This method should be called from your model's update function
    /// when receiving a StopwatchTickMsg. It automatically returns a
    /// command to continue ticking if the stopwatch is running.
    ///
    /// - Parameter msg: The message to process (checks for StopwatchTickMsg)
    /// - Returns: A command to continue ticking if running, nil otherwise
    public mutating func update<M: Message>(msg: any Message) -> Command<M>? {
        if msg is StopwatchTickMsg, isRunning {
            return tick()
        }
        return nil
    }

    /// Creates a command that generates periodic tick messages.
    ///
    /// The returned command emits a StopwatchTickMsg every 100ms
    /// for smooth time display updates. This should be called when
    /// starting the stopwatch to initiate the update cycle.
    ///
    /// - Returns: A command that emits StopwatchTickMsg periodically
    public func tick<M: Message>() -> Command<M> {
        // Update every 100ms for smooth display
        every(.milliseconds(100)) { _ in
            StopwatchTickMsg() as! M
        }
    }

    /// Formats the elapsed time as a human-readable string.
    ///
    /// The format adapts based on elapsed time:
    /// - Less than 1 hour: "MM:SS.t" (e.g., "03:45.6")
    /// - 1 hour or more: "HH:MM:SS.t" (e.g., "01:23:45.6")
    ///
    /// Note: Shows only tenths of seconds, not full milliseconds.
    ///
    /// - Returns: Formatted time string
    public func format() -> String {
        let totalSeconds = Int(elapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 10)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
        }
    }

    /// Renders the stopwatch display.
    ///
    /// Currently returns the formatted time string.
    /// Can be extended to include visual indicators for running state.
    ///
    /// - Returns: String representation of the stopwatch
    public func view() -> String {
        format()
    }
}

// MARK: - StopwatchTickMsg

/// Message type for stopwatch tick updates.
///
/// This message is emitted periodically by the stopwatch's tick command
/// to trigger elapsed time updates in the UI.
public struct StopwatchTickMsg: Message {
    public init() {}
}

// MARK: - Helper Functions

public extension Stopwatch {
    /// Creates a new stopwatch that starts immediately.
    ///
    /// Convenience factory method for creating an already-running stopwatch.
    ///
    /// - Returns: A new stopwatch in the running state
    static func started() -> Stopwatch {
        var stopwatch = Stopwatch()
        stopwatch.start()
        return stopwatch
    }

    /// Extracts individual time components from the elapsed time.
    ///
    /// Useful for custom formatting or display logic.
    ///
    /// - Returns: Tuple containing hours, minutes, seconds, and milliseconds
    var timeComponents: (hours: Int, minutes: Int, seconds: Int, milliseconds: Int) {
        let totalSeconds = Int(elapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 1000)
        return (hours, minutes, seconds, milliseconds)
    }

    /// Formats the stopwatch time with a custom separator.
    ///
    /// Allows customization of the time display format.
    /// Hours are only shown when elapsed time exceeds 1 hour.
    ///
    /// - Parameter separator: String to use between time components
    /// - Returns: Formatted time string with custom separator
    func format(separator: String) -> String {
        let c = timeComponents
        if c.hours > 0 {
            return "\(c.hours)\(separator)\(String(format: "%02d", c.minutes))\(separator)\(String(format: "%02d", c.seconds))"
        } else {
            return "\(c.minutes)\(separator)\(String(format: "%02d", c.seconds))"
        }
    }
}
