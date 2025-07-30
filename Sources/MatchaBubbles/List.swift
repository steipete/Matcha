//
//  List.swift
//  MatchaBubbles
//
//  A flexible list component for Matcha TUI applications.
//

import Foundation
import Matcha
import MatchaStyle

/// A list component that displays a selectable list of items
public struct List: Sendable {
    // MARK: - Properties
    
    /// The items in the list
    public var items: [Item]
    
    /// The currently selected index
    public var selectedIndex: Int
    
    /// Whether the list is currently focused
    public var focused: Bool
    
    /// Height of the list (0 means show all items)
    public var height: Int
    
    /// Whether to show help text
    public var showHelp: Bool
    
    /// Whether to show pagination status
    public var showPagination: Bool
    
    /// Whether to wrap around when navigating
    public var wrapAround: Bool
    
    /// The viewport offset for scrolling
    private var viewportOffset: Int
    
    /// Style for normal items
    public var normalStyle: Style
    
    /// Style for the selected item
    public var selectedStyle: Style
    
    /// Style for help text
    public var helpStyle: Style
    
    /// Style for pagination
    public var paginationStyle: Style
    
    /// Prefix for selected items
    public var selectedPrefix: String
    
    /// Prefix for unselected items
    public var unselectedPrefix: String
    
    /// A single item in the list
    public struct Item: Sendable {
        public let title: String
        public let description: String?
        public let value: String
        
        public init(title: String, description: String? = nil, value: String? = nil) {
            self.title = title
            self.description = description
            self.value = value ?? title
        }
        
