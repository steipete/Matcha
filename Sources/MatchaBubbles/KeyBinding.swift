import Foundation
import Matcha
import MatchaStyle

// MARK: - KeyBinding

/// A single key binding that maps keys to actions
public struct KeyBinding: Sendable, Equatable {
    /// The keys that trigger this binding
    public let keys: [String]

    /// The help text for this binding
    public let help: KeyHelp

    /// Whether this binding is currently enabled
    public var enabled: Bool

    /// Creates a new key binding
    public init(keys: [String], help: KeyHelp, enabled: Bool = true) {
        self.keys = keys
        self.help = help
        self.enabled = enabled
    }

    /// Creates a new key binding with simple string help
    public init(keys: [String], help: String, enabled: Bool = true) {
        self.keys = keys
        self.help = KeyHelp(key: keys.first ?? "", desc: help)
        self.enabled = enabled
    }
}

// MARK: - KeyHelp

/// Help information for a key binding
public struct KeyHelp: Sendable, Equatable {
    /// The key representation to show
    public let key: String

    /// The description of what the key does
    public let desc: String

    /// Whether this help is a separator
    public let isSeparator: Bool

    /// Creates key help
    public init(key: String = "", desc: String = "", isSeparator: Bool = false) {
        self.key = key
        self.desc = desc
        self.isSeparator = isSeparator
    }

    /// Creates a separator
    public static func separator() -> KeyHelp {
        KeyHelp(isSeparator: true)
    }
}

// MARK: - KeyMap

/// A collection of key bindings organized by category
public struct KeyMap: Sendable {
    /// Storage for bindings by category
    private var bindings: [String: [KeyBinding]]

    /// Creates an empty key map
    public init() {
        self.bindings = [:]
    }

    /// Creates a key map with initial bindings
    public init(_ bindings: [String: [KeyBinding]]) {
        self.bindings = bindings
    }

    // MARK: - Accessors

    /// Gets bindings for a category
    public func bindings(for category: String) -> [KeyBinding] {
        bindings[category] ?? []
    }

    /// Gets all categories
    public var categories: [String] {
        Array(bindings.keys).sorted()
    }

    /// Gets all bindings across all categories
    public var allBindings: [KeyBinding] {
        bindings.values.flatMap(\.self)
    }

    /// Checks if any key matches any binding
    public func matches(_ key: String) -> Bool {
        allBindings.contains { binding in
            binding.enabled && binding.keys.contains(key)
        }
    }

    /// Gets the first enabled binding that matches the key
    public func binding(for key: String) -> KeyBinding? {
        allBindings.first { binding in
            binding.enabled && binding.keys.contains(key)
        }
    }

    // MARK: - Mutating Methods

    /// Adds a binding to a category
    public mutating func add(_ binding: KeyBinding, to category: String) {
        if bindings[category] == nil {
            bindings[category] = []
        }
        bindings[category]?.append(binding)
    }

    /// Adds multiple bindings to a category
    public mutating func add(_ newBindings: [KeyBinding], to category: String) {
        if bindings[category] == nil {
            bindings[category] = []
        }
        bindings[category]?.append(contentsOf: newBindings)
    }

    /// Removes all bindings for a category
    public mutating func removeCategory(_ category: String) {
        bindings.removeValue(forKey: category)
    }

    /// Enables or disables a binding by its keys
    public mutating func setEnabled(_ enabled: Bool, for keys: [String]) {
        for (category, categoryBindings) in bindings {
            bindings[category] = categoryBindings.map { binding in
                if binding.keys == keys {
                    var updated = binding
                    updated.enabled = enabled
                    return updated
                }
                return binding
            }
        }
    }

    /// Merges another key map into this one
    public mutating func merge(_ other: KeyMap) {
        for (category, otherBindings) in other.bindings {
            if bindings[category] == nil {
                bindings[category] = otherBindings
            } else {
                bindings[category]?.append(contentsOf: otherBindings)
            }
        }
    }
}

// MARK: - KeyMapBuilder

/// Helper for building key maps fluently
public struct KeyMapBuilder {
    private var keyMap = KeyMap()
    private var currentCategory: String?

    /// Creates a new builder
    public init() {}

    /// Sets the current category for subsequent bindings
    public func category(_ name: String) -> KeyMapBuilder {
        var builder = self
        builder.currentCategory = name
        return builder
    }

