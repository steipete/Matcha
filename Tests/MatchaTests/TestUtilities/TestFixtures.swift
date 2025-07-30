import Foundation
@testable import Matcha

// MARK: - TestModel

/// A minimal test model for basic testing
public struct TestModel: Model {
    public typealias Msg = TestMessage

    public var value: Int = 0
    public var text: String = ""
    public var isRunning: Bool = false

    public init() {}

    public init(value: Int, text: String = "") {
        self.value = value
        self.text = text
    }

    public func `init`() -> Command<TestMessage>? {
        nil
    }

    public func update(_ message: TestMessage) -> (TestModel, Command<TestMessage>?) {
        var model = self

        switch message {
        case .increment:
            model.value += 1
            return (model, nil)

        case .decrement:
            model.value -= 1
            return (model, nil)

        case let .setText(text):
            model.text = text
            return (model, nil)

        case .start:
            model.isRunning = true
            return (model, Tick(.seconds(1)) { _ in .tick })

        case .stop:
            model.isRunning = false
            return (model, nil)

        case .tick:
            model.value += 1
            return (model, model.isRunning ? Tick(.seconds(1)) { _ in .tick } : nil)

        case .quit:
            return (model, quit())
        }
    }

    public func view() -> String {
        """
        Value: \(value)
        Text: \(text)
        Running: \(isRunning)
        """
    }
}

// MARK: - TestMessage

public enum TestMessage: Message, Equatable {
    case increment
    case decrement
    case setText(String)
    case start
    case stop
    case tick
    case quit
}

// MARK: - ComplexTestModel

/// A more complex model for testing advanced features
public struct ComplexTestModel: Model {
    public typealias Msg = ComplexMessage

    public var items: [String] = []
    public var selectedIndex: Int = 0
    public var filter: String = ""
    public var error: String?
    public var isLoading: Bool = false

    public init() {}

    public func `init`() -> Command<ComplexMessage>? {
        nil
    }

    public func update(_ message: ComplexMessage) -> (ComplexTestModel, Command<ComplexMessage>?) {
        var model = self

        switch message {
        case let .addItem(item):
            model.items.append(item)
            return (model, nil)

        case let .removeItem(index):
            guard index < model.items.count else {
                model.error = "Invalid index"
                return (model, nil)
            }
            model.items.remove(at: index)
            if model.selectedIndex >= model.items.count, model.selectedIndex > 0 {
                model.selectedIndex = model.items.count - 1
            }
            return (model, nil)

        case let .selectItem(index):
            guard index < model.items.count else {
                model.error = "Invalid index"
                return (model, nil)
            }
            model.selectedIndex = index
            return (model, nil)

        case let .setFilter(filter):
            model.filter = filter
            return (model, nil)

        case .startLoading:
            model.isLoading = true
            model.error = nil
            return (model, loadData())

        case let .dataLoaded(items):
            model.isLoading = false
            model.items = items
            return (model, nil)

        case let .loadFailed(error):
            model.isLoading = false
            model.error = error
            return (model, nil)

        case .clearError:
            model.error = nil
            return (model, nil)
        }
    }

    public func view() -> String {
        var view = "Items:\n"

        let filteredItems = filter.isEmpty
            ? items
            : items.filter { $0.localizedCaseInsensitiveContains(filter) }

        for (index, item) in filteredItems.enumerated() {
            let prefix = index == selectedIndex ? "> " : "  "
            view += "\(prefix)\(item)\n"
        }

        if let error {
            view += "\nError: \(error)\n"
        }

        if isLoading {
            view += "\nLoading...\n"
        }

        return view
    }

    private func loadData() -> Command<ComplexMessage> {
        Command { () async -> ComplexMessage? in
            // Simulate async data loading
            try? await Task.sleep(for: .milliseconds(100))

            // Simulate random success/failure
            if Bool.random() {
                return .dataLoaded(["Item 1", "Item 2", "Item 3"])
            } else {
                return .loadFailed("Network error")
            }
        }
    }
}

// MARK: - ComplexMessage

public enum ComplexMessage: Message, Equatable {
    case addItem(String)
    case removeItem(Int)
    case selectItem(Int)
    case setFilter(String)
    case startLoading
    case dataLoaded([String])
    case loadFailed(String)
    case clearError
}

// MARK: - Test Helpers

/// Creates a sample key binding configuration
public func sampleKeyBindings() -> [(String, String)] {
    [
        ("q", "Quit"),
        ("j", "Move down"),
        ("k", "Move up"),
        ("enter", "Select"),
        ("esc", "Cancel")
    ]
}

/// Creates sample table data
public func sampleTableData() -> [[String: String]] {
    [
        ["name": "Alice", "age": "30", "city": "New York"],
        ["name": "Bob", "age": "25", "city": "San Francisco"],
        ["name": "Charlie", "age": "35", "city": "Chicago"],
        ["name": "Diana", "age": "28", "city": "Boston"]
    ]
}

/// Generates a random string of specified length
public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}
