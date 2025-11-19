//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
//
//  VZKitLogger.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 06/01/25.
//

import os

/// A utility structure for logging messages within the VirtualizationKit framework.
/// This struct provides an interface for structured logging using Apple's `os.Logger`.
struct VZKitLogger {
    
    /// The default logger instance with the category set to "general".
    /// Use this for general-purpose logging within the framework.
    static let `default`: VZKitLogger = VZKitLogger.create(for: "general")
    
    /// The underlying `os.Logger` instance used for logging messages.
    private let logger: Logger
    
    /// Creates a `VZKitLogger` instance for a specified category.
    ///
    /// - Parameter category: The category to associate with this logger instance.
    /// - Returns: A configured `VZKitLogger` instance.
    static func create(for category: String) -> VZKitLogger {
        return VZKitLogger(category: category)
    }
    
    /// Logs an informational message.
    ///
    /// - Parameter message: The message to log. The message's privacy is set to `.public`.
    /// - Note: Use this method to log messages that provide context about the normal operation of the application.
    func info(_ message: String) {
        self.logger.info("\(message, privacy: .public)")
    }
    
    /// Logs an error message.
    ///
    /// - Parameter message: The message to log. The message's privacy is set to `.public`.
    /// - Note: Use this method to log errors or unexpected conditions in the application.
    func error(_ message: String) {
        self.logger.error("VirtualizationKit: \(message, privacy: .public)")
    }
    
    /// Logs a fatal error message and calls fatalError.
    ///
    /// - Parameter message: The message to log. The message's privacy is set to `.public`.
    /// - Note: Use this method only for irrecoverable conditions in the application.
    func fatalError(_ message: String) -> Never {
        self.logger.error("VirtualizationKit: \(message, privacy: .public)")
        fatalError("VirtualizationKit: \(message)")
    }
    
    /// Initializes a new `VZKitLogger` instance for a specific category.
    ///
    /// - Parameter category: The category to associate with the logger.
    /// - Note: This initializer is private to ensure controlled creation of loggers using `create(for:)`.
    private init(category: String) {
        self.logger = Logger(subsystem: "VirtualizationKit", category: category)
    }
}

