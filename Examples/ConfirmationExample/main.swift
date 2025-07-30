import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - ConfirmationModel

struct ConfirmationModel: Model {
    var confirmation: Confirmation
    var result: String?
    var showSecondDialog: Bool = false
    var secondConfirmation: Confirmation?

    enum Message: Matcha.Message {
        case key(KeyMsg)
        case showSecondDialog
        case quit
    }

    init() {
        self.confirmation = Confirmation(
            title: "🗑️  Delete File",
            message: "Are you sure you want to delete 'important.txt'?"
        )
        .withYesText("Delete")
        .withNoText("Cancel")
        .boxStyle(Style().background(Color(235)))
        .titleStyle(Style().bold().foreground(.brightRed))
        .messageStyle(Style().foreground(.white))
        .selectedStyle(Style().background(.brightRed).foreground(.white).bold())
        .unselectedStyle(Style().foreground(Color(240)))
        .withBorderStyle(.rounded)
        .withPadding(2)
    }

    func `init`() -> Command<Message>? {
        nil
    }

    func update(_ message: Message) -> (ConfirmationModel, Command<Message>?) {
        var model = self

        switch message {
        case let .key(key):
            switch key.description {
            case "ctrl+c",
                 "q":
                return (model, quit())
            case "r":
                // Reset the first dialog
                model.confirmation = model.confirmation.withActive(true).withSelected(.yes)
                model.result = nil
            case "s":
                // Show second dialog
                if model.result != nil, !model.showSecondDialog {
                    return model.update(.showSecondDialog)
                }
            default:
                if model.showSecondDialog, let secondConfirmation = model.secondConfirmation {
                    model.secondConfirmation = secondConfirmation.update(key)

                    if !model.secondConfirmation!.active {
                        model.showSecondDialog = false
                    }
                } else if model.confirmation.active {
                    model.confirmation = model.confirmation.update(key)

                    if !model.confirmation.active {
                        if model.confirmation.hasChoice {
                            model.result = model.confirmation.isConfirmed ? "deleted" : "cancelled"
                        } else {
                            model.result = "escaped"
                        }
                    }
                }
            }

        case .showSecondDialog:
            model.showSecondDialog = true
            model.secondConfirmation = Confirmation(
                title: "💾 Save Changes?",
                message: "You have unsaved changes. Do you want to save them?"
            )
            .withYesText("Save")
            .withNoText("Discard")
            .boxStyle(Style().background(Color(17)))
            .titleStyle(Style().bold().foreground(.brightCyan))
            .messageStyle(Style().foreground(.white))
            .selectedStyle(Style().background(.brightCyan).foreground(.black).bold())
            .unselectedStyle(Style().foreground(Color(240)))
            .withBorderStyle(.double)
            .withWidth(50)

        case .quit:
            return (model, quit())
        }

        return (model, nil)
    }

    func view() -> String {
        var view = ""

        // Title
        view += Style().bold().foreground(.brightMagenta).render("✨ Confirmation Dialog Demo") + "\n\n"

        // Instructions
        view += Style().foreground(Color(240))
            .render("Use arrow keys or tab to select, Enter to confirm, Escape to cancel") + "\n"
        view += Style().foreground(Color(240)).render("You can also press 'y' for yes or 'n' for no") + "\n\n"

        // First dialog
        if confirmation.active {
            view += confirmation.view() + "\n\n"
        } else {
            // Show result
            view += Style().foreground(Color(240)).render("First dialog result: ")

            switch result {
            case "deleted":
                view += Style().foreground(.brightRed).bold().render("✓ File deleted!") + "\n\n"
            case "cancelled":
                view += Style().foreground(.brightYellow).render("✗ Operation cancelled") + "\n\n"
            case "escaped":
                view += Style().foreground(Color(240)).render("Dialog closed without choice") + "\n\n"
            default:
                break
            }

            view += Style().foreground(Color(240)).render("Press 'r' to reset the dialog") + "\n"

            if result == "deleted" {
                view += Style().foreground(Color(240)).render("Press 's' to show another dialog") + "\n"
            }
        }

        view += "\n"

        // Second dialog (overlay)
        if showSecondDialog, let secondConfirmation {
            let dialogLines = secondConfirmation.view().split(separator: "\n")
            let startLine = 8

            // Create overlay effect
            let viewLines = view.split(separator: "\n").map(String.init)
            var overlayView = ""

            for (index, line) in viewLines.enumerated() {
                if index >= startLine, index - startLine < dialogLines.count {
                    overlayView += String(dialogLines[index - startLine]) + "\n"
                } else {
                    overlayView += line + "\n"
                }
            }

            view = overlayView

            // Show result below
            if !secondConfirmation.active {
                view += "\n" + Style().foreground(Color(240)).render("Second dialog result: ")

                if secondConfirmation.hasChoice {
                    if secondConfirmation.isConfirmed {
                        view += Style().foreground(.brightGreen).bold().render("✓ Changes saved!")
                    } else {
                        view += Style().foreground(.brightYellow).render("✗ Changes discarded")
                    }
                } else {
                    view += Style().foreground(Color(240)).render("Escaped without choice")
                }
            }
        }

        // Different dialog styles showcase
        if !confirmation.active, !showSecondDialog {
            view += "\n" + Style().bold().render("Dialog Style Examples:") + "\n\n"

            // Minimal style
            let minimal = Confirmation(message: "Continue?")
                .withBorder(false)
                .withPadding(0)
                .withWidth(20)
                .withActive(false)
            view += Style().foreground(Color(240)).render("Minimal: ") + minimal.view() + "\n\n"

            // Success style
            let success = Confirmation(title: "✅ Success", message: "Operation completed!")
                .withYesText("OK")
                .withNoText("Close")
                .titleStyle(Style().foreground(.brightGreen).bold())
                .selectedStyle(Style().background(.brightGreen).foreground(.black))
                .withBorderStyle(.thick)
                .withActive(false)
            view += Style().foreground(Color(240)).render("Success: ") + success.view() + "\n\n"

            // Warning style
            let warning = Confirmation(title: "⚠️  Warning", message: "This action cannot be undone")
                .titleStyle(Style().foreground(.brightYellow).bold())
                .selectedStyle(Style().background(.brightYellow).foreground(.black))
                .withBorderStyle(.single)
                .withActive(false)
            view += Style().foreground(Color(240)).render("Warning: ") + warning.view() + "\n"
        }

        view += "\n\n" + Style().foreground(Color(240)).render("Press 'q' to quit")

        return view
    }
}

// MARK: - ConfirmationExampleApp

@main
struct ConfirmationExampleApp {
    static func main() async throws {
        let program = Program(
            initialModel: ConfirmationModel(),
            options: ProgramOptions()
        )
        _ = try await program.run()
    }
}
