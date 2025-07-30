//
//  main.swift
//  Simple Example
//
//  The simplest possible Matcha application.
//

import Matcha

// Simple model that just displays a message
public struct SimpleModel: Model {
    // Define messages (none for this simple example)
    public enum Message: Matcha.Message {
        case dummy // Add a dummy case to avoid empty enum
    }

    public init() {}

    public func `init`() -> Command<Message>? {
        nil
    }

    public func update(_ message: Message) -> (SimpleModel, Command<Message>?) {
        // No messages to handle
        (self, nil)
    }

    public func view() -> String {
        """
        Hello from Matcha! 🍵

        Press 'q' or Ctrl+C to quit.
        """
    }
}

@main
enum SimpleApp {
    static func main() async throws {
        let program = Program(initialModel: SimpleModel())
        _ = try await program.run()
    }
}
