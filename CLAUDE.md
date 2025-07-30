# Matcha Project Guidelines for Claude

## Testing Framework

**IMPORTANT:** This project uses Swift Testing (introduced in Swift 6/Xcode 16) instead of XCTest for all new tests.

### Key Differences:
- Use `@Test` attribute instead of `func test...()` methods
- Use `#expect()` and `#require()` macros instead of `XCTAssert...` functions
- Use `@Suite` for test organization instead of `XCTestCase` subclasses
- Tests run in parallel by default
- Use `init()` and `deinit` for setup/teardown instead of `setUp()`/`tearDown()`

### Example:
```swift
// ❌ Don't use XCTest
import XCTest
class MyTests: XCTestCase {
    func testSomething() {
        XCTAssertEqual(1 + 1, 2)
    }
}

// ✅ Use Swift Testing
import Testing
@Suite struct MyTests {
    @Test func addition() {
        #expect(1 + 1 == 2)
    }
}
```

### Migration Status:
- All tests created after this note should use Swift Testing
- Existing XCTest tests will be migrated incrementally
- Both frameworks can coexist during the migration period

For more details, see `/Users/steipete/Projects/Matcha/docs/swift-testing-playbook.md`

## Implementation Guidelines

**CRITICAL:** When implementing features, always compare with the Bubbletea Go implementation to ensure compatibility and correctness.

### Key Principle:
> "Whenever you are unsure, refactor things to be more in line with what Bubble Tea does. Bubble Tea works, our stuff doesn't work yet."

### Implementation Approach:
1. **Always check Bubbletea source** - Before implementing any feature, read the corresponding Bubbletea Go code
2. **Match behavior exactly** - Use the same ANSI sequences, same logic flow, same edge case handling
3. **Don't innovate** - This is a port, not a reimplementation. Stick to what works in Bubbletea
4. **Test against Bubbletea behavior** - Ensure our tests validate the same behavior as Bubbletea

### Key Files to Reference:
- `/Users/steipete/Projects/bubbletea/tea.go` - Main program logic
- `/Users/steipete/Projects/bubbletea/commands.go` - Command implementations
- `/Users/steipete/Projects/bubbletea/standard_renderer.go` - Renderer implementation
- `/Users/steipete/Projects/bubbletea/mouse.go` - Mouse handling
- `/Users/steipete/Projects/bubbletea/key.go` - Keyboard handling

### Recent Alignment Work:
- Scroll regions now use InsertLine (`\u{1B}[nL`) like Bubbletea's `insertTop`
- Message queue handling matches Bubbletea's `queuedMessageLines` behavior
- Terminal size tracking follows Bubbletea's width/height management
- Ignored lines functionality matches Bubbletea's `ignoreLines` map approach