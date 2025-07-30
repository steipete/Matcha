# Tutorial 3: Building a Chat Client

In this tutorial, we'll create a real-time chat client with networking, concurrent operations, and live updates. This is our most advanced tutorial, combining everything you've learned.

## What We're Building

A terminal-based chat client with:
- 💬 Real-time messaging
- 👥 User list with online status
- ✍️ Typing indicators
- 🔔 Message notifications
- 📜 Scrollable message history
- 🎨 Rich message formatting
- 🔐 Simple authentication

## Prerequisites

- Completed Tutorials 1 & 2
- Understanding of async/await
- Basic networking knowledge

## Architecture Overview

We'll build a WebSocket-based chat client that connects to a server. The architecture includes:
- WebSocket connection management
- Message queue for reliability
- Concurrent message handling
- UI updates from network events

## Step 1: Project Setup

```bash
mkdir ChatClient
cd ChatClient
swift package init --type executable
```

Update `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatClient",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/yourusername/matcha", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ChatClient",
            dependencies: [
                .product(name: "Matcha", package: "matcha"),
                .product(name: "MatchaBubbles", package: "matcha"),
                .product(name: "MatchaStyle", package: "matcha")
            ]
        )
    ]
)
```

## Step 2: Define the Model

Create `Sources/ChatClient/ChatModel.swift`:

```swift
import Foundation
import Matcha
import MatchaBubbles
import MatchaStyle

// MARK: - Data Types

struct User: Identifiable, Codable, Equatable {
    let id: UUID
    let username: String
    let color: String
    var isOnline: Bool = true
    var isTyping: Bool = false
    
    var displayColor: Color {
        Color(hex: color) ?? .white
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let userId: UUID
    let username: String
    let content: String
    let timestamp: Date
    let type: MessageType
    
    enum MessageType: String, Codable {
        case text
        case join
        case leave
        case system
    }
}

// MARK: - Network Messages

enum ServerMessage: Codable {
    case welcome(user: User, users: [User])
    case message(ChatMessage)
    case userJoined(User)
    case userLeft(userId: UUID)
    case userStartedTyping(userId: UUID)
    case userStoppedTyping(userId: UUID)
    case error(String)
}

enum ClientMessage: Codable {
    case join(username: String)
    case message(String)
    case startTyping
    case stopTyping
}

// MARK: - Model

struct ChatModel: Model {
    // Connection state
    var connectionState: ConnectionState = .disconnected
    var currentUser: User?
    var serverURL: String = "ws://localhost:8080"
    
    // Chat state
    var messages: [ChatMessage] = []
    var users: [User] = []
    var typingUsers: Set<UUID> = []
    
    // UI state
    var messageInput = TextInput()
    var usernameInput = TextInput()
    var scrollOffset: Int = 0
    var showUserList: Bool = true
    var notificationCount: Int = 0
    
    // Network
    var webSocket: URLSessionWebSocketTask?
    var messageQueue: [ClientMessage] = []
    var reconnectAttempts: Int = 0
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // Messages
    enum Message: Matcha.Message {
        // Connection
        case connect
        case disconnect
        case connectionEstablished
        case connectionFailed(Error)
        case reconnect
        
        // Authentication
        case setUsername
        case usernameInputMsg(TextInput.Message)
        
        // Messaging
        case sendMessage
        case messageInputMsg(TextInput.Message)
        case startTyping
        case stopTyping
        
        // Server messages
        case receivedServerMessage(ServerMessage)
        case handleNetworkError(Error)
        
        // UI
        case toggleUserList
        case scrollUp
        case scrollDown
        case markAsRead
        
        // System
        case quit
    }
    
    // MARK: - Initialization
    
    init() {
        messageInput.placeholder = "Type a message..."
        messageInput.characterLimit = 500
        
        usernameInput.placeholder = "Enter username..."
        usernameInput.characterLimit = 20
    }
    
    func `init`() -> Command<Message>? {
        nil  // Wait for user to enter username
    }
}
```

## Step 3: Network Layer

Add networking functionality:

