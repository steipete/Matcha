import Testing
@testable import Matcha
@testable import MatchaBubbles

@Suite("Keyboard Shortcut Tests")
struct KeyboardShortcutTests {
    // MARK: - TextInput Keyboard Shortcuts

    @Test("TextInput keyboard shortcuts")
    func textInputKeyboardShortcuts() {
        var input = TextInput()
        input = input.withValue("Hello World")
        input = input.withFocus(true)
        input.cursorPosition = 5 // Cursor after "Hello"

        // Ctrl+A - Move to beginning
        let input1 = input.update(KeyMsg(type: .ctrlA))
        #expect(input1.cursorPosition == 0)

        // Ctrl+E - Move to end
        let input2 = input1.update(KeyMsg(type: .ctrlE))
        #expect(input2.cursorPosition == 11)

        // Left arrow - Move left
        let input3 = input2.update(KeyMsg(type: .left))
        #expect(input3.cursorPosition == 10)

        // Right arrow - Move right
        let input4 = input3.update(KeyMsg(type: .right))
        #expect(input4.cursorPosition == 11)

        // Ctrl+K - Kill to end of line
        input.cursorPosition = 5
        let input5 = input.update(KeyMsg(type: .ctrlK))
        #expect(input5.value == "Hello")
        #expect(input5.cursorPosition == 5)

        // Ctrl+U - Kill to beginning of line
        input = input.withValue("Hello World")
        input.cursorPosition = 5
        let input6 = input.update(KeyMsg(type: .ctrlU))
        #expect(input6.value == " World")
        #expect(input6.cursorPosition == 0)

        // Ctrl+W - Delete word backward
        input = input.withValue("Hello World")
        input.cursorPosition = 11
        let input7 = input.update(KeyMsg(type: .ctrlW))
        #expect(input7.value == "Hello ")
        #expect(input7.cursorPosition == 6)

        // Home - Move to beginning
        input.cursorPosition = 5
        let input8 = input.update(KeyMsg(type: .home))
        #expect(input8.cursorPosition == 0)

        // End - Move to end
        let input9 = input8.update(KeyMsg(type: .end))
        #expect(input9.cursorPosition == input9.value.count)

        // Backspace - Delete backward
        input = input.withValue("Hello World")
        input.cursorPosition = 5
        let input10 = input.update(KeyMsg(type: .backspace))
        #expect(input10.value == "Hell World")
        #expect(input10.cursorPosition == 4)

        // Delete - Delete forward
        input = input.withValue("Hello World")
        input.cursorPosition = 5
        let input11 = input.update(KeyMsg(type: .delete))
        #expect(input11.value == "HelloWorld")
        #expect(input11.cursorPosition == 5)
    }

    @Test("TextInput multi-character shortcuts")
    func textInputMultiCharShortcuts() {
        var input = TextInput()
        input = input.withValue("The quick brown fox").withFocus(true)

        // Regular character input
        input.cursorPosition = 0
        let input1 = input.update(KeyMsg(type: .runes, runes: ["X"]))
        #expect(input1.value == "XThe quick brown fox")
        #expect(input1.cursorPosition == 1)

        // Home key - Move to beginning
        input.cursorPosition = 10
        let input2 = input.update(KeyMsg(type: .home))
        #expect(input2.cursorPosition == 0)

        // End key - Move to end
        let input3 = input2.update(KeyMsg(type: .end))
        #expect(input3.cursorPosition == input.value.count)

        // Insert text with paste
        input.cursorPosition = 4
        let input4 = input.update(PasteMsg(text: " very"))
        #expect(input4.value == "The very quick brown fox")
        #expect(input4.cursorPosition == 9)
    }

    // MARK: - TextArea Keyboard Shortcuts

