import Foundation
import Matcha
import MatchaStyle

/// A table component for displaying structured data in a grid layout.
///
/// The Table component provides a scrollable grid view with:
/// - Configurable columns with fixed widths
/// - Row selection and navigation
/// - Optional borders with box-drawing characters
/// - Header row with customizable styling
/// - Viewport scrolling for large datasets
/// - Focus state support for keyboard navigation
///
/// Example usage:
/// ```swift
/// var table = Table()
/// table.setColumns([
///     Column(key: "name", title: "Name", width: 20),
///     Column(key: "age", title: "Age", width: 10)
/// ])
/// table.setRows([
///     ["name": "Alice", "age": "30"],
///     ["name": "Bob", "age": "25"]
/// ])
/// let rendered = table.view()
/// ```
public struct Table: Sendable {
    /// Defines a table column with its key, title, and width.
    ///
    /// The key is used to extract values from row dictionaries,
    /// while the title is displayed in the header row.
    public struct Column: Sendable {
        public let key: String
        public let title: String
        public let width: Int

        public init(key: String, title: String, width: Int) {
            self.key = key
            self.title = title
            self.width = width
        }
    }

    // MARK: - Properties

    /// Column definitions for the table
    public var columns: [Column] = []
    /// Data rows as dictionaries mapping column keys to values
    public var rows: [[String: String]] = []
    /// Current cursor position (selected row index)
    public var cursor: Int = 0
    /// Whether to draw borders around the table
    public var showBorder: Bool = true
    /// Whether the table has keyboard focus
    public var focus: Bool = false

    // MARK: - Styles

    /// Style applied to the header row
    public var headerStyle = Style().bold()
    /// Style applied to the selected row when focused
    public var selectedStyle = Style().foreground(.cyan)
    /// Style applied to table borders
    public var borderStyle = Style().foreground(.brightBlack)

    // MARK: - Viewport Management

    /// Starting row index for the visible viewport
    private var offset: Int = 0
    /// Number of rows to display in the viewport
    private var height: Int = 10

    /// Creates a new empty table
    public init() {}

    // MARK: - Configuration

    /// Sets the table columns.
    /// - Parameter columns: Array of column definitions
    public mutating func setColumns(_ columns: [Column]) {
        self.columns = columns
    }

    /// Sets the table data rows.
    ///
    /// Automatically adjusts cursor position if it becomes out of bounds.
    /// - Parameter rows: Array of dictionaries mapping column keys to values
    public mutating func setRows(_ rows: [[String: String]]) {
        self.rows = rows
        if cursor >= rows.count, !rows.isEmpty {
            cursor = rows.count - 1
        }
    }

    /// Sets the viewport height (number of visible rows).
    /// - Parameter height: Number of rows to display
    public mutating func setHeight(_ height: Int) {
        self.height = height
    }

    // MARK: - Navigation

    /// Moves the cursor up one row.
    ///
    /// Automatically scrolls the viewport if the cursor moves outside
    /// the visible area.
    public mutating func moveUp() {
        if cursor > 0 {
            cursor -= 1

            // Adjust viewport if needed
            if cursor < offset {
                offset = cursor
            }
        }
    }

    /// Moves the cursor down one row.
    ///
    /// Automatically scrolls the viewport if the cursor moves outside
    /// the visible area.
    public mutating func moveDown() {
        if cursor < rows.count - 1 {
            cursor += 1

            // Adjust viewport if needed
            if cursor >= offset + height {
                offset = cursor - height + 1
            }
        }
    }

    /// Jumps to the first row in the table.
    /// Resets both cursor and viewport offset.
    public mutating func goToTop() {
        cursor = 0
        offset = 0
    }

    /// Jumps to the last row in the table.
    /// Adjusts viewport to show the bottom row.
    public mutating func goToBottom() {
        cursor = rows.count - 1
        offset = max(0, rows.count - height)
    }

    // MARK: - Rendering

    /// Renders the table as a string.
    ///
    /// The table is rendered with:
    /// - Optional box-drawing borders
    /// - Header row with column titles
    /// - Data rows within the current viewport
    /// - Selection highlighting when focused
    ///
    /// Cells are padded to their column width and truncated if necessary.
    ///
    /// - Returns: String representation of the table
    public func view() -> String {
        var lines: [String] = []

        if showBorder {
            // Top border
            var topBorder = "┌"
            for (i, col) in columns.enumerated() {
                topBorder += String(repeating: "─", count: col.width)
                if i < columns.count - 1 {
                    topBorder += "┬"
                }
            }
            topBorder += "┐"
            lines.append(borderStyle.render(topBorder))
        }

        // Header row
        var headerRow = showBorder ? borderStyle.render("│") : ""
        for (i, col) in columns.enumerated() {
            let title = col.title.padding(toLength: col.width, withPad: " ", startingAt: 0)
            headerRow += headerStyle.render(title)
            if i < columns.count - 1 || showBorder {
                headerRow += showBorder ? borderStyle.render("│") : " "
            }
        }
        if showBorder {
            headerRow += borderStyle.render("│")
        }
        lines.append(headerRow)

        if showBorder {
            // Header separator
            var separator = "├"
            for (i, col) in columns.enumerated() {
                separator += String(repeating: "─", count: col.width)
                if i < columns.count - 1 {
                    separator += "┼"
                }
            }
            separator += "┤"
            lines.append(borderStyle.render(separator))
        }

        // Data rows
        let endIdx = min(offset + height, rows.count)
        for (idx, row) in rows[offset..<endIdx].enumerated() {
            let rowIdx = offset + idx
            let isSelected = rowIdx == cursor && focus

            var rowLine = showBorder ? borderStyle.render("│") : ""
            for (i, col) in columns.enumerated() {
                let value = row[col.key] ?? ""
                let cellValue = value.padding(toLength: col.width, withPad: " ", startingAt: 0)

                if isSelected {
                    rowLine += selectedStyle.render(cellValue)
                } else {
                    rowLine += cellValue
                }

                if i < columns.count - 1 || showBorder {
                    rowLine += showBorder ? borderStyle.render("│") : " "
                }
            }
            if showBorder {
                rowLine += borderStyle.render("│")
            }
            lines.append(rowLine)
        }

        if showBorder {
            // Bottom border
            var bottomBorder = "└"
            for (i, col) in columns.enumerated() {
                bottomBorder += String(repeating: "─", count: col.width)
                if i < columns.count - 1 {
                    bottomBorder += "┴"
                }
            }
            bottomBorder += "┘"
            lines.append(borderStyle.render(bottomBorder))
        }

        return lines.joined(separator: "\n")
    }
}