```swift
extension ChatModel {
    // MARK: - WebSocket Management
    
    func connectToServer() -> Command<Message> {
        Command {
            do {
                let url = URL(string: serverURL)!
                let session = URLSession.shared
                let webSocket = session.webSocketTask(with: url)
                
                webSocket.resume()
                
                // Start receiving messages
                Task {
                    await receiveMessages(from: webSocket)
                }
                
                return .connectionEstablished
            } catch {
                return .connectionFailed(error)
            }
        }
    }
    
    func receiveMessages(from webSocket: URLSessionWebSocketTask) async {
        do {
            while true {
                let message = try await webSocket.receive()
                
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let serverMessage = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                        await MainActor.run {
                            _ = Program.current?.sendMessage(.receivedServerMessage(serverMessage))
                        }
                    }
                    
                case .data(let data):
                    // Handle binary data if needed
                    break
                    
                @unknown default:
                    break
                }
            }
        } catch {
            await MainActor.run {
                _ = Program.current?.sendMessage(.handleNetworkError(error))
            }
        }
    }
    
    func send(_ message: ClientMessage, using webSocket: URLSessionWebSocketTask?) -> Command<Message> {
        Command {
            guard let webSocket = webSocket else { return nil }
            
            do {
                let data = try JSONEncoder().encode(message)
                let string = String(data: data, encoding: .utf8)!
                try await webSocket.send(.string(string))
            } catch {
                return .handleNetworkError(error)
            }
            
            return nil
        }
    }
}
```

## Step 4: Update Logic

Implement the update function:

```swift
extension ChatModel {
    func update(_ message: Message) -> (ChatModel, Command<Message>?) {
        var model = self
        
        switch message {
        // MARK: - Connection
        case .connect:
            guard !model.usernameInput.value.isEmpty else { return (model, nil) }
            
            model.connectionState = .connecting
            return (model, connectToServer())
            
        case .disconnect:
            model.webSocket?.cancel(with: .goingAway, reason: nil)
            model.webSocket = nil
            model.connectionState = .disconnected
            model.currentUser = nil
            model.users = []
            model.messages = []
            return (model, nil)
            
        case .connectionEstablished:
            model.connectionState = .connected
            
            // Send join message
            let joinMsg = ClientMessage.join(username: model.usernameInput.value)
            return (model, send(joinMsg, using: model.webSocket))
            
        case .connectionFailed(let error):
            model.connectionState = .error(error.localizedDescription)
            model.reconnectAttempts += 1
            
            // Auto-reconnect with backoff
            if model.reconnectAttempts < 5 {
                let delay = Double(model.reconnectAttempts) * 2.0
                return (model, after(.seconds(delay)) { .reconnect })
            }
            return (model, nil)
            
        case .reconnect:
            return model.update(.connect)
            
        // MARK: - Authentication
        case .setUsername:
            return model.update(.connect)
            
        case .usernameInputMsg(let msg):
            let (newInput, cmd) = model.usernameInput.update(msg)
            model.usernameInput = newInput
            return (model, cmd?.map { .usernameInputMsg($0) })
            
        // MARK: - Messaging
        case .sendMessage:
            let text = model.messageInput.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return (model, nil) }
            
            model.messageInput.reset()
            
            let clientMsg = ClientMessage.message(text)
            return (model, send(clientMsg, using: model.webSocket))
            
        case .messageInputMsg(let msg):
            let (newInput, cmd) = model.messageInput.update(msg)
            let wasEmpty = model.messageInput.value.isEmpty
            let isEmpty = newInput.value.isEmpty
            
            model.messageInput = newInput
            
            // Handle typing indicators
            var commands: [Command<Message>] = []
            if let mappedCmd = cmd?.map({ .messageInputMsg($0) }) {
                commands.append(mappedCmd)
            }
            
            if wasEmpty && !isEmpty {
                // Started typing
                commands.append(send(.startTyping, using: model.webSocket))
            } else if !wasEmpty && isEmpty {
                // Stopped typing
                commands.append(send(.stopTyping, using: model.webSocket))
            }
            
            return (model, commands.isEmpty ? nil : .batch(commands))
            
        case .startTyping:
            return (model, send(.startTyping, using: model.webSocket))
            
        case .stopTyping:
            return (model, send(.stopTyping, using: model.webSocket))
            
        // MARK: - Server Messages
        case .receivedServerMessage(let serverMsg):
            switch serverMsg {
            case .welcome(let user, let users):
                model.currentUser = user
                model.users = users
                model.usernameInput.blur()
                model.messageInput.focus()
                
                // Add system message
                let welcomeMsg = ChatMessage(
                    userId: UUID(),
                    username: "System",
                    content: "Welcome to the chat, \(user.username)!",
                    timestamp: Date(),
                    type: .system
                )
                model.messages.append(welcomeMsg)
                
            case .message(let msg):
                model.messages.append(msg)
                model.scrollToBottom()
                
                // Notification if not from current user
                if msg.userId != model.currentUser?.id {
                    model.notificationCount += 1
                }
                
            case .userJoined(let user):
                model.users.append(user)
                
                let joinMsg = ChatMessage(
                    userId: user.id,
                    username: "System",
                    content: "\(user.username) joined the chat",
                    timestamp: Date(),
                    type: .join
                )
                model.messages.append(joinMsg)
                
            case .userLeft(let userId):
                if let user = model.users.first(where: { $0.id == userId }) {
                    model.users.removeAll { $0.id == userId }
                    model.typingUsers.remove(userId)
                    
                    let leaveMsg = ChatMessage(
                        userId: userId,
                        username: "System",
                        content: "\(user.username) left the chat",
                        timestamp: Date(),
                        type: .leave
                    )
                    model.messages.append(leaveMsg)
                }
                
            case .userStartedTyping(let userId):
                model.typingUsers.insert(userId)
                
            case .userStoppedTyping(let userId):
                model.typingUsers.remove(userId)
                
            case .error(let message):
                model.connectionState = .error(message)
            }
            
            return (model, nil)
            
        case .handleNetworkError(let error):
            model.connectionState = .error(error.localizedDescription)
            return (model, after(.seconds(5)) { .reconnect })
            
        // MARK: - UI
        case .toggleUserList:
            model.showUserList.toggle()
            return (model, nil)
            
        case .scrollUp:
            if model.scrollOffset > 0 {
                model.scrollOffset -= 1
            }
            return (model, nil)
            
        case .scrollDown:
            let maxScroll = max(0, model.messages.count - 20)
            if model.scrollOffset < maxScroll {
                model.scrollOffset += 1
            }
            return (model, nil)
            
        case .markAsRead:
            model.notificationCount = 0
            return (model, nil)
            
        case .quit:
            // Clean disconnect
            return model.update(.disconnect).0.update(.quit)
        }
    }
    
    mutating func scrollToBottom() {
        scrollOffset = max(0, messages.count - 20)
    }
}
```

