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
//  VZKitLocale.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 10/01/25.
//

import Foundation

/// A utility for handling localized strings in the `VZKit` framework.
///
/// The `VZKitLocale` struct provides an abstraction for retrieving localized strings
/// from the framework's resource bundle. It supports format arguments and additional contextual
/// data to generate localized messages dynamically. This utility ensures that all localization
/// operations are centralized and consistent across the framework.
///
/// ## Features
/// - Centralized management of localized strings for `VZKit`.
/// - Supports dynamic string formatting with multiple initialization options.
/// - Automatically retrieves localized strings from the framework's bundle.
///
/// ## Usage
/// ```swift
/// let localizedMessage = VZKitLocale("key.successMessage", 42)
/// print(localizedMessage.value) // Outputs the localized and formatted message.
/// ```
///
/// ## Initialization Options
/// 1. **Basic Localization**: Retrieve a localized string by key.
/// 2. **String Formatting**: Pass arguments for dynamic string formatting.
/// 3. **Feature-Specific Localization**: Include a `Feature` object to customize the localized string.
/// 4. **Version Comparison**: Provide operating system versions to generate version-specific messages.
///
/// - Note: This struct is designed for internal use within the `VZKit` framework and relies on the
///         `VirtualizationKit.bundle` for localization resources.
struct VZKitLocale {
    
    // MARK: - Properties
    
    /// The final localized string value.
    ///
    /// This property holds the result of the localization process, including any applied format arguments
    /// or contextual modifications.
    let value: String
    
    // MARK: - Methods
    
    /// A helper method for localizing a string using a key and optional format arguments.
    ///
    /// This method retrieves the localized string from the `VirtualizationKit.bundle` and applies
    /// any provided format arguments to generate the final string.
    ///
    /// - Parameters:
    ///   - key: A `String.LocalizationValue` representing the key to look up in the localization table.
    ///   - arguments: A variadic list of arguments to format the localized string dynamically.
    /// - Returns: A fully localized and formatted string.
    private static func localize(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let localizedKey: String = .init(
            localized: key,
            bundle: VirtualizationKit.bundle
        )
        return arguments.count != 0 ? .init(format: localizedKey, arguments) : localizedKey
    }
    
    // MARK: - Initializers
    
    /// Initializes a localized string with a key and optional format arguments.
    ///
    /// - Parameters:
    ///   - key: A `String.LocalizationValue` representing the localization key.
    ///   - arguments: A variadic list of arguments to format the localized string dynamically.
    init(_ key: String.LocalizationValue, _ arguments: CVarArg...) {
        self.value = Self.localize(key, arguments)
    }
    
    /// Initializes a localized string with a key and a `OptionalCapability` object for context.
    ///
    /// This initializer retrieves a localized string and formats it using details from the provided `OptionalCapability` object.
    ///
    /// - Parameters:
    ///   - key: A `String.LocalizationValue` representing the localization key.
    ///   - capability: A `OptionalCapability` object providing additional context for the localized string.
    init(_ key: String.LocalizationValue, _ capability: OptionalCapability) {
        self.init(key, capability.featureScope, capability.localizedName)
    }
    
    /// Initializes a localized string with a key and two operating system versions for comparison.
    ///
    /// This initializer generates a localized string that incorporates descriptions of two operating
    /// system versions, such as when comparing requirements or compatibility.
    ///
    /// - Parameters:
    ///   - key: A `String.LocalizationValue` representing the localization key.
    ///   - lver: A `OperatingSystem.Version` representing the left-hand version in the comparison.
    ///   - rver: A `OperatingSystem.Version` representing the right-hand version in the comparison.
    init(
        _ key: String.LocalizationValue,
        _ lver: OperatingSystem.Version,
        _ rver: OperatingSystem.Version
    ) {
        self.init(key, lver.description, rver.description)
    }
}

