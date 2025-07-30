import Foundation
import Matcha
import MatchaStyle

// MARK: - Spinner

/// An animated spinner component that displays a rotating animation
public struct Spinner: Sendable {
    /// The style of spinner to display
    public enum Style: String, CaseIterable, Sendable {
        case line
        case dots
        case minidots
        case jump
        case pulse
        case points
        case globe
        case moon
        case monkey
        case meter
        case hamburger

        /// The frames for this spinner style
        var frames: [String] {
            switch self {
            case .line:
                ["|", "/", "-", "\\"]
            case .dots:
                ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"]
            case .minidots:
                ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            case .jump:
                ["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"]
            case .pulse:
                ["█", "▓", "▒", "░", "▒", "▓"]
            case .points:
                ["∙∙∙", "●∙∙", "∙●∙", "∙∙●", "∙∙∙"]
            case .globe:
                ["🌍", "🌎", "🌏"]
            case .moon:
                ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
            case .monkey:
                ["🙈", "🙉", "🙊"]
            case .meter:
                ["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▱▰▰", "▱▱▰", "▱▱▱"]
            case .hamburger:
                ["☱", "☲", "☴", "☲"]
            }
        }

        /// The frame duration for this spinner style (in milliseconds)
        var frameDuration: Int {
            switch self {
            case .jump,
                 .line,
                 .meter:
                130
            case .dots,
                 .minidots:
                80
            case .pulse:
                100
            case .points:
                120
            case .globe:
                180
            case .moon:
                200
            case .monkey:
                300
            case .hamburger:
                100
            }
        }
    }

    /// The style of spinner to use
    public var style: Style

    /// The current frame index
    public var frameIndex: Int = 0

    /// Whether the spinner is currently animating
    public private(set) var isAnimating: Bool = false

    /// Custom text to display alongside the spinner
    public var text: String = ""

    /// The style to apply to the spinner
    public var spinnerStyle: MatchaStyle.Style = .defaultStyle()

    /// The style to apply to the text
    public var textStyle: MatchaStyle.Style = .defaultStyle()

    /// Create a new spinner with the given style
    public init(style: Style = .line) {
        self.style = style
    }

    /// Start the spinner animation
    public mutating func start() {
        isAnimating = true
        frameIndex = 0
    }

    /// Stop the spinner animation
    public mutating func stop() {
        isAnimating = false
    }

    /// Update the spinner (advances animation frame)
    public mutating func update<M: Message>(msg: any Message) -> Command<M>? {
        if msg is SpinnerTickMsg, isAnimating {
            frameIndex = (frameIndex + 1) % style.frames.count
            return tick()
        }
        return nil
    }

    /// Get the tick command for animation
    public func tick<M: Message>() -> Command<M> {
        Tick(.milliseconds(style.frameDuration)) { _ in
            SpinnerTickMsg() as! M
        }
    }

    /// Render the spinner
    public func view() -> String {
        guard isAnimating else { return "" }

        let frames = style.frames
        let frame = frames[frameIndex]
        let styledFrame = spinnerStyle.render(frame)

        if text.isEmpty {
            return styledFrame
        } else {
            let styledText = textStyle.render(text)
            return "\(styledFrame) \(styledText)"
        }
    }
}

// MARK: - SpinnerTickMsg

/// Message type for spinner ticks
public struct SpinnerTickMsg: Message {
    public init() {}
}

// MARK: - Helper Extensions

public extension Spinner {
    /// Create a spinner with text
    static func withText(_ text: String, style: Style = .line) -> Spinner {
        var spinner = Spinner(style: style)
        spinner.text = text
        return spinner
    }
}
