# Testing Migration Plan: Aligning with Bubbletea

## Deep Analysis

After careful analysis of Bubbletea's testing philosophy, the core insight is:

**Bubbletea tests the CONTRACT (ANSI sequences), not the RESULT (visual appearance)**

This is fundamentally more robust because:
1. ANSI sequences are the actual API between your program and the terminal
2. Visual appearance varies by terminal emulator 
3. Testing visual output is testing the terminal's job, not yours
4. Unit tests are faster, more reliable, and less brittle

## Key Principle

> "Test what you control, not what you observe"

We control the ANSI sequences we emit. We don't control how terminals render them.

## Migration Strategy

### Phase 1: Remove Golden Testing (IMMEDIATE)
1. Delete `/Tests/MatchaTests/GoldenTests/` directory
2. Delete `/Tests/MatchaTests/TestUtilities/GoldenFileTestCase.swift`
3. Remove golden test data from `/Tests/MatchaTests/TestData/Golden/`
4. Update test documentation

### Phase 2: Add Bubbletea-Style Tests (HIGH PRIORITY)

#### 1. ANSI Sequence Tests
Test that operations emit correct escape sequences:
```swift
@Test func clearScreenEmitsCorrectSequence() {
    var output = TestOutput()
    let renderer = StandardRenderer(output: output)
    
    renderer.clearScreen()
    
    #expect(output.buffer == "\u{1B}[2J\u{1B}[H")
}
```

#### 2. Component State Tests
Test component logic without rendering:
```swift
@Test func textInputHandlesBackspace() {
    var textInput = TextInput().withValue("hello")
    
    textInput = textInput.update(KeyMsg(type: .backspace))
    
    #expect(textInput.value == "hell")
}
```

#### 3. Message Handling Tests
Test models process messages correctly:
```swift
@Test func modelIncrementsCounter() {
    var model = CounterModel(count: 0)
    let (newModel, cmd) = model.update(.increment)
    
    #expect(newModel.count == 1)
    #expect(cmd == nil)
}
```

#### 4. Renderer Operation Tests
Test that renderer tracks state correctly:
```swift
@Test func rendererTracksScrollRegion() {
    let renderer = StandardRenderer()
    
    renderer.setScrollRegion(top: 5, bottom: 10)
    
    #expect(renderer.scrollTop == 5)
    #expect(renderer.scrollBottom == 10)
}
```

### Phase 3: Test Categories

#### Core Tests (matching Bubbletea's tea_test.go)
- Program lifecycle (init, run, quit)
- Message dispatching
- Command execution
- Context handling

#### Input Tests (matching key_test.go, mouse_test.go)
- Key sequence parsing
- Mouse event parsing
- Special key detection
- Modifier key handling

#### Screen Tests (matching screen_test.go)
- Alt screen enter/exit sequences
- Cursor visibility sequences
- Mouse mode sequences
- Bracketed paste sequences

#### Component Tests (new, but following Bubbletea patterns)
- State management
- Event handling
- **NO** visual output testing

## What We're NOT Testing

1. **Visual appearance** - That's the terminal's job
2. **Rendered output** - We test ANSI sequences instead
3. **Integration scenarios** - We test units in isolation
4. **Golden files** - No regression testing of visuals

## Benefits of This Approach

1. **Faster tests** - No terminal emulation needed
2. **More reliable** - No brittle visual comparisons
3. **Better isolation** - Test one thing at a time
4. **Clearer failures** - Know exactly what broke
5. **Matches Bubbletea** - Same testing philosophy

## Example Test Structure

```swift
// Instead of this (golden test):
@Test func listNavigationGolden() async throws {
    let output = try await captureOutput(for: ListModel()) { program in
        program.send(.key(.down))
    }
    try assertGoldenMatch(output, goldenFile: "list-nav")
}

// Do this (unit test):
@Test func listNavigationMovesSelection() {
    var list = List().withItems(["A", "B", "C"])
    #expect(list.selectedIndex == 0)
    
    list = list.update(KeyMsg(type: .down))
    #expect(list.selectedIndex == 1)
    
    list = list.update(KeyMsg(type: .down))
    #expect(list.selectedIndex == 2)
    
    list = list.update(KeyMsg(type: .down))
    #expect(list.selectedIndex == 2) // Stays at end
}

@Test func listRendererEmitsCorrectSequences() {
    var output = TestOutput()
    let renderer = StandardRenderer(output: output)
    
    // Test that list rendering emits expected ANSI sequences
    renderer.write("→ Item 1")
    renderer.newline()
    
    #expect(output.buffer.contains("→ Item 1\r\n"))
}
```

## Timeline

1. **Immediately**: Remove golden tests (they're already broken)
2. **Next**: Add ANSI sequence tests for renderer
3. **Then**: Add component state tests
4. **Finally**: Add missing Bubbletea-equivalent tests

## Success Criteria

- All golden tests removed
- Core renderer operations have ANSI sequence tests
- All components have state management tests
- Test suite runs fast (<1 second)
- No dependency on terminal emulation
- Tests match Bubbletea's approach