    @Test("TextArea navigation")
    func textAreaNavigation() {
        var area = TextArea()
        area = area.withFocus(true)
        area.lines = ["Line 1", "Line 2", "Line 3"]
        area.cursorLine = 1 // On "Line 2"
        area.cursorColumn = 0

        // Left arrow - Move left
        area.cursorColumn = 3
        let area1 = area.update(KeyMsg(type: .left))
        #expect(area1.cursorColumn == 2)

        // Right arrow - Move right
        let area2 = area1.update(KeyMsg(type: .right))
        #expect(area2.cursorColumn == 3)

        // Down arrow - Move down
        let area3 = area2.update(KeyMsg(type: .down))
        #expect(area3.cursorLine == 2)

        // Up arrow - Move up
        let area4 = area3.update(KeyMsg(type: .up))
        #expect(area4.cursorLine == 1)

        // Home - Move to beginning of line
        area.cursorColumn = 5
        let area5 = area.update(KeyMsg(type: .home))
        #expect(area5.cursorColumn == 0)

        // End - Move to end of line
        let area6 = area5.update(KeyMsg(type: .end))
        #expect(area6.cursorColumn == 6) // "Line 2" has 6 chars

        // Character input
        area.cursorLine = 0
        area.cursorColumn = 0
        let area7 = area.update(KeyMsg(type: .runes, runes: ["X"]))
        #expect(area7.lines[0] == "XLine 1")
        #expect(area7.cursorColumn == 1)
    }

    @Test("TextArea control shortcuts")
    func textAreaControlShortcuts() {
        var area = TextArea()
        area = area.withFocus(true)
        area.lines = ["First line", "Second line", "Third line"]
        area.cursorLine = 1
        area.cursorColumn = 5

        // Ctrl+A - Beginning of line
        let area1 = area.update(KeyMsg(type: .ctrlA))
        #expect(area1.cursorColumn == 0)

        // Ctrl+E - End of line
        let area2 = area1.update(KeyMsg(type: .ctrlE))
        #expect(area2.cursorColumn == 11) // "Second line" length

        // Ctrl+P - Previous line
        let area3 = area2.update(KeyMsg(type: .ctrlP))
        #expect(area3.cursorLine == 0)

        // Ctrl+N - Next line
        let area4 = area3.update(KeyMsg(type: .ctrlN))
        #expect(area4.cursorLine == 1)

        // Ctrl+F - Forward char
        area.cursorColumn = 5
        let area5 = area.update(KeyMsg(type: .ctrlF))
        #expect(area5.cursorColumn == 6)

        // Ctrl+B - Backward char
        let area6 = area5.update(KeyMsg(type: .ctrlB))
        #expect(area6.cursorColumn == 5)

        // Backspace
        area.cursorLine = 0
        area.cursorColumn = 5
        let area7 = area.update(KeyMsg(type: .backspace))
        #expect(area7.lines[0] == "Firs line")
        #expect(area7.cursorColumn == 4)
    }

    // MARK: - List Keyboard Shortcuts

    @Test("List keyboard navigation")
    func listKeyboardNavigation() {
        var list = List()
        list = list.withStringItems(["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"])
            .withFocus(true)
            .withHeight(3)

        // Down - Move down
        let list1 = list.update(KeyMsg(type: .down))
        #expect(list1.selectedIndex == 1)

        let list2 = list1.update(KeyMsg(type: .down))
        #expect(list2.selectedIndex == 2)

        // Up - Move up
        let list3 = list2.update(KeyMsg(type: .up))
        #expect(list3.selectedIndex == 1)

        let list4 = list3.update(KeyMsg(type: .up))
        #expect(list4.selectedIndex == 0)

        // Home - Go to first
        list = list.withSelectedIndex(3)
        let list5 = list.update(KeyMsg(type: .home))
        #expect(list5.selectedIndex == 0)

        // End - Go to last
        let list6 = list5.update(KeyMsg(type: .end))
        #expect(list6.selectedIndex == 4)

        // PageDown - Page down
        list = list.withSelectedIndex(0)
        let list7 = list.update(KeyMsg(type: .pageDown))
        #expect(list7.selectedIndex == 3) // Move by height (3)

        // PageUp - Page up
        let list8 = list7.update(KeyMsg(type: .pageUp))
        #expect(list8.selectedIndex == 0) // Back to start

        // Character input - j/k for vim navigation
        let list9 = list.update(KeyMsg(type: .runes, runes: ["j"]))
        #expect(list9.selectedIndex == 1) // Move down

        let list10 = list9.update(KeyMsg(type: .runes, runes: ["k"]))
        #expect(list10.selectedIndex == 0) // Move up

        // g/G for vim top/bottom
        let list11 = list10.update(KeyMsg(type: .runes, runes: ["g"]))
        #expect(list11.selectedIndex == 0) // Go to top

        let list12 = list11.update(KeyMsg(type: .runes, runes: ["G"]))
        #expect(list12.selectedIndex == 4) // Go to bottom
    }