## Step 5: Create the View

Implement the chat interface:

```swift
extension ChatModel {
    func view() -> String {
        switch connectionState {
        case .disconnected, .error:
            return renderLoginScreen()
        case .connecting:
            return renderConnectingScreen()
        case .connected:
            return renderChatInterface()
        }
    }
    
    private func renderLoginScreen() -> String {
        let titleStyle = Style().bold().foreground(.cyan)
        let errorStyle = Style().foreground(.red)
        
        var output = """
        \(titleStyle.render("💬 Terminal Chat"))
        
        Welcome! Please enter your username to join.
        
        Username: \(usernameInput.view())
        
        """
        
        if case .error(let message) = connectionState {
            output += "\n\(errorStyle.render("Error: \(message)"))\n"
            output += "\(Style().faint().render("Press Enter to retry"))\n"
        } else {
            output += "\n\(Style().faint().render("Press Enter to connect"))\n"
        }
        
        return output
    }
    
    private func renderConnectingScreen() -> String {
        let spinner = Spinner()
        return """
        \(spinner.view()) Connecting to server...
        
        \(Style().faint().render("Server: \(serverURL)"))
        """
    }
    
    private func renderChatInterface() -> String {
        var lines: [String] = []
        
        // Header
        lines.append(renderHeader())
        lines.append("")
        
        // Main content area
        if showUserList {
            // Split view with user list
            let chatLines = renderMessages()
            let userLines = renderUserList()
            
            let chatWidth = 60
            let userWidth = 20
            
            for i in 0..<max(chatLines.count, userLines.count) {
                let chatLine = i < chatLines.count ? chatLines[i] : ""
                let userLine = i < userLines.count ? userLines[i] : ""
                
                lines.append("\(chatLine.padding(toLength: chatWidth, withPad: " ", startingAt: 0)) │ \(userLine)")
            }
        } else {
            // Full width chat
            lines.append(contentsOf: renderMessages())
        }
        
        // Typing indicators
        if !typingUsers.isEmpty {
            lines.append(renderTypingIndicator())
        }
        
        // Input area
        lines.append("")
        lines.append(renderInputArea())
        
        // Footer
        lines.append("")
        lines.append(renderFooter())
        
        return lines.joined(separator: "\n")
    }
    
    private func renderHeader() -> String {
        let title = Style().bold().foreground(.cyan).render("💬 Terminal Chat")
        let userCount = "\(users.count) users online"
        let notifications = notificationCount > 0 ? " 🔔 \(notificationCount)" : ""
        
        return "\(title) • \(userCount)\(notifications)"
    }
    
    private func renderMessages() -> [String] {
        var lines: [String] = []
        
        // Calculate visible messages
        let visibleCount = 20
        let start = scrollOffset
        let end = min(start + visibleCount, messages.count)
        
        let visibleMessages = Array(messages[start..<end])
        
        for message in visibleMessages {
            lines.append(renderMessage(message))
            
            // Add spacing between messages from different users
            if message != visibleMessages.last,
               let nextMsg = visibleMessages.firstIndex(of: message).map({ visibleMessages[$0 + 1] }),
               nextMsg.userId != message.userId {
                lines.append("")
            }
        }
        
        return lines
    }
    
    private func renderMessage(_ message: ChatMessage) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timestamp = timeFormatter.string(from: message.timestamp)
        
        switch message.type {
        case .text:
            let user = users.first { $0.id == message.userId }
            let userStyle = Style().foreground(user?.displayColor ?? .white).bold()
            let timeStyle = Style().faint()
            
            let header = "\(userStyle.render(message.username)) \(timeStyle.render(timestamp))"
            let content = message.content
            
            return "\(header)\n\(content)"
            
        case .join, .leave:
            let systemStyle = Style().foreground(.green).italic()
            return systemStyle.render("→ \(message.content)")
            
        case .system:
            let systemStyle = Style().foreground(.yellow).italic()
            return systemStyle.render("ℹ \(message.content)")
        }
    }
    
    private func renderUserList() -> [String] {
        var lines: [String] = []
        
        let headerStyle = Style().bold().underline()
        lines.append(headerStyle.render("Online Users"))
        lines.append("")
        
        for user in users.sorted(by: { $0.username < $1.username }) {
            var userLine = ""
            
            // Status indicator
            if typingUsers.contains(user.id) {
                userLine += "✍️ "
            } else {
                userLine += "● "
            }
            
            // Username with color
            let userStyle = Style().foreground(user.displayColor)
            userLine += userStyle.render(user.username)
            
            // Current user indicator
            if user.id == currentUser?.id {
                userLine += " (you)"
            }
            
            lines.append(userLine)
        }
        
        return lines
    }
    
    private func renderTypingIndicator() -> String {
        let typingUsernames = typingUsers.compactMap { userId in
            users.first { $0.id == userId }?.username
        }
        
        guard !typingUsernames.isEmpty else { return "" }
        
        let text = if typingUsernames.count == 1 {
            "\(typingUsernames[0]) is typing..."
        } else if typingUsernames.count == 2 {
            "\(typingUsernames[0]) and \(typingUsernames[1]) are typing..."
        } else {
            "Several people are typing..."
        }
        
        return Style().italic().faint().render(text)
    }
    
    private func renderInputArea() -> String {
        let prompt = currentUser.map { "\($0.username): " } ?? ""
        return "\(prompt)\(messageInput.view())"
    }
    
    private func renderFooter() -> String {
        let shortcuts = [
            "Enter: Send",
            "↑/↓: Scroll",
            "Tab: Toggle users",
            "Ctrl+C: Quit"
        ]
        
        return Style().faint().render(shortcuts.joined(separator: " • "))
    }
}
```

