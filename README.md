# Matcha 🍵

A Swift port of [Bubble Tea](https://github.com/charmbracelet/bubbletea), the delightful framework for building terminal apps created by the amazing team at [Charm](https://charm.sh).

Matcha brings the elegance of The Elm Architecture to Swift for building rich Terminal User Interfaces (TUIs), staying true to Bubble Tea's philosophy while embracing Swift's language features.

> 💖 **Special thanks to the Charm team** for creating Bubble Tea and inspiring this Swift port. Their work on terminal user interfaces has revolutionized how we think about command-line applications.

## Features

- 🎯 **The Elm Architecture** - Simple, composable, and testable
- 🔄 **Swift Concurrency** - Built with async/await and actors
- ⌨️ **Comprehensive Input Handling** - Full keyboard and mouse support
- 🎨 **Flexible Rendering** - Frame-based rendering with customizable FPS
- 🖥️ **Cross-Platform** - Works on macOS and Linux
- 🔒 **Type-Safe** - Leverages Swift's strong type system
- ⚡ **High Performance** - Efficient diffing and rendering

## Platform Support

Matcha currently supports:
- ✅ **macOS** - Full support with native terminal capabilities
- ✅ **Linux** - Full support (tested on Ubuntu, should work on other distributions)
- ❌ **Windows** - Not currently supported (Windows users can use WSL2)

> **Note**: Windows support is not currently a development goal. The framework focuses on providing an excellent experience for Unix-like systems (macOS and Linux). Windows users can run Matcha applications through WSL2.

## Quick Start

```swift
import Matcha

struct CounterModel: Model {
    var count: Int = 0
    
    enum Message: Matcha.Message {
        case increment
        case decrement
        case key(Key)
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
        case .key(let key):
            switch key.description {
            case "up", "+": return update(.increment)
            case "down", "-": return update(.decrement)
            default: break
            }
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        "Count: \(count)\n\nPress +/- to change"
    }
}

@main
struct App {
    static func main() async throws {
        let program = Program(initialModel: CounterModel())
        _ = try await program.run()
    }
}
```

## Examples

Check out the `Examples/` directory for more examples:

- **Counter** - Basic state management and keyboard input
- **Timer** - Using timer commands for periodic updates
- **AltScreen** - Alternate screen buffer management
- **Mouse** - Mouse tracking and events

## Building

```bash
swift build
```

## Running Examples

```bash
swift run CounterExample
swift run TimerExample
swift run AltScreenExample
swift run MouseExample
```

## Documentation

See [docs/spec.md](docs/spec.md) for the full specification and implementation details.

## License

MIT