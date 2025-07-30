# Testing Approach Comparison: Matcha vs Bubbletea

## Summary

Matcha uses **golden file testing** for visual regression testing, while Bubbletea uses **unit testing** focused on logic and ANSI sequences. This represents a fundamental difference in testing philosophy.

## Bubbletea's Testing Approach

### 1. Unit Testing Focus
- Tests individual components and functions
- Table-driven tests with expected inputs/outputs
- Direct assertions on parsed results
- No visual output testing

### 2. ANSI Sequence Testing
```go
// From screen_test.go
{
    name:     "clear_screen",
    cmds:     []Cmd{ClearScreen},
    expected: "\x1b[?25l\x1b[?2004h\x1b[2J\x1b[H\rsuccess\x1b[K\r\n\x1b[K\x1b[80D\x1b[2K\r\x1b[?2004l\x1b[?25h\x1b[?1002l\x1b[?1003l\x1b[?1006l",
}
```
- Tests exact ANSI escape sequences
- Verifies terminal commands work correctly
- No testing of visual appearance

### 3. Mock Models
```go
// From tea_test.go
type testModel struct {
    executed atomic.Value
    counter  atomic.Value
}
```
- Uses simple test models with atomic values
- Tests state changes and message handling
- Buffer-based input/output testing

### 4. Key/Mouse Event Testing
```go
// From key_test.go and mouse_test.go
tt := []struct {
    name     string
    event    MouseEvent
    expected string
}{
    {
        name: "left",
        event: MouseEvent{
            Action: MouseActionPress,
            Button: MouseButtonLeft,
            Type:   MouseLeft,
        },
        expected: "left press",
    },
}
```
- Tests parsing and string representation
- Verifies event detection logic
- No testing of how events affect visual output

## Matcha's Golden Testing Approach

### 1. Visual Regression Testing
- Captures actual terminal output
- Compares against stored "golden" files
- Tests complete component rendering
- Verifies visual appearance

### 2. Component Integration Testing
```swift
// From ComponentGoldenTests.swift
@Test("TextInput rendering")
func textInputRendering() async throws {
    let output = try await goldenTester.captureOutput(for: TextInputModel()) { program in
        // Type some text
        program.send(TextInputModel.Message.key(KeyMsg(type: .runes, runes: ["J"])))
        // ...
    }
    try goldenTester.assertGoldenMatch(output, goldenFile: "textinput-basic")
}
```
- Tests full component behavior
- Captures user interactions
- Verifies complete visual output

### 3. Normalization Features
- Strip ANSI sequences (optional)
- Normalize timestamps
- Normalize UUIDs
- Trim whitespace
- Makes tests less brittle

### 4. Golden File Management
- `UPDATE_GOLDEN_FILES=1` to update expected output
- Version controlled golden files
- Easy to review visual changes

## Analysis: Why the Difference?

### Bubbletea's Philosophy
1. **Correctness over appearance**: Focus on correct ANSI sequences and logic
2. **Stability**: Unit tests are less brittle than visual tests
3. **Speed**: Unit tests run faster than full integration tests
4. **Simplicity**: No need for golden file management

### Matcha's Philosophy
1. **Visual correctness**: Ensure components look right, not just work right
2. **Regression prevention**: Catch unintended visual changes
3. **Documentation**: Golden files serve as visual documentation
4. **User experience**: Test what users actually see

## Recommendation

Given the directive to "refactor things to be more in line with what Bubble Tea does", we should consider:

### Option 1: Remove Golden Testing (Align with Bubbletea)
**Pros:**
- Matches Bubbletea's approach exactly
- Simpler test infrastructure
- Less brittle tests
- Faster test execution

**Cons:**
- Lose visual regression testing
- Can't catch rendering bugs
- Less confidence in visual output

### Option 2: Keep Golden Testing as Matcha Enhancement
**Pros:**
- Additional safety net for visual bugs
- Better documentation of expected output
- Catches issues Bubbletea tests might miss
- Good for TUI framework where visuals matter

**Cons:**
- Diverges from Bubbletea's approach
- More complex testing infrastructure
- Potentially brittle tests
- Requires golden file management

### Option 3: Hybrid Approach (Recommended)
1. **Primary tests**: Follow Bubbletea's unit testing approach
2. **Secondary tests**: Keep golden tests but make them optional
3. **Focus**: Ensure all Bubbletea-style tests pass first
4. **Golden tests**: Run separately, not required for CI

## Implementation Plan

If we choose to align more with Bubbletea:

1. **Add unit tests** for all components matching Bubbletea patterns
2. **Test ANSI sequences** directly for rendering operations
3. **Add mock models** for testing state management
4. **Move golden tests** to a separate test suite
5. **Make golden tests optional** (e.g., only run with specific flag)

This way we get the best of both worlds: Bubbletea compatibility and visual regression testing.