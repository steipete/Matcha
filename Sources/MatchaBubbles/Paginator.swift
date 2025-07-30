import Foundation
import Matcha
import MatchaStyle

/// A pagination component for navigating through paged content.
///
/// The Paginator component provides visual feedback and navigation controls
/// for content divided into pages. It supports multiple display styles:
/// - Dots style: Shows filled/empty circles for each page
/// - Numbers style: Shows page numbers with smart ellipsis
/// - Compact style: Shows current page and total (e.g., "3/10")
///
/// Example usage:
/// ```swift
/// var paginator = Paginator(
///     totalItems: 100,
///     itemsPerPage: 10,
///     currentPage: 0
/// )
/// paginator.displayStyle = .numbers
/// paginator.nextPage()
/// let display = paginator.view()
/// ```
public struct Paginator: Sendable {
    /// Available display styles for the paginator
    public enum DisplayStyle: Sendable {
        /// Shows filled (●) and empty (○) dots for each page
        case dots
        /// Shows page numbers with smart ellipsis for large page counts
        case numbers
        /// Shows compact format like "3/10"
        case compact
    }

    // MARK: - Properties

    /// Total number of items across all pages
    public var totalItems: Int

    /// Number of items displayed per page
    public var itemsPerPage: Int

    /// Current page index (0-based)
    public var currentPage: Int

    /// Visual style for displaying pagination
    public var displayStyle: DisplayStyle = .dots

    // MARK: - Computed Properties

    /// Total number of pages based on items and items per page
    public var totalPages: Int {
        guard itemsPerPage > 0 else { return 0 }
        return (totalItems + itemsPerPage - 1) / itemsPerPage
    }

    /// Creates a new paginator
    /// - Parameters:
    ///   - totalItems: Total number of items to paginate
    ///   - itemsPerPage: Number of items per page (must be > 0)
    ///   - currentPage: Initial page index (0-based)
    public init(totalItems: Int = 0, itemsPerPage: Int = 10, currentPage: Int = 0) {
        self.totalItems = totalItems
        self.itemsPerPage = itemsPerPage
        self.currentPage = currentPage
    }

    // MARK: - Navigation

    /// Advances to the next page if available
    public mutating func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    /// Goes back to the previous page if available
    public mutating func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }

    /// Jumps to a specific page
    /// - Parameter page: Target page index (0-based), will be clamped to valid range
    public mutating func goToPage(_ page: Int) {
        currentPage = max(0, min(page, totalPages - 1))
    }

    // MARK: - Rendering

    /// Renders the paginator based on the current display style.
    ///
    /// The appearance varies by style:
    /// - `.dots`: Simple dot indicators (●○○○○)
    /// - `.numbers`: Smart page numbers with ellipsis (1 2 [3] 4 5 ... 10)
    /// - `.compact`: Minimal format (3/10)
    ///
    /// - Returns: String representation of the paginator, empty if no pages
    public func view() -> String {
        guard totalPages > 0 else { return "" }

        switch displayStyle {
        case .dots:
            return renderDots()
        case .numbers:
            return renderNumbers()
        case .compact:
            return renderCompact()
        }
    }

    private func renderDots() -> String {
        var dots: [String] = []

        for i in 0..<totalPages {
            if i == currentPage {
                dots.append("●")
            } else {
                dots.append("○")
            }
        }

        return dots.joined(separator: " ")
    }

    private func renderNumbers() -> String {
        var numbers: [String] = []
        let style = Style()

        // Show up to 7 page numbers with ellipsis
        if totalPages <= 7 {
            // Show all pages
            for i in 0..<totalPages {
                if i == currentPage {
                    numbers.append(style.bold().foreground(.cyan).render("[\(i + 1)]"))
                } else {
                    numbers.append("\(i + 1)")
                }
            }
        } else {
            // Show first, last, and pages around current
            if currentPage <= 3 {
                // Near beginning
                for i in 0..<5 {
                    if i == currentPage {
                        numbers.append(style.bold().foreground(.cyan).render("[\(i + 1)]"))
                    } else {
                        numbers.append("\(i + 1)")
                    }
                }
                numbers.append("...")
                numbers.append("\(totalPages)")
            } else if currentPage >= totalPages - 4 {
                // Near end
                numbers.append("1")
                numbers.append("...")
                for i in (totalPages - 5)..<totalPages {
                    if i == currentPage {
                        numbers.append(style.bold().foreground(.cyan).render("[\(i + 1)]"))
                    } else {
                        numbers.append("\(i + 1)")
                    }
                }
            } else {
                // In middle
                numbers.append("1")
                numbers.append("...")
                for i in (currentPage - 1)...(currentPage + 1) {
                    if i == currentPage {
                        numbers.append(style.bold().foreground(.cyan).render("[\(i + 1)]"))
                    } else {
                        numbers.append("\(i + 1)")
                    }
                }
                numbers.append("...")
                numbers.append("\(totalPages)")
            }
        }

        return numbers.joined(separator: " ")
    }

    private func renderCompact() -> String {
        "\(currentPage + 1)/\(totalPages)"
    }
}
