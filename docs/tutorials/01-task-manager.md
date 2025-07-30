# Tutorial 1: Building a Task Manager

In this tutorial, we'll build a fully functional task manager from scratch. You'll learn the fundamentals of Matcha while creating something useful!

## What We're Building

A terminal-based task manager with:
- ✅ Add, edit, and delete tasks
- 🎯 Priority levels (High, Medium, Low)
- 📅 Due dates
- 🔍 Filtering by status and priority
- 💾 Persistent storage
- ⌨️ Intuitive keyboard shortcuts

![Task Manager Preview](images/task-manager-preview.png)

## Setup

Create a new Swift package:

```bash
mkdir TaskManager
cd TaskManager
swift package init --type executable
```

Edit `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TaskManager",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/yourusername/matcha", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TaskManager",
            dependencies: [
                .product(name: "Matcha", package: "matcha"),
                .product(name: "MatchaBubbles", package: "matcha")
            ]
        )
    ]
)
```

## Step 1: Define the Model

Let's start by defining our data structures and model. Create `Sources/TaskManager/TaskModel.swift`:

```swift
import Foundation
import Matcha
import MatchaBubbles

// MARK: - Data Types

struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var description: String = ""
    var priority: Priority = .medium
    var dueDate: Date?
    var completed: Bool = false
    var createdAt = Date()
    
    enum Priority: String, CaseIterable, Codable {
        case high, medium, low
        
        var emoji: String {
            switch self {
            case .high: return "🔴"
            case .medium: return "🟡"
            case .low: return "🟢"
            }
        }
    }
}

// MARK: - Model

struct TaskModel: Model {
    // State
    var tasks: [Task] = []
    var filter: Filter = .all
    var sortBy: SortOption = .priority
    var selectedIndex: Int = 0
    var mode: Mode = .normal
    
    // UI Components
    var titleInput = TextInput()
    var descriptionInput = TextInput()
    var searchInput = TextInput()
    
    // Enums
    enum Filter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case highPriority = "High Priority"
        case dueSoon = "Due Soon"
    }
    
    enum SortOption: String, CaseIterable {
        case priority = "Priority"
        case dueDate = "Due Date"
        case created = "Created"
        case title = "Title"
    }
    
    enum Mode {
        case normal
        case adding
        case editing(Task)
        case searching
        case confirmDelete(Task)
    }
    
    // Messages
    enum Message: Matcha.Message {
        // Navigation
        case moveUp
        case moveDown
        case select
        
        // Task operations
        case startAdd
        case startEdit
        case deleteTask
        case confirmDelete(Bool)
        case toggleComplete
        case changePriority
        
        // Input
        case titleInputMsg(TextInput.Message)
        case descriptionInputMsg(TextInput.Message)
        case searchInputMsg(TextInput.Message)
        case saveTask
        case cancelEdit
        
        // View control
        case changeFilter(Filter)
        case changeSort(SortOption)
        case toggleSearch
        
        // Data
        case loadTasks([Task])
        case saveTasks
        case quit
    }
    
    // MARK: - Initialization
    
    init() {
        titleInput.placeholder = "Task title..."
        titleInput.characterLimit = 50
        
        descriptionInput.placeholder = "Description (optional)..."
        descriptionInput.characterLimit = 200
        
        searchInput.placeholder = "Search tasks..."
    }
    
    func `init`() -> Command<Message>? {
        // Load tasks on startup
        Command {
            if let tasks = try? loadTasksFromDisk() {
                return .loadTasks(tasks)
            }
            return nil
        }
    }
}
```

## Step 2: Implement Update Logic

Add the update function to handle all state transitions:

