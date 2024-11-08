//
//  VZKitResult.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

/// `VZKitResult` is a typealias representing the result of a virtual machine operation within the `VirtualizationKit` framework.
///
/// This type provides a "graceful" way to handle and represent the outcome of operations, either returning a successfully created
/// `VirtualMachine` instance or capturing any errors encountered during the process. By using `VZKitResult`, error propagation is
/// simplified, allowing for controlled handling of success and failure cases without the need to throw or propagate errors further.
///
/// - Parameters:
///   - TemplateType: The type of template used to configure the virtual machine. Must conform to `VZKitTemplate`.
/// - Returns: A `Result` type where:
///   - `.success` holds a `VirtualMachine` instance parameterized by `TemplateType`,
///     representing a successfully created virtual machine.
///   - `.failure` holds an `Error`, representing an issue encountered during the virtual machine creation process.
public typealias VZKitResult<TemplateType: VZKitTemplate> = Result<VirtualMachine<TemplateType>, Error>
