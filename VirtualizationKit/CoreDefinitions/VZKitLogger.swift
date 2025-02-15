//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
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