```swift
extension TaskModel {
    func update(_ message: Message) -> (TaskModel, Command<Message>?) {
        var model = self
        
        switch message {
        // MARK: - Navigation
        case .moveUp:
            if model.selectedIndex > 0 {
                model.selectedIndex -= 1
            }
            return (model, nil)
            
        case .moveDown:
            let maxIndex = model.filteredTasks.count - 1
            if model.selectedIndex < maxIndex {
                model.selectedIndex += 1
            }
            return (model, nil)
            
        case .select:
            guard model.mode == .normal else { return (model, nil) }
            return model.update(.toggleComplete)
            
        // MARK: - Task Operations
        case .startAdd:
            model.mode = .adding
            model.titleInput.reset()
            model.descriptionInput.reset()
            model.titleInput.focus()
            return (model, nil)
            
        case .startEdit:
            guard model.mode == .normal,
                  let task = model.selectedTask else { return (model, nil) }
            
            model.mode = .editing(task)
            model.titleInput.setValue(task.title)
            model.descriptionInput.setValue(task.description)
            model.titleInput.focus()
            return (model, nil)
            
        case .deleteTask:
            guard let task = model.selectedTask else { return (model, nil) }
            model.mode = .confirmDelete(task)
            return (model, nil)
            
        case .confirmDelete(let confirmed):
            if case .confirmDelete(let task) = model.mode, confirmed {
                model.tasks.removeAll { $0.id == task.id }
                model.selectedIndex = min(model.selectedIndex, model.filteredTasks.count - 1)
                return (model, Command { .saveTasks })
            }
            model.mode = .normal
            return (model, nil)
            
        case .toggleComplete:
            guard let task = model.selectedTask,
                  let index = model.tasks.firstIndex(where: { $0.id == task.id }) else {
                return (model, nil)
            }
            
            model.tasks[index].completed.toggle()
            return (model, Command { .saveTasks })
            
        case .changePriority:
            guard let task = model.selectedTask,
                  let index = model.tasks.firstIndex(where: { $0.id == task.id }) else {
                return (model, nil)
            }
            
            // Cycle through priorities
            let priorities = Task.Priority.allCases
            let currentIndex = priorities.firstIndex(of: task.priority) ?? 0
            let nextIndex = (currentIndex + 1) % priorities.count
            model.tasks[index].priority = priorities[nextIndex]
            
            return (model, Command { .saveTasks })
            
        // MARK: - Input Handling
        case .titleInputMsg(let msg):
            let (newInput, cmd) = model.titleInput.update(msg)
            model.titleInput = newInput
            return (model, cmd?.map { .titleInputMsg($0) })
            
        case .descriptionInputMsg(let msg):
            let (newInput, cmd) = model.descriptionInput.update(msg)
            model.descriptionInput = newInput
            return (model, cmd?.map { .descriptionInputMsg($0) })
            
        case .searchInputMsg(let msg):
            let (newInput, cmd) = model.searchInput.update(msg)
            model.searchInput = newInput
            model.selectedIndex = 0  // Reset selection when searching
            return (model, cmd?.map { .searchInputMsg($0) })
            
        case .saveTask:
            switch model.mode {
            case .adding:
                guard !model.titleInput.value.isEmpty else { return (model, nil) }
                
                let newTask = Task(
                    title: model.titleInput.value,
                    description: model.descriptionInput.value
                )
                model.tasks.append(newTask)
                model.mode = .normal
                model.titleInput.blur()
                model.descriptionInput.blur()
                
                return (model, Command { .saveTasks })
                
            case .editing(let oldTask):
                guard !model.titleInput.value.isEmpty,
                      let index = model.tasks.firstIndex(where: { $0.id == oldTask.id }) else {
                    return (model, nil)
                }
                
                model.tasks[index].title = model.titleInput.value
                model.tasks[index].description = model.descriptionInput.value
                model.mode = .normal
                model.titleInput.blur()
                model.descriptionInput.blur()
                
                return (model, Command { .saveTasks })
                
            default:
                return (model, nil)
            }
            
        case .cancelEdit:
            model.mode = .normal
            model.titleInput.blur()
            model.descriptionInput.blur()
            model.searchInput.blur()
            return (model, nil)
            
        // MARK: - View Control
        case .changeFilter(let filter):
            model.filter = filter
            model.selectedIndex = 0
            return (model, nil)
            
        case .changeSort(let sort):
            model.sortBy = sort
            return (model, nil)
            
        case .toggleSearch:
            if model.mode == .searching {
                model.mode = .normal
                model.searchInput.blur()
                model.searchInput.reset()
            } else {
                model.mode = .searching
                model.searchInput.focus()
            }
            return (model, nil)
            
        // MARK: - Data Operations
        case .loadTasks(let tasks):
            model.tasks = tasks
            return (model, nil)
            
        case .saveTasks:
            return (model, saveTasksToDisk(model.tasks))
            
        case .quit:
            return (model, quit())
        }
    }
}
```

