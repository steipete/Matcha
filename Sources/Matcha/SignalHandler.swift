import Foundation
#if os(macOS) || os(Linux)
import Darwin

/// Represents different signal types
public enum Signal: Sendable {
    case interrupt      // SIGINT (Ctrl+C)
    case suspend        // SIGTSTP (Ctrl+Z)
    case windowChanged  // SIGWINCH
    case terminated     // SIGTERM
    case continued      // SIGCONT
}

/// Manages signal handling for the terminal
public final class SignalManager: @unchecked Sendable {
    /// Shared instance
    public static let shared = SignalManager()
    
    /// Callback for signal events
    public var onSignal: (@Sendable (Signal) -> Void)?
    
    private init() {
        setupSignalHandlers()
    }
    
    private func setupSignalHandlers() {
        // Install signal handlers
        signal(SIGINT) { _ in
            SignalManager.shared.onSignal?(.interrupt)
        }
        
        signal(SIGTSTP) { _ in
            SignalManager.shared.onSignal?(.suspend)
        }
        
        signal(SIGWINCH) { _ in
            SignalManager.shared.onSignal?(.windowChanged)
        }
        
        signal(SIGTERM) { _ in
            SignalManager.shared.onSignal?(.terminated)
        }
        
        signal(SIGCONT) { _ in
            SignalManager.shared.onSignal?(.continued)
        }
    }
}
#endif