import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - Model

public struct PaginatorModel: Model {
    var paginator: Paginator
    var items: [String] = []
    var itemsPerPage: Int = 10
    var displayStyle: Paginator.DisplayStyle = .dots
    
    // Define messages this model can handle
    public enum Message: Matcha.Message {
        case key(Key)
        case changeStyle
        case changeItemsPerPage(delta: Int)
    }
    
    public init() {
        // Generate sample items
        for i in 1...100 {
            items.append("Item #\(i): Sample content for item number \(i)")
        }
        
        // Create paginator
        paginator = Paginator(
            totalItems: items.count,
            itemsPerPage: itemsPerPage,
            currentPage: 0
        )
        paginator.displayStyle = displayStyle
    }
    
    public func `init`() -> Command<Message>? {
        nil
    }
    
    public func update(_ message: Message) -> (PaginatorModel, Command<Message>?) {
        var model = self
        
        switch message {
        case .key(let key):
            switch key.type {
            case .left:
                model.paginator.previousPage()
                return (model, nil)
                
            case .right:
                model.paginator.nextPage()
                return (model, nil)
                
            case .home:
                model.paginator.goToPage(0)
                return (model, nil)
                
            case .end:
                model.paginator.goToPage(model.paginator.totalPages - 1)
                return (model, nil)
                
            default:
                switch key.description {
                case "h":
                    model.paginator.previousPage()
                    return (model, nil)
                case "l":
                    model.paginator.nextPage()
                    return (model, nil)
                case "g":
                    model.paginator.goToPage(0)
                    return (model, nil)
                case "G":
                    model.paginator.goToPage(model.paginator.totalPages - 1)
                    return (model, nil)
                case "s":
                    return update(.changeStyle)
                case "+":
                    return update(.changeItemsPerPage(delta: 5))
                case "-":
                    return update(.changeItemsPerPage(delta: -5))
                case let c where "1"..."9" ~= c:
                    if let page = Int(String(c)) {
                        model.paginator.goToPage(page - 1)
                    }
                    return (model, nil)
                default:
                    return (model, nil)
                }
            }
            
        case .changeStyle:
            // Cycle through display styles
            switch model.paginator.displayStyle {
            case .dots:
                model.paginator.displayStyle = .numbers
            case .numbers:
                model.paginator.displayStyle = .compact
            case .compact:
                model.paginator.displayStyle = .dots
            }
            model.displayStyle = model.paginator.displayStyle
            return (model, nil)
            
        case .changeItemsPerPage(let delta):
            // Change items per page
            let newCount = max(5, min(50, model.itemsPerPage + delta))
            model.itemsPerPage = newCount
            model.paginator = Paginator(
                totalItems: model.items.count,
                itemsPerPage: newCount,
                currentPage: model.paginator.currentPage
            )
            model.paginator.displayStyle = model.displayStyle
            return (model, nil)
        }
    }
    
    public func view() -> String {
        var lines: [String] = []
        let style = Style()
        
        // Title
        lines.append(style.bold().render("Paginator Example"))
        lines.append("")
        
        // Info
        let pageInfo = "Page \(paginator.currentPage + 1) of \(paginator.totalPages)"
        let itemsInfo = "\(itemsPerPage) items per page"
        lines.append(style.foreground(.cyan).render("\(pageInfo) • \(itemsInfo)"))
        lines.append("")
        
        // Display current page items
        lines.append(style.underline().render("Current Page Items:"))
        lines.append("")
        
        let startIdx = paginator.currentPage * paginator.itemsPerPage
        let endIdx = min(startIdx + paginator.itemsPerPage, items.count)
        
        for i in startIdx..<endIdx {
            let item = items[i]
            lines.append("  \(style.foreground(.brightBlack).render(item))")
        }
        
        lines.append("")
        
        // Paginator
        lines.append(paginator.view())
        lines.append("")
        
        // Style examples
        lines.append(style.underline().render("Display Styles:"))
        
        // Dots style
        var dotsPaginator = paginator
        dotsPaginator.displayStyle = .dots
        lines.append("Dots:     \(dotsPaginator.view())")
        
        // Numbers style
        var numbersPaginator = paginator
        numbersPaginator.displayStyle = .numbers
        lines.append("Numbers:  \(numbersPaginator.view())")
        
        // Compact style
        var compactPaginator = paginator
        compactPaginator.displayStyle = .compact
        lines.append("Compact:  \(compactPaginator.view())")
        
        lines.append("")
        
        // Controls
        lines.append(style.faint().render("Controls:"))
        lines.append(style.faint().render("  ←/h       - Previous page"))
        lines.append(style.faint().render("  →/l       - Next page"))
        lines.append(style.faint().render("  Home/g    - First page"))
        lines.append(style.faint().render("  End/G     - Last page"))
        lines.append(style.faint().render("  1-9       - Go to page"))
        lines.append(style.faint().render("  s         - Change style"))
        lines.append(style.faint().render("  +/-       - Change items per page"))
        lines.append(style.faint().render("  q         - Quit"))
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Main

@main
enum PaginatorApp {
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
                    return PaginatorModel.Message.key(key)
                }
            default:
                return message
            }
        }
        
        let program = Program(initialModel: PaginatorModel(), options: options)
        _ = try await program.run()
    }
}