        /// Creates an item from a simple string
        public init(_ title: String) {
            self.title = title
            self.description = nil
            self.value = title
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new list with default settings
    public init() {
        self.items = []
        self.selectedIndex = 0
        self.focused = false
        self.height = 0
        self.showHelp = true
        self.showPagination = true
        self.wrapAround = true
        self.viewportOffset = 0
        self.normalStyle = Style()
        self.selectedStyle = Style().foreground(.magenta).bold()
        self.helpStyle = Style().faint()
        self.paginationStyle = Style().faint()
        self.selectedPrefix = "> "
        self.unselectedPrefix = "  "
    }
    
    // MARK: - Builder Methods
    
    /// Sets the items
    public func withItems(_ items: [Item]) -> List {
        var list = self
        list.items = items
        // Ensure selected index is valid
        if list.selectedIndex >= items.count && !items.isEmpty {
            list.selectedIndex = items.count - 1
        }
        return list
    }
    
    /// Sets the items from strings
    public func withStringItems(_ items: [String]) -> List {
        withItems(items.map { Item($0) })
    }
    
    /// Sets the selected index
    public func withSelectedIndex(_ index: Int) -> List {
        var list = self
        list.selectedIndex = max(0, min(index, items.count - 1))
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Sets the focus state
    public func withFocus(_ focused: Bool) -> List {
        var list = self
        list.focused = focused
        return list
    }
    
    /// Sets the height
    public func withHeight(_ height: Int) -> List {
        var list = self
        list.height = height
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Sets whether to show help
    public func withShowHelp(_ show: Bool) -> List {
        var list = self
        list.showHelp = show
        return list
    }
    
    /// Sets whether to show pagination
    public func withShowPagination(_ show: Bool) -> List {
        var list = self
        list.showPagination = show
        return list
    }
    
    /// Sets whether to wrap around
    public func withWrapAround(_ wrap: Bool) -> List {
        var list = self
        list.wrapAround = wrap
        return list
    }
    
    /// Sets the selected prefix
    public func withSelectedPrefix(_ prefix: String) -> List {
        var list = self
        list.selectedPrefix = prefix
        return list
    }
    
    /// Sets the unselected prefix
    public func withUnselectedPrefix(_ prefix: String) -> List {
        var list = self
        list.unselectedPrefix = prefix
        return list
    }
    
    // MARK: - Style Methods
    
    /// Sets the normal item style
    public func normalStyle(_ style: Style) -> List {
        var list = self
        list.normalStyle = style
        return list
    }
    
    /// Sets the selected item style
    public func selectedStyle(_ style: Style) -> List {
        var list = self
        list.selectedStyle = style
        return list
    }
    
    /// Sets the help style
    public func helpStyle(_ style: Style) -> List {
        var list = self
        list.helpStyle = style
        return list
    }
    
    /// Sets the pagination style
    public func paginationStyle(_ style: Style) -> List {
        var list = self
        list.paginationStyle = style
        return list
    }
    
    // MARK: - Update Methods
    
    /// Updates the list based on a message
    public func update(_ msg: any Message) -> List {
        guard focused else { return self }
        
        if let key = msg as? KeyMsg {
            return handleKey(key)
        }
        
        return self
    }
    
    private func handleKey(_ key: KeyMsg) -> List {
        // Handle key types first
        switch key.type {
        case .up:
            return moveUp()
        case .down:
            return moveDown()
        case .home:
            return moveToStart()
        case .end:
            return moveToEnd()
        case .pageUp:
            return pageUp()
        case .pageDown:
            return pageDown()
        case .runes:
            // Handle vim-style keybindings
            guard let rune = key.runes.first else { return self }
            switch rune {
            case "j":
                return moveDown()
            case "k":
                return moveUp()
            case "g":
                return moveToStart()
            case "G":
                return moveToEnd()
            case "f":
                return pageDown()  // Ctrl+f in vim
            case "b":
                return pageUp()    // Ctrl+b in vim
            default:
                return self
            }
        default:
            return self
        }
    }
    
    // MARK: - Navigation
    
    /// Moves the selection up
    public func moveUp() -> List {
        guard !items.isEmpty else { return self }
        
        var list = self
        if list.selectedIndex > 0 {
            list.selectedIndex -= 1
        } else if wrapAround {
            list.selectedIndex = items.count - 1
        }
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Moves the selection down
    public func moveDown() -> List {
        guard !items.isEmpty else { return self }
        
        var list = self
        if list.selectedIndex < items.count - 1 {
            list.selectedIndex += 1
        } else if wrapAround {
            list.selectedIndex = 0
        }
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Moves to the start of the list
    public func moveToStart() -> List {
        var list = self
        list.selectedIndex = 0
        list.viewportOffset = 0
        return list
    }
    
    /// Moves to the end of the list
    public func moveToEnd() -> List {
        guard !items.isEmpty else { return self }
        
        var list = self
        list.selectedIndex = items.count - 1
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Moves up by one page
    public func pageUp() -> List {
        guard height > 0 else { return moveToStart() }
        
        var list = self
        var pageSize = height
        if showHelp { pageSize -= 1 }
        if showPagination && height > 0 && items.count > height - 2 { pageSize -= 1 }
        pageSize = max(1, pageSize) // Ensure at least 1
        
        list.selectedIndex = max(0, selectedIndex - pageSize)
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    /// Moves down by one page
    public func pageDown() -> List {
        guard height > 0, !items.isEmpty else { return moveToEnd() }
        
        var list = self
        var pageSize = height
        if showHelp { pageSize -= 1 }
        if showPagination && height > 0 && items.count > height - 2 { pageSize -= 1 }
        pageSize = max(1, pageSize) // Ensure at least 1
        
        list.selectedIndex = min(items.count - 1, selectedIndex + pageSize)
        list.viewportOffset = list.calculateViewportOffset()
        return list
    }
    
    // MARK: - Accessors
    
    /// Returns the currently selected item
    public var selectedItem: Item? {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }
    
    /// Returns the value of the selected item
    public var selectedValue: String? {
        selectedItem?.value
    }
    
    // MARK: - Rendering
    
    /// Renders the list as a string
    public func view() -> String {
        guard !items.isEmpty else {
            return helpStyle.render("(empty list)")
        }
        
        var lines: [String] = []
        
        // Calculate visible range
        let visibleItems: ArraySlice<Item>
        let startIndex: Int
        let endIndex: Int
        
        if height > 0 {
            // Fixed height with scrolling
            let availableHeight = showHelp ? height - 1 : height
            let viewportHeight = showPagination ? availableHeight - 1 : availableHeight
            
            startIndex = viewportOffset
            endIndex = min(viewportOffset + viewportHeight, items.count)
            visibleItems = items[startIndex..<endIndex]
        } else {
            // Show all items
            startIndex = 0
            endIndex = items.count
            visibleItems = items[...]
        }
        
        // Render visible items
        for (offset, item) in visibleItems.enumerated() {
            let absoluteIndex = startIndex + offset
            let isSelected = absoluteIndex == selectedIndex
            let prefix = isSelected ? selectedPrefix : unselectedPrefix
            let style = isSelected ? selectedStyle : normalStyle
            
            var line = prefix + item.title
            if let desc = item.description {
                line += " - " + desc
            }
            
            lines.append(style.render(line))
        }
        
        // Add pagination if needed
        if showPagination && height > 0 && items.count > height - 2 {
            let current = selectedIndex + 1
            let total = items.count
            let pagination = "[\(current)/\(total)]"
            lines.append(paginationStyle.render(pagination))
        }
        
        // Add help text
        if showHelp {
            let help = "↑/↓: navigate • enter: select • q: quit"
            lines.append(helpStyle.render(help))
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Private Methods
    
    private func calculateViewportOffset() -> Int {
        guard height > 0 else { return 0 }
        
        let availableHeight = showHelp ? height - 1 : height
        let viewportHeight = showPagination ? availableHeight - 1 : availableHeight
        
        // Keep selected item visible
        if selectedIndex < viewportOffset {
            return selectedIndex
        } else if selectedIndex >= viewportOffset + viewportHeight {
            return selectedIndex - viewportHeight + 1
        }
        
        return viewportOffset
    }
}