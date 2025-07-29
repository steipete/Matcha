# Matcha: A Swift Port of Bubble Tea

## Executive Summary

Matcha is a Swift port of Charm's Bubble Tea framework, bringing the elegant Elm Architecture to Swift for building rich terminal user interfaces. This specification outlines the architecture, API design, and implementation strategy for creating a production-ready TUI framework that maintains the spirit of Bubble Tea while embracing Swift's language features and idioms.

## Project Goals

1. **API Compatibility**: Maintain conceptual compatibility with Bubble Tea's API while adapting to Swift idioms
2. **Performance**: Achieve high-performance rendering with minimal CPU usage
3. **Type Safety**: Leverage Swift's type system for safer, more expressive APIs
4. **Cross-Platform**: Support macOS and Linux from day one
5. **Swift-First**: Embrace Swift concurrency, property wrappers, and modern language features
6. **Extensibility**: Provide clear extension points for custom components and renderers

## Core Architecture

### The Elm Architecture in Swift

The framework follows The Elm Architecture with three core concepts:

```swift
// Core protocol for messages
protocol Message {}

// Model protocol that all apps must implement
protocol Model {
    associatedtype Msg: Message
    
    init()
    func update(_ message: Msg) -> (Self, Command<Msg>?)
    func view() -> String
}

// Command represents an async operation that produces a message
struct Command<Msg: Message> {
    let operation: () async -> Msg?
}
```

### Program Lifecycle

```swift
// Main program class that runs the app
class Program<M: Model> {
    let model: M
    private let renderer: Renderer
    private let inputHandler: InputHandler
    
    init(initialModel: M, options: ProgramOptions = .default) {
        self.model = initialModel
        self.renderer = StandardRenderer(options: options.rendererOptions)
        self.inputHandler = InputHandler()
    }
    
    func run() async throws {
        // Initialize terminal
        // Start input handling
        // Run main loop
        // Cleanup on exit
    }
}
```

## Component Design

### 1. Message System

Messages are strongly typed using protocols and enums:

```swift
// Built-in messages
enum BuiltInMessage: Message {
    case key(Key)
    case mouse(MouseEvent)
    case windowSize(Size)
    case tick(Date)
    case quit
    case suspend
}

// User messages extend the Message protocol
enum AppMessage: Message {
    case increment
    case decrement
    case reset
}
```

### 2. Keyboard Input

Comprehensive keyboard handling with a type-safe API:

```swift
struct Key: Equatable {
    enum KeyType {
        case character(Character)
        case control(ControlKey)
        case function(Int)
        case special(SpecialKey)
    }
    
    let type: KeyType
    let modifiers: KeyModifiers
}

struct KeyModifiers: OptionSet {
    let rawValue: Int
    static let alt = KeyModifiers(rawValue: 1 << 0)
    static let ctrl = KeyModifiers(rawValue: 1 << 1)
    static let shift = KeyModifiers(rawValue: 1 << 2)
}

// Pattern matching support
extension Key {
    static func ~= (pattern: String, key: Key) -> Bool {
        // Match strings like "ctrl+c", "alt+enter", etc.
    }
}
```

### 3. Mouse Support

Rich mouse event handling:

```swift
struct MouseEvent {
    let position: Point
    let action: MouseAction
    let button: MouseButton
    let modifiers: KeyModifiers
}

enum MouseAction {
    case press
    case release
    case motion
}

enum MouseButton {
    case left, middle, right
    case wheelUp, wheelDown
    case additional(Int)
}
```

### 4. Commands

Async operations that integrate with Swift concurrency:

```swift
extension Command {
    // Batch multiple commands
    static func batch(_ commands: [Command]) -> Command
    
    // Run commands in sequence
    static func sequence(_ commands: [Command]) -> Command
    
    // Common commands
    static func tick(duration: Duration) -> Command<TickMessage>
    static func setWindowTitle(_ title: String) -> Command<Never>
    static func println(_ text: String) -> Command<Never>
}

// Timer support
func every(_ interval: Duration, _ tick: @escaping (Date) -> Msg) -> Command<Msg> {
    Command {
        for await _ in Timer.publish(every: interval).values {
            return tick(Date())
        }
        return nil
    }
}
```

