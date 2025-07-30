import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - ListModel

// Model that uses List component
public struct ListModel: Model {
    var list: List
    var choice: String?

    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(KeyMsg)
        case selectItem
    }

    public init() {
        // Initialize list with some items
        let items = [
            List.Item(title: "Ramen", description: "Japanese noodle soup", value: "ramen"),
            List.Item(title: "Tomato Soup", description: "Smooth and creamy", value: "tomato"),
            List.Item(title: "Hamburgers", description: "American classic", value: "burger"),
            List.Item(title: "Quesadillas", description: "Cheesy Mexican delight", value: "quesadilla"),
            List.Item(title: "Sushi", description: "Fresh Japanese delicacy", value: "sushi"),
            List.Item(title: "Pizza", description: "Italian favorite", value: "pizza"),
            List.Item(title: "Tacos", description: "Mexican street food", value: "tacos"),
            List.Item(title: "Fish & Chips", description: "British classic", value: "fish-chips"),
            List.Item(title: "Pad Thai", description: "Thai stir-fried noodles", value: "pad-thai"),
            List.Item(title: "Curry", description: "Spicy Indian dish", value: "curry")
        ]

        self.list = List()
            .withItems(items)
            .withHeight(7)
            .withFocus(true)
            .selectedStyle(Style().foreground(.cyan).bold())
            .normalStyle(Style().foreground(.white))
            .helpStyle(Style().foreground(Color(240)))
            .paginationStyle(Style().foreground(.yellow))
    }

    public func `init`() -> Command<Message>? {
        nil
    }

    public func update(_ message: Message) -> (ListModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.type {
            case .enter:
                // Select the current item
                model.choice = model.list.selectedValue
                return (model, quit())

            default:
                // Pass to list
                model.list = model.list.update(key)
                return (model, nil)
            }

        case .selectItem:
            model.choice = model.list.selectedValue
            return (model, quit())
        }
    }

    public func view() -> String {
        let title = Style().bold().foreground(.magenta).render("🍜 What should we have for lunch? 🍜")

        var output = """
        \(title)

        \(list.view())
        """

        if let choice {
            let selected = Style().foreground(.green).render("✓ You chose: \(choice)")
            output += "\n\n\(selected)"
        }

        return output
    }
}

// MARK: - ListApp

// Main entry point
@main
enum ListApp {
    static func main() async throws {
        var options = ProgramOptions()

        // Add a filter to convert messages
        options.filter = { _, message in
            switch message {
            case let key as KeyMsg:
                switch key.description {
                case "ctrl+c",
                     "q":
                    QuitMsg()
                default:
                    ListModel.Message.key(key)
                }
            default:
                message
            }
        }

        let program = Program(initialModel: ListModel(), options: options)
        let finalModel = try await program.run()

        // Print the final choice after the program exits
        if let choice = finalModel.choice {
            print("\nYou selected: \(choice)")
        }
    }
}
