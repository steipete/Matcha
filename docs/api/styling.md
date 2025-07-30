# Styling with MatchaStyle

MatchaStyle provides a powerful, composable styling system for terminal user interfaces, inspired by Lip Gloss.

## Basic Styling

Create and apply styles to text:

```swift
import MatchaStyle

// Create a style
let titleStyle = Style()
    .foreground(.cyan)
    .background(.black)
    .bold()
    .underline()

// Apply to text
let styledText = titleStyle.render("Welcome to Matcha!")
```

## Style Properties

### Colors

#### Foreground Color
```swift
style.foreground(.red)
style.foreground(.brightCyan)
style.foreground(Color(r: 255, g: 128, b: 0))  // RGB
style.foreground(Color(hex: "#FF8000"))        // Hex
```

#### Background Color
```swift
style.background(.blue)
style.background(.brightWhite)
style.background(Color(gray: 128))             // Grayscale
```

### Text Decoration

```swift
style.bold()                    // Bold text
style.italic()                  // Italic text
style.underline()              // Underlined text
style.strikethrough()          // Strikethrough text
style.reverse()                // Reverse video
style.blink()                  // Blinking text
style.faint()                  // Dimmed text
```

### Borders

```swift
// Simple border
style.border(.rounded)

// Custom border
style.border(.custom(
    top: "─", bottom: "─",
    left: "│", right: "│",
    topLeft: "╭", topRight: "╮",
    bottomLeft: "╰", bottomRight: "╯"
))

// Border styling
style
    .border(.double)
    .borderColor(.cyan)
    .borderTop(true)
    .borderBottom(true)
    .borderLeft(false)
    .borderRight(false)
```

### Spacing

```swift
// Padding
style
    .padding(2)                      // All sides
    .paddingTop(1)
    .paddingBottom(1)
    .paddingLeft(4)
    .paddingRight(4)

// Margin
style
    .margin(1)                       // All sides
    .marginTop(2)
    .marginBottom(2)
```

### Dimensions

```swift
style
    .width(40)                       // Fixed width
    .height(10)                      // Fixed height
    .maxWidth(80)                    // Maximum width
    .maxHeight(24)                   // Maximum height
```

### Alignment

```swift
style
    .align(.center)                  // Horizontal alignment
    .alignVertical(.middle)          // Vertical alignment
```

## Color System

### Basic Colors
```swift
.black, .red, .green, .yellow, .blue, .magenta, .cyan, .white
.brightBlack, .brightRed, .brightGreen, .brightYellow, 
.brightBlue, .brightMagenta, .brightCyan, .brightWhite
```

### Creating Colors
```swift
// RGB
let orange = Color(r: 255, g: 165, b: 0)

// Hex
let purple = Color(hex: "#9B59B6")

// Grayscale (0-255)
let gray = Color(gray: 128)

// Adaptive colors (light/dark mode)
let adaptive = AdaptiveColor(
    light: Color(hex: "#000000"),
    dark: Color(hex: "#FFFFFF")
)
```

## Composing Styles

### Combining Styles
```swift
let baseStyle = Style().foreground(.white)
let errorStyle = baseStyle.background(.red).bold()
let warningStyle = baseStyle.background(.yellow)
let successStyle = baseStyle.background(.green)
```

### Style Inheritance
```swift
// Create a base style
let baseButton = Style()
    .padding(1, 3)  // vertical, horizontal
    .border(.rounded)

// Extend for specific buttons
let primaryButton = baseButton
    .foreground(.white)
    .background(.blue)

let secondaryButton = baseButton
    .foreground(.blue)
    .borderColor(.blue)
```

## Practical Examples

