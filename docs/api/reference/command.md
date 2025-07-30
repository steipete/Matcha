# Command

Represents an asynchronous operation that produces a message. Commands are the way to perform side effects in Matcha applications.

## Declaration

```swift
public struct Command<M: Message>: Sendable {
    public init(operation: @escaping @Sendable () async -> M?)
    
    // Constructors
    public static func pure(_ message: M) -> Command<M>
    public static func batch(_ commands: Command<M>...) -> Command<M>
    public static func batch(_ commands: [Command<M>]) -> Command<M>
    
    // Transformation
    public func map<N: Message>(_ transform: @escaping @Sendable (M) -> N) -> Command<N>
}
```

## Overview

Commands enable:
- Asynchronous operations (network requests, file I/O)
- Timer-based events
- Integration with external systems
- Side effects in a controlled manner

## Creating Commands

### Basic Command

```swift
let command = Command<MyMessage> {
    // Async operation
    let data = try await fetchData()
    return .dataLoaded(data)
}
```

### Pure Command

Immediately returns a message without async operation:

```swift
let command = Command.pure(.refresh)
```

### Batch Commands

Execute multiple commands concurrently:

```swift
let command = Command.batch(
    fetchUserData(),
    loadPreferences(),
    startBackgroundSync()
)
```

## Built-in Command Functions

### Quit

```swift
public func quit<M: Message>() -> Command<M> {
    Command { nil }  // Special nil indicates quit
}
```

### Timer Commands

```swift
// Run after delay
public func after<M: Message>(
    _ duration: Duration,
    perform: @escaping @Sendable () -> M?
) -> Command<M>

// Run periodically
public func every<M: Message>(
    _ interval: Duration,
    perform: @escaping @Sendable (Date) -> M?
) -> Command<M>
```

### Examples

```swift
// Delay
let delayCmd = after(.seconds(2)) {
    .showNotification("Time's up!")
}

// Periodic
let tickCmd = every(.milliseconds(100)) { date in
    .tick(date)
}
```

## Command Patterns

### Network Requests

```swift
func fetchUser(id: String) -> Command<Message> {
    Command {
        do {
            let url = URL(string: "https://api.example.com/users/\(id)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let user = try JSONDecoder().decode(User.self, from: data)
            return .userLoaded(user)
        } catch {
            return .error(error)
        }
    }
}
```

### File Operations

```swift
func saveToFile(_ content: String) -> Command<Message> {
    Command {
        do {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("data.txt")
            
            try content.write(to: url, atomically: true, encoding: .utf8)
            return .saved
        } catch {
            return .saveFailed(error)
        }
    }
}
```

### Conditional Commands

```swift
func conditionalCommand(shouldRun: Bool) -> Command<Message>? {
    guard shouldRun else { return nil }
    
    return Command {
        // Perform operation
        return .done
    }
}
```

### Sequential Operations

```swift
func sequentialOperations() -> Command<Message> {
    Command {
        // First operation
        let result1 = try await operation1()
        
        // Second operation depends on first
        let result2 = try await operation2(result1)
        
        // Third operation
        let result3 = try await operation3(result2)
        
        return .allComplete(result3)
    }
}
```

## Command Transformation

### Mapping Messages

Transform command output to different message type:

```swift
struct ParentModel: Model {
    var child: ChildModel
    
    enum Message: Matcha.Message {
        case childMsg(ChildModel.Message)
    }
    
    func update(_ message: Message) -> (ParentModel, Command<Message>?) {
        switch message {
        case .childMsg(let msg):
            let (newChild, cmd) = child.update(msg)
            var model = self
            model.child = newChild
            
            // Map child command to parent message
            let parentCmd = cmd?.map { .childMsg($0) }
            return (model, parentCmd)
        }
    }
}
```

## Error Handling

### Try-Catch Pattern

```swift
Command {
    do {
        let result = try await riskyOperation()
        return .success(result)
    } catch {
        return .failure(error)
    }
}
```

### Result Type

```swift
Command {
    let result = await performOperation()
    switch result {
    case .success(let value):
        return .loaded(value)
    case .failure(let error):
        return .error(error.localizedDescription)
    }
}
```

## Advanced Patterns

### Debouncing

```swift
var searchDebounceTask: Task<Void, Never>?

func debounceSearch(query: String) -> Command<Message> {
    Command {
        // Cancel previous search
        searchDebounceTask?.cancel()
        
        // Create new debounced task
        let task = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            
            // Perform search
            let results = await search(query)
            if !Task.isCancelled {
                return Message.searchResults(results)
            }
        }
        
        searchDebounceTask = task
        return await task.value
    }
}
```

### Polling

```swift
func pollStatus() -> Command<Message> {
    Command {
        while true {
            let status = try await checkStatus()
            
            if status.isComplete {
                return .complete(status)
            }
            
            try await Task.sleep(for: .seconds(1))
        }
    }
}
```

### Timeout

```swift
func withTimeout<T>(
    _ duration: Duration,
    operation: () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## Performance Considerations

### Command Pooling

Reuse commands when possible:

```swift
// Good - reuse command
let refreshCommand = Command<Message> { .refresh }

// Avoid - creating new command each time
func update(_ msg: Message) -> (Model, Command<Message>?) {
    case .tick:
        return (model, Command { .refresh })  // Creates new command
}
```

### Cancellation

Commands should check for cancellation:

```swift
Command {
    for item in largeDataset {
        // Check cancellation
        try Task.checkCancellation()
        
        // Process item
        await processItem(item)
    }
    
    return .processed
}
```

## Testing Commands

Commands can be tested by executing them directly:

```swift
func testFetchCommand() async throws {
    let command = fetchUserData()
    
    // Execute command
    let message = await command.operation()
    
    // Assert result
    switch message {
    case .userLoaded(let user):
        XCTAssertEqual(user.name, "Test User")
    default:
        XCTFail("Unexpected message")
    }
}
```

## Best Practices

1. **Keep Commands Focused**: Each command should do one thing
2. **Handle Errors**: Always catch and convert errors to messages
3. **Check Cancellation**: For long-running operations
4. **Use Batch**: For independent concurrent operations
5. **Avoid State**: Commands should not capture mutable state

## See Also

- [Model Protocol](model.md)
- [Message Protocol](message.md)
- [Built-in Functions](../README.md#global-functions)