## Step 3: Helper Functions

Add helper functions for filtering, sorting, and persistence:

```swift
extension TaskModel {
    // MARK: - Computed Properties
    
    var filteredTasks: [Task] {
        let filtered: [Task]
        
        // Apply search filter first
        if mode == .searching && !searchInput.value.isEmpty {
            let query = searchInput.value.lowercased()
            filtered = tasks.filter { task in
                task.title.lowercased().contains(query) ||
                task.description.lowercased().contains(query)
            }
        } else {
            // Apply regular filters
            switch filter {
            case .all:
                filtered = tasks
            case .active:
                filtered = tasks.filter { !$0.completed }
            case .completed:
                filtered = tasks.filter { $0.completed }
            case .highPriority:
                filtered = tasks.filter { $0.priority == .high && !$0.completed }
            case .dueSoon:
                let threeDaysFromNow = Date().addingTimeInterval(3 * 24 * 60 * 60)
                filtered = tasks.filter { task in
                    guard let dueDate = task.dueDate else { return false }
                    return dueDate <= threeDaysFromNow && !task.completed
                }
            }
        }
        
        // Apply sorting
        return filtered.sorted { lhs, rhs in
            switch sortBy {
            case .priority:
                if lhs.priority == rhs.priority {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.priority.rawValue < rhs.priority.rawValue
            case .dueDate:
                if let lhsDate = lhs.dueDate, let rhsDate = rhs.dueDate {
                    return lhsDate < rhsDate
                }
                return lhs.dueDate != nil
            case .created:
                return lhs.createdAt > rhs.createdAt
            case .title:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
    
    var selectedTask: Task? {
        let tasks = filteredTasks
        guard selectedIndex < tasks.count else { return nil }
        return tasks[selectedIndex]
    }
}

// MARK: - Persistence

func loadTasksFromDisk() throws -> [Task] {
    let url = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("tasks.json")
    
    guard FileManager.default.fileExists(atPath: url.path) else {
        return []
    }
    
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([Task].self, from: data)
}

func saveTasksToDisk(_ tasks: [Task]) -> Command<TaskModel.Message> {
    Command {
        do {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("tasks.json")
            
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: url)
        } catch {
            print("Failed to save tasks: \(error)")
        }
        return nil
    }
}
```

## Step 4: Create the View

Implement the view to display our task manager:

