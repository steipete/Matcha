# Migrating from Bubble Tea to Matcha

This guide helps developers familiar with Bubble Tea (Go) transition to Matcha (Swift).

## Core Concepts

The fundamental concepts remain the same:
- **The Elm Architecture**: Model, Update, View
- **Messages**: Events that trigger updates
- **Commands**: Side effects and async operations
- **Components**: Reusable UI elements

## Key Differences

### 1. Type System

**Bubble Tea (Go)**:
```go
type model struct {
    count int
}

type tickMsg time.Time

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tickMsg:
        m.count++
        return m, nil
    }
    return m, nil
}
```

**Matcha (Swift)**:
```swift
struct Model: Matcha.Model {
    var count: Int = 0
    
    enum Message: Matcha.Message {
        case tick(Date)
    }
    
    func update(_ message: Message) -> (Model, Command<Message>?) {
        var model = self
        switch message {
        case .tick:
            model.count += 1
            return (model, nil)
        }
    }
}
```

### 2. Commands

**Bubble Tea**:
```go
func tickEvery() tea.Cmd {
    return tea.Every(time.Second, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}
```

**Matcha**:
```swift
func tickEvery() -> Command<Message> {
    .tick(interval: .seconds(1)) { _ in .tick(Date()) }
}
```

### 3. Initialization

**Bubble Tea**:
```go
func (m model) Init() tea.Cmd {
    return tea.Batch(
        tea.EnterAltScreen,
        tickEvery(),
    )
}
```

**Matcha**:
```swift
func `init`() -> Command<Message>? {
    .batch([
        .enterAltScreen(),
        tickEvery()
    ])
}
```

### 4. Running the Program

**Bubble Tea**:
```go
p := tea.NewProgram(initialModel())
if _, err := p.Run(); err != nil {
    log.Fatal(err)
}
```

**Matcha**:
```swift
let program = Program(initialModel: Model())
try await program.run()
```

## Component Mapping

| Bubble Tea | Matcha | Notes |
|------------|---------|-------|
| `textinput` | `TextInput` | Same API, Swift naming |
| `list` | `List` | Item type is more flexible |
| `table` | `Table` | Uses Swift dictionaries |
| `progress` | `Progress` | Identical functionality |
| `spinner` | `Spinner` | Same styles available |
| `paginator` | `Paginator` | Same behavior |
| `viewport` | `Viewport` | Performance optimized |
| `filepicker` | `FileBrowser` | Enhanced with more features |
| `timer` | `Timer` | Swift Duration types |
| `stopwatch` | `Stopwatch` | Same functionality |
| `help` | `Help` | More flexible formatting |

## Swift-Specific Features

### 1. Strong Typing
```swift
// Messages are enums, preventing typos
enum Message {
    case increment
    case decrement
    case reset(to: Int)
}
```

### 2. Async/Await
```swift
// Commands can use async/await
func fetchData() -> Command<Message> {
    .run { send in
        let data = try await api.getData()
        await send(.dataReceived(data))
    }
}
```

### 3. Property Wrappers
```swift
// Components use builder pattern
let input = TextInput()
    .withPlaceholder("Enter name...")
    .withValue(currentValue)
    .withFocus(true)
```

### 4. Result Builders
```swift
// Future: SwiftUI-style view building
var body: some View {
    VStack {
        TextInput($name)
        Button("Submit") { submit() }
    }
}
```

## Common Patterns

### Message Handling

**Bubble Tea**:
```go
case tea.KeyMsg:
    switch msg.String() {
    case "ctrl+c", "q":
        return m, tea.Quit
    }
```

**Matcha**:
```swift
case .key(let key):
    switch key.type {
    case .ctrlC, .runes where key.runes.first == "q":
        return (model, .quit())
    }
```

### Batching Commands

**Bubble Tea**:
```go
return m, tea.Batch(cmd1, cmd2, cmd3)
```

**Matcha**:
```swift
return (model, .batch([cmd1, cmd2, cmd3]))
```

### Window Size

**Bubble Tea**:
```go
case tea.WindowSizeMsg:
    m.width = msg.Width
    m.height = msg.Height
```

**Matcha**:
```swift
case .windowSize(let size):
    model.width = size.width
    model.height = size.height
```

## Performance Considerations

Matcha often performs better than Bubble Tea due to:
- Swift's value types and copy-on-write
- Efficient string handling
- Compile-time optimizations

However, be aware of:
- Swift's ARC vs Go's GC
- Different async models
- Platform-specific optimizations

## Debugging

### Logging
```swift
// Use debug renderer
var options = ProgramOptions()
options.renderer = DebugRenderer()

// Or add debug prints
func update(_ message: Message) -> (Model, Command<Message>?) {
    debugPrint("Received: \(message)")
    // ...
}
```

### Testing
```swift
// Matcha has built-in test utilities
let tester = ProgramTester(model: Model())
try await tester.send(.increment)
#expect(tester.model.count == 1)
```

## Resources

- [Matcha Examples](../Examples/) - Ports of Bubble Tea examples
- [API Documentation](./API.md) - Complete API reference
- [Component Guide](./components.md) - Using built-in components
- [Bubble Tea Docs](https://github.com/charmbracelet/bubbletea) - Original documentation

## Getting Help

- **Familiar with Bubble Tea?** The concepts translate directly
- **New to both?** Start with the [Getting Started](./getting-started.md) guide
- **Specific questions?** Check the [FAQ](./FAQ.md) or open an issue

Remember: If you know Bubble Tea, you already know 90% of Matcha!