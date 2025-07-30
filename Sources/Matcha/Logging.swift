//
//  Logging.swift
//  Matcha
//
//  Logging utilities for Matcha TUI applications.
//

import Foundation

/// LogOptionsSetter is a protocol implemented by logging libraries.
public protocol LogOptionsSetter {
    func setOutput(_ output: TextOutputStream)
    func setPrefix(_ prefix: String)
}

/// LogToFile sets up default logging to log to a file. This is helpful as we
/// can't print to the terminal since our TUI is occupying it. If the file
/// doesn't exist it will be created.
///
/// Don't forget to close the file when you're done with it.
///
///     let fileHandle = try LogToFile("debug.log", prefix: "debug")
///     defer { fileHandle.closeFile() }
public func LogToFile(_ path: String, prefix: String) throws -> FileHandle {
    let logger = StandardLogger()
    return try LogToFileWith(path, prefix: prefix, logger: logger)
}

/// LogToFileWith allows you to call LogToFile with a custom LogOptionsSetter.
public func LogToFileWith(_ path: String, prefix: String, logger: LogOptionsSetter) throws -> FileHandle {
    // Create the file if it doesn't exist
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        fileManager.createFile(atPath: path, contents: nil, attributes: nil)
    }
    
    // Open the file for appending
    guard let fileHandle = FileHandle(forWritingAtPath: path) else {
        throw LoggingError.failedToOpenFile(path)
    }
    
    // Seek to end for appending
    fileHandle.seekToEndOfFile()
    
    // Set up the logger
    logger.setOutput(FileHandleOutputStream(fileHandle: fileHandle))
    
    // Add a space after the prefix if needed
    var finalPrefix = prefix
    if !prefix.isEmpty && !prefix.hasSuffix(" ") {
        finalPrefix += " "
    }
    logger.setPrefix(finalPrefix)
    
    return fileHandle
}

/// Standard logger implementation
public class StandardLogger: LogOptionsSetter {
    private var output: TextOutputStream = FileHandleOutputStream(fileHandle: .standardOutput)
    private var prefix: String = ""
    
    public init() {}
    
    public func setOutput(_ output: TextOutputStream) {
        self.output = output
    }
    
    public func setPrefix(_ prefix: String) {
        self.prefix = prefix
    }
    
    public func log(_ message: String) {
        var stream = self.output
        stream.write("\(prefix)\(message)\n")
    }
}

/// TextOutputStream wrapper for FileHandle
struct FileHandleOutputStream: TextOutputStream {
    let fileHandle: FileHandle
    
    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

/// Logging-related errors
public enum LoggingError: Error, LocalizedError {
    case failedToOpenFile(String)
    
    public var errorDescription: String? {
        switch self {
        case .failedToOpenFile(let path):
            return "Failed to open file for logging: \(path)"
        }
    }
}