```swift
import MatchaStyle

extension TaskModel {
    func view() -> String {
        var lines: [String] = []
        
        // Header
        lines.append(renderHeader())
        lines.append("")
        
        // Mode-specific content
        switch mode {
        case .normal, .searching:
            lines.append(renderTaskList())
        case .adding:
            lines.append(renderAddForm())
        case .editing:
            lines.append(renderEditForm())
        case .confirmDelete(let task):
            lines.append(renderDeleteConfirmation(task))
        }
        
        // Footer
        lines.append("")
        lines.append(renderFooter())
        
        return lines.joined(separator: "\n")
    }
    
    private func renderHeader() -> String {
        let title = Style().bold().foreground(.cyan).render("📋 Task Manager")
        let stats = "[\(tasks.filter { !$0.completed }.count) active, \(tasks.filter { $0.completed }.count) completed]"
        return "\(title) \(stats)"
    }
    
    private func renderTaskList() -> String {
        var lines: [String] = []
        
        // Search bar (if active)
        if mode == .searching {
            lines.append("🔍 \(searchInput.view())")
            lines.append("")
        }
        
        // Filter tabs
        let filterLine = Filter.allCases.map { f in
            let style = f == filter ? Style().bold().underline() : Style().faint()
            return style.render(f.rawValue)
        }.joined(separator: "  ")
        lines.append(filterLine)
        lines.append(String(repeating: "─", count: 60))
        
        // Task list
        let tasks = filteredTasks
        if tasks.isEmpty {
            lines.append(Style().faint().render("No tasks found"))
        } else {
            for (index, task) in tasks.enumerated() {
                let isSelected = index == selectedIndex
                let prefix = isSelected ? "▶ " : "  "
                
                let checkbox = task.completed ? "☑" : "☐"
                let priority = task.priority.emoji
                
                var taskLine = "\(prefix)\(checkbox) \(priority) \(task.title)"
                
                if let dueDate = task.dueDate {
                    let formatter = RelativeDateTimeFormatter()
                    let dueText = formatter.localizedString(for: dueDate, relativeTo: Date())
                    taskLine += " 📅 \(dueText)"
                }
                
                let style: Style
                if task.completed {
                    style = Style().strikethrough().faint()
                } else if isSelected {
                    style = Style().foreground(.cyan).bold()
                } else {
                    style = Style()
                }
                
                lines.append(style.render(taskLine))
                
                // Show description on selected item
                if isSelected && !task.description.isEmpty {
                    let descStyle = Style().faint().italic()
                    lines.append(descStyle.render("     \(task.description)"))
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func renderAddForm() -> String {
        """
        ➕ Add New Task
        ──────────────
        
        Title: \(titleInput.view())
        
        Description: \(descriptionInput.view())
        
        \(Style().faint().render("Enter to save, Esc to cancel"))
        """
    }
    
    private func renderEditForm() -> String {
        """
        ✏️ Edit Task
        ───────────
        
        Title: \(titleInput.view())
        
        Description: \(descriptionInput.view())
        
        \(Style().faint().render("Enter to save, Esc to cancel"))
        """
    }
    
    private func renderDeleteConfirmation(_ task: Task) -> String {
        let warningStyle = Style().foreground(.red).bold()
        return """
        \(warningStyle.render("⚠️  Delete Task?"))
        
        Are you sure you want to delete:
        "\(task.title)"
        
        \(Style().faint().render("Press 'y' to confirm, 'n' to cancel"))
        """
    }
    
    private func renderFooter() -> String {
        let shortcuts: [String]
        
        switch mode {
        case .normal:
            shortcuts = [
                "j/↓: Down",
                "k/↑: Up",
                "Space: Toggle",
                "a: Add",
                "e: Edit",
                "d: Delete",
                "p: Priority",
                "/: Search",
                "1-5: Filter",
                "q: Quit"
            ]
        case .adding, .editing:
            shortcuts = [
                "Enter: Save",
                "Esc: Cancel"
            ]
        case .searching:
            shortcuts = [
                "Enter: Search",
                "Esc: Exit search",
                "↑/↓: Navigate results"
            ]
        case .confirmDelete:
            shortcuts = [
                "y: Yes, delete",
                "n: No, cancel"
            ]
        }
        
        let shortcutStyle = Style().faint()
        return shortcutStyle.render(shortcuts.joined(separator: " │ "))
    }
}
```

## Step 5: Wire It All Together

Create the main application in `Sources/TaskManager/main.swift`:

