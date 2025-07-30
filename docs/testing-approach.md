# Matcha Testing Approach

## Overview

Following extensive analysis of Bubbletea's testing patterns, Matcha has adopted a unit-testing focused approach that emphasizes correctness over visual appearance.

## Core Principles

1. **Test behavior, not appearance** - Focus on state management and logic
2. **Verify ANSI sequences** - Test the contract with the terminal, not the visual result
3. **Fast, isolated tests** - Unit tests that run in milliseconds
4. **No visual regression testing** - Trust that correct ANSI sequences produce correct output

## Test Categories

### 1. Component State Tests
Located in `Tests/MatchaTests/Components/`

- Test state management (cursor position, selection, input handling)
- Verify keyboard navigation
- Test builder patterns and configuration
- Example: `TextInputUnitTests.swift`, `ListUnitTests.swift`, `TableUnitTests.swift`

```swift
@Test("TextInput handles backspace")
func handlesBackspace() {
    var textInput = TextInput().withValue("hello")
    
    textInput = textInput.update(KeyMsg(type: .backspace))
    #expect(textInput.value == "hell")
}
```

### 2. ANSI Sequence Tests
Located in `Tests/MatchaTests/Core/ANSISequenceTests.swift`

- Verify correct escape sequences are emitted
- Test terminal commands (cursor, mouse, alt screen)
- Match Bubbletea's sequence testing approach

```swift
@Test("Hide cursor emits correct sequence")
func hideCursorSequence() async throws {
    let output = TestOutputStream()
    let renderer = StandardRenderer(output: output)
    
    await renderer.hideCursor()
    
    #expect(output.content == "\u{1B}[?25l")
}
```

### 3. Core Logic Tests
Located in `Tests/MatchaTests/Core/`

- Test message handling
- Command execution
- Program lifecycle
- Error handling

## What We Don't Test

1. **Visual Output** - No golden files or visual regression tests
2. **Rendered Appearance** - Trust ANSI sequences to render correctly
3. **Terminal Behavior** - Not our responsibility to test terminal emulators
4. **Integration Scenarios** - Focus on unit tests over integration tests

## Migration from Golden Tests

We've removed all golden testing infrastructure:
- Deleted `Tests/MatchaTests/GoldenTests/`
- Removed `GoldenFileTestCase.swift`
- Removed golden test data files

This aligns with Bubbletea's philosophy: if you emit the right ANSI sequences, the terminal will display it correctly.

## Benefits

1. **Faster Tests** - No terminal emulation or visual comparison
2. **More Reliable** - No brittle visual comparisons
3. **Better Isolation** - Test one thing at a time
4. **Clearer Failures** - Know exactly what broke
5. **Bubbletea Alignment** - Same testing philosophy as the reference implementation

## Example Test Structure

```swift
@Suite("Component Unit Tests")
struct ComponentUnitTests {
    // State management tests
    @Test("Component handles input")
    func handlesInput() {
        var component = MyComponent()
        component = component.update(someMessage)
        #expect(component.state == expectedState)
    }
    
    // Builder pattern tests
    @Test("Component builder methods")
    func builderMethods() {
        let component = MyComponent()
            .withOption(value)
            .withAnotherOption(value2)
        
        #expect(component.option == value)
    }
}
```

## Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ComponentUnitTests

# Run with parallel execution
swift test --parallel
```

## Best Practices

1. **Test State Changes** - Verify component state after updates
2. **Test Edge Cases** - Empty lists, boundary conditions, invalid input
3. **Test Key Handling** - Verify keyboard navigation works correctly
4. **Mock Dependencies** - Use test doubles for external dependencies
5. **Keep Tests Fast** - Aim for sub-millisecond test execution

## Future Considerations

While we've aligned with Bubbletea's approach, we may consider:
- Performance benchmarks for critical paths
- Stress tests for high-frequency updates
- Memory usage tests for large datasets

But these would be separate from the core unit test suite.