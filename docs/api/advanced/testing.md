# Testing Strategies

Comprehensive guide to testing Matcha applications, from unit tests to integration testing.

## Testing Philosophy

Matcha's architecture makes testing straightforward:
- **Pure Functions**: Model updates are pure and predictable
- **Explicit Effects**: All side effects go through commands
- **Isolated Components**: Each component can be tested independently

## Unit Testing Models

### Basic Model Testing

```swift
import XCTest
@testable import MyApp

final class CounterModelTests: XCTestCase {
    func testIncrement() {
        // Arrange
        var model = CounterModel(count: 0)
        
        // Act
        let (newModel, command) = model.update(.increment)
        
        // Assert
        XCTAssertEqual(newModel.count, 1)
        XCTAssertNil(command)
    }
    
    func testDecrementBelowZero() {
        var model = CounterModel(count: 0)
        let (newModel, _) = model.update(.decrement)
        
        XCTAssertEqual(newModel.count, 0, "Count should not go below zero")
    }
}
```

### Testing Complex State Transitions

```swift
final class TodoModelTests: XCTestCase {
    func testAddTodo() {
        // Given
        var model = TodoModel()
        model.inputText = "Buy milk"
        
        // When
        let (newModel, command) = model.update(.addTodo)
        
        // Then
        XCTAssertEqual(newModel.todos.count, 1)
        XCTAssertEqual(newModel.todos.first?.text, "Buy milk")
        XCTAssertEqual(newModel.inputText, "", "Input should be cleared")
        XCTAssertNotNil(command, "Should trigger save command")
    }
    
    func testFilterTodos() {
        // Given
        var model = TodoModel()
        model.todos = [
            Todo(text: "Task 1", completed: true),
            Todo(text: "Task 2", completed: false),
            Todo(text: "Task 3", completed: true)
        ]
        
        // When
        let (filteredModel, _) = model.update(.setFilter(.active))
        
        // Then
        let visibleTodos = filteredModel.visibleTodos
        XCTAssertEqual(visibleTodos.count, 1)
        XCTAssertEqual(visibleTodos.first?.text, "Task 2")
    }
}
```

### Testing Message Sequences

```swift
final class WorkflowTests: XCTestCase {
    func testLoginFlow() {
        var model = LoginModel()
        
        // Enter username
        let (model1, _) = model.update(.setUsername("alice"))
        XCTAssertEqual(model1.username, "alice")
        
        // Enter password
        let (model2, _) = model1.update(.setPassword("secret"))
        XCTAssertEqual(model2.password, "secret")
        
        // Submit
        let (model3, command) = model2.update(.submit)
        XCTAssertTrue(model3.isLoading)
        XCTAssertNotNil(command, "Should trigger login command")
        
        // Handle success
        let (model4, _) = model3.update(.loginSuccess(token: "abc123"))
        XCTAssertFalse(model4.isLoading)
        XCTAssertTrue(model4.isAuthenticated)
    }
}
```

## Testing Commands

### Async Command Testing

```swift
final class CommandTests: XCTestCase {
    func testFetchDataCommand() async throws {
        // Create command
        let command = fetchUserData(id: "123")
        
        // Execute
        let message = await command.operation()
        
        // Verify
        switch message {
        case .userLoaded(let user):
            XCTAssertEqual(user.id, "123")
            XCTAssertEqual(user.name, "Test User")
        default:
            XCTFail("Expected userLoaded message")
        }
    }
    
    func testCommandWithError() async {
        // Create command that will fail
        let command = fetchUserData(id: "invalid")
        
        // Execute
        let message = await command.operation()
        
        // Verify error handling
        switch message {
        case .error(let error):
            XCTAssertTrue(error.contains("not found"))
        default:
            XCTFail("Expected error message")
        }
    }
}
```

### Testing Timer Commands

```swift
final class TimerCommandTests: XCTestCase {
    func testDelayedCommand() async throws {
        let expectation = XCTestExpectation(description: "Delayed command")
        var messageReceived: Message?
        
        // Create delayed command
        let command = after(.milliseconds(100)) {
            messageReceived = .timeout
            expectation.fulfill()
            return .timeout
        }
        
        // Execute
        Task {
            _ = await command.operation()
        }
        
        // Wait for completion
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(messageReceived, .timeout)
    }
}
```

## Testing Views

### Snapshot Testing

```swift
final class ViewTests: XCTestCase {
    func testTableView() {
        let model = TableModel(
            headers: ["Name", "Age", "City"],
            rows: [
                ["Alice", "30", "New York"],
                ["Bob", "25", "London"]
            ]
        )
        
        let view = model.view()
        
        // Snapshot test
        assertSnapshot(matching: view, as: .lines)
        
        // Or verify specific content
        XCTAssertTrue(view.contains("Alice"))
        XCTAssertTrue(view.contains("30"))
    }
}
```

### View Regression Testing

```swift
func testViewConsistency() {
    let model = createComplexModel()
    
    // Generate view multiple times
    let view1 = model.view()
    let view2 = model.view()
    
    // Views should be identical for same model
    XCTAssertEqual(view1, view2, "View should be deterministic")
}
```

## Testing Components

### TextInput Testing

