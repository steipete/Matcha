# Contributing to Matcha

Thank you for your interest in contributing to Matcha! We love contributions from the community and are grateful for any help you can provide.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Respect differing viewpoints and experiences

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

1. **Use a clear title** that describes the issue
2. **Describe the exact steps** to reproduce the problem
3. **Provide specific examples** with code snippets
4. **Describe the behavior** you observed and what you expected
5. **Include system information** (OS, Swift version, terminal emulator)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

1. **Use a clear title** that describes the enhancement
2. **Provide a detailed description** of the proposed functionality
3. **Explain why** this enhancement would be useful
4. **Include code examples** of how it might work

### Pull Requests

1. **Fork the repo** and create your branch from `main`
2. **Follow the style guide** (see below)
3. **Add tests** for any new functionality
4. **Update documentation** as needed
5. **Ensure all tests pass** with `swift test`
6. **Write a good commit message** (see below)

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/matcha.git
cd matcha

# Add upstream remote
git remote add upstream https://github.com/originalrepo/matcha.git

# Create a feature branch
git checkout -b feature/my-new-feature

# Build the project
swift build

# Run tests
swift test

# Run a specific example
swift run CounterExample
```

## Style Guide

### Swift Style

We follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) with these additions:

```swift
// MARK: - Section Headers
// Use MARK comments to organize code into logical sections

// Good: Descriptive names
func handleKeyboardInput(_ key: Key) -> Message

// Bad: Abbreviated names
func handleKbInput(_ k: Key) -> Message

// Good: Clear intent
extension Model {
    mutating func incrementCounter() {
        counter += 1
    }
}

// Bad: Unclear side effects
extension Model {
    func inc() -> Int {
        counter += 1  // Mutating in non-mutating function!
        return counter
    }
}
```

### Documentation

All public APIs must be documented:

```swift
/// A progress bar component for displaying task completion status.
///
/// The Progress component provides visual feedback for long-running operations,
/// with multiple display styles and customizable appearance.
///
/// Example:
/// ```swift
/// var progress = Progress()
/// progress.percent = 0.75
/// progress.width = 40
/// ```
public struct Progress {
    /// Current progress percentage (0.0 to 1.0)
    public var percent: Double = 0
}
```

### Testing

Write tests for all new functionality:

```swift
final class ComponentTests: XCTestCase {
    func testProgressBarRendering() {
        // Given
        var progress = Progress()
        progress.percent = 0.5
        progress.width = 10
        
        // When
        let rendered = progress.view()
        
        // Then
        XCTAssertEqual(rendered, "█████░░░░░")
    }
}
```

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
feat: add color gradient support to Progress component

- Add gradient property to Progress
- Support smooth color transitions
- Update documentation with examples

Closes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes

## Project Structure

```
Matcha/
├── Sources/
│   ├── Matcha/           # Core framework
│   ├── MatchaStyle/      # Styling system
│   └── MatchaBubbles/    # UI components
├── Tests/
│   ├── MatchaTests/
│   └── MatchaBubblesTests/
├── Examples/             # Example applications
├── docs/                 # Documentation
│   ├── api/             # API documentation
│   └── tutorials/       # Tutorial series
└── Package.swift
```

## Adding New Components

When adding a new component to MatchaBubbles:

1. **Create the component file** in `Sources/MatchaBubbles/`
2. **Follow the component pattern**:
   ```swift
   public struct MyComponent: Sendable {
       // State
       public var value: String = ""
       
       // Configuration
       public var style = Style()
       
       // Messages
       public enum Message {
           case update(String)
       }
       
       // Update
       public func update(_ msg: Message) -> (MyComponent, Command<Message>?) {
           var component = self
           // Handle message
           return (component, nil)
       }
       
       // View
       public func view() -> String {
           // Render component
       }
   }
   ```

3. **Add comprehensive tests**
4. **Create documentation** in `docs/api/components/`
5. **Add an example** to demonstrate usage

## Testing Guidelines

### Unit Tests
- Test individual functions and components
- Mock external dependencies
- Aim for >80% code coverage

### Integration Tests
- Test component interactions
- Use `ProgramTester` for full app testing
- Test error conditions

### Performance Tests
- Benchmark critical paths
- Test with large datasets
- Monitor memory usage

## Documentation

### Where to Document

1. **Inline Documentation**: All public APIs
2. **API Reference**: Detailed type documentation in `docs/api/reference/`
3. **Component Docs**: Usage guides in `docs/api/components/`
4. **Tutorials**: Step-by-step guides for complex features
5. **Examples**: Working code demonstrating features

### Documentation Style

- Start with a brief summary
- Provide context and use cases
- Include code examples
- Link to related documentation
- Keep it concise but complete

## Review Process

1. **Automated Checks**: All CI checks must pass
2. **Code Review**: At least one maintainer approval required
3. **Documentation Review**: Ensure docs are updated
4. **Testing**: New features must include tests

### What We Look For

- **Code Quality**: Clean, readable, maintainable code
- **Performance**: No regressions, efficient implementations
- **Compatibility**: Works on all supported platforms
- **Documentation**: Clear and helpful
- **Tests**: Comprehensive coverage

## Release Process

1. **Version Bump**: Follow semantic versioning
2. **Changelog**: Update CHANGELOG.md
3. **Documentation**: Ensure docs reflect changes
4. **Tag Release**: Create git tag
5. **Announce**: Post release notes

## Getting Help

- **Discord**: Join our community (coming soon)
- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Check existing issues before creating new ones

## Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project README

Thank you for contributing to Matcha! 🍵