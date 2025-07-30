//
//  Mouse.swift
//  Matcha
//
//  Mouse input handling for the Matcha TUI framework.
//

import Foundation

/// Represents a mouse event
public struct MouseEvent: Message, Equatable {
    /// X coordinate of the mouse event (0-based)
    public let x: Int

    /// Y coordinate of the mouse event (0-based)
    public let y: Int

    /// Whether the Shift key was held during the event
    public let shift: Bool

    /// Whether the Alt/Option key was held during the event
    public let alt: Bool

    /// Whether the Control key was held during the event
    public let ctrl: Bool

    /// The type of mouse action
    public let action: MouseAction

    /// The mouse button involved in the event
    public let button: MouseButton

    public init(
        x: Int,
        y: Int,
        shift: Bool = false,
        alt: Bool = false,
        ctrl: Bool = false,
        action: MouseAction,
        button: MouseButton = .noButton
    ) {
        self.x = x
        self.y = y
        self.shift = shift
        self.alt = alt
        self.ctrl = ctrl
        self.action = action
        self.button = button
    }
}

/// The type of mouse action
public enum MouseAction: Sendable, Equatable {
    /// Mouse button was pressed
    case press

    /// Mouse button was released
    case release

    /// Mouse moved (with or without buttons pressed)
    case motion
}

/// The mouse button involved in an event
public enum MouseButton: Sendable, Equatable {
    /// No specific button (used for motion without buttons)
    case noButton

    /// Left mouse button
    case left

    /// Middle mouse button (wheel click)
    case middle

    /// Right mouse button
    case right

    /// Mouse wheel scrolled up
    case wheelUp

    /// Mouse wheel scrolled down
    case wheelDown

    /// Mouse wheel scrolled left (horizontal scroll)
    case wheelLeft

    /// Mouse wheel scrolled right (horizontal scroll)
    case wheelRight

    /// Back button (button 4)
    case backward

    /// Forward button (button 5)
    case forward

    /// Additional numbered buttons (6+)
    case button(Int)
}

/// Type alias for compatibility with Bubble Tea
public typealias MouseMsg = MouseEvent

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

    /// Returns true if this is a wheel event
    var isWheel: Bool {
        switch button {
        case .wheelUp, .wheelDown, .wheelLeft, .wheelRight:
            true
        default:
            false
        }
    }

    /// Returns true if any modifier key is pressed
    var hasModifier: Bool {
        shift || alt || ctrl
    }
}

// MARK: - String Representation

extension MouseEvent: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []

        // Add modifiers
        if ctrl { parts.append("ctrl") }
        if alt { parts.append("alt") }
        if shift { parts.append("shift") }

        // Add button
        switch button {
        case .noButton:
            break
        case .left:
            parts.append("left")
        case .middle:
            parts.append("middle")
        case .right:
            parts.append("right")
        case .wheelUp:
            parts.append("wheelup")
        case .wheelDown:
            parts.append("wheeldown")
        case .wheelLeft:
            parts.append("wheelleft")
        case .wheelRight:
            parts.append("wheelright")
        case .backward:
            parts.append("back")
        case .forward:
            parts.append("forward")
        case let .button(n):
            parts.append("button\(n)")
        }

        // Add action
        switch action {
        case .press:
            parts.append("press")
        case .release:
            parts.append("release")
        case .motion:
            parts.append("motion")
        }

        // Add coordinates
        parts.append("(\(x),\(y))")

        return parts.joined(separator: "+")
    }
}