### 5. Rendering Engine

High-performance, frame-based rendering:

```swift
protocol Renderer {
    func start() async throws
    func stop() async
    func render(_ content: String) async
    func clear() async
    func enterAltScreen() async
    func exitAltScreen() async
}

class StandardRenderer: Renderer {
    private let frameRate: Int
    private let output: FileHandle
    private var buffer: String = ""
    private var lastRender: [String] = []
    
    // Diff-based rendering for efficiency
    private func flush() async {
        let newLines = buffer.split(separator: "\n")
        let diff = computeDiff(old: lastRender, new: newLines)
        
        for change in diff {
            switch change {
            case .unchanged(let line, let index):
                // Skip unchanged lines
            case .modified(let line, let index):
                // Update only changed lines
                await moveCursor(to: Point(x: 0, y: index))
                await write(line)
            }
        }
        
        lastRender = newLines
        buffer = ""
    }
}
```

## Platform Abstraction

### Terminal I/O

```swift
protocol Terminal {
    func enableRawMode() throws
    func disableRawMode() throws
    func getSize() throws -> Size
    func hideCursor() async
    func showCursor() async
    func clear() async
}

// Platform-specific implementations
#if os(macOS) || os(Linux)
class UnixTerminal: Terminal {
    // termios-based implementation
}
#endif
```

### Input Handling

```swift
class InputHandler {
    private let input: AsyncStream<UInt8>
    
    func start() -> AsyncStream<Message> {
        AsyncStream { continuation in
            Task {
                var parser = ANSIParser()
                
                for await byte in input {
                    if let message = parser.parse(byte) {
                        continuation.yield(message)
                    }
                }
            }
        }
    }
}
```

## Example Usage

### Simple Counter App

```swift
struct CounterModel: Model {
    var count: Int = 0
    
    enum Message: Matcha.Message {
        case increment
        case decrement
        case tick
    }
    
    init() {}
    
    func update(_ message: Message) -> (CounterModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .increment:
            model.count += 1
            return (model, nil)
            
        case .decrement:
            model.count -= 1
            return (model, nil)
            
        case .tick:
            return (model, .tick(duration: .seconds(1)))
        }
    }
    
    func view() -> String {
        """
        Counter: \(count)
        
        Press + to increment
        Press - to decrement
        Press q to quit
        """
    }
}

// Running the app
@main
struct CounterApp {
    static func main() async throws {
        let program = Program(initialModel: CounterModel())
        try await program.run()
    }
}
```

### Advanced Features Example

```swift
struct TodoModel: Model {
    var items: [TodoItem] = []
    var cursor: Int = 0
    var filter: Filter = .all
    
    enum Message: Matcha.Message {
        case key(Key)
        case addItem(String)
        case toggleItem(Int)
        case deleteItem(Int)
        case filterChanged(Filter)
        case loaded([TodoItem])
    }
    
    func update(_ message: Message) -> (TodoModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key {
            case "up", "k":
                model.cursor = max(0, model.cursor - 1)
            case "down", "j":
                model.cursor = min(model.items.count - 1, model.cursor + 1)
            case "enter", " ":
                return (model, .pure(.toggleItem(model.cursor)))
            case "d":
                return (model, .pure(.deleteItem(model.cursor)))
            default:
                break
            }
            
        case .toggleItem(let index):
            model.items[index].completed.toggle()
            return (model, .execute(saveTodos))
            
        // ... other cases
        }
        
        return (model, nil)
    }
    
    func view() -> String {
        // Render todo list with styling
    }
    
    // Async command example
    func saveTodos() async -> Message? {
        do {
            try await TodoService.save(items)
            return nil
        } catch {
            return .error(error)
        }
    }
}
```