    // MARK: - Table Keyboard Shortcuts

    @Test("Table navigation shortcuts")
    func tableNavigationShortcuts() {
        var table = Table()
        table.setColumns([
            Table.Column(key: "col1", title: "Col1", width: 10),
            Table.Column(key: "col2", title: "Col2", width: 10)
        ])
        table.setRows([
            ["col1": "A1", "col2": "B1"],
            ["col1": "A2", "col2": "B2"],
            ["col1": "A3", "col2": "B3"],
            ["col1": "A4", "col2": "B4"],
            ["col1": "A5", "col2": "B5"]
        ])
        table.setHeight(3)

        // Navigation with mutating functions
        table.moveDown()
        #expect(table.cursor == 1)

        table.moveUp()
        #expect(table.cursor == 0)

        // Jump to bottom
        table.goToBottom()
        #expect(table.cursor == 4)

        // Jump to top
        table.goToTop()
        #expect(table.cursor == 0)

        // Move down multiple times
        table.moveDown()
        table.moveDown()
        table.moveDown()
        #expect(table.cursor == 3)

        // Try to move past the bottom
        table.goToBottom()
        table.moveDown()
        #expect(table.cursor == 4) // Should stay at bottom
    }

    // MARK: - FileBrowser Keyboard Shortcuts

    @Test("FileBrowser keyboard shortcuts")
    func fileBrowserKeyboardShortcuts() {
        var browser = FileBrowser()
        browser = browser.withFocus(true)
        // The FileBrowser loads entries from the actual file system,
        // so we'll test navigation assuming it has loaded some entries

        // Down arrow - Move down
        let initialIndex = browser.selectedIndex
        let browser1 = browser.update(KeyMsg(type: .down))
        if browser.entries.count > 1 {
            #expect(browser1.selectedIndex == initialIndex + 1)
        }

        // Up arrow - Move up
        let browser2 = browser1.update(KeyMsg(type: .up))
        #expect(browser2.selectedIndex == initialIndex)

        // Home - Go to first
        if browser.entries.count > 3 {
            browser.selectedIndex = 3
        }
        let browser3 = browser.update(KeyMsg(type: .home))
        #expect(browser3.selectedIndex == 0)

        // End - Go to last
        let browser4 = browser3.update(KeyMsg(type: .end))
        if !browser.entries.isEmpty {
            #expect(browser4.selectedIndex == browser.entries.count - 1)
        }

        // Enter - Select/enter directory
        // (Result depends on what's selected - directory or file)
        let browser5 = browser.update(KeyMsg(type: .enter))
        // The action taken depends on whether a directory or file is selected

        // Toggle hidden files with '.'
        #expect(browser.showHidden == false)
        let browser6 = browser.update(KeyMsg(type: .runes, runes: ["."]))
        #expect(browser6.showHidden == true)

        // Character navigation - j/k for vim style
        let browser7 = browser.update(KeyMsg(type: .runes, runes: ["j"]))
        if browser.entries.count > 1 {
            #expect(browser7.selectedIndex == 1)
        }

        let browser8 = browser7.update(KeyMsg(type: .runes, runes: ["k"]))
        #expect(browser8.selectedIndex == 0)
    }

    // MARK: - Tabs Keyboard Shortcuts

