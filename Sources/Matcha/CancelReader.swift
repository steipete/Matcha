//
//  CancelReader.swift
//  Matcha
//
//  Cancel reader for cancellable input operations.
//

import Foundation

/// Protocol for cancellable readers
public protocol CancelReader: Sendable {
    /// Cancel the reader
    func cancel() async -> Bool
    
    /// Close the reader
    func close() async throws
    
    /// Check if the reader is cancelled
    var isCancelled: Bool { get async }
}

/// Actor-based implementation of CancelReader for async input operations
public actor AsyncCancelReader: CancelReader {
    private var cancelled = false
    private var continuation: AsyncStream<UInt8>.Continuation?
    
    public init() {}
    
    public func cancel() -> Bool {
        guard !cancelled else { return false }
        cancelled = true
        continuation?.finish()
        return true
    }
    
    public func close() throws {
        _ = cancel()
    }
    
    public var isCancelled: Bool {
        cancelled
    }
    
    /// Set the continuation for the async stream
    func setContinuation(_ continuation: AsyncStream<UInt8>.Continuation) {
        self.continuation = continuation
    }
}