## Component Library (Bubbles Equivalent)

### Text Input

```swift
struct TextInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    
    func handleKey(_ key: Key) -> Command<Message>? {
        // Handle text input
    }
}
```

### List View

```swift
struct ListView<Item>: View {
    let items: [Item]
    @Binding var selectedIndex: Int
    let itemView: (Item, Bool) -> String
    
    func handleKey(_ key: Key) -> Command<Message>? {
        // Handle navigation
    }
}
```

### Progress Bar

```swift
struct ProgressBar: View {
    let progress: Double
    let width: Int
    let showPercentage: Bool
    
    func render() -> String {
        // Render progress bar
    }
}
```

## Styling System

Integration with a styling library (similar to Lip Gloss):

```swift
struct Style {
    var foreground: Color?
    var background: Color?
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var strikethrough: Bool = false
    
    func apply(to text: String) -> String {
        // Apply ANSI styling
    }
}

extension String {
    func styled(_ style: Style) -> String {
        style.apply(to: self)
    }
}
```

## Testing Support

Built-in testing utilities:

```swift
class ProgramTester<M: Model> {
    private let program: Program<M>
    
    func send(_ message: M.Message) async
    func sendKey(_ key: String) async
    func sendMouse(_ event: MouseEvent) async
    func expectView(_ expected: String) async throws
    func getCurrentView() -> String
}

// Example test
func testCounter() async throws {
    let tester = ProgramTester(model: CounterModel())
    
    await tester.sendKey("+")
    await tester.expectView(containing: "Counter: 1")
    
    await tester.sendKey("-")
    await tester.sendKey("-")
    await tester.expectView(containing: "Counter: -1")
}
```

## Exhaustive Implementation Checklist

This checklist covers every feature, API, and capability present in Bubble Tea that needs to be implemented for a complete port to Swift.

### 1. Core Architecture & Program Management

#### Program Structure
- [ ] Create `Program` class with all required fields
  - [ ] `initialModel` storage
  - [ ] `output` writer (default stdout)
  - [ ] `input` reader (default stdin)
  - [ ] `renderer` implementation
  - [ ] `context` management
  - [ ] `msgs` channel equivalent (AsyncChannel)
  - [ ] `errs` channel equivalent
  - [ ] `finished` completion handler
  - [ ] Terminal state management (input/output states)
  - [ ] Cancel reader implementation
  - [ ] Signal handler storage
  - [ ] Mouse mode state
  - [ ] Alt screen state tracking
  - [ ] Bracketed paste state
  - [ ] Focus reporting state
  - [ ] Filter function support
  - [ ] FPS configuration

#### Core Interfaces & Types
- [ ] Define `Model` protocol with `init()`, `update()`, `view()`
- [ ] Define `Message` protocol (marker protocol)
- [ ] Define `Command` type (async closure returning Message?)
- [ ] Implement `Msg` type alias for `Message`
- [ ] Implement `Cmd` type alias for `Command`

#### Program Methods
- [ ] `init(initialModel:options:)` - Main initializer
- [ ] `run() async throws -> Model` - Main run loop
- [ ] `send(_ message: Message)` - External message sending
- [ ] `quit()` - Graceful shutdown
- [ ] `kill()` - Force terminate
- [ ] `wait() async` - Wait for completion
- [ ] `releaseTerminal() throws` - Release terminal control
- [ ] `restoreTerminal() throws` - Restore terminal state
- [ ] `println(_ items: Any...)` - Print to terminal
- [ ] `printf(_ format: String, _ args: Any...)` - Formatted print

### 2. Options System

