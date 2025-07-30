# TextInput Component

A flexible single-line text input component with cursor management, validation, and comprehensive keyboard support.

## Basic Usage

```swift
import MatchaBubbles

var input = TextInput()
input.placeholder = "Enter your name..."
input.focus()

// In your view
let rendered = input.view()
```

## Features

- **Cursor Management**: Visible cursor with customizable style
- **Placeholder Text**: Shows when input is empty
- **Character Limit**: Optional maximum length
- **Text Masking**: For password inputs
- **Validation**: Built-in and custom validators
- **Keyboard Navigation**: Full cursor movement support
- **Clipboard Support**: Copy/paste functionality

## Properties

### Content Properties
```swift
var value: String                    // Current text value
var placeholder: String = ""         // Placeholder text
var characterLimit: Int = 0          // Max length (0 = unlimited)
var width: Int = 20                  // Display width
```

### Display Properties
```swift
var echoMode: EchoMode = .normal    // .normal, .password, or .none
var cursor: Character = "█"          // Cursor character
var showCursor: Bool = true         // Toggle cursor visibility
```

### Style Properties
```swift
var textStyle: Style                // Style for input text
var placeholderStyle: Style         // Style for placeholder
var cursorStyle: Style              // Style for cursor
var promptStyle: Style              // Style for prompt (if used)
```

## Methods

### Core Methods
```swift
func focus()                        // Give input focus
func blur()                         // Remove focus
func reset()                        // Clear the input
func setValue(_ text: String)       // Set value programmatically
```

### Cursor Control
```swift
func cursorStart()                  // Move to beginning
func cursorEnd()                    // Move to end
func setCursorPosition(_ pos: Int)  // Set specific position
```

### Validation
```swift
func validate() -> Bool             // Run validation
var validator: ((String) -> Bool)?  // Custom validation function
```

## Messages

TextInput defines its own message type for updates:

```swift
enum Message {
    case characterInput(Character)
    case backspace
    case delete
    case moveLeft
    case moveRight
    case moveWordLeft
    case moveWordRight
    case home
    case end
    case paste(String)
}
```

## Integration Example

Here's how to integrate TextInput into your model:

```swift
struct FormModel: Model {
    var nameInput = TextInput()
    var emailInput = TextInput()
    var passwordInput = TextInput()
    var focusedField: Field = .name
    
    enum Field {
        case name, email, password
    }
    
    enum Message: Matcha.Message {
        case nameInputMsg(TextInput.Message)
        case emailInputMsg(TextInput.Message)
        case passwordInputMsg(TextInput.Message)
        case tabPressed
        case submitted
    }
    
    init() {
        // Configure inputs
        nameInput.placeholder = "Full name"
        nameInput.width = 30
        nameInput.focus()
        
        emailInput.placeholder = "Email address"
        emailInput.width = 30
        emailInput.validator = { text in
            text.contains("@") && text.contains(".")
        }
        
        passwordInput.placeholder = "Password"
        passwordInput.width = 30
        passwordInput.echoMode = .password
    }
    
    func update(_ message: Message) -> (FormModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .nameInputMsg(let msg):
            let (newInput, cmd) = model.nameInput.update(msg)
            model.nameInput = newInput
            return (model, cmd?.map { .nameInputMsg($0) })
            
        case .emailInputMsg(let msg):
            let (newInput, cmd) = model.emailInput.update(msg)
            model.emailInput = newInput
            return (model, cmd?.map { .emailInputMsg($0) })
            
        case .passwordInputMsg(let msg):
            let (newInput, cmd) = model.passwordInput.update(msg)
            model.passwordInput = newInput
            return (model, cmd?.map { .passwordInputMsg($0) })
            
        case .tabPressed:
            // Cycle through fields
            switch model.focusedField {
            case .name:
                model.nameInput.blur()
                model.emailInput.focus()
                model.focusedField = .email
            case .email:
                model.emailInput.blur()
                model.passwordInput.focus()
                model.focusedField = .password
            case .password:
                model.passwordInput.blur()
                model.nameInput.focus()
                model.focusedField = .name
            }
            return (model, nil)
            
        case .submitted:
            // Validate all fields
            let isValid = model.emailInput.validate()
            // Handle submission...
            return (model, nil)
        }
    }
    
    func view() -> String {
        """
        User Registration
        ════════════════
        
        Name:     \(nameInput.view())
        Email:    \(emailInput.view())
        Password: \(passwordInput.view())
        
        Tab to switch fields, Enter to submit
        """
    }
}
```

## Advanced Usage

### Custom Validation

```swift
input.validator = { text in
    // Only allow alphanumeric characters
    text.allSatisfy { $0.isLetter || $0.isNumber }
}

// Check validation
if input.validate() {
    // Input is valid
}
```

### Password Input

```swift
var passwordInput = TextInput()
passwordInput.echoMode = .password
passwordInput.placeholder = "Enter password"
```

### Limiting Input Length

```swift
input.characterLimit = 10  // Max 10 characters
```

### Handling Special Keys

In your message filter:

```swift
options.filter = { model, message in
    if model.nameInput.focused, let key = message as? Key {
        switch key {
        case .character(let char):
            return FormModel.Message.nameInputMsg(.characterInput(char))
        case .backspace:
            return FormModel.Message.nameInputMsg(.backspace)
        case .left:
            return FormModel.Message.nameInputMsg(.moveLeft)
        case .right:
            return FormModel.Message.nameInputMsg(.moveRight)
        case .tab:
            return FormModel.Message.tabPressed
        default:
            break
        }
    }
    return message
}
```

## Styling

Customize the appearance:

```swift
// Modern style
input.textStyle = Style().foreground(.white)
input.placeholderStyle = Style().foreground(.brightBlack)
input.cursorStyle = Style().foreground(.cyan).blink()

// Minimal style
input.showCursor = false
input.textStyle = Style().underline()

// Error state
input.textStyle = input.validate() 
    ? Style().foreground(.green) 
    : Style().foreground(.red)
```

## Tips

1. **Focus Management**: Only one TextInput should be focused at a time
2. **Validation**: Run validation on blur or before form submission
3. **Placeholders**: Keep them short and descriptive
4. **Width**: Set appropriate width for expected content
5. **Accessibility**: Consider screen reader users with clear labels

## Common Patterns

### Search Input
```swift
var search = TextInput()
search.placeholder = "Search..."
search.width = 40
// Update results on each change
```

### Numeric Input
```swift
var ageInput = TextInput()
ageInput.placeholder = "Age"
ageInput.width = 5
ageInput.validator = { text in
    Int(text) != nil
}
```

### Masked Input
```swift
var phoneInput = TextInput()
phoneInput.placeholder = "(555) 555-5555"
phoneInput.characterLimit = 14
// Add formatting in update handler
```