## Step 6: Main Application

Create `Sources/ChatClient/main.swift`:

```swift
import Matcha

// Global reference for async message sending
extension Program {
    static weak var current: Program<ChatModel>?
}

@main
struct ChatClientApp {
    static func main() async throws {
        var options = ProgramOptions.default
        options.useAltScreen = true
        
        options.filter = { model, message in
            // Connection state handling
            switch model.connectionState {
            case .disconnected, .error:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return ChatModel.Message.setUsername
                    case .character(let char):
                        return ChatModel.Message.usernameInputMsg(.characterInput(char))
                    case .backspace:
                        return ChatModel.Message.usernameInputMsg(.backspace)
                    default:
                        break
                    }
                }
                
            case .connected:
                if let key = message as? Key {
                    switch key {
                    case .enter:
                        return ChatModel.Message.sendMessage
                    case .character(let char):
                        return ChatModel.Message.messageInputMsg(.characterInput(char))
                    case .backspace:
                        return ChatModel.Message.messageInputMsg(.backspace)
                    case .up:
                        return ChatModel.Message.scrollUp
                    case .down:
                        return ChatModel.Message.scrollDown
                    case .tab:
                        return ChatModel.Message.toggleUserList
                    default:
                        break
                    }
                }
                
            case .connecting:
                // No input during connection
                break
            }
            
            // Global quit
            if let key = message as? Key {
                switch key.description {
                case "ctrl+c":
                    return ChatModel.Message.quit
                default:
                    break
                }
            }
            
            return message
        }
        
        let program = Program(
            initialModel: ChatModel(),
            options: options
        )
        
        // Store reference for async operations
        Program.current = program
        
        _ = try await program.run()
        print("\nDisconnected. Goodbye! 👋")
    }
}
```