#### ProgramOption Implementation
- [ ] Create `ProgramOption` protocol/enum
- [ ] `withOutput(_ output: TextOutputStream)` - Custom output
- [ ] `withInput(_ input: AsyncSequence<UInt8>)` - Custom input
- [ ] `withInputTTY()` - Force TTY input
- [ ] `withContext(_ context: Task)` - External context
- [ ] `withEnvironment(_ env: [String: String])` - Environment vars
- [ ] `withoutSignalHandler()` - Disable signal handling
- [ ] `withoutCatchPanics()` - Disable panic recovery
- [ ] `withoutSignals()` - Disable all signals
- [ ] `withAltScreen()` - Start in alternate screen
- [ ] `withoutBracketedPaste()` - Disable bracketed paste
- [ ] `withMouseCellMotion()` - Enable cell-based mouse
- [ ] `withMouseAllMotion()` - Enable all mouse motion
- [ ] `withoutRenderer()` - Disable rendering
- [ ] `withFilter(_ filter: (Model, Message) -> Message?)` - Message filter
- [ ] `withFPS(_ fps: Int)` - Set frame rate
- [ ] `withReportFocus()` - Enable focus reporting

### 3. Message System

#### Core Messages
- [ ] `QuitMsg` struct
- [ ] `SuspendMsg` struct
- [ ] `ResumeMsg` struct
- [ ] `InterruptMsg` struct
- [ ] `WindowSizeMsg` with width/height
- [ ] `BatchMsg` for command batching
- [ ] Internal sequence message type
- [ ] Internal window title message
- [ ] Internal print messages

#### Keyboard Messages
- [ ] `KeyMsg` type (alias for Key)
- [ ] `Key` struct with:
  - [ ] `type: KeyType` enum
  - [ ] `runes: [Character]` for text
  - [ ] `alt: Bool` modifier
  - [ ] `paste: Bool` flag
- [ ] `KeyType` enum with all variants:
  - [ ] Control keys (null, break, enter, backspace, tab, escape, delete)
  - [ ] Navigation (up, down, right, left, home, end, pgup, pgdown)
  - [ ] Editing (insert)
  - [ ] Function keys (F1-F20)
  - [ ] Special keys (print screen, pause, caps lock, num lock, scroll lock)
  - [ ] Control characters (ctrl+a through ctrl+z, ctrl+[, ctrl+\, ctrl+], ctrl+^, ctrl+_)
  - [ ] Runes type for regular characters
- [ ] `unknownInputByteMsg` for unrecognized bytes
- [ ] `unknownCSISequenceMsg` for unknown ANSI sequences

#### Mouse Messages
- [ ] `MouseMsg` type (alias for MouseEvent)
- [ ] `MouseEvent` struct with:
  - [ ] `x: Int` coordinate
  - [ ] `y: Int` coordinate
  - [ ] `shift: Bool` modifier
  - [ ] `alt: Bool` modifier
  - [ ] `ctrl: Bool` modifier
  - [ ] `action: MouseAction` enum
  - [ ] `button: MouseButton` enum
- [ ] `MouseAction` enum: press, release, motion
- [ ] `MouseButton` enum:
  - [ ] Basic buttons: none, left, middle, right
  - [ ] Wheel: wheelUp, wheelDown, wheelLeft, wheelRight
  - [ ] Extra: backward, forward, button(Int) for extras

#### Focus Messages
- [ ] `FocusMsg` struct
- [ ] `BlurMsg` struct

#### Screen Control Messages (Internal)
- [ ] Clear screen message
- [ ] Enter/exit alt screen messages
- [ ] Enable/disable mouse messages
- [ ] Show/hide cursor messages
- [ ] Enable/disable bracketed paste messages
- [ ] Enable/disable focus reporting messages
- [ ] Repaint message

### 4. Commands System

#### Basic Commands
- [ ] `batch(_ cmds: Command...) -> Command` - Run commands concurrently
- [ ] `sequence(_ cmds: Command...) -> Command` - Run commands in order
- [ ] `every(_ duration: Duration, _ fn: (Date) -> Message) -> Command` - Repeated timer
- [ ] `tick(_ duration: Duration, _ fn: (Date) -> Message) -> Command` - Single timer

