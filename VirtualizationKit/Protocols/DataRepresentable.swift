//
//  DataRepresentable.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 11/01/25.
//

import Virtualization

/// A protocol representing types that can be converted to and from a `Data` representation.
///
/// Types conforming to this protocol must implement an initializer to create an instance
/// from a `Data` representation and a property to retrieve the `Data` representation.
protocol DataRepresentable: Constructible where Product: DataRepresentable {
    
    /// Creates an instance of the conforming type from its `Data` representation.
    ///
    /// - Parameter dataRepresentation: A `Data` instance representing the object.
    /// - Returns: An optional instance of the conforming type if the `Data` is valid; otherwise, `nil`.
    init?(dataRepresentation: Data)
    
    /// The `Data` representation of the object.
    ///
    /// This property provides a serialized representation of the instance as `Data`.
    var dataRepresentation: Data { get }
}

/// Default implementation of utility methods for types conforming to `DataRepresentable`.
extension DataRepresentable {
    
    /// Creates an instance of a type conforming to `DataRepresentable` from a file located at the specified URL.
    ///
    /// This method reads the data from the specified file URL, attempts to initialize an object
    /// of the specified type using its `dataRepresentation` initializer, and returns the resulting object.
    ///
    /// - Parameters:
    ///   - url: The file URL containing the serialized representation of the object.
    /// - Returns: An instance of the specified `Constructible` type created from the file's data.
    /// - Throws:
    ///   - `VZKitError.coreFilesMissing` if the file cannot be read or the data is missing.
    ///   - `VZKitError.coreFilesTampered` if the data is invalid or cannot be used to create the object.
    static func create(dataAt url: URL) throws -> Product {
        
        guard let dataRepresentation = try? Data(contentsOf: url) else {
            throw VZKitError.coreFilesMissing
        }
        
        guard let object = Product(dataRepresentation: dataRepresentation) else {
            throw VZKitError.coreFilesTampered
        }
        
        return object
    }
}

/// Extension to make `VZMacHardwareModel` conform to the `DataRepresentable` protocol.
///
/// This extension enables `VZMacHardwareModel` to utilize the default functionality
/// provided by the `DataRepresentable` protocol, such as serialization and deserialization.
extension VZMacHardwareModel: DataRepresentable {}
