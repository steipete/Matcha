# Matcha Architecture

This document provides a deep dive into the internal architecture of Matcha, explaining how the framework is designed and how its components work together.

## Overview

Matcha is built on three architectural pillars:
1. **The Elm Architecture (TEA)** - Predictable state management
2. **Swift Concurrency** - Modern async/await and actor-based design
3. **Terminal Abstraction** - Platform-agnostic terminal I/O

```
┌─────────────────────────────────────────────────────────┐
│                     User Application                     │
├─────────────────────────────────────────────────────────┤
│                        Matcha                            │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │   Program    │  │    Model     │  │    Command     │ │
│  │  (Runtime)   │  │  Protocol    │  │   (Effects)    │ │
│  └──────┬──────┘  └──────┬───────┘  └────────┬───────┘ │
│         │                 │                    │         │
│  ┌──────▼──────┐  ┌──────▼───────┐  ┌────────▼───────┐ │
│  │   Renderer   │  │   Message    │  │     Input      │ │
│  │  (Display)   │  │   System     │  │   Handler      │ │
│  └──────┬──────┘  └──────────────┘  └────────┬───────┘ │
├─────────┴──────────────────────────────────────┴────────┤
│                    Terminal Layer                        │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │     TTY     │  │    ANSI      │  │    Platform    │ │
│  │    (I/O)    │  │   Escape     │  │   Specific     │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Program (Runtime Engine)

The `Program` class is the heart of Matcha, managing the entire application lifecycle:

```swift
public final class Program<M: Model>: Sendable {
    private let model: M
    private let renderer: Renderer
    private let inputHandler: InputHandler
    private let messageQueue: AsyncChannel<M.Msg>
    
    @MainActor
    public func run() async throws -> M {
        // Setup terminal
        try await setup()
        
        // Main loop
        while !shouldQuit {
            // Process messages
            if let message = await messageQueue.receive() {
                await processMessage(message)
            }
            
            // Render if needed
            if needsRender {
                await render()
            }
        }
        
        // Cleanup
        await cleanup()
        return currentModel
    }
}
```

#### Message Processing Pipeline

1. **Input Reception**: Raw terminal input is received
2. **Input Parsing**: Converted to structured input events
3. **Message Creation**: Input events become messages
4. **Filtering**: Optional message transformation via filters
5. **Model Update**: Message passed to model's update function
6. **Command Execution**: Resulting commands are executed
7. **Re-render**: View is updated if model changed

### 2. Model Protocol

The Model protocol enforces the Elm Architecture pattern:

```swift
public protocol Model: Sendable {
    associatedtype Msg: Message
    
    init()
    func `init`() -> Command<Msg>?
    func update(_ message: Msg) -> (Self, Command<Msg>?)
    func view() -> String
}
```

#### State Management Philosophy

- **Immutability**: Models are value types, updates create new instances
- **Explicit Effects**: All side effects go through Commands
- **Single Source of Truth**: All state lives in the model
- **Predictability**: Same input always produces same output

### 3. Rendering System

The rendering system optimizes terminal updates using several techniques:

```swift
actor StandardRenderer: Renderer {
    private var lastFrame: [String] = []
    private var renderTask: Task<Void, Never>?
    private let renderInterval: Duration = .milliseconds(16)  // 60 FPS
    
    func render(_ content: String) async {
        // Cancel pending render
        renderTask?.cancel()
        
        // Schedule new render
        renderTask = Task {
            try? await Task.sleep(for: renderInterval)
            guard !Task.isCancelled else { return }
            
            await performRender(content)
        }
    }
    
    private func performRender(_ content: String) async {
        let lines = content.split(separator: "\n").map(String.init)
        
        // Diff-based rendering
        for (index, newLine) in lines.enumerated() {
            if index < lastFrame.count && lastFrame[index] == newLine {
                continue  // Skip unchanged lines
            }
            
            // Update only changed line
            await moveCursor(to: .line(index))
            await clearLine()
            await write(newLine)
        }
        
        lastFrame = lines
    }
}
```

#### Rendering Optimizations

1. **Diff-Based Updates**: Only changed lines are redrawn
2. **Render Coalescing**: Rapid updates are batched
3. **Frame Rate Control**: Configurable FPS limiting
4. **Buffer Pooling**: Reuses string buffers
5. **Viewport Culling**: Only renders visible content

### 4. Input System

Input handling is abstracted to support different input types:

```swift
actor InputHandler {
    private let input: AsyncStream<InputEvent>
    
    func start() async {
        // Enable raw mode
        await TTY.enableRawMode()
        
        // Start input loop
        for await byte in FileHandle.standardInput.bytes {
            let event = await parseInput(byte)
            if let event = event {
                await handleEvent(event)
            }
        }
    }
    
    private func parseInput(_ bytes: [UInt8]) async -> InputEvent? {
        // ANSI escape sequence parsing
        if bytes.starts(with: [0x1B]) {  // ESC
            return parseEscapeSequence(bytes)
        }
        
        // Regular character
        if let char = Character(bytes) {
            return .key(Key(char))
        }
        
        return nil
    }
}
```

#### Input Types

- **Keyboard**: Characters, special keys, modifiers
- **Mouse**: Clicks, movement, scrolling
- **Terminal Events**: Resize, focus/blur
- **System Signals**: SIGINT, SIGWINCH, etc.

### 5. Command System

Commands represent asynchronous effects:

```swift
public struct Command<M: Message>: Sendable {
    private let operation: @Sendable () async -> M?
    