#### Control Commands
- [ ] `quit() -> Message` - Return QuitMsg
- [ ] `suspend() -> Message` - Return SuspendMsg
- [ ] `interrupt() -> Message` - Return InterruptMsg

#### Window Commands
- [ ] `setWindowTitle(_ title: String) -> Command` - Set terminal title
- [ ] `windowSize() -> Command` - Get current size

#### Screen Commands
- [ ] `clearScreen() -> Message`
- [ ] `enterAltScreen() -> Message`
- [ ] `exitAltScreen() -> Message`

#### Mouse Commands
- [ ] `enableMouseCellMotion() -> Message`
- [ ] `enableMouseAllMotion() -> Message`
- [ ] `disableMouse() -> Message`

#### Cursor Commands
- [ ] `hideCursor() -> Message`
- [ ] `showCursor() -> Message`

#### Paste Commands
- [ ] `enableBracketedPaste() -> Message`
- [ ] `disableBracketedPaste() -> Message`

#### Focus Commands
- [ ] `enableReportFocus() -> Message`
- [ ] `disableReportFocus() -> Message`

#### Print Commands
- [ ] `println(_ args: Any...) -> Command`
- [ ] `printf(_ format: String, _ args: Any...) -> Command`

#### Scroll Commands (High-Performance)
- [ ] `syncScrollArea(lines: [String], topBoundary: Int, bottomBoundary: Int) -> Command`
- [ ] `clearScrollArea() -> Message`
- [ ] `scrollUp(newLines: [String], topBoundary: Int, bottomBoundary: Int) -> Command`
- [ ] `scrollDown(newLines: [String], topBoundary: Int, bottomBoundary: Int) -> Command`

### 5. Exec System

- [ ] Define `ExecCommand` protocol with:
  - [ ] `run() async throws`
  - [ ] `setStdin(_ reader: AsyncSequence<UInt8>)`
  - [ ] `setStdout(_ writer: TextOutputStream)`
  - [ ] `setStderr(_ writer: TextOutputStream)`
- [ ] `exec(_ command: ExecCommand, _ callback: (Error?) -> Message) -> Command`
- [ ] `execProcess(_ process: Process, _ callback: (Error?) -> Message) -> Command`
- [ ] Process wrapper implementation
- [ ] Exec message type

### 6. Renderer System

#### Renderer Protocol
- [ ] Define `Renderer` protocol with all required methods:
  - [ ] `start()` - Start renderer
  - [ ] `stop()` - Stop renderer
  - [ ] `kill()` - Force kill
  - [ ] `write(_ content: String)` - Queue content
  - [ ] `repaint()` - Force repaint
  - [ ] `clearScreen()` - Clear screen
  - [ ] `altScreen() -> Bool` - Alt screen state
  - [ ] `enterAltScreen()` - Enter alt screen
  - [ ] `exitAltScreen()` - Exit alt screen
  - [ ] `showCursor()` - Show cursor
  - [ ] `hideCursor()` - Hide cursor
  - [ ] `enableMouseCellMotion()` - Cell mouse mode
  - [ ] `disableMouseCellMotion()` - Disable cell mouse
  - [ ] `enableMouseAllMotion()` - All mouse mode
  - [ ] `disableMouseAllMotion()` - Disable all mouse
  - [ ] `enableMouseSGRMode()` - SGR mouse protocol
  - [ ] `disableMouseSGRMode()` - Disable SGR mouse
  - [ ] `enableBracketedPaste()` - Bracketed paste mode
  - [ ] `disableBracketedPaste()` - Disable bracketed paste
  - [ ] `bracketedPasteActive() -> Bool` - Check paste state
  - [ ] `setWindowTitle(_ title: String)` - Set window title
  - [ ] `reportFocus() -> Bool` - Focus reporting state
  - [ ] `enableReportFocus()` - Enable focus reports
  - [ ] `disableReportFocus()` - Disable focus reports
  - [ ] `resetLinesRendered()` - Reset line counter

