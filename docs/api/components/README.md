# MatchaBubbles Components

MatchaBubbles provides a rich set of pre-built components for common TUI patterns. Each component is designed to be composable, customizable, and easy to integrate into your Matcha applications.

## Available Components

### Input Components

#### [TextInput](text-input.md)
Single-line text input with cursor, placeholder, and validation support.

```swift
var input = TextInput()
input.placeholder = "Enter your name..."
input.focus()
```

#### TextArea *(Coming Soon)*
Multi-line text editor with word wrap and scrolling.

### Display Components

#### [List](list.md)
Scrollable list with selection, filtering, and custom item rendering.

```swift
var list = List(items: ["Apple", "Banana", "Cherry"])
list.style.selectedStyle = Style().foreground(.cyan).bold()
```

#### [Table](table.md)
Data table with columns, sorting, and cell formatting.

```swift
let table = Table(
    columns: [.init(title: "Name", width: 20), .init(title: "Age", width: 10)],
    rows: [["Alice", "30"], ["Bob", "25"]]
)
```

#### [Viewport](viewport.md)
Scrollable view for content larger than the terminal.

```swift
var viewport = Viewport(width: 80, height: 20)
viewport.setContent(longText)
viewport.scrollPercent = 0.5
```

### Progress & Loading

#### [Progress](progress.md)
Progress bars with multiple styles and animations.

```swift
var progress = Progress()
progress.percent = 0.75
progress.width = 40
progress.style = .dots
```

#### [Spinner](spinner.md)
Animated loading indicators with various styles.

```swift
var spinner = Spinner()
spinner.style = .dots
spinner.start()
```

### Navigation

#### [Paginator](paginator.md)
Page navigation for multi-page content.

```swift
var paginator = Paginator()
paginator.totalPages = 10
paginator.currentPage = 3
```

#### Tabs *(Coming Soon)*
Tab navigation for organizing content into sections.

### Utilities

#### [Help](help.md)
Formatted help text showing keybindings.

```swift
let help = Help(bindings: [
    ("j/↓", "Move down"),
    ("k/↑", "Move up"),
    ("q", "Quit")
])
```

#### [Timer](timer.md)
Countdown and elapsed time display.

```swift
let timer = Timer()
timer.start()
// or
timer.countdown(from: .minutes(5))
```

#### [Sparkline](sparkline.md)
Mini line charts for data visualization.

```swift
let sparkline = Sparkline(data: [1, 5, 3, 8, 2, 9, 4])
sparkline.width = 20
```

### Dialogs

#### Confirmation *(Coming Soon)*
Yes/No confirmation dialogs.

#### FileBrowser *(Coming Soon)*
File system navigation and selection.

## Using Components in Your Model

Components are typically stored as properties in your model:

```swift
struct MyModel: Model {
    var nameInput = TextInput()
    var itemList = List(items: loadItems())
    var loading = Spinner()
    
    enum Message: Matcha.Message {
        case nameInputMsg(TextInput.Message)
        case listMsg(List.Message)
        case spinnerMsg(Spinner.Message)
    }
}
```

## Updating Components

Forward messages to components in your update function:

```swift
func update(_ message: Message) -> (MyModel, Command<Message>?) {
    var model = self
    
    switch message {
    case .nameInputMsg(let msg):
        let (newInput, cmd) = model.nameInput.update(msg)
        model.nameInput = newInput
        return (model, cmd?.map { .nameInputMsg($0) })
        
    case .listMsg(let msg):
        let (newList, cmd) = model.itemList.update(msg)
        model.itemList = newList
        return (model, cmd?.map { .listMsg($0) })
    }
}
```

## Rendering Components

Include components in your view:

```swift
func view() -> String {
    """
    Name: \(nameInput.view())
    
    Items:
    \(itemList.view())
    
    \(loading.view()) Loading...
    """
}
```

## Styling Components

Most components support customization through styles:

```swift
// TextInput styling
input.textStyle = Style().foreground(.white)
input.placeholderStyle = Style().foreground(.brightBlack)
input.cursorStyle = Style().foreground(.cyan).bold()

// List styling
list.style.normalStyle = Style()
list.style.selectedStyle = Style().background(.blue).foreground(.white)
list.style.matchedStyle = Style().foreground(.yellow).bold()

// Table styling
table.style.headerStyle = Style().bold().underline()
table.style.selectedStyle = Style().background(.blue)
table.style.borderStyle = Style().foreground(.brightBlack)
```

## Creating Custom Components

Follow these patterns when creating your own components:

1. **Implement Component Protocol** (if applicable)
2. **Define Component-Specific Messages**
3. **Provide Update and View Methods**
4. **Support Styling Options**
5. **Handle Focus State** (for input components)

Example structure:

```swift
public struct MyComponent {
    public enum Message {
        case activate
        case deactivate
    }
    
    // State
    private var isActive = false
    
    // Styling
    public var activeStyle = Style().foreground(.green)
    public var inactiveStyle = Style().foreground(.red)
    
    public func update(_ msg: Message) -> (MyComponent, Command<Message>?) {
        var component = self
        switch msg {
        case .activate:
            component.isActive = true
        case .deactivate:
            component.isActive = false
        }
        return (component, nil)
    }
    
    public func view() -> String {
        let style = isActive ? activeStyle : inactiveStyle
        return style.render(isActive ? "● Active" : "○ Inactive")
    }
}
```

## Best Practices

1. **Composition Over Inheritance**: Build complex UIs by combining simple components
2. **Consistent Styling**: Use a common style palette across components
3. **Keyboard Navigation**: Ensure all interactive components support keyboard control
4. **Accessibility**: Consider screen reader users when designing components
5. **Performance**: Components should render efficiently even with large datasets

## Examples

For complete examples of components in action, see:
- [ListExample](https://github.com/yourusername/matcha/tree/main/Examples/ListExample)
- [TextInputExample](https://github.com/yourusername/matcha/tree/main/Examples/TextInputExample)
- [TableExample](https://github.com/yourusername/matcha/tree/main/Examples/TableExample)