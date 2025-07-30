# Performance Optimization

Comprehensive guide to optimizing Matcha applications for speed, efficiency, and responsiveness.

## Rendering Performance

### Understanding the Render Pipeline

1. **Model Update** → 2. **View Generation** → 3. **Diff Calculation** → 4. **Terminal Update**

Each step can be optimized:

### 1. Efficient Model Updates

```swift
// ❌ Inefficient: Recreating large arrays
func update(_ message: Message) -> (Model, Command<Message>?) {
    var model = self
    model.items = model.items.map { item in
        item.id == targetId ? updatedItem : item
    }
    return (model, nil)
}

// ✅ Efficient: Targeted updates
func update(_ message: Message) -> (Model, Command<Message>?) {
    var model = self
    if let index = model.items.firstIndex(where: { $0.id == targetId }) {
        model.items[index] = updatedItem
    }
    return (model, nil)
}
```

### 2. View Generation Optimization

#### Lazy Rendering
Only render visible content:

```swift
func view() -> String {
    let visibleRange = calculateVisibleRange()
    var output = ""
    
    // Only render items in viewport
    for index in visibleRange {
        output += renderItem(items[index])
    }
    
    return output
}

private func calculateVisibleRange() -> Range<Int> {
    let startIndex = max(0, scrollOffset)
    let endIndex = min(items.count, scrollOffset + viewportHeight)
    return startIndex..<endIndex
}
```

#### String Building Performance

```swift
// ❌ Slow: String concatenation in loops
var output = ""
for item in items {
    output += item.description + "\n"
}

// ✅ Fast: String interpolation or array joining
let output = items.map { $0.description }.joined(separator: "\n")

// ✅ Fastest: Pre-allocated string buffer
var output = String()
output.reserveCapacity(items.count * averageItemLength)
for item in items {
    output.append(item.description)
    output.append("\n")
}
```

### 3. Render Diffing

The renderer automatically diffs output, but you can help:

```swift
struct OptimizedModel: Model {
    // Cache rendered sections
    private var cachedHeader: String?
    private var cachedFooter: String?
    private var lastContentHash: Int?
    
    func view() -> String {
        // Reuse cached sections if unchanged
        let header = cachedHeader ?? renderHeader()
        let footer = cachedFooter ?? renderFooter()
        
        let contentHash = items.hashValue
        let content = if contentHash != lastContentHash {
            renderContent()
        } else {
            cachedContent
        }
        
        return "\(header)\n\(content)\n\(footer)"
    }
}
```

### 4. Frame Rate Management

Configure FPS based on content:

```swift
// Static content: Lower FPS
options.framesPerSecond = 10

// Animated content: Higher FPS
options.framesPerSecond = 60

// Adaptive FPS
func adaptiveFPS(for model: Model) -> Int {
    switch model.state {
    case .idle: return 10
    case .animating: return 60
    case .scrolling: return 30
    }
}
```

## Memory Optimization

### 1. Avoid Memory Leaks

```swift
// ❌ Potential retain cycle
class MyModel: Model {
    var timer: Timer?
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.tick()  // Strong reference to self
        }
    }
}

// ✅ Weak reference
func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        self?.tick()
    }
}
```

### 2. Data Structure Choices

```swift
// For large collections with frequent lookups
var itemsById: [String: Item] = [:]  // O(1) lookup

// For ordered collections
var items: [Item] = []  // O(n) lookup, but preserves order

// For unique, unordered collections
var tags: Set<String> = []  // O(1) insert/remove/contains
```

### 3. Copy-on-Write Optimization

```swift
// Swift arrays/dictionaries are copy-on-write
// This is efficient:
var model = self
model.items.append(newItem)  // Only copies if items is shared

// But be careful with nested structures:
struct Item {
    var data: [String: Any]  // This might cause unexpected copies
}

// Better:
struct Item {
    var id: String
    var name: String
    var value: Int
    // Specific fields instead of dictionary
}
```

## Command Performance

### 1. Concurrent Commands

```swift
// ❌ Sequential execution
func loadData() -> Command<Message> {
    Command {
        let user = try await fetchUser()
        let posts = try await fetchPosts()
        let comments = try await fetchComments()
        return .dataLoaded(user, posts, comments)
    }
}

// ✅ Concurrent execution
func loadData() -> Command<Message> {
    Command {
        async let user = fetchUser()
        async let posts = fetchPosts()
        async let comments = fetchComments()
        
        do {
            let data = try await (user, posts, comments)
            return .dataLoaded(data.0, data.1, data.2)
        } catch {
            return .loadError(error)
        }
    }
}
```