#### Standard Renderer Implementation
- [ ] Frame-based rendering with configurable FPS
- [ ] Render timer/ticker implementation
- [ ] Buffer management (current buffer + flush queue)
- [ ] Line tracking for optimization
- [ ] Diff algorithm for line-by-line updates
- [ ] ANSI sequence generation
- [ ] Terminal size tracking
- [ ] Render mutex/synchronization
- [ ] Message queue handling
- [ ] Ignored lines functionality
- [ ] Scroll region support
- [ ] Full/partial screen repainting

#### Nil Renderer Implementation
- [ ] Complete no-op renderer for testing
- [ ] All protocol methods returning appropriate defaults

### 7. Input System

#### ANSI Parser
- [ ] Create `ANSIParser` class with:
  - [ ] UTF-8 decoding support
  - [ ] Multi-byte sequence handling
  - [ ] Escape sequence detection
  - [ ] CSI sequence parsing
  - [ ] OSC sequence parsing
  - [ ] DCS sequence parsing

#### Key Input Processing
- [ ] `readAnsiInputs()` async sequence implementation
- [ ] `detectOneMsg()` parser function
- [ ] `detectSequence()` for escape sequences
- [ ] `detectBracketedPaste()` for paste mode
- [ ] `detectReportFocus()` for focus events
- [ ] Key sequence mapping tables:
  - [ ] Standard sequences map
  - [ ] Extended sequences map
  - [ ] Special key mappings
- [ ] UTF-8 rune assembly
- [ ] Alt modifier detection
- [ ] Control character handling

#### Mouse Input Processing
- [ ] X10 mouse protocol parser
- [ ] SGR mouse protocol parser
- [ ] Mouse coordinate normalization (1-based to 0-based)
- [ ] Button state tracking
- [ ] Modifier key detection
- [ ] Motion event handling

### 8. Terminal Control

#### TTY Management
- [ ] Platform-specific TTY handling:
  - [ ] macOS: `/dev/tty` support
  - [ ] Linux: `/dev/tty` support
  - [ ] Windows: `CONIN$`/`CONOUT$` support
- [ ] Terminal state save/restore
- [ ] Raw mode implementation:
  - [ ] termios configuration (Unix)
  - [ ] Console mode (Windows)
- [ ] Non-blocking I/O setup
- [ ] Terminal capability detection

#### Signal Handling
- [ ] Unix signal handling:
  - [ ] SIGWINCH for window resize
  - [ ] SIGINT for interrupt
  - [ ] SIGTERM for termination
  - [ ] SIGTSTP for suspend
  - [ ] SIGCONT for resume
- [ ] Windows console events:
  - [ ] Window buffer size events
  - [ ] Ctrl+C handling

### 9. Platform-Specific Features

#### macOS/Unix Features
- [ ] termios-based raw mode
- [ ] TTY device handling
- [ ] Signal handling implementation
- [ ] File descriptor management
- [ ] Non-canonical mode setup

#### Linux-Specific Features
- [ ] Linux console compatibility
- [ ] Different terminal emulator support
- [ ] /proc/self/fd handling

#### Windows Features
- [ ] Console API usage
- [ ] VT processing mode
- [ ] Console input/output handles
- [ ] Windows-specific key codes
- [ ] No SIGWINCH (polling required)

### 10. Utility Features

#### Logging System
- [ ] `logToFile(path: String, prefix: String) -> FileHandle`
- [ ] `logToFileWith(path: String, prefix: String, options: LogOptions) -> FileHandle`
- [ ] Log options configuration
- [ ] Thread-safe logging
- [ ] Debug vs production logging

#### Error Types
- [ ] `ProgramPanicError` - For panic recovery
- [ ] `ProgramKilledError` - For force termination
- [ ] `InterruptedError` - For interrupts
- [ ] Platform-specific error types

