# Core Concepts

Matcha follows The Elm Architecture (TEA), a pattern for building applications with a clear separation of concerns and predictable state management.

## The Elm Architecture

The Elm Architecture consists of three main parts:

### 1. Model
Your application's state. Everything your app knows is stored here.

```swift
struct TodoModel: Model {
    var todos: [Todo] = []
    var input: String = ""
    var filter: Filter = .all
}
```

### 2. Update
A function that takes the current model and a message, returning a new model and optional commands.

```swift
func update(_ message: Message) -> (TodoModel, Command<Message>?) {
    var model = self
    switch message {
    case .addTodo:
        model.todos.append(Todo(text: model.input))
        model.input = ""
        return (model, nil)
    case .toggleTodo(let id):
        model.todos[id].completed.toggle()
        return (model, nil)
    }
}
```

### 3. View
A function that renders your model as a string for the terminal.

```swift
func view() -> String {
    var output = "TODO LIST\n\n"
    for (index, todo) in todos.enumerated() {
        let marker = todo.completed ? "✓" : "○"
        output += "\(marker) \(todo.text)\n"
    }
    return output
}
```

## Messages

Messages represent all possible events in your application:

```swift
enum Message: Matcha.Message {
    case keyPressed(Key)
    case tick
    case httpResponse(Data)
    case userAction(UserAction)
}
```

## Commands

Commands are asynchronous operations that produce messages:

```swift
// Timer that ticks every second
let tickCmd = every(.seconds(1)) { _ in .tick }

// HTTP request
let fetchCmd = Command<Message> { 
    let data = try await URLSession.shared.data(from: url).0
    return .httpResponse(data)
}

// Batch multiple commands
let batchCmd = Command.batch(tickCmd, fetchCmd)
```

## Program Lifecycle

1. **Initialization**: Create your initial model and setup commands
2. **Message Loop**: 
   - User input or command produces a message
   - Update function processes the message
   - New model is created
   - View renders the new state
3. **Termination**: Cleanup and restore terminal

```swift
@main
struct MyApp {
    static func main() async throws {
        let program = Program(
            initialModel: TodoModel(),
            options: .default
        )
        try await program.run()
    }
}
```

## Input Handling

Matcha provides comprehensive input handling:

### Keyboard Input
```swift
case .key(let key):
    switch key {
    case .character("q"):
        return (model, quit())
    case .up:
        model.selectedIndex -= 1
    case .down:
        model.selectedIndex += 1
    case .enter:
        model.confirmSelection()
    }
```

### Mouse Input
```swift
case .mouse(let event):
    switch event.type {
    case .click:
        model.handleClick(at: event.position)
    case .scroll(let direction):
        model.scroll(direction)
    }
```

## Window Management

Handle terminal resize events:

```swift
case .windowSize(let width, let height):
    model.width = width
    model.height = height
    model.recalculateLayout()
```

## Best Practices

1. **Keep Models Immutable**: Always create new models in update
2. **Pure Functions**: Update and view should be pure functions
3. **Single Source of Truth**: All state lives in the model
4. **Explicit Effects**: Use commands for all side effects
5. **Message Design**: Design messages to represent user intent, not implementation

## Advanced Patterns

### Sub-Models
Break complex models into smaller, focused sub-models:

```swift
struct AppModel: Model {
    var sidebar: SidebarModel
    var content: ContentModel
    var footer: FooterModel
}
```

### Message Mapping
Transform messages between parent and child models:

```swift
case .sidebar(let sidebarMsg):
    let (newSidebar, cmd) = model.sidebar.update(sidebarMsg)
    model.sidebar = newSidebar
    return (model, cmd?.map { .sidebar($0) })
```

### Middleware
Use program options to intercept and transform messages:

```swift
var options = ProgramOptions.default
options.filter = { model, message in
    // Log all messages
    print("Message: \(message)")
    
    // Transform quit keys
    if let key = message as? Key, key.description == "q" {
        return QuitMsg()
    }
    
    return message
}
```