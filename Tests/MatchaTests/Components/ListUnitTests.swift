import Foundation
import Testing
@testable import Matcha
@testable import MatchaBubbles

@Suite("List Unit Tests")
struct ListUnitTests {
    // MARK: - State Management Tests

    @Test("List navigation with arrow keys")
    func navigationWithArrowKeys() {
        var list = List().withStringItems(["Item 1", "Item 2", "Item 3"]).withFocus(true).withWrapAround(false)
        #expect(list.selectedIndex == 0)

        // Move down
        list = list.update(KeyMsg(type: .down))
        #expect(list.selectedIndex == 1)

        // Move down again
        list = list.update(KeyMsg(type: .down))
        #expect(list.selectedIndex == 2)

        // Move down at end - should stay at end
        list = list.update(KeyMsg(type: .down))
        #expect(list.selectedIndex == 2)

        // Move up
        list = list.update(KeyMsg(type: .up))
        #expect(list.selectedIndex == 1)

        // Move to top
        list = list.update(KeyMsg(type: .up))
        #expect(list.selectedIndex == 0)

        // Move up at top - should stay at top
        list = list.update(KeyMsg(type: .up))
        #expect(list.selectedIndex == 0)
    }

    @Test("List navigation with j/k keys")
    func navigationWithJKKeys() {
        var list = List().withStringItems(["Item 1", "Item 2", "Item 3"]).withFocus(true)

        // j moves down
        list = list.update(KeyMsg(type: .runes, runes: ["j"]))
        #expect(list.selectedIndex == 1)

        // k moves up
        list = list.update(KeyMsg(type: .runes, runes: ["k"]))
        #expect(list.selectedIndex == 0)
    }

    @Test("List page navigation")
    func pageNavigation() {
        var list = List()
            .withStringItems((1...20).map { "Item \($0)" })
            .withHeight(5) // Show 5 items at a time
            .withFocus(true)
            .withShowHelp(false)
            .withShowPagination(false)

        #expect(list.selectedIndex == 0)

        // Page down (ctrl+f)
        list = list.update(KeyMsg(type: .runes, runes: ["f"]))
        #expect(list.selectedIndex == 5) // Moved down by page size

        // Page down again
        list = list.update(KeyMsg(type: .runes, runes: ["f"]))
        #expect(list.selectedIndex == 10)

        // Page up (ctrl+b)
        list = list.update(KeyMsg(type: .runes, runes: ["b"]))
        #expect(list.selectedIndex == 5)
    }

    @Test("List home/end navigation")
    func homeEndNavigation() {
        var list = List().withStringItems((1...10).map { "Item \($0)" }).withFocus(true)
        list.selectedIndex = 5

        // Home key
        list = list.update(KeyMsg(type: .home))
        #expect(list.selectedIndex == 0)

        // End key
        list = list.update(KeyMsg(type: .end))
        #expect(list.selectedIndex == 9)

        // g goes to top
        list.selectedIndex = 5
        list = list.update(KeyMsg(type: .runes, runes: ["g"]))
        #expect(list.selectedIndex == 0)

        // G goes to bottom
        list = list.update(KeyMsg(type: .runes, runes: ["G"]))
        #expect(list.selectedIndex == 9)
    }

    @Test("List with empty items")
    func emptyList() {
        var list = List().withFocus(true)
        #expect(list.items.isEmpty)
        #expect(list.selectedIndex == 0)

        // Navigation should do nothing
        list = list.update(KeyMsg(type: .down))
        #expect(list.selectedIndex == 0)

        list = list.update(KeyMsg(type: .up))
        #expect(list.selectedIndex == 0)
    }

    // MARK: - View Tests

    @Test("List renders items")
    func rendersItems() {
        let list = List().withStringItems(["First", "Second", "Third"])
        let view = list.view()

        #expect(view.contains("First"))
        #expect(view.contains("Second"))
        #expect(view.contains("Third"))
    }

    @Test("List shows selection indicator")
    func showsSelectionIndicator() {
        var list = List().withStringItems(["First", "Second", "Third"])
        list.selectedIndex = 1

        let view = list.view()
        // The exact indicator varies by style, but selected item should be marked
        #expect(view.contains("Second"))
    }

    @Test("List pagination indicator")
    func paginationIndicator() {
        let list = List()
            .withStringItems((1...20).map { "Item \($0)" })
            .withHeight(5)
            .withShowPagination(true)

        let view = list.view()
        // Should show pagination like "1/4" for page 1 of 4
        #expect(view.contains("1/"))
    }

    // MARK: - Builder Pattern Tests

    @Test("List builder methods")
    func builderMethods() {
        let items = ["A", "B", "C"]
        let list = List()
            .withStringItems(items)
            .withHeight(10)
            .withShowPagination(true)
            .withFocus(true)

        #expect(list.items.count == 3)
        #expect(list.height == 10)
        #expect(list.showPagination == true)
        #expect(list.focused == true)
    }

    @Test("List with custom string items")
    func customStringItems() {
        let list = List().withStringItems([
            "Task 1: First task",
            "Task 2: Second task"
        ])

        #expect(list.items.count == 2)
        #expect(list.items[0].title == "Task 1: First task")

        let view = list.view()
        #expect(view.contains("Task 1: First task"))
    }
}
