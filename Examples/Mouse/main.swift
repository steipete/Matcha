//
//  main.swift
//  Mouse Example
//
//  Demonstrates mouse tracking and events in Matcha.
//

import Foundation
import Matcha

// Model that tracks mouse events
public struct MouseModel: Model {
    var mouseEnabled: Bool = false
    var lastEvent: String = "No mouse events yet"
    var clickCount: Int = 0
    var lastPosition: (x: Int, y: Int)?
    var mouseMode: MouseMode = .disabled

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case toggleMouse
        case setMouseMode(MouseMode)
        case mouseEvent(MouseMsg)
        case key(KeyMsg)
    }

    public init() {}

    // Start with mouse disabled
    public func `init`() -> Command<Message>? {
        nil
    }

    // Update the model based on messages
    public func update(_ message: Message) -> (MouseModel, Command<Message>?) {
        var model = self

        switch message {
        case .toggleMouse:
            model.mouseEnabled.toggle()
            if model.mouseEnabled {
                model.mouseMode = .cellMotion
                return (model, nil) // Program will handle mouse enabling
            } else {
                model.mouseMode = .disabled
                model.lastEvent = "Mouse disabled"
                return (model, nil) // Program will handle mouse disabling
            }

        case let .setMouseMode(mode):
            model.mouseMode = mode
            model.mouseEnabled = mode != .disabled
            return (model, nil)

        case let .mouseEvent(event):
            model.lastPosition = (event.x, event.y)

            switch event.action {
            case .press:
                model.clickCount += 1
                model.lastEvent = "Pressed \(event.button) at (\(event.x), \(event.y))"
            case .release:
                model.lastEvent = "Released \(event.button) at (\(event.x), \(event.y))"
            case .motion:
                model.lastEvent = "Motion at (\(event.x), \(event.y))"
            }

            // Add modifier info
            var modifiers: [String] = []
            if event.shift { modifiers.append("Shift") }
            if event.alt { modifiers.append("Alt") }
            if event.ctrl { modifiers.append("Ctrl") }

            if !modifiers.isEmpty {
                model.lastEvent += " [" + modifiers.joined(separator: "+") + "]"
            }

            return (model, nil)

        case let .key(key):
            switch key.description {
            case "m":
                return update(.toggleMouse)
            case "1":
                return update(.setMouseMode(.disabled))
            case "2":
                return update(.setMouseMode(.cellMotion))
            case "3":
                return update(.setMouseMode(.allMotion))
            default:
                return (model, nil)
            }
        }
    }

    // Render the view
    public func view() -> String {
        let modeString = switch mouseMode {
        case .disabled:
            "Disabled"
        case .cellMotion:
            "Cell Motion (clicks only)"
        case .allMotion:
            "All Motion (movement + clicks)"
        }

        let positionString = if let pos = lastPosition {
            "(\(pos.x), \(pos.y))"
        } else {
            "Unknown"
        }

        return """
        ╭─────────────────────────────────────────╮
        │         Mouse Tracking Demo             │
        ├─────────────────────────────────────────┤
        │                                         │
        │  Mouse Mode: \(String(format: "%-25s", modeString)) │
        │  Status: \(mouseEnabled ? "🟢 Enabled " : "🔴 Disabled")                      │
        │                                         │
        │  Last Position: \(String(format: "%-23s", positionString)) │
        │  Click Count: \(String(format: "%-3d", clickCount))                       │
        │                                         │
        │  Last Event:                            │
        │  \(String(format: "%-38s", String(lastEvent.prefix(38)))) │
        │                                         │
        ├─────────────────────────────────────────┤
        │  Controls:                              │
        │  m      Toggle mouse on/off             │
        │  1      Disable mouse                   │
        │  2      Cell motion mode                │
        │  3      All motion mode                 │
        │  q      Quit                            │
        │                                         │
        │  Try clicking and moving the mouse!     │
        ╰─────────────────────────────────────────╯
        """
    }
}

// Main entry point
@main
enum MouseApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Enable mouse support
        options.mouseMode = .cellMotion

        // Add a filter to handle messages
        options.filter = { model, message in
            if let key = message as? KeyMsg {
                switch key.description {
                case "q", "ctrl+c":
                    return QuitMsg()
                default:
                    return MouseModel.Message.key(key)
                }
            } else if let mouse = message as? MouseMsg {
                return MouseModel.Message.mouseEvent(mouse)
            }
            return message
        }

        let program = Program(
            initialModel: MouseModel(),
            options: options
        )

        do {
            _ = try await program.run()
            print("\nMouse tracking ended. 🖱️")
        } catch {
            print("\nError: \(error)")
        }
    }
}
