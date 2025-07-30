import Foundation

// MARK: - MouseMsg

/// MouseMsg contains information about a mouse event and are sent to a programs
/// update function when mouse activity occurs. Note that the mouse must first
/// be enabled in order for the mouse events to be received.
public struct MouseMsg: Message, Sendable {
    /// The underlying mouse event
    private let event: MouseEvent

    /// X coordinate of the mouse event (0-based)
    public var x: Int { event.x }

    /// Y coordinate of the mouse event (0-based)
    public var y: Int { event.y }

    /// Whether the Shift key was held during the event
    public var shift: Bool { event.shift }

    /// Whether the Alt/Option key was held during the event
    public var alt: Bool { event.alt }

    /// Whether the Control key was held during the event
    public var ctrl: Bool { event.ctrl }

    /// The type of mouse action
    public var action: MouseAction { event.action }

    /// The mouse button involved in the event
    public var button: MouseButton { event.button }

    /// Deprecated: Use action and button instead
    public var type: MouseEventType { event.type }

    public init(
        x: Int,
        y: Int,
        shift: Bool = false,
        alt: Bool = false,
        ctrl: Bool = false,
        action: MouseAction,
        button: MouseButton = .none
    ) {
        self.event = MouseEvent(
            x: x, y: y,
            shift: shift, alt: alt, ctrl: ctrl,
            action: action, button: button,
            type: MouseEventType.unknown // Will be computed
        )
    }

    public init(_ event: MouseEvent) {
        self.event = event
    }
}

// MARK: CustomStringConvertible

extension MouseMsg: CustomStringConvertible {
    /// Returns a string representation of a mouse event.
    public var description: String {
        event.description
    }
}

// MARK: - MouseEvent

/// MouseEvent represents a mouse event, which could be a click, a scroll wheel
/// movement, a cursor movement, or a combination.
public struct MouseEvent: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let shift: Bool
    public let alt: Bool
    public let ctrl: Bool
    public let action: MouseAction
    public let button: MouseButton

    /// Deprecated: Use MouseAction & MouseButton instead.
    public let type: MouseEventType

    public init(
        x: Int,
        y: Int,
        shift: Bool = false,
        alt: Bool = false,
        ctrl: Bool = false,
        action: MouseAction,
        button: MouseButton = .none,
        type: MouseEventType = .unknown
    ) {
        self.x = x
        self.y = y
        self.shift = shift
        self.alt = alt
        self.ctrl = ctrl
        self.action = action
        self.button = button
        self.type = type
    }
}

// MARK: - Mouse Event Methods

public extension MouseEvent {
    /// IsWheel returns true if the mouse event is a wheel event.
    var isWheel: Bool {
        button == .wheelUp || button == .wheelDown ||
            button == .wheelLeft || button == .wheelRight
    }
}

// MARK: - String Representation

extension MouseEvent: CustomStringConvertible {
    /// Returns a string representation of a mouse event.
    public var description: String {
        var s = ""

        if ctrl {
            s += "ctrl+"
        }
        if alt {
            s += "alt+"
        }
        if shift {
            s += "shift+"
        }

        if button == .none {
            if action == .motion || action == .release {
                s += mouseActions[action] ?? "unknown"
            } else {
                s += "unknown"
            }
        } else if isWheel {
            s += mouseButtons[button] ?? ""
        } else {
            if let btn = mouseButtons[button] {
                s += btn
            }
            if let act = mouseActions[action] {
                s += " " + act
            }
        }

        return s
    }
}

/// MouseAction represents the action that occurred during a mouse event.
public enum MouseAction: Int, Sendable {
    case press = 0
    case release = 1
    case motion = 2
}

private let mouseActions: [MouseAction: String] = [
    .press: "press",
    .release: "release",
    .motion: "motion"
]

/// MouseButton represents the button that was pressed during a mouse event.
public enum MouseButton: Int, Sendable {
    /// Mouse event buttons
    ///
    /// This is based on X11 mouse button codes.
    ///
    ///    1 = left button
    ///    2 = middle button (pressing the scroll wheel)
    ///    3 = right button
    ///    4 = turn scroll wheel up
    ///    5 = turn scroll wheel down
    ///    6 = push scroll wheel left
    ///    7 = push scroll wheel right
    ///    8 = 4th button (aka browser backward button)
    ///    9 = 5th button (aka browser forward button)
    ///    10+ = additional buttons
    case none = 0
    case left = 1
    case middle = 2
    case right = 3
    case wheelUp = 4
    case wheelDown = 5
    case wheelLeft = 6
    case wheelRight = 7
    case backward = 8
    case forward = 9
    case button10 = 10
    case button11 = 11

    /// Initialize from raw button number
    public init(rawValue: Int) {
        switch rawValue {
        case 0: self = .none
        case 1: self = .left
        case 2: self = .middle
        case 3: self = .right
        case 4: self = .wheelUp
        case 5: self = .wheelDown
        case 6: self = .wheelLeft
        case 7: self = .wheelRight
        case 8: self = .backward
        case 9: self = .forward
        case 10: self = .button10
        case 11: self = .button11
        default: self = .none
        }
    }
}

private let mouseButtons: [MouseButton: String] = [
    .none: "",
    .left: "left",
    .middle: "middle",
    .right: "right",
    .wheelUp: "wheel up",
    .wheelDown: "wheel down",
    .wheelLeft: "wheel left",
    .wheelRight: "wheel right",
    .backward: "backward",
    .forward: "forward",
    .button10: "button 10",
    .button11: "button 11"
]

/// MouseEventType represents the type of mouse event (deprecated).
public enum MouseEventType: String, Sendable {
    case unknown
    case motion
    case release
    case press
    case wheelUp = "wheel up"
    case wheelDown = "wheel down"
    case wheelLeft = "wheel left"
    case wheelRight = "wheel right"
}

// MARK: - Mouse Event Extensions

public extension MouseEvent {
    /// Returns true if this is a primary (left) click
    var isPrimaryClick: Bool {
        action == .press && button == .left
    }

    /// Returns true if this is a secondary (right) click
    var isSecondaryClick: Bool {
        action == .press && button == .right
    }

    /// Returns true if any modifier key is pressed
    var hasModifier: Bool {
        shift || alt || ctrl
    }
}