```swift
final class TextInputTests: XCTestCase {
    func testCharacterInput() {
        var input = TextInput()
        
        let (updated, _) = input.update(.characterInput("H"))
        XCTAssertEqual(updated.value, "H")
        XCTAssertEqual(updated.cursorPosition, 1)
    }
    
    func testBackspace() {
        var input = TextInput()
        input.value = "Hello"
        input.cursorPosition = 5
        
        let (updated, _) = input.update(.backspace)
        XCTAssertEqual(updated.value, "Hell")
        XCTAssertEqual(updated.cursorPosition, 4)
    }
    
    func testValidation() {
        var input = TextInput()
        input.validator = { text in
            text.count >= 3
        }
        
        input.value = "Hi"
        XCTAssertFalse(input.validate())
        
        input.value = "Hello"
        XCTAssertTrue(input.validate())
    }
}
```

## Integration Testing

### Using ProgramTester

```swift
final class IntegrationTests: XCTestCase {
    func testFullApplication() async throws {
        let tester = ProgramTester<TodoModel>()
        
        // Start program
        try await tester.start()
        
        // Verify initial state
        try await tester.expectView(containing: "TODO LIST")
        try await tester.expectView(containing: "0 items")
        
        // Add a todo
        try await tester.sendKey("a")  // Add mode
        try await tester.typeText("Buy groceries")
        try await tester.sendKey(.enter)
        
        // Verify todo was added
        try await tester.expectView(containing: "Buy groceries")
        try await tester.expectView(containing: "1 items")
        
        // Mark as complete
        try await tester.sendKey(.space)
        try await tester.expectView(containing: "✓ Buy groceries")
        
        // Cleanup
        try await tester.stop()
    }
}
```

### Mock Renderer Testing

```swift
final class RenderingTests: XCTestCase {
    func testRenderingPerformance() async throws {
        let mockRenderer = MockRenderer()
        var model = LargeListModel(items: generateItems(1000))
        
        // Measure rendering
        let start = Date()
        for _ in 0..<60 {  // 60 frames
            await mockRenderer.render(model.view())
            model = model.update(.scroll(1)).0
        }
        let elapsed = Date().timeIntervalSince(start)
        
        // Should render 60 frames in under 1 second
        XCTAssertLessThan(elapsed, 1.0)
        
        // Verify render calls
        XCTAssertEqual(mockRenderer.renderCount, 60)
        XCTAssertGreaterThan(mockRenderer.diffEfficiency, 0.8)
    }
}
```

## Test Utilities

### Test Fixtures

```swift
// TestFixtures.swift
extension TodoModel {
    static func fixture(
        todos: [Todo] = [],
        filter: Filter = .all,
        inputText: String = ""
    ) -> TodoModel {
        var model = TodoModel()
        model.todos = todos
        model.filter = filter
        model.inputText = inputText
        return model
    }
}

// Usage
let model = TodoModel.fixture(
    todos: [
        Todo(text: "Task 1", completed: true),
        Todo(text: "Task 2", completed: false)
    ],
    filter: .active
)
```

### Custom Assertions

```swift
func XCTAssertModelTransition<M: Model>(
    from initial: M,
    message: M.Msg,
    to expected: M,
    file: StaticString = #file,
    line: UInt = #line
) {
    let (actual, _) = initial.update(message)
    
    // Use Mirror for detailed comparison
    let expectedMirror = Mirror(reflecting: expected)
    let actualMirror = Mirror(reflecting: actual)
    
    for (expectedChild, actualChild) in zip(expectedMirror.children, actualMirror.children) {
        XCTAssertEqual(
            "\(expectedChild.value)",
            "\(actualChild.value)",
            "Property \(expectedChild.label ?? "unknown") mismatch",
            file: file,
            line: line
        )
    }
}
```

## Testing Best Practices

### 1. Test Structure

```swift
final class ModelTests: XCTestCase {
    // MARK: - Properties
    var sut: Model!  // System Under Test
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        sut = Model()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func test_initialState_isCorrect() {
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.items.isEmpty)
    }
    
    func test_update_withIncrement_increasesCount() {
        // Given
        let initialCount = sut.count
        
        // When
        let (updated, _) = sut.update(.increment)
        
        // Then
        XCTAssertEqual(updated.count, initialCount + 1)
    }
}
```

### 2. Testing Checklist

- [ ] Unit test all model updates
- [ ] Test edge cases and error conditions
- [ ] Test command execution
- [ ] Verify view output for key states
- [ ] Integration test user workflows
- [ ] Performance test with realistic data
- [ ] Test on all supported platforms

### 3. Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
        
    steps:
    - uses: actions/checkout@v3
    - uses: swift-actions/setup-swift@v1
      with:
        swift-version: "6.0"
        
    - name: Build
      run: swift build
      
    - name: Test
      run: swift test --parallel
      
    - name: Coverage
      run: |
        swift test --enable-code-coverage
        xcrun llvm-cov export \
          .build/debug/MatchaPackageTests.xctest/Contents/MacOS/MatchaPackageTests \
          -instr-profile .build/debug/codecov/default.profdata \
          -format="lcov" > coverage.lcov
```

## Debugging Tests

### Verbose Test Output

```swift
func debug<M: Model>(_ model: M, message: String = "") {
    #if DEBUG
    print("""
    ===== Model Debug: \(message) =====
    \(String(describing: model))
    ===== View =====
    \(model.view())
    ================
    """)
    #endif
}
```

### Test Timeouts

```swift
func testSlowOperation() async throws {
    try await withTimeout(seconds: 5) {
        // Test that should complete within 5 seconds
    }
}

func withTimeout(seconds: TimeInterval, operation: () async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        
        try await group.next()
        group.cancelAll()
    }
}
```