```swift
import Matcha

@main
struct TaskManagerApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        
        // Configure input handling
        options.filter = { model, message in
            // Mode-specific input handling
            switch model.mode {
            case .adding, .editing:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return TaskModel.Message.saveTask
                    case .escape:
                        return TaskModel.Message.cancelEdit
                    case .character(let char):
                        if model.titleInput.focused {
                            return TaskModel.Message.titleInputMsg(.characterInput(char))
                        } else if model.descriptionInput.focused {
                            return TaskModel.Message.descriptionInputMsg(.characterInput(char))
                        }
                    case .backspace:
                        if model.titleInput.focused {
                            return TaskModel.Message.titleInputMsg(.backspace)
                        } else if model.descriptionInput.focused {
                            return TaskModel.Message.descriptionInputMsg(.backspace)
                        }
                    case .tab:
                        // Switch between inputs
                        if model.titleInput.focused {
                            return TaskModel.Message.titleInputMsg(.blur)
                        } else {
                            return TaskModel.Message.descriptionInputMsg(.blur)
                        }
                    default:
                        break
                    }
                }
                
            case .searching:
                if let key = message as? Key {
                    switch key {
                    case .escape:
                        return TaskModel.Message.toggleSearch
                    case .character(let char):
                        return TaskModel.Message.searchInputMsg(.characterInput(char))
                    case .backspace:
                        return TaskModel.Message.searchInputMsg(.backspace)
                    case .up:
                        return TaskModel.Message.moveUp
                    case .down:
                        return TaskModel.Message.moveDown
                    default:
                        break
                    }
                }
                
            case .confirmDelete:
                if let key = message as? Key {
                    switch key.description {
                    case "y", "Y":
                        return TaskModel.Message.confirmDelete(true)
                    case "n", "N", "escape":
                        return TaskModel.Message.confirmDelete(false)
                    default:
                        break
                    }
                }
                
            case .normal:
                if let key = message as? Key {
                    switch key.description {
                    case "j", "down":
                        return TaskModel.Message.moveDown
                    case "k", "up":
                        return TaskModel.Message.moveUp
                    case " ", "enter":
                        return TaskModel.Message.select
                    case "a":
                        return TaskModel.Message.startAdd
                    case "e":
                        return TaskModel.Message.startEdit
                    case "d":
                        return TaskModel.Message.deleteTask
                    case "p":
                        return TaskModel.Message.changePriority
                    case "/":
                        return TaskModel.Message.toggleSearch
                    case "1":
                        return TaskModel.Message.changeFilter(.all)
                    case "2":
                        return TaskModel.Message.changeFilter(.active)
                    case "3":
                        return TaskModel.Message.changeFilter(.completed)
                    case "4":
                        return TaskModel.Message.changeFilter(.highPriority)
                    case "5":
                        return TaskModel.Message.changeFilter(.dueSoon)
                    case "q", "ctrl+c":
                        return QuitMsg()
                    default:
                        break
                    }
                }
            }
            
            return message
        }
        
        let program = Program(
            initialModel: TaskModel(),
            options: options
        )
        
        _ = try await program.run()
        print("\nTasks saved. Goodbye! 👋")
    }
}
```

## Step 6: Run Your Task Manager

Build and run your application:

```bash
swift build
swift run
```

## Exercises

Now that you have a working task manager, try these exercises:

### 1. Add Due Dates
Extend the task model to include due dates:
- Add a date picker mode
- Show tasks due today in red
- Sort by due date

### 2. Task Categories
Add categories/tags to tasks:
- Create a category selection mode
- Filter by category
- Show category colors

### 3. Data Export
Add export functionality:
- Export to CSV
- Export to Markdown
- Import from CSV

### 4. Statistics View
Create a statistics screen:
- Tasks completed this week
- Average completion time
- Productivity trends

## Complete Source Code

The complete source code for this tutorial is available at:
[Examples/Tutorials/TaskManager](https://github.com/yourusername/matcha/tree/main/Examples/Tutorials/TaskManager)

## What's Next?

Congratulations! You've built a fully functional task manager. You've learned:
- ✅ The Elm Architecture pattern
- ✅ State management with models
- ✅ Handling keyboard input
- ✅ Working with components (TextInput)
- ✅ File I/O for persistence
- ✅ Complex UI layouts

Ready for more? Continue to [Tutorial 2: File Explorer](02-file-explorer.md) where we'll build a more complex application with split panes and file operations!