### Status Messages
```swift
enum Status {
    case success(String)
    case warning(String)
    case error(String)
    
    var styled: String {
        switch self {
        case .success(let msg):
            return Style()
                .foreground(.green)
                .bold()
                .render("✓ \(msg)")
                
        case .warning(let msg):
            return Style()
                .foreground(.yellow)
                .render("⚠ \(msg)")
                
        case .error(let msg):
            return Style()
                .foreground(.white)
                .background(.red)
                .padding(0, 1)
                .render("✗ \(msg)")
        }
    }
}
```

### Table Styling
```swift
let headerStyle = Style()
    .bold()
    .underline()
    .foreground(.cyan)

let selectedStyle = Style()
    .background(.blue)
    .foreground(.white)

let borderStyle = Style()
    .foreground(.brightBlack)
```

### Progress Bar
```swift
let progressStyle = Style()
    .foreground(.green)
    .background(.brightBlack)

let percentage = 0.75
let width = 30
let filled = Int(Double(width) * percentage)
let empty = width - filled

let bar = progressStyle.render(
    String(repeating: "█", count: filled) +
    String(repeating: "░", count: empty)
)
```

### Layout Components
```swift
// Card component
func card(title: String, content: String) -> String {
    let cardStyle = Style()
        .border(.rounded)
        .borderColor(.cyan)
        .padding(1)
        .width(40)
    
    let titleStyle = Style()
        .bold()
        .foreground(.cyan)
        .align(.center)
        .width(38)  // Account for padding
    
    let card = """
    \(titleStyle.render(title))
    
    \(content)
    """
    
    return cardStyle.render(card)
}
```

## Performance Tips

1. **Reuse Styles**: Create styles once and reuse them
```swift
struct Styles {
    static let title = Style().bold().foreground(.cyan)
    static let subtitle = Style().italic().foreground(.blue)
    static let body = Style()
}
```

2. **Conditional Styling**: Apply styles conditionally
```swift
let itemStyle = isSelected 
    ? Style().background(.blue).foreground(.white)
    : Style()
```

3. **Avoid Excessive Nesting**: Deeply nested styles can impact performance
```swift
// Good
let style = Style().padding(2).border(.rounded)

// Avoid
let style = Style().padding(1).padding(1).padding(0)
```

## Advanced Techniques

### Gradient Effects
```swift
func gradient(text: String, colors: [Color]) -> String {
    let chars = Array(text)
    let step = chars.count / colors.count
    var result = ""
    
    for (index, char) in chars.enumerated() {
        let colorIndex = min(index / step, colors.count - 1)
        result += Style()
            .foreground(colors[colorIndex])
            .render(String(char))
    }
    
    return result
}
```

### Animation Helpers
```swift
func pulse(text: String, phase: Int) -> String {
    let colors: [Color] = [.red, .brightRed, .white, .brightRed]
    let colorIndex = phase % colors.count
    
    return Style()
        .foreground(colors[colorIndex])
        .bold()
        .render(text)
}
```

### Responsive Styling
```swift
func responsiveStyle(width: Int) -> Style {
    if width < 40 {
        // Compact style
        return Style().padding(0, 1)
    } else if width < 80 {
        // Normal style
        return Style().padding(1, 2)
    } else {
        // Spacious style
        return Style().padding(2, 4).margin(1)
    }
}
```

## Theme System

Create consistent themes:

```swift
struct Theme {
    let primary = Color(hex: "#007ACC")
    let secondary = Color(hex: "#68217A")
    let success = Color(hex: "#4CAF50")
    let warning = Color(hex: "#FF9800")
    let error = Color(hex: "#F44336")
    let text = Color(hex: "#FFFFFF")
    let textMuted = Color(hex: "#CCCCCC")
    let background = Color(hex: "#1E1E1E")
    
    var titleStyle: Style {
        Style()
            .foreground(primary)
            .bold()
            .underline()
    }
    
    var buttonStyle: Style {
        Style()
            .foreground(text)
            .background(primary)
            .padding(0, 2)
            .border(.rounded)
    }
}

let theme = Theme()
let title = theme.titleStyle.render("My App")
```