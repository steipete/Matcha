import Foundation

// MARK: - SafeOutput

/// Thread-safe wrapper for terminal output
public final class SafeOutput: TextOutputStream, @unchecked Sendable {
    private let fileHandle: FileHandle
    private let queue = DispatchQueue(label: "com.matcha.output", qos: .userInteractive)

    public init(fileHandle: FileHandle = .standardOutput) {
        self.fileHandle = fileHandle
    }

    public func write(_ string: String) {
        queue.sync {
            if let data = string.data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }
}

// MARK: - BufferedOutput

/// A buffered output wrapper that batches writes for performance
public final class BufferedOutput: TextOutputStream, @unchecked Sendable {
    private let underlying: any TextOutputStream & Sendable
    private let queue = DispatchQueue(label: "com.matcha.buffered-output", qos: .userInteractive)
    private var buffer: String = ""
    private let flushThreshold: Int
    private var flushWorkItem: DispatchWorkItem?

    public init(underlying: any TextOutputStream & Sendable, flushThreshold: Int = 4096) {
        self.underlying = underlying
        self.flushThreshold = flushThreshold
    }

    public func write(_ string: String) {
        queue.async { [weak self] in
            guard let self else { return }
            buffer.append(string)

            // Flush if buffer exceeds threshold
            if buffer.count >= flushThreshold {
                flushInternal()
            } else {
                // Schedule deferred flush
                flushWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.flushInternal()
                }
                flushWorkItem = workItem
                queue.asyncAfter(deadline: .now() + 0.016, execute: workItem) // ~60fps
            }
        }
    }

    public func flush() {
        queue.sync {
            flushInternal()
        }
    }

    private func flushInternal() {
        guard !buffer.isEmpty else { return }
        var output = underlying
        output.write(buffer)
        buffer = ""
    }
}
