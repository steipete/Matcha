//
//  TestFixtures.swift
//  MatchaTests
//
//  Common test fixtures and sample models.
//

import Foundation
@testable import Matcha

// MARK: - Simple Test Model

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
    
    public func update(_ message: TestMessage) -> (TestModel, Command<TestMessage>?) {
        var model = self
        
        switch message {
        case .increment:
            model.value += 1
            return (model, nil)
            
        case .decrement:
            model.value -= 1
            return (model, nil)
            
        case .setText(let text):
            model.text = text
            return (model, nil)
            
        case .start:
            model.isRunning = true
            return (model, every(.seconds(1)) { _ in .tick })
            
        case .stop:
            model.isRunning = false
            return (model, nil)
            
        case .tick:
            model.value += 1
            return (model, model.isRunning ? every(.seconds(1)) { _ in .tick } : nil)
            
        case .quit:
            return (model, quit())
        }
    }
    
    public func view() -> String {
        return """
        Value: \(value)
        Text: \(text)
        Running: \(isRunning)
        """
    }
}

public enum TestMessage: Message {
    case increment
    case decrement
    case setText(String)
    case start
    case stop
    case tick
    case quit
}

// MARK: - Complex Test Model

/// A more complex model for testing advanced features
public struct ComplexTestModel: Model {
    public typealias Msg = ComplexMessage
    
    public var items: [String] = []
    public var selectedIndex: Int = 0
    public var filter: String = ""
    public var error: String?
    public var isLoading: Bool = false
    
    public init() {}
    
    public func update(_ message: ComplexMessage) -> (ComplexTestModel, Command<ComplexMessage>?) {
        var model = self
        
        switch message {
        case .addItem(let item):
            model.items.append(item)
            return (model, nil)
            
        case .removeItem(let index):
            guard index < model.items.count else {
                model.error = "Invalid index"
                return (model, nil)
            }
            model.items.remove(at: index)
            if model.selectedIndex >= model.items.count && model.selectedIndex > 0 {
                model.selectedIndex = model.items.count - 1
            }
            return (model, nil)
            
        case .selectItem(let index):
            guard index < model.items.count else {
                model.error = "Invalid index"
                return (model, nil)
            }
            model.selectedIndex = index
            return (model, nil)
            
        case .setFilter(let filter):
            model.filter = filter
            return (model, nil)
            
        case .startLoading:
            model.isLoading = true
            model.error = nil
            return (model, loadData())
            
        case .dataLoaded(let items):
            model.isLoading = false
            model.items = items
            return (model, nil)
            
        case .loadFailed(let error):
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
        
        if let error = error {
            view += "\nError: \(error)\n"
        }
        
        if isLoading {
            view += "\nLoading...\n"
        }
        
        return view
    }
    
    private func loadData() -> Command<ComplexMessage> {
        return Command { () async -> ComplexMessage? in
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

public enum ComplexMessage: Message {
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
    return [
        ("q", "Quit"),
        ("j", "Move down"),
        ("k", "Move up"),
        ("enter", "Select"),
        ("esc", "Cancel")
    ]
}

/// Creates sample table data
public func sampleTableData() -> [[String: String]] {
    return [
        ["name": "Alice", "age": "30", "city": "New York"],
        ["name": "Bob", "age": "25", "city": "San Francisco"],
        ["name": "Charlie", "age": "35", "city": "Chicago"],
        ["name": "Diana", "age": "28", "city": "Boston"],
    ]
}

/// Generates a random string of specified length
public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}