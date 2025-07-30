# Model Protocol

The foundation of every Matcha application. Models encapsulate application state and define how it changes in response to messages.

## Declaration

```swift
public protocol Model: Sendable {
    associatedtype Msg: Message
    
    init()
    func `init`() -> Command<Msg>?
    func update(_ message: Msg) -> (Self, Command<Msg>?)
    func view() -> String
}
```

## Overview

The Model protocol follows The Elm Architecture pattern, providing a clean separation between:
- **State** (stored properties)
- **Logic** (update function)
- **Presentation** (view function)

## Requirements

### Associated Types

#### `Msg`
The message type that this model can handle. Must conform to the `Message` protocol.

```swift
enum MyMessage: Message {
    case increment
    case decrement
    case reset
}
```

### Required Methods

#### `init()`
Standard Swift initializer for creating the model with default values.

```swift
init() {
    self.count = 0
    self.items = []
}
```

#### `init() -> Command<Msg>?`
Called after initialization to return any startup commands. Note the backticks around `init` to distinguish it from the standard initializer.

```swift
func `init`() -> Command<Msg>? {
    // Load data on startup
    return Command {
        let data = try await loadData()
        return .dataLoaded(data)
    }
}
```

Common patterns:
- Return `nil` if no startup commands needed
- Start timers with `every()`
- Load initial data
- Set up subscriptions

#### `update(_ message: Msg) -> (Self, Command<Msg>?)`
The core update function that handles state transitions.

Rules:
1. **Pure Function**: Given the same model and message, always return the same result
2. **Immutable Updates**: Return a new model, don't mutate `self`
3. **Explicit Effects**: All side effects go through commands

```swift
func update(_ message: Msg) -> (Self, Command<Msg>?) {
    var model = self  // Create mutable copy
    
    switch message {
    case .increment:
        model.count += 1
        return (model, nil)
        
    case .save:
        return (model, saveToFile(model.data))
        
    case .refresh:
        return (model, .batch(
            clearCache(),
            fetchNewData()
        ))
    }
}
```

#### `view() -> String`
Renders the current model state as a string for terminal display.

```swift
func view() -> String {
    """
    Count: \(count)
    Items: \(items.count)
    
    Press + to increment, - to decrement
    """
}
```

## Implementation Example

Here's a complete example of a todo list model:

```swift
struct TodoModel: Model {
    // State
    var todos: [Todo] = []
    var filter: Filter = .all
    var input = TextInput()
    
    // Message type
    enum Message: Matcha.Message {
        case addTodo
        case toggleTodo(id: UUID)
        case deleteTodo(id: UUID)
        case setFilter(Filter)
        case inputMsg(TextInput.Message)
        case load([Todo])
        case save
        case tick
    }
    
    enum Filter {
        case all, active, completed
    }
    
    struct Todo: Identifiable {
        let id = UUID()
        var text: String
        var completed = false
    }
    
    // Initialization
    init() {
        input.placeholder = "What needs to be done?"
    }
    
    // Startup commands
    func `init`() -> Command<Message>? {
        .batch(
            // Load saved todos
            Command {
                let todos = try await loadTodos()
                return .load(todos)
            },
            // Auto-save every 30 seconds
            every(.seconds(30)) { _ in .save }
        )
    }
    
    // Update logic
    func update(_ message: Message) -> (TodoModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .addTodo:
            guard !model.input.value.isEmpty else {
                return (model, nil)
            }
            
            let todo = Todo(text: model.input.value)
            model.todos.append(todo)
            model.input.reset()
            
            return (model, Command { .save })
            
        case .toggleTodo(let id):
            if let index = model.todos.firstIndex(where: { $0.id == id }) {
                model.todos[index].completed.toggle()
            }
            return (model, nil)
            
        case .deleteTodo(let id):
            model.todos.removeAll { $0.id == id }
            return (model, nil)
            
        case .setFilter(let filter):
            model.filter = filter
            return (model, nil)
            
        case .inputMsg(let msg):
            let (newInput, cmd) = model.input.update(msg)
            model.input = newInput
            return (model, cmd?.map { .inputMsg($0) })
            
        case .load(let todos):
            model.todos = todos
            return (model, nil)
            
        case .save:
            return (model, saveTodos(model.todos))
            
        case .tick:
            // Could update relative times, etc.
            return (model, nil)
        }
    }
    
    // View rendering
    func view() -> String {
        let filteredTodos = todos.filter { todo in
            switch filter {
            case .all: return true
            case .active: return !todo.completed
            case .completed: return todo.completed
            }
        }
        
        return """
        TODO LIST
        ═════════
        
        \(input.view())
        
        \(renderTodos(filteredTodos))
        
        [\(renderFilter())] \(todos.count) items
        """
    }
}
```

## Best Practices

### 1. Keep Models Focused
Break large models into sub-models:

```swift
struct AppModel: Model {
    var header: HeaderModel
    var sidebar: SidebarModel
    var content: ContentModel
}
```

### 2. Message Design
Design messages to represent user intent:

```swift
// Good
case selectItem(id: String)
case search(query: String)

// Avoid
case setSelectedIndex(Int)
case updateSearchText(String)
```

### 3. Pure Updates
Keep update functions pure and predictable:

```swift
// Good
case .refresh:
    model.isLoading = true
    return (model, fetchData())

// Avoid
case .refresh:
    Task { await self.loadData() }  // Don't do this!
    return (model, nil)
```

### 4. Command Composition
Use command batching for complex operations:

```swift
case .submit:
    return (model, .batch(
        validateForm(model.form),
        submitToServer(model.form),
        showNotification("Submitted!")
    ))
```

## Common Patterns

### Loading States
```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

var dataState: LoadingState<[Item]> = .idle
```

### Form Handling
```swift
struct FormModel: Model {
    var fields: [String: String] = [:]
    var errors: [String: String] = [:]
    var isSubmitting = false
}
```

### Navigation
```swift
enum Screen {
    case list
    case detail(id: String)
    case settings
}

var currentScreen: Screen = .list
```

## Testing

Models are highly testable due to their pure nature:

```swift
func testIncrement() {
    var model = CounterModel()
    let (newModel, cmd) = model.update(.increment)
    XCTAssertEqual(newModel.count, 1)
    XCTAssertNil(cmd)
}
```

## Performance Considerations

1. **Efficient View Rendering**: Avoid expensive computations in `view()`
2. **Lazy Updates**: Only update what changed
3. **Command Debouncing**: Batch rapid updates
4. **Memory Management**: Clean up resources in commands

## See Also

- [Message Protocol](message.md)
- [Command Type](command.md)
- [Program Type](program.md)