### 2. Command Debouncing

```swift
struct DebouncedCommand {
    private var task: Task<Void, Never>?
    private let delay: Duration
    
    init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }
    
    mutating func debounce<M: Message>(
        _ operation: @escaping () async -> M?
    ) -> Command<M> {
        task?.cancel()
        
        return Command {
            let newTask = Task {
                try? await Task.sleep(for: self.delay)
                guard !Task.isCancelled else { return nil }
                return await operation()
            }
            
            self.task = newTask
            return await newTask.value
        }
    }
}
```

### 3. Resource Management

```swift
// Connection pooling for network requests
actor ConnectionPool {
    private var connections: [URL: URLSession] = [:]
    private let maxConnections = 10
    
    func session(for url: URL) -> URLSession {
        if let existing = connections[url] {
            return existing
        }
        
        if connections.count >= maxConnections {
            // Evict least recently used
            connections.removeValue(forKey: connections.keys.first!)
        }
        
        let session = URLSession(configuration: .default)
        connections[url] = session
        return session
    }
}
```

## Large Data Handling

### Virtual Scrolling

```swift
struct VirtualList: Model {
    let allItems: [Item]  // Could be thousands
    var viewportOffset: Int = 0
    var viewportHeight: Int = 20
    
    // Only keep visible items in memory
    var visibleItems: ArraySlice<Item> {
        let start = viewportOffset
        let end = min(viewportOffset + viewportHeight, allItems.count)
        return allItems[start..<end]
    }
    
    func view() -> String {
        var output = ""
        
        // Render scroll indicator
        let scrollPercent = Double(viewportOffset) / Double(max(1, allItems.count - viewportHeight))
        output += renderScrollbar(scrollPercent)
        
        // Render only visible items
        for (index, item) in visibleItems.enumerated() {
            output += renderItem(item, isSelected: index == selectedIndex)
        }
        
        return output
    }
}
```

### Pagination

```swift
struct PaginatedModel: Model {
    var currentPage: Int = 0
    let itemsPerPage: Int = 50
    var pages: [Int: [Item]] = [:]  // Lazy-loaded pages
    
    func loadPage(_ page: Int) -> Command<Message> {
        Command {
            let items = try await fetchItems(
                offset: page * itemsPerPage,
                limit: itemsPerPage
            )
            return .pageLoaded(page, items)
        }
    }
}
```

## Profiling and Measurement

### Built-in Performance Metrics

```swift
extension Model {
    func measureUpdate<M: Message>(_ message: M) -> (Self, Command<M>?, TimeInterval) {
        let start = CFAbsoluteTimeGetCurrent()
        let (model, cmd) = update(message)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        if elapsed > 0.016 {  // Slower than 60 FPS
            print("⚠️ Slow update (\(elapsed * 1000)ms): \(message)")
        }
        
        return (model, cmd, elapsed)
    }
}
```

### Memory Profiling

```swift
func memoryFootprint() -> String {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        return String(format: "Memory: %.1f MB", usedMB)
    }
    
    return "Memory: Unknown"
}
```

## Best Practices Checklist

### Do's ✅
- Profile before optimizing
- Use lazy evaluation for expensive operations
- Cache computed values when appropriate
- Batch related updates
- Use appropriate data structures
- Leverage Swift's copy-on-write
- Keep views simple and fast

### Don'ts ❌
- Premature optimization
- Blocking operations in update
- Excessive string concatenation
- Unnecessary object creation
- Deep view hierarchies
- Complex calculations in view()

## Real-World Example

Here's a optimized file browser:

```swift
struct FileBrowser: Model {
    // Efficient data structures
    private var fileCache: [String: FileInfo] = [:]
    private var sortedPaths: [String] = []
    
    // Viewport management
    var scrollOffset: Int = 0
    let viewportHeight: Int = 30
    
    // Lazy loading
    var loadedDirectories: Set<String> = []
    
    // Performance metrics
    var lastRenderTime: TimeInterval = 0
    
    func view() -> String {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            lastRenderTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        // Only render visible files
        let visibleRange = scrollOffset..<min(scrollOffset + viewportHeight, sortedPaths.count)
        
        var output = String()
        output.reserveCapacity(viewportHeight * 80)  // Pre-allocate
        
        for index in visibleRange {
            let path = sortedPaths[index]
            if let info = fileCache[path] {
                output += renderFileRow(info, index: index)
            }
        }
        
        // Show performance in footer
        output += "\nRender time: \(lastRenderTime * 1000)ms"
        
        return output
    }
}
```