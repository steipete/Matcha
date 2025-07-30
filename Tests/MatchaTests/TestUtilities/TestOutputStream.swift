//
//  TestOutputStream.swift
//  MatchaTests
//
//  Test output streams for capturing output in tests.
//

import Foundation
@testable import Matcha

/// Test output stream that conforms to TextOutputStream for use with StandardRenderer and ProgramOptions
public final class TestOutputStream: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var _content = ""
    
    public var content: String {
        lock.lock()
        defer { lock.unlock() }
        return _content
    }
    
    public func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        _content += string
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _content = ""
    }
    
    public func reset() {
        clear()
    }
}

/// Test output stream that can be used as TextOutputStream in ProgramOptions
/// This wraps TestOutputStream to make it easy to use
public typealias TestOutput = TestOutputStream