## Step 7: Simple Chat Server (Bonus)

Here's a basic WebSocket server for testing:

```swift
// Sources/ChatServer/main.swift
import Foundation
import Vapor

struct ChatServer {
    static var users: [UUID: User] = [:]
    static var connections: [UUID: WebSocket] = [:]
    
    static func main() throws {
        let app = Application()
        
        app.webSocket("") { req, ws in
            let userId = UUID()
            
            ws.onText { ws, text in
                // Handle incoming messages
                handleMessage(userId: userId, text: text, ws: ws)
            }
            
            ws.onClose.whenComplete { _ in
                // Handle disconnection
                handleDisconnect(userId: userId)
            }
        }
        
        try app.run()
    }
    
    static func handleMessage(userId: UUID, text: String, ws: WebSocket) {
        // Parse and broadcast messages
        // Implementation details...
    }
    
    static func broadcast(_ message: ServerMessage, except: UUID? = nil) {
        // Send to all connected clients
        // Implementation details...
    }
}
```

## Exercises

Enhance your chat client:

### 1. Message Formatting
- Markdown support
- Emoji reactions
- Code syntax highlighting
- Link preview

### 2. Direct Messages
- Private conversations
- User profiles
- Online/offline status
- Message history

### 3. Rooms/Channels
- Multiple chat rooms
- Room creation
- Topic management
- User permissions

### 4. Media Support
- Image sharing
- File transfers
- Voice messages
- Screen sharing

### 5. Persistence
- Message history
- Offline support
- Message sync
- Search functionality

## Complete Code

Find the complete implementation at:
[Examples/Tutorials/ChatClient](https://github.com/yourusername/matcha/tree/main/Examples/Tutorials/ChatClient)

## What You've Learned

Through this advanced tutorial, you've mastered:
- ✅ WebSocket networking
- ✅ Concurrent operations
- ✅ Real-time UI updates
- ✅ Complex state management
- ✅ Message queuing
- ✅ Error handling & reconnection
- ✅ Multi-pane layouts
- ✅ Notification systems

## Conclusion

Congratulations! You've built three progressively complex applications with Matcha:

1. **Task Manager** - Fundamentals and persistence
2. **File Explorer** - Advanced UI and file operations  
3. **Chat Client** - Networking and real-time updates

You're now equipped to build sophisticated terminal applications with Matcha. The patterns you've learned—state management, async operations, component composition, and error handling—will serve you well in any TUI project.

## What's Next?

- Explore the [Examples](../../Examples/) directory for more patterns
- Read the [API Reference](../api/reference/) for detailed documentation
- Build your own amazing terminal applications!
- Share your creations with the Matcha community

Happy coding! 🍵