# Getting Started with Matcha

This guide will walk you through building your first terminal user interface with Matcha.

## Installation

Add Matcha to your Swift package dependencies:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/yourusername/matcha", from: "1.0.0")
]
```

## Your First Matcha App

Let's build a simple todo list application to understand the core concepts.

### Step 1: Define Your Model

```swift
import Matcha
import MatchaStyle

struct TodoModel: Model {
    // Your app's state
    var todos: [String] = ["Learn Matcha", "Build awesome TUIs"]
    var selectedIndex: Int = 0
    var inputMode: Bool = false
    var newTodoText: String = ""
    
    // Messages your app can handle
    enum Message: Matcha.Message {
        case moveUp
        case moveDown
        case toggleComplete
        case enterInputMode
        case exitInputMode
        case updateInput(String)
        case addTodo
        case deleteTodo
        case quit
    }
    
    init() {}
    
    // Initial commands when app starts
    func `init`() -> Command<Message>? {
        nil
    }
}
```

### Step 2: Implement Update Logic

```swift
extension TodoModel {
    func update(_ message: Message) -> (TodoModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .moveUp:
            if model.selectedIndex > 0 {
                model.selectedIndex -= 1
            }
            
        case .moveDown:
            if model.selectedIndex < model.todos.count - 1 {
                model.selectedIndex += 1
            }
            
        case .enterInputMode:
            model.inputMode = true
            model.newTodoText = ""
            
        case .exitInputMode:
            model.inputMode = false
            model.newTodoText = ""
            
        case .updateInput(let text):
            model.newTodoText = text
            
        case .addTodo:
            if !model.newTodoText.isEmpty {
                model.todos.append(model.newTodoText)
                model.newTodoText = ""
                model.inputMode = false
            }
            
        case .deleteTodo:
            if !model.todos.isEmpty {
                model.todos.remove(at: model.selectedIndex)
                if model.selectedIndex >= model.todos.count && model.selectedIndex > 0 {
                    model.selectedIndex -= 1
                }
            }
            
        case .toggleComplete:
            // In a real app, todos would have a completed state
            break
            
        case .quit:
            return (model, quit())
        }
        
        return (model, nil)
    }
}
```

### Step 3: Create the View

```swift
extension TodoModel {
    func view() -> String {
        var output = Style().bold().render("📝 My Todo List\n\n")
        
        // Show todos
        for (index, todo) in todos.enumerated() {
            let prefix = index == selectedIndex ? "▶ " : "  "
            let style = index == selectedIndex ? Style().foreground(.cyan) : Style()
            output += style.render("\(prefix)\(todo)\n")
        }
        
        if todos.isEmpty {
            output += Style().faint().render("  (no todos yet)\n")
        }
        
        output += "\n"
        
        // Input mode
        if inputMode {
            output += "New todo: \(newTodoText)_\n\n"
            output += Style().faint().render("Enter to save, Esc to cancel")
        } else {
            // Controls
            output += Style().faint().render("""
            j/↓: down  k/↑: up  a: add  d: delete  q: quit
            """)
        }
        
        return output
    }
}
```

### Step 4: Handle Input

```swift
@main
struct TodoApp {
    static func main() async throws {
        var options = ProgramOptions.default
        
        // Configure input handling
        options.filter = { model, message in
            // Handle text input mode
            if model.inputMode {
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return TodoModel.Message.addTodo
                    case .escape:
                        return TodoModel.Message.exitInputMode
                    case .character(let char):
                        return TodoModel.Message.updateInput(
                            model.newTodoText + String(char)
                        )
                    case .backspace:
                        let text = model.newTodoText
                        if !text.isEmpty {
                            return TodoModel.Message.updateInput(
                                String(text.dropLast())
                            )
                        }
                    default:
                        break
                    }
                }
                return message
            }
            
            // Normal mode key handling
            if let key = message as? Key {
                switch key.description {
                case "j", "down":
                    return TodoModel.Message.moveDown
                case "k", "up":
                    return TodoModel.Message.moveUp
                case "a":
                    return TodoModel.Message.enterInputMode
                case "d":
                    return TodoModel.Message.deleteTodo
                case "q", "ctrl+c":
                    return QuitMsg()
                default:
                    break
                }
            }
            
            return message
        }
        
        let program = Program(
            initialModel: TodoModel(),
            options: options
        )
        
        try await program.run()
    }
}
```

## Key Concepts Explained

### The Model Protocol
Your model must conform to the `Model` protocol:
- Store all application state
- Define message types
- Implement `init()` for startup commands
- Implement `update()` for state transitions
- Implement `view()` for rendering

### Messages
Messages represent all possible events:
- User input (keyboard, mouse)
- Timer events
- Network responses
- Custom application events

### Commands
Commands handle asynchronous operations:
- `quit()` - Exit the program
- `every(.seconds(1))` - Periodic timer
- `Command { ... }` - Custom async operations

### Program Options
Configure your app's behavior:
- `useAltScreen` - Use alternate screen buffer
- `mouseMode` - Enable mouse tracking
- `filter` - Transform messages before they reach your model

## Next Steps

1. **Explore Components**: Check out the built-in components in MatchaBubbles
2. **Add Styling**: Use MatchaStyle to make your app beautiful
3. **Handle Async**: Learn about commands for network requests and timers
4. **Study Examples**: Browse the Examples directory for more patterns

## Common Patterns

### Loading Data on Startup

```swift
func `init`() -> Command<Message>? {
    Command {
        let data = try await fetchData()
        return .dataLoaded(data)
    }
}
```

### Periodic Updates

```swift
func `init`() -> Command<Message>? {
    every(.seconds(1)) { _ in .tick }
}
```

### Combining Commands

```swift
return (model, .batch(
    saveToFile(model.data),
    showNotification("Saved!"),
    after(.seconds(2)) { .hideNotification }
))
```

## Tips

1. **Keep Models Immutable**: Always create new models in update
2. **Use Components**: Don't reinvent the wheel - use MatchaBubbles
3. **Handle Errors Gracefully**: Bubble Tea apps should never crash
4. **Test Your Logic**: Model updates are pure functions - easy to test!

Ready to build something amazing? Check out the [examples](https://github.com/yourusername/matcha/tree/main/Examples) for inspiration!