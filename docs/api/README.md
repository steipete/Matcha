# Matcha API Documentation

Welcome to the Matcha API documentation. Matcha is a Swift framework for building terminal user interfaces using The Elm Architecture.

## Documentation Structure

- [Core Concepts](core-concepts.md) - Understanding The Elm Architecture in Matcha
- [Getting Started](getting-started.md) - Quick start guide for building your first TUI
- [API Reference](reference/) - Complete API documentation for all types
- [Components](components/) - Built-in UI components (TextInput, List, Table, etc.)
- [Styling](styling.md) - Working with MatchaStyle for visual design
- [Advanced Topics](advanced/) - Performance, testing, and advanced patterns
- [Migration Guide](migration-from-bubbletea.md) - For developers coming from Bubble Tea

## Quick Example

```swift
import Matcha

struct CounterModel: Model {
    var count = 0
    
    enum Message: Matcha.Message {
        case increment
        case decrement
    }
    
    init() {}
    
    func `init`() -> Command<Message>? { nil }
    
    func update(_ message: Message) -> (CounterModel, Command<Message>?) {
        var model = self
        switch message {
        case .increment:
            model.count += 1
        case .decrement:
            model.count -= 1
        }
        return (model, nil)
    }
    
    func view() -> String {
        "Count: \(count)\n\nPress + to increment, - to decrement, q to quit"
    }
}
```

## Core Types

### Model Protocol
The heart of every Matcha application. Defines your app's state and behavior.

### Program
Manages the runtime lifecycle of your TUI application.

### Command
Represents asynchronous operations that produce messages.

### Message
Type-safe messages that drive state changes in your model.

## Getting Help

- Browse the [examples](https://github.com/yourusername/matcha/tree/main/Examples) directory
- Check the [API Reference](reference/) for detailed documentation
- Join our community Discord/Slack (coming soon)

## Requirements

- Swift 6.0+
- macOS 13+ or Linux
- Terminal with ANSI escape sequence support