### 11. Advanced Features

#### Focus Management
- [ ] Focus state tracking
- [ ] Focus/blur message generation
- [ ] Multi-window focus handling

#### Bracketed Paste
- [ ] Paste mode detection
- [ ] Multi-line paste handling
- [ ] Paste event generation

#### Alternate Screen
- [ ] Alt screen buffer management
- [ ] State preservation on switch
- [ ] Automatic cleanup on exit

#### Performance Optimizations
- [ ] Render coalescing
- [ ] Update batching
- [ ] Minimal redraws
- [ ] Buffer pooling

### 12. Example Implementations

Create Swift ports of key examples:
- [ ] Simple counter (tutorials/basics)
- [ ] Command tutorial (tutorials/commands)
- [ ] Alt screen toggle example
- [ ] Mouse tracking example
- [ ] Exec/external command example
- [ ] Send message from outside example
- [ ] Prevent quit with filter example
- [ ] Full screen example
- [ ] Split panes example
- [ ] Real-time updates example
- [ ] Progress bar example
- [ ] Text input example
- [ ] List/menu example
- [ ] Table example
- [ ] File picker example
- [ ] HTTP request example

### 13. Testing Infrastructure

- [ ] Unit tests for all components
- [ ] Integration tests for full programs
- [ ] Mock terminal for testing
- [ ] Golden file testing support
- [ ] Performance benchmarks
- [ ] Cross-platform CI/CD

### 14. Documentation

- [ ] API documentation for all public types
- [ ] Migration guide from Bubble Tea
- [ ] Tutorial series
- [ ] Example collection
- [ ] Architecture documentation
- [ ] Contributing guidelines

### 15. Component Library (Bubbles Port)

Essential components to port:
- [ ] Text input with cursor
- [ ] Text area (multi-line input)
- [ ] List/menu component
- [ ] Table with scrolling
- [ ] Progress bar
- [ ] Spinner
- [ ] Viewport (scrollable area)
- [ ] Paginator
- [ ] Help view
- [ ] Key binding system
- [ ] Tabs component
- [ ] Timer/stopwatch
- [ ] File browser
- [ ] Confirmation dialog

### 16. Integration Features

- [ ] Lip Gloss style system integration
- [ ] Harmonica animation support
- [ ] BubbleZone mouse region tracking
- [ ] Wish SSH server support
- [ ] Glow markdown rendering

## Technical Considerations

### Dependencies
- **Swift 5.9+**: For modern concurrency features
- **Foundation**: Basic I/O and system APIs
- **Darwin/Glibc**: Platform-specific terminal control
- **swift-argument-parser**: For example apps
- **XCTest**: Testing framework

### Performance Goals
- 60 FPS rendering with <5% CPU usage
- <10MB memory footprint for typical apps
- Instant keyboard response (<16ms latency)
- Efficient diff algorithm for large views

### Compatibility
- Full API documentation with Bubble Tea comparison
- Migration guide for Go developers
- Conceptual compatibility over literal translation

## Open Questions

1. **Package Structure**: Single package or split (core, components, styling)?
2. **Async Design**: How deep should async/await integration go?
3. **Property Wrappers**: Use for state management helpers?
4. **SwiftUI Inspiration**: How much to borrow from SwiftUI patterns?
5. **Color System**: Built-in color support or separate package?

## Success Criteria

1. **Feature Parity**: Cover 90% of Bubble Tea's features
2. **Performance**: Match or exceed Bubble Tea's performance
3. **Adoption**: 100+ GitHub stars in first 6 months
4. **Examples**: 20+ example applications
5. **Documentation**: Comprehensive guides and API docs
6. **Community**: Active Discord/Slack channel

## Conclusion

Matcha will bring the joy of building TUIs with The Elm Architecture to the Swift ecosystem. By embracing Swift's strengths while maintaining the elegant simplicity of Bubble Tea, we can create a framework that's both powerful and delightful to use.