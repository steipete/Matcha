# Matcha API Documentation

Matcha is a Swift framework for building terminal user interfaces (TUIs) based on The Elm Architecture. It's a port of the popular Go framework [Bubble Tea](https://github.com/charmbracelet/bubbletea).

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Model Protocol](#model-protocol)
3. [Messages](#messages)
4. [Commands](#commands)
5. [Program](#program)
6. [Input Handling](#input-handling)
7. [Rendering](#rendering)
8. [Mouse Support](#mouse-support)
9. [Advanced Features](#advanced-features)

## Core Concepts

Matcha follows The Elm Architecture pattern with three main components:

- **Model**: Your application state
- **Update**: How your state changes in response to messages
- **View**: How your state is rendered as a string

## Model Protocol

Every Matcha application starts with a model that conforms to the `Model` protocol:

```swift
public protocol Model: Sendable {
    /// The message type this model handles
    associatedtype Msg: Message
    
    /// Initialize the model and optionally return an initial command
    func `init`() -> Command<Msg>?
    
    /// Update the model based on a message, returning the new model and optional command
    func update(_ message: Msg) -> (Self, Command<Msg>?)
    
    /// Render the model as a string for display
    func view() -> String
}
```

### Example Model

```swift
struct CounterModel: Model {
    typealias Msg = CounterMsg
    
    var count: Int = 0
    
    enum CounterMsg: Message {
        case increment
        case decrement
        case reset
    }
    
    func `init`() -> Command<CounterMsg>? {
        nil // No initial command
    }
    
    func update(_ message: CounterMsg) -> (CounterModel, Command<CounterMsg>?) {
        var model = self
        
        switch message {
        case .increment:
            model.count += 1
        case .decrement:
            model.count -= 1
        case .reset:
            model.count = 0
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        return "Count: \(count)\n\nPress + to increment, - to decrement, r to reset, q to quit"
    }
}
```

## Messages

Messages represent events in your application. They must conform to the `Message` protocol:

```swift
public protocol Message: Sendable {}
```

### Built-in Messages

Matcha provides several built-in messages:

#### Input Messages
- `KeyMsg`: Keyboard input events
- `MouseMsg`: Mouse events (clicks, motion, wheel)

#### Window Messages
- `WindowSizeMsg`: Terminal size changes
- `FocusMsg`: Terminal focus gained
- `BlurMsg`: Terminal focus lost

#### System Messages
- `QuitMsg`: Request to quit the program
- `BatchMsg<M>`: Execute multiple commands concurrently
- `SequenceMsg<M>`: Execute commands sequentially

### KeyMsg

```swift
let key = KeyMsg(character: "a")
let enterKey = KeyMsg(type: .enter)
let arrowKey = KeyMsg(type: .up)
let ctrlC = KeyMsg(type: .ctrlC)
```

Key types include:
- Character keys
- Special keys: enter, tab, backspace, escape, space, delete
- Arrow keys: up, down, left, right
- Navigation: home, end, pageUp, pageDown
- Control combinations: ctrlA through ctrlZ

### MouseMsg

```swift
let click = MouseMsg(
    x: 10,
    y: 5,
    type: .left,
    action: .press
)
```

Mouse actions:
- `.press`: Button pressed
- `.release`: Button released
- `.motion`: Mouse moved (with button held)
- `.wheel`: Wheel scrolled

## Commands

Commands represent asynchronous operations that produce messages:

```swift
public struct Command<M: Message> {
    public init(_ action: @escaping () async -> M?)
    public init(_ action: @escaping () async throws -> M?)
}
```

### Common Command Patterns

```swift
// Simple async operation
Command { () async -> MyMsg? in
    try? await Task.sleep(for: .seconds(1))
    return .timerTick
}

// HTTP request
Command { () async -> MyMsg? in
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        return .dataLoaded(data)
    } catch {
        return .error(error)
    }
}

// Multiple commands
batch(
    Command { .message1 },
    Command { .message2 }
)

// Sequential commands
sequence(
    Command { .first },
    Command { .second }
)
```

### Built-in Commands

```swift
// Quit the program
quit<MyMsg>()

// Set window title
setWindowTitle<MyMsg>("My App")

// Execute external process
Exec(myCommand) { error in
    .processFinished(error)
}
```

## Program

The `Program` class manages your application lifecycle:

```swift
let program = Program(
    initialModel: MyModel(),
    options: ProgramOptions(
        altScreen: true,      // Use alternate screen buffer
        mouseAllMotion: true, // Track all mouse motion
        reportFocus: true     // Report focus/blur events
    )
)

try await program.run()
```

### Program Options

```swift
public struct ProgramOptions {
    /// Use alternate screen buffer
    public var altScreen: Bool = true
    
    /// Enable mouse support
    public var mouseEnabled: Bool = true
    
    /// Track all mouse motion
    public var mouseAllMotion: Bool = false
    
    /// Track only mouse motion with buttons pressed
    public var mouseCellMotion: Bool = false
    
    /// Report focus/blur events
    public var reportFocus: Bool = false
    
    /// Without signals disables the signal handler
    public var withoutSignals: Bool = false
    
    /// Without catch-panics disables the panic handler
    public var withoutCatchPanics: Bool = false
    
    /// Without renderer disables rendering
    public var withoutRenderer: Bool = false
    
    /// Filter for limiting which messages are logged
    public var filter: ((any Message) -> Bool)?
    
    /// External context for cancellation
    public var context: Task<Void, Never>?
    
    /// Output writer (defaults to stdout)
    public var output: TextOutputStream?
    
    /// Input reader (defaults to stdin)
    public var input: FileHandle?
}
```

## Input Handling

Input is automatically parsed and converted to messages:

```swift
func update(_ message: MyMsg) -> (MyModel, Command<MyMsg>?) {
    switch message {
    case let key as KeyMsg:
        switch key.type {
        case .character(let char):
            // Handle character input
        case .enter:
            // Handle enter key
        case .ctrlC, .escape:
            return (self, quit())
        default:
            break
        }
        
    case let mouse as MouseMsg:
        // Handle mouse events
        
    default:
        break
    }
    
    return (self, nil)
}
```

## Rendering

The `view()` method returns a string that represents your UI:

```swift
func view() -> String {
    var output = ""
    
    // Add title
    output += "╭─ My App ─╮\n"
    output += "│          │\n"
    
    // Add content
    output += "│ \(content) │\n"
    
    // Add footer
    output += "╰──────────╯\n"
    
    return output
}
```

### ANSI Styling

You can use ANSI escape codes for styling:

```swift
// Colors
let red = "\u{1B}[31mRed Text\u{1B}[0m"
let green = "\u{1B}[32mGreen Text\u{1B}[0m"
let blue = "\u{1B}[34mBlue Text\u{1B}[0m"

// Styles
let bold = "\u{1B}[1mBold Text\u{1B}[0m"
let italic = "\u{1B}[3mItalic Text\u{1B}[0m"
let underline = "\u{1B}[4mUnderlined Text\u{1B}[0m"
```

## Mouse Support

Enable mouse tracking in your program options:

```swift
let options = ProgramOptions(
    mouseEnabled: true,      // Basic mouse support
    mouseAllMotion: true     // Track all motion
)
```

Handle mouse events in your update function:

```swift
case let mouse as MouseMsg:
    switch mouse.action {
    case .press:
        if mouse.type == .left {
            // Handle left click at (mouse.x, mouse.y)
        }
    case .release:
        // Handle button release
    case .motion:
        // Handle drag (motion with button pressed)
    case .wheel:
        // Handle scroll
    }
```

## Advanced Features

### Scroll Regions

Create scrollable areas within your terminal:

```swift
// In your update function, return scroll commands
ScrollSyncMsg(
    lines: ["Line 1", "Line 2", "Line 3"],
    topBoundary: 5,
    bottomBoundary: 15
)

// Scroll content up
ScrollUpMsg(
    lines: ["New line at top"],
    topBoundary: 5,
    bottomBoundary: 15
)

// Scroll content down
ScrollDownMsg(
    lines: ["New line at bottom"],
    topBoundary: 5,
    bottomBoundary: 15
)
```

### Message Batching

Execute multiple commands concurrently:

```swift
let commands = BatchMsg<MyMsg>(
    Command { .firstMessage },
    Command { .secondMessage },
    Command { .thirdMessage }
)
```

Execute commands sequentially:

```swift
let sequence = SequenceMsg<MyMsg>(
    Command { .step1 },
    Command { .step2 },
    Command { .step3 }
)
```

### External Process Execution

Run external commands:

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/ls")
process.arguments = ["-la"]

let command = ExecProcess(process) { error in
    if let error = error {
        return .commandFailed(error)
    } else {
        return .commandSucceeded
    }
}
```

### Error Handling

Send errors to the program:

```swift
program.sendError(MyCustomError())
```

Handle errors in your model:

```swift
case let error as ErrMsg:
    // Handle error
    model.error = error.error
```

### Focus Detection

Enable focus detection:

```swift
let options = ProgramOptions(reportFocus: true)
```

Handle focus events:

```swift
case is FocusMsg:
    model.hasFocus = true
case is BlurMsg:
    model.hasFocus = false
```

## Complete Example

Here's a complete example of a simple TODO application:

```swift
import Matcha

struct TodoModel: Model {
    typealias Msg = TodoMsg
    
    var items: [String] = []
    var input: String = ""
    var selectedIndex: Int = 0
    
    enum TodoMsg: Message {
        case keyPressed(KeyMsg)
        case addItem
        case removeItem
        case moveUp
        case moveDown
    }
    
    func `init`() -> Command<TodoMsg>? {
        nil
    }
    
    func update(_ message: TodoMsg) -> (TodoModel, Command<TodoMsg>?) {
        var model = self
        
        switch message {
        case .keyPressed(let key):
            switch key.type {
            case .character(let char):
                model.input.append(char)
            case .backspace:
                _ = model.input.popLast()
            case .enter:
                return model.update(.addItem)
            case .up:
                return model.update(.moveUp)
            case .down:
                return model.update(.moveDown)
            case .delete:
                return model.update(.removeItem)
            case .ctrlC, .escape:
                return (model, quit())
            default:
                break
            }
            
        case .addItem:
            if !model.input.isEmpty {
                model.items.append(model.input)
                model.input = ""
            }
            
        case .removeItem:
            if model.selectedIndex < model.items.count {
                model.items.remove(at: model.selectedIndex)
                if model.selectedIndex >= model.items.count && model.selectedIndex > 0 {
                    model.selectedIndex -= 1
                }
            }
            
        case .moveUp:
            if model.selectedIndex > 0 {
                model.selectedIndex -= 1
            }
            
        case .moveDown:
            if model.selectedIndex < model.items.count - 1 {
                model.selectedIndex += 1
            }
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        var output = "TODO List\n"
        output += "═════════\n\n"
        
        // Show items
        for (index, item) in items.enumerated() {
            let cursor = index == selectedIndex ? "▶ " : "  "
            output += "\(cursor)\(item)\n"
        }
        
        if items.isEmpty {
            output += "  (no items)\n"
        }
        
        // Show input
        output += "\n"
        output += "Add item: \(input)█\n"
        output += "\n"
        output += "Controls: ↑/↓ navigate, Delete remove, Enter add, Esc quit"
        
        return output
    }
}

// Run the application
let program = Program(
    initialModel: TodoModel(),
    options: ProgramOptions(altScreen: true)
)

try await program.run()
```

## Best Practices

1. **Keep Models Immutable**: Always create a new model in `update()` rather than mutating
2. **Use Commands for Side Effects**: Keep your update function pure by returning commands
3. **Handle All Message Types**: Always include a default case in your message handling
4. **Test with Golden Files**: Use the GoldenFileTester for consistent UI testing
5. **Enable Mouse Support Thoughtfully**: Not all terminal emulators support all mouse modes
6. **Use Alternate Screen**: For full-screen apps, use `altScreen: true`
7. **Handle Errors Gracefully**: Always provide error feedback to users