    /// Adds a binding to the current category
    public func bind(_ keys: String..., help: String, enabled: Bool = true) -> KeyMapBuilder {
        guard let category = currentCategory else {
            fatalError("No category set. Call category() first.")
        }

        var builder = self
        let binding = KeyBinding(keys: keys, help: help, enabled: enabled)
        builder.keyMap.add(binding, to: category)
        return builder
    }

    /// Adds a binding with custom help to the current category
    public func bind(_ keys: String..., help: KeyHelp, enabled: Bool = true) -> KeyMapBuilder {
        guard let category = currentCategory else {
            fatalError("No category set. Call category() first.")
        }

        var builder = self
        let binding = KeyBinding(keys: keys, help: help, enabled: enabled)
        builder.keyMap.add(binding, to: category)
        return builder
    }

    /// Adds a separator to the current category
    public func separator() -> KeyMapBuilder {
        guard let category = currentCategory else {
            fatalError("No category set. Call category() first.")
        }

        var builder = self
        let binding = KeyBinding(keys: [], help: KeyHelp.separator())
        builder.keyMap.add(binding, to: category)
        return builder
    }

    /// Builds the final key map
    public func build() -> KeyMap {
        keyMap
    }
}

/// Common key binding patterns
public extension KeyBinding {
    /// Navigation bindings
    static let navigationBindings = [
        KeyBinding(keys: ["up", "k"], help: "Move up"),
        KeyBinding(keys: ["down", "j"], help: "Move down"),
        KeyBinding(keys: ["left", "h"], help: "Move left"),
        KeyBinding(keys: ["right", "l"], help: "Move right"),
        KeyBinding(keys: ["pgup", "ctrl+u"], help: "Page up"),
        KeyBinding(keys: ["pgdown", "ctrl+d"], help: "Page down"),
        KeyBinding(keys: ["home", "g"], help: "Go to start"),
        KeyBinding(keys: ["end", "G"], help: "Go to end"),
    ]

    /// Common action bindings
    static let actionBindings = [
        KeyBinding(keys: ["enter", " "], help: "Select/Confirm"),
        KeyBinding(keys: ["esc"], help: "Cancel/Back"),
        KeyBinding(keys: ["tab"], help: "Next field"),
        KeyBinding(keys: ["shift+tab"], help: "Previous field"),
        KeyBinding(keys: ["ctrl+c", "q"], help: "Quit"),
    ]

    /// Editing bindings
    static let editBindings = [
        KeyBinding(keys: ["ctrl+a"], help: "Select all"),
        KeyBinding(keys: ["ctrl+x"], help: "Cut"),
        KeyBinding(keys: ["ctrl+c"], help: "Copy"),
        KeyBinding(keys: ["ctrl+v"], help: "Paste"),
        KeyBinding(keys: ["ctrl+z"], help: "Undo"),
        KeyBinding(keys: ["ctrl+shift+z", "ctrl+y"], help: "Redo"),
    ]
}

/// Extension to make key bindings work with Help component
public extension KeyMap {
    /// Converts the key map to help groups for the Help component
    func helpGroups() -> [Help.Group] {
        var result: [Help.Group] = []

        for category in categories {
            let categoryBindings = bindings(for: category)
            let helpBindings = categoryBindings.compactMap { binding -> Help.Binding? in
                guard binding.enabled else { return nil }

                if binding.help.isSeparator {
                    // Skip separators for now - Help component doesn't directly support them
                    return nil
                }

                // Use the help key if provided, otherwise use the first binding key
                let displayKeys = binding.help.key.isEmpty ? binding.keys : [binding.help.key]
                return Help.Binding(keys: displayKeys, description: binding.help.desc, disabled: !binding.enabled)
            }

            if !helpBindings.isEmpty {
                result.append(Help.Group(title: category, bindings: helpBindings))
            }
        }

        return result
    }
}

/// Protocol for models that use key bindings
public protocol KeyBindable {
    /// The key map for this model
    var keyMap: KeyMap { get }

    /// Checks if a key matches any binding
    func matches(_ key: Key) -> Bool

    /// Gets the binding for a key
    func binding(for key: Key) -> KeyBinding?
}

/// Default implementation for KeyBindable
public extension KeyBindable {
    func matches(_ key: Key) -> Bool {
        keyMap.matches(key.description)
    }

    func binding(for key: Key) -> KeyBinding? {
        keyMap.binding(for: key.description)
    }
}
