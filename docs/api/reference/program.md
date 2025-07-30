# Program

The main runtime that manages your Matcha application's lifecycle, input handling, rendering, and message dispatch.

## Declaration

```swift
public final class Program<M: Model>: Sendable {
    public init(initialModel: M, options: ProgramOptions = .default)
    public func run() async throws -> M
}
```

## Overview

Program is responsible for:
- Setting up the terminal environment
- Managing the main event loop
- Handling input from keyboard and mouse
- Rendering the view
- Dispatching messages to your model
- Running commands
- Cleaning up on exit

## Initialization

### Basic Usage

```swift
let program = Program(initialModel: MyModel())
try await program.run()
```

### With Options

```swift
var options = ProgramOptions()
options.useAltScreen = true
options.mouseMode = .all
options.framesPerSecond = 60

let program = Program(
    initialModel: MyModel(),
    options: options
)
```

## Program Options

Configure program behavior through `ProgramOptions`:

```swift
public struct ProgramOptions {
    // Display options
    var useAltScreen: Bool = false
    var startFullScreen: Bool = false
    var windowTitle: String? = nil
    
    // Input options
    var mouseMode: MouseMode = .disabled
    var reportFocus: Bool = false
    
    // Rendering options
    var framesPerSecond: Int = 60
    var maxFPS: Int = 120
    
    // Message filtering
    var filter: Filter? = nil
    
    // Signal handling
    var catchInterrupt: Bool = true
    var catchSuspend: Bool = true
}
```

### Message Filtering

The filter function allows you to intercept and transform messages:

```swift
options.filter = { model, message in
    // Log all messages
    print("Message: \(message)")
    
    // Transform quit keys
    if let key = message as? Key {
        switch key.description {
        case "q", "ctrl+c":
            return QuitMsg()
        case "?":
            return MyModel.Message.toggleHelp
        default:
            break
        }
    }
    
    return message
}
```

## Lifecycle

### 1. Initialization Phase
```swift
// Program creates:
// - Terminal I/O handler
// - Input handler
// - Renderer
// - Message dispatcher

// Then calls model's init command
if let cmd = model.init() {
    // Execute startup command
}
```

### 2. Main Loop
```swift
while !shouldQuit {
    // 1. Check for input
    if let input = await inputHandler.read() {
        let message = convertToMessage(input)
        let filtered = filter?(model, message) ?? message
        
        // 2. Update model
        let (newModel, command) = model.update(filtered)
        model = newModel
        
        // 3. Execute command
        if let command = command {
            Task { 
                if let msg = await command.execute() {
                    messageQueue.send(msg)
                }
            }
        }
    }
    
    // 4. Render view
    if needsRender {
        let view = model.view()
        renderer.render(view)
    }
}
```

### 3. Cleanup Phase
```swift
// On exit:
// - Restore terminal settings
// - Exit alternate screen
// - Show cursor
// - Flush output
```

## Input Handling

Program automatically converts terminal input to messages:

### Keyboard Input
```swift
// Key presses become Key messages
Key(character: "a")
Key(type: .up)
Key(type: .enter)
Key(type: .escape)
```

### Mouse Input
```swift
// Mouse events when enabled
MouseEvent(type: .click, x: 10, y: 5)
MouseEvent(type: .scroll(.up), x: 10, y: 5)
MouseEvent(type: .move, x: 15, y: 8)
```

### Window Events
```swift
// Terminal resize
WindowSizeMsg(width: 120, height: 40)
```

## Rendering

Program uses intelligent rendering:

1. **Diff-based Updates**: Only redraws changed lines
2. **Frame Rate Control**: Respects FPS settings
3. **Render Coalescing**: Batches rapid updates
4. **Automatic Resize**: Handles terminal size changes

## Error Handling

Program handles various error conditions:

```swift
do {
    let finalModel = try await program.run()
    // Program exited normally
} catch is ProgramKilledError {
    // User pressed Ctrl+C
} catch is ProgramPanicError {
    // Program panic
} catch {
    // Other errors
}
```

## Signal Handling

Program responds to Unix signals:

- **SIGINT** (Ctrl+C): Graceful shutdown
- **SIGTERM**: Graceful shutdown
- **SIGWINCH**: Window resize
- **SIGTSTP** (Ctrl+Z): Suspend/resume
- **SIGCONT**: Resume after suspend

## Example: Complete Application

```swift
import Matcha

struct ChatModel: Model {
    var messages: [String] = []
    var input = TextInput()
    
    enum Message: Matcha.Message {
        case send
        case inputMsg(TextInput.Message)
        case quit
    }
    
    init() {
        input.placeholder = "Type a message..."
        input.focus()
    }
    
    func `init`() -> Command<Message>? { nil }
    
    func update(_ message: Message) -> (ChatModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .send:
            if !model.input.value.isEmpty {
                model.messages.append(model.input.value)
                model.input.reset()
            }
            return (model, nil)
            
        case .inputMsg(let msg):
            let (newInput, cmd) = model.input.update(msg)
            model.input = newInput
            return (model, cmd?.map { .inputMsg($0) })
            
        case .quit:
            return (model, quit())
        }
    }
    
    func view() -> String {
        var output = "💬 Chat\n\n"
        
        for message in messages.suffix(10) {
            output += "• \(message)\n"
        }
        
        output += "\n\(input.view())\n"
        output += "\nEnter to send, Ctrl+C to quit"
        
        return output
    }
}

@main
struct ChatApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        
        options.filter = { _, message in
            if let key = message as? Key {
                switch key {
                case .enter:
                    return ChatModel.Message.send
                case .character(let char):
                    return ChatModel.Message.inputMsg(.characterInput(char))
                case .backspace:
                    return ChatModel.Message.inputMsg(.backspace)
                default:
                    break
                }
            }
            return message
        }
        
        let program = Program(
            initialModel: ChatModel(),
            options: options
        )
        
        _ = try await program.run()
        print("Goodbye! 👋")
    }
}
```

## Advanced Usage

### Custom Message Types

Handle multiple message sources:

```swift
options.filter = { model, message in
    switch message {
    case let key as Key:
        return handleKey(key, model: model)
    case let mouse as MouseEvent:
        return handleMouse(mouse, model: model)
    case let custom as MyCustomMessage:
        return MyModel.Message.custom(custom)
    default:
        return message
    }
}
```

### Performance Tuning

```swift
// High-performance settings
options.framesPerSecond = 120
options.maxFPS = 144

// Battery-saving settings
options.framesPerSecond = 30
options.maxFPS = 30
```

### Focus Tracking

```swift
options.reportFocus = true

// In your model
case .focusGained:
    model.hasFocus = true
case .focusLost:
    model.hasFocus = false
```

## Thread Safety

Program is thread-safe and uses Swift concurrency:
- Model updates happen on the main actor
- Commands run on background tasks
- Rendering is synchronized
- Input handling is non-blocking

## See Also

- [Model Protocol](model.md)
- [ProgramOptions](program-options.md)
- [Command Type](command.md)
- [Renderer Protocol](renderer.md)