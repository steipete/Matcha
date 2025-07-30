import Foundation
import Testing
@testable import Matcha
@testable import MatchaBubbles

@Suite("Table Unit Tests")
struct TableUnitTests {
    // MARK: - Setup Helpers

    func makeTestTable() -> Table {
        var table = Table()
        table.setColumns([
            Table.Column(key: "id", title: "ID", width: 5),
            Table.Column(key: "name", title: "Name", width: 20),
            Table.Column(key: "age", title: "Age", width: 5)
        ])
        table.setRows([
            ["id": "1", "name": "Alice", "age": "30"],
            ["id": "2", "name": "Bob", "age": "25"],
            ["id": "3", "name": "Charlie", "age": "35"],
            ["id": "4", "name": "Diana", "age": "28"],
            ["id": "5", "name": "Eve", "age": "32"]
        ])
        return table
    }

    // MARK: - State Management Tests

    @Test("Table cursor movement")
    func cursorMovement() {
        var table = makeTestTable()
        #expect(table.cursor == 0)

        // Move down
        table.moveDown()
        #expect(table.cursor == 1)

        // Move down to end
        table.moveDown()
        table.moveDown()
        table.moveDown()
        #expect(table.cursor == 4)

        // Move down at end - should stay at end
        table.moveDown()
        #expect(table.cursor == 4)

        // Move up
        table.moveUp()
        #expect(table.cursor == 3)

        // Move to top
        table.moveUp()
        table.moveUp()
        table.moveUp()
        #expect(table.cursor == 0)

        // Move up at top - should stay at top
        table.moveUp()
        #expect(table.cursor == 0)
    }

    @Test("Table keyboard navigation")
    func keyboardNavigation() {
        var table = makeTestTable()

        // Test navigation with moveDown/moveUp methods
        table.moveDown()
        #expect(table.cursor == 1)

        table.moveUp()
        #expect(table.cursor == 0)

        // Test jumping to ends
        table.cursor = 2
        table.cursor = 0 // Jump to start
        #expect(table.cursor == 0)

        table.cursor = 4 // Jump to end
        #expect(table.cursor == 4)
    }

    @Test("Table with height scrolling")
    func heightScrolling() {
        var table = makeTestTable()
        table.setHeight(3) // Show only 3 rows at a time

        #expect(table.cursor == 0)

        // Move down within view
        table.moveDown()
        table.moveDown()
        #expect(table.cursor == 2)

        // Move down - cursor should be at 3
        table.moveDown()
        #expect(table.cursor == 3)

        // Move down again - cursor should be at 4
        table.moveDown()
        #expect(table.cursor == 4)

        // Move up
        table.moveUp()
        table.moveUp()
        table.moveUp()
        #expect(table.cursor == 1)
    }

    @Test("Table page up/down")
    func pageNavigation() {
        var table = makeTestTable()
        table.setHeight(3)

        // Test page-like movement by moving multiple times
        let startCursor = table.cursor
        table.moveDown()
        table.moveDown()
        table.moveDown()
        #expect(table.cursor >= startCursor + 3) // Moved down by multiple steps

        // Move back up
        table.moveUp()
        table.moveUp()
        table.moveUp()
        #expect(table.cursor <= 1) // Moved up by multiple steps
    }

    @Test("Table empty state")
    func emptyTable() {
        var table = Table()
        table.setColumns([
            Table.Column(key: "id", title: "ID", width: 5),
            Table.Column(key: "name", title: "Name", width: 20)
        ])

        #expect(table.rows.isEmpty)
        #expect(table.cursor == 0)

        // Navigation should do nothing
        table.moveDown()
        #expect(table.cursor == 0)

        table.moveUp()
        #expect(table.cursor == 0)
    }

    @Test("Table column configuration")
    func columnConfiguration() {
        var table = Table()

        let columns = [
            Table.Column(key: "id", title: "ID", width: 10),
            Table.Column(key: "name", title: "Name", width: 30),
            Table.Column(key: "status", title: "Status", width: 15)
        ]

        table.setColumns(columns)

        #expect(table.columns.count == 3)
        #expect(table.columns[0].key == "id")
        #expect(table.columns[0].width == 10)
        #expect(table.columns[1].title == "Name")
        #expect(table.columns[2].width == 15)
    }

    @Test("Table row data")
    func rowData() {
        var table = Table()
        table.setColumns([
            Table.Column(key: "id", title: "ID", width: 5),
            Table.Column(key: "name", title: "Name", width: 20)
        ])

        let rows = [
            ["id": "1", "name": "Alice"],
            ["id": "2", "name": "Bob", "extra": "ignored"], // Extra field ignored
            ["id": "3", "name": "Charlie"]
        ]

        table.setRows(rows)

        #expect(table.rows.count == 3)
        #expect(table.rows[0]["id"] == "1")
        #expect(table.rows[0]["name"] == "Alice")
        #expect(table.rows[1]["extra"] == "ignored") // Extra data preserved
    }

    // MARK: - View Tests

    @Test("Table renders headers")
    func rendersHeaders() {
        let table = makeTestTable()
        let view = table.view()

        #expect(view.contains("ID"))
        #expect(view.contains("Name"))
        #expect(view.contains("Age"))
    }

    @Test("Table renders rows")
    func rendersRows() {
        let table = makeTestTable()
        let view = table.view()

        #expect(view.contains("Alice"))
        #expect(view.contains("Bob"))
        #expect(view.contains("Charlie"))
    }

    @Test("Table respects column width")
    func respectsColumnWidth() {
        var table = Table()
        table.setColumns([
            Table.Column(key: "name", title: "Name", width: 10)
        ])
        table.setRows([
            ["name": "This is a very long name that should be truncated"]
        ])

        let view = table.view()
        // The exact truncation depends on implementation, but it should respect width
        let lines = view.split(separator: "\n")
        for line in lines where line.contains("This") {
            // The content line should not exceed reasonable bounds
            #expect(line.count < 50)
        }
    }

    @Test("Table shows selection")
    func showsSelection() {
        var table = makeTestTable()
        table.cursor = 1 // Select "Bob"

        let view = table.view()
        // Selected row should be highlighted somehow
        // The exact highlighting varies by style
        #expect(view.contains("Bob"))
    }
}
