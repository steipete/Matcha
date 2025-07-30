//
//  SafeOutput.swift
//  Matcha
//
//  Thread-safe output wrapper for terminal writing.
//

import Foundation

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
            guard let self = self else { return }
            self.buffer.append(string)
            
            // Flush if buffer exceeds threshold
            if self.buffer.count >= self.flushThreshold {
                self.flushInternal()
            } else {
                // Schedule deferred flush
                self.flushWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.flushInternal()
                }
                self.flushWorkItem = workItem
                self.queue.asyncAfter(deadline: .now() + 0.016, execute: workItem) // ~60fps
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