    public init(operation: @escaping @Sendable () async -> M?) {
        self.operation = operation
    }
    
    func execute() async -> M? {
        await operation()
    }
}

// Command combinators
extension Command {
    public static func batch(_ commands: Command...) -> Command {
        Command {
            await withTaskGroup(of: M?.self) { group in
                for command in commands {
                    group.addTask { await command.execute() }
                }
                
                // Collect non-nil results
                var messages: [M] = []
                for await message in group {
                    if let message = message {
                        messages.append(message)
                    }
                }
                
                // Return first message (or nil)
                return messages.first
            }
        }
    }
}
```

## Concurrency Architecture

### Actor-Based Design

Matcha uses Swift actors to ensure thread safety:

```swift
@MainActor
class ModelContainer<M: Model> {
    private var model: M
    
    func update(_ message: M.Msg) -> Command<M.Msg>? {
        let (newModel, command) = model.update(message)
        model = newModel
        return command
    }
}
```

### Async Message Flow

```
User Input ──► InputHandler ──► Message Queue ──► Model Update
                   (Actor)      (AsyncChannel)     (@MainActor)
                      │                                  │
                      │                                  ▼
Terminal ◄── Renderer ◄──────── View ◄──────── Command Execution
            (Actor)                               (Background)
```

### Cancellation and Cleanup

```swift
class Program {
    private var tasks: Set<Task<Void, Never>> = []
    
    func executeCommand(_ command: Command<M.Msg>) {
        let task = Task {
            if let message = await command.execute() {
                await messageQueue.send(message)
            }
        }
        tasks.insert(task)
        
        // Cleanup completed tasks
        task.onCompletion { [weak self] in
            self?.tasks.remove(task)
        }
    }
    
    func shutdown() async {
        // Cancel all pending commands
        tasks.forEach { $0.cancel() }
        
        // Wait for cleanup
        await withTaskGroup(of: Void.self) { group in
            tasks.forEach { task in
                group.addTask { await task.value }
            }
        }
    }
}
```

## Terminal Abstraction Layer

### Platform Abstraction

```swift
protocol TerminalPlatform {
    func enableRawMode() async throws
    func disableRawMode() async throws
    func getSize() async -> (width: Int, height: Int)
    func hideCursor() async
    func showCursor() async
}

#if os(macOS) || os(Linux)
struct UnixTerminal: TerminalPlatform {
    // POSIX implementation
}
#elseif os(Windows)
struct WindowsTerminal: TerminalPlatform {
    // Windows Console API implementation
}
#endif
```

### ANSI Escape Sequences

```swift
enum ANSICode {
    // Cursor
    static let saveCursor = "\u{1B}[s"
    static let restoreCursor = "\u{1B}[u"
    static func moveCursor(x: Int, y: Int) -> String {
        "\u{1B}[\(y);\(x)H"
    }
    