    @Test("Tabs keyboard navigation")
    func tabsKeyboardNavigation() {
        var tabs = Tabs(items: ["Tab 1", "Tab 2", "Tab 3", "Tab 4"])
        tabs = tabs.withFocus(true)

        // Navigate with arrow keys
        #expect(tabs.selectedIndex == 0)

        let tabs1 = tabs.update(KeyMsg(type: .right))
        #expect(tabs1.selectedIndex == 1)

        let tabs2 = tabs1.update(KeyMsg(type: .left))
        #expect(tabs2.selectedIndex == 0)

        // Navigate with Tab/Shift+Tab
        let tabs3 = tabs2.update(KeyMsg(type: .tab))
        #expect(tabs3.selectedIndex == 1)

        let tabs4 = tabs3.update(KeyMsg(type: .shiftTab))
        #expect(tabs4.selectedIndex == 0)

        // Navigate with number keys (1-based in UI)
        let tabs5 = tabs4.update(KeyMsg(type: .runes, runes: ["2"]))
        #expect(tabs5.selectedIndex == 1) // "2" selects second tab (index 1)

        let tabs6 = tabs5.update(KeyMsg(type: .runes, runes: ["4"]))
        #expect(tabs6.selectedIndex == 3) // "4" selects fourth tab (index 3)

        // Test edge behavior - going past the end
        tabs = tabs.withSelectedIndex(3)
        let tabs7 = tabs.update(KeyMsg(type: .right))
        #expect(tabs7.selectedIndex == 3) // Should stay at end (no wrap by default)

        // Test edge behavior - going before the beginning
        tabs = tabs.withSelectedIndex(0)
        let tabs8 = tabs.update(KeyMsg(type: .left))
        #expect(tabs8.selectedIndex == 0) // Should stay at beginning
    }

    // MARK: - Global Keyboard Shortcuts

    @Test("Common keyboard shortcuts across components")
    func commonKeyboardShortcuts() {
        // Test that common shortcuts work consistently

        // Escape in various components
        var input = TextInput().withFocus(true).withValue("test")
        let input1 = input.update(KeyMsg(type: .escape))
        // Note: TextInput doesn't clear on escape, it just passes the key
        #expect(input1.value == "test")

        // Enter in confirmation dialog
        var confirmation = Confirmation(title: "Confirm?", message: "Are you sure?")
        let conf1 = confirmation.update(KeyMsg(type: .enter))
        // Confirmation returns itself with the selected choice
        #expect(conf1.selected == .yes) // Default selection is yes

        // Left/Right in confirmation to change selection
        let conf2 = conf1.update(KeyMsg(type: .right))
        #expect(conf2.selected == .no)

        let conf3 = conf2.update(KeyMsg(type: .left))
        #expect(conf3.selected == .yes)

        // Y/N shortcuts in confirmation
        let conf4 = confirmation.update(KeyMsg(type: .runes, runes: ["n"]))
        #expect(conf4.selected == .no)

        let conf5 = conf4.update(KeyMsg(type: .runes, runes: ["y"]))
        #expect(conf5.selected == .yes)
    }

    // MARK: - Accessibility Shortcuts

    @Test("Accessibility keyboard shortcuts")
    func accessibilityShortcuts() {
        // Test keyboard shortcuts for accessibility

        // Help component setup
        let help = Help(bindings: [
            ("↑/↓", "Navigate"),
            ("Enter", "Select"),
            ("q", "Quit"),
            ("Tab", "Next field"),
            ("Shift+Tab", "Previous field")
        ])

        // Help is a display-only component that doesn't handle input
        // It's used to show available keyboard shortcuts to users

        // Test that help displays correctly
        let view = help.view()
        #expect(view.contains("Navigate"))
        #expect(view.contains("Select"))
        #expect(view.contains("Quit"))

        // Test focus navigation in components
        // Most components handle Tab/Shift+Tab for navigation
        var tabs = Tabs(items: ["Tab 1", "Tab 2"]).withFocus(true)
        let tabs1 = tabs.update(KeyMsg(type: .tab))
        #expect(tabs1.selectedIndex == 1)

        let tabs2 = tabs1.update(KeyMsg(type: .shiftTab))
        #expect(tabs2.selectedIndex == 0)
    }
}
