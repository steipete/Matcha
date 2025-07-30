import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - Model

struct Person: Sendable {
    let name: String
    let age: Int
    let city: String
    let occupation: String
}

public struct TableModel: Model {
    var table: Table
    var people: [Person]
    
    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(Key)
        case sortByAge
        case sortByName
        case toggleBorder
    }
    
    public init() {
        // Sample data
        self.people = [
            Person(name: "Alice Johnson", age: 28, city: "New York", occupation: "Software Engineer"),
            Person(name: "Bob Smith", age: 35, city: "San Francisco", occupation: "Product Manager"),
            Person(name: "Charlie Brown", age: 42, city: "Chicago", occupation: "Designer"),
            Person(name: "Diana Prince", age: 31, city: "Los Angeles", occupation: "Data Scientist"),
            Person(name: "Ethan Hunt", age: 39, city: "Seattle", occupation: "Security Analyst"),
            Person(name: "Fiona Green", age: 26, city: "Austin", occupation: "DevOps Engineer"),
            Person(name: "George Wilson", age: 45, city: "Boston", occupation: "Architect"),
            Person(name: "Helen Troy", age: 33, city: "Miami", occupation: "QA Engineer"),
            Person(name: "Ian Malcolm", age: 37, city: "Portland", occupation: "Researcher"),
            Person(name: "Julia Roberts", age: 29, city: "Denver", occupation: "UX Designer"),
        ]
        
        // Define columns
        let columns = [
            Table.Column(key: "name", title: "Name", width: 20),
            Table.Column(key: "age", title: "Age", width: 8),
            Table.Column(key: "city", title: "City", width: 15),
            Table.Column(key: "occupation", title: "Occupation", width: 20)
        ]
        
        // Create table
        var table = Table()
        table.setColumns(columns)
        
        // Set rows
        let rows = people.map { person in
            [
                "name": person.name,
                "age": String(person.age),
                "city": person.city,
                "occupation": person.occupation
            ]
        }
        table.setRows(rows)
        
        // Configure styles
        let style = Style()
        table.headerStyle = style.bold().foreground(.cyan)
        table.selectedStyle = style.foreground(.yellow).background(.brightBlack)
        table.borderStyle = style.foreground(.brightBlack)
        
        self.table = table
    }
    
    public func `init`() -> Command<Message>? {
        nil
    }
    
    public func update(_ message: Message) -> (TableModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key.type {
            case .up:
                model.table.moveUp()
                return (model, nil)
                
            case .down:
                model.table.moveDown()
                return (model, nil)
                
            case .home:
                model.table.goToTop()
                return (model, nil)
                
            case .end:
                model.table.goToBottom()
                return (model, nil)
                
            default:
                switch key.description {
                case "a":
                    return update(.sortByAge)
                case "n":
                    return update(.sortByName)
                case "b":
                    return update(.toggleBorder)
                default:
                    return (model, nil)
                }
            }
            
        case .sortByAge:
            // Sort by age
            model.people.sort { $0.age < $1.age }
            let rows = model.people.map { person in
                [
                    "name": person.name,
                    "age": String(person.age),
                    "city": person.city,
                    "occupation": person.occupation
                ]
            }
            model.table.setRows(rows)
            return (model, nil)
            
        case .sortByName:
            // Sort by name
            model.people.sort { $0.name < $1.name }
            let rows = model.people.map { person in
                [
                    "name": person.name,
                    "age": String(person.age),
                    "city": person.city,
                    "occupation": person.occupation
                ]
            }
            model.table.setRows(rows)
            return (model, nil)
            
        case .toggleBorder:
            // Toggle border
            model.table.showBorder.toggle()
            return (model, nil)
        }
    }
    
    public func view() -> String {
        var lines: [String] = []
        let style = Style()
        
        // Title
        lines.append(style.bold().render("Table Example - Employee Directory"))
        lines.append("")
        
        // Selected person info
        if table.cursor < people.count {
            let selected = people[table.cursor]
            lines.append(style.foreground(.green).render("Selected: \(selected.name) - \(selected.occupation)"))
            lines.append("")
        }
        
        // Table
        lines.append(table.view())
        lines.append("")
        
        // Controls
        lines.append(style.faint().render("Controls:"))
        lines.append(style.faint().render("  ↑/↓       - Navigate"))
        lines.append(style.faint().render("  Home/End  - Go to top/bottom"))
        lines.append(style.faint().render("  a         - Sort by age"))
        lines.append(style.faint().render("  n         - Sort by name"))
        lines.append(style.faint().render("  b         - Toggle border"))
        lines.append(style.faint().render("  q         - Quit"))
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Main

@main
enum TableApp {
    static func main() async throws {
        var options = ProgramOptions()
        options.useAltScreen = true
        
        // Add a filter to convert messages
        options.filter = { _, message in
            switch message {
            case let key as Key:
                switch key.description {
                case "q", "ctrl+c":
                    return QuitMsg()
                default:
                    return TableModel.Message.key(key)
                }
            default:
                return message
            }
        }
        
        let program = Program(initialModel: TableModel(), options: options)
        _ = try await program.run()
    }
}