    // Screen
    static let clearScreen = "\u{1B}[2J"
    static let clearLine = "\u{1B}[2K"
    static let alternateScreen = "\u{1B}[?1049h"
    static let normalScreen = "\u{1B}[?1049l"
    
    // Styling
    static func color(_ color: Color) -> String {
        switch color {
        case .ansi(let code):
            return "\u{1B}[38;5;\(code)m"
        case .rgb(let r, let g, let b):
            return "\u{1B}[38;2;\(r);\(g);\(b)m"
        }
    }
}
```

## Component Architecture

### Component Protocol

```swift
public protocol Component: Sendable {
    associatedtype Message
    
    mutating func update(_ msg: Message) -> Command<Message>?
    func view() -> String
}
```

### Component Integration

```swift
struct AppModel: Model {
    var textInput = TextInput()
    var list = List(items: [])
    
    enum Message: Matcha.Message {
        case textInputMsg(TextInput.Message)
        case listMsg(List.Message)
    }
    
    func update(_ message: Message) -> (AppModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .textInputMsg(let msg):
            let cmd = model.textInput.update(msg)
            return (model, cmd?.map { .textInputMsg($0) })
            
        case .listMsg(let msg):
            let cmd = model.list.update(msg)
            return (model, cmd?.map { .listMsg($0) })
        }
    }
}
```

## Performance Considerations

### Memory Management

1. **Model Copying**: Use copy-on-write for large collections
2. **String Building**: Pre-allocate capacity for known sizes
3. **Component Reuse**: Cache rendered component output when possible

### Rendering Performance

1. **Viewport Culling**: Only render visible content
2. **Lazy Evaluation**: Defer expensive computations
3. **Batch Updates**: Group related changes
4. **Diff Optimization**: Minimize comparison overhead

### Async Performance

1. **Task Cancellation**: Cancel obsolete operations
2. **Debouncing**: Limit rapid event processing
3. **Priority Queues**: Handle important messages first
4. **Backpressure**: Prevent queue overflow

## Extension Points

### Custom Renderers

```swift
protocol Renderer: Actor {
    func render(_ content: String) async
    func clear() async
    func setup(options: RendererOptions) async
}

// Custom implementation
actor WebRenderer: Renderer {
    // Render to web terminal via WebSocket
}
```

### Custom Input Sources

```swift
protocol InputSource: Actor {
    var events: AsyncStream<InputEvent> { get }
}

// Network input
actor NetworkInput: InputSource {
    // Receive input from remote client
}
```

### Plugin System

```swift
protocol MatchaPlugin {
    func configure(program: ProgramBuilder)
    func middleware<M: Model>(model: M, message: M.Msg) -> M.Msg?
}
```

## Testing Architecture

### Test Utilities

```swift
class MockProgram<M: Model> {
    private var model: M
    private let renderer = MockRenderer()
    
    func sendMessage(_ message: M.Msg) async {
        let (newModel, command) = model.update(message)
        model = newModel
        
        if let command = command {
            if let resultMsg = await command.execute() {
                await sendMessage(resultMsg)
            }
        }
    }
    
    func expectView(containing text: String) {
        let view = model.view()
        XCTAssertTrue(view.contains(text))
    }
}
```

## Security Considerations

1. **Input Sanitization**: Escape sequences are validated
2. **Resource Limits**: Prevent memory/CPU exhaustion
3. **Safe Mode**: Restricted command execution
4. **Audit Logging**: Track security-relevant events

## Future Architecture Directions

1. **Multi-Window Support**: Multiple Program instances
2. **Remote Rendering**: Client-server architecture
3. **Plugin Ecosystem**: Dynamic component loading
4. **GPU Acceleration**: Metal/Vulkan for complex UIs
5. **Accessibility**: Screen reader integration

## Conclusion

Matcha's architecture prioritizes:
- **Predictability** through immutable state
- **Performance** through intelligent rendering
- **Safety** through Swift's type system and actors
- **Extensibility** through protocols and plugins

This design enables building complex, performant terminal applications while maintaining code clarity and correctness.