# API Reference

Complete API documentation for all Matcha types, protocols, and functions.

## Core Framework

### Protocols

- [Model](model.md) - The core protocol for application models
- [Message](message.md) - Protocol for all messages in the system
- [Component](component.md) - Protocol for reusable UI components

### Types

- [Program](program.md) - Main application runner
- [Command](command.md) - Asynchronous operations that produce messages
- [ProgramOptions](program-options.md) - Configuration for Program behavior
- [Key](key.md) - Keyboard input representation
- [MouseEvent](mouse-event.md) - Mouse input events

### Rendering

- [Renderer](renderer.md) - Terminal rendering protocol
- [StandardRenderer](standard-renderer.md) - Default renderer implementation
- [View](view.md) - View rendering utilities

### Input

- [InputHandler](input-handler.md) - Keyboard and mouse input processing
- [TTY](tty.md) - Terminal I/O operations

## MatchaStyle

### Core Types

- [Style](style.md) - Main styling type
- [Color](color.md) - Color representation
- [Border](border.md) - Border styles and rendering

### Enums

- [Alignment](alignment.md) - Text alignment options
- [BorderStyle](border-style.md) - Pre-defined border styles

## MatchaBubbles

### Input Components

- [TextInput](../components/text-input.md) - Single-line text input
- TextArea *(Coming Soon)* - Multi-line text editor

### Display Components

- [List](../components/list.md) - Scrollable selection list
- [Table](../components/table.md) - Data table with columns
- [Viewport](../components/viewport.md) - Scrollable content area
- [Help](../components/help.md) - Keybinding help display

### Progress Components

- [Progress](../components/progress.md) - Progress bars
- [Spinner](../components/spinner.md) - Loading spinners
- [Timer](../components/timer.md) - Countdown and elapsed time

### Navigation Components

- [Paginator](../components/paginator.md) - Page navigation
- Tabs *(Coming Soon)* - Tab navigation

### Data Visualization

- [Sparkline](../components/sparkline.md) - Mini line charts

## Global Functions

### Command Constructors

```swift
// Quit the program
func quit() -> Command<Any>

// Run after a delay
func after<M>(_ duration: Duration, perform: @escaping () -> M?) -> Command<M>

// Run periodically
func every<M>(_ interval: Duration, perform: @escaping (Date) -> M?) -> Command<M>

// Batch multiple commands
extension Command {
    static func batch(_ commands: Command<M>...) -> Command<M>
}
```

### Terminal Utilities

```swift
// Get terminal size
func terminalSize() -> (width: Int, height: Int)

// Clear screen
func clearScreen()

// Set cursor position
func setCursorPosition(x: Int, y: Int)
```

## Type Aliases

```swift
// Common message types
typealias QuitMsg = BuiltInMessage.Quit
typealias WindowSizeMsg = BuiltInMessage.WindowSize
typealias TickMsg = BuiltInMessage.Tick
```

## Error Types

- [ProgramError](errors.md#programerror) - General program errors
- [ProgramPanicError](errors.md#programpanicerror) - Panic conditions
- [ProgramKilledError](errors.md#programkillederror) - Program termination
- [InterruptedError](errors.md#interruptederror) - User interruption

## Platform Support

### macOS
- Full keyboard and mouse support
- Terminal.app, iTerm2, and other modern terminals
- Requires macOS 13+

### Linux
- Full keyboard support
- Basic mouse support
- Requires modern terminal emulator
- Tested on Ubuntu 22.04+

### Windows
- Not yet supported
- Planned for future release

## Swift Version Requirements

- Swift 6.0+
- Strict concurrency checking enabled
- Full Sendable conformance

## Common Patterns

### Model Composition
```swift
struct AppModel: Model {
    var sidebar: SidebarModel
    var content: ContentModel
    
    enum Message: Matcha.Message {
        case sidebar(SidebarModel.Message)
        case content(ContentModel.Message)
    }
}
```

### Async Commands
```swift
func fetchData() -> Command<Message> {
    Command {
        do {
            let data = try await api.fetch()
            return .dataLoaded(data)
        } catch {
            return .error(error)
        }
    }
}
```

### Custom Components
```swift
protocol MyComponent {
    associatedtype Message
    mutating func update(_ msg: Message) -> Command<Message>?
    func view() -> String
}
```