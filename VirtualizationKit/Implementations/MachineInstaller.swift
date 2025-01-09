//
//  MachineInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 01/05/24.
//

import Combine

@preconcurrency import Virtualization

/// The `MachineInstaller` struct provides the necessary facilities to install macOS on a virtual machine,
/// leveraging a valid restore image. It conforms to the `VZKitMachineInstaller` protocol, implementing the required
/// properties and installation method to handle the macOS installation process.
///
/// - Important: The `VZVirtualMachine` instance used here is not `Sendable`, which affects concurrency safety.
///   As a result, the `Virtualization` framework is imported with `@preconcurrency` to silence the Swift compiler.
struct MachineInstaller: VZKitMachineInstaller {
    
    /// A URL that points to the location of the restore image on the host file system.
    ///
    /// The `restoreImage` property provides the path to a macOS restore image required for the installation process.
    /// This URL should point to a compatible image, typically an IPSW file, that will be used to initialize the virtual
    /// machine’s macOS environment.
    let restoreImage: URL
    
    /// A reference to the `VZVirtualMachine` instance on which the installation process will be performed.
    ///
    /// The `vzVirtualMachine` property provides access to the virtual machine where macOS will be installed. It is essential
    /// that this `VZVirtualMachine` instance is properly initialized and ready to accept the installation image.
    /// Note that `VZVirtualMachine` is not `Sendable`, so it should be managed with care in concurrent contexts.
    let vzVirtualMachine: VZVirtualMachine
            
    /// Initiates the macOS installation process on the virtual machine, tracking progress and handling errors.
    ///
    /// This method is marked with `@VZKitActor`, ensuring it executes on the same actor queue as the virtual
    /// machine’s initializer, maintaining thread safety and sequence consistency. Due to limitations in the
    /// `Virtualization` framework’s concurrency model, this method uses a checked continuation to bridge the asynchronous
    /// API with Swift’s structured concurrency.
    ///
    /// - Parameter stateManager: The `VZKitObservableState` instance responsible for tracking the execution state and
    ///   installation progress. This method registers the installer’s progress with `stateManager` so that any observers
    ///   (e.g., SwiftUI views) can receive real-time updates.
    ///
    /// - Throws: An error if the installation process encounters an issue. If the installer fails with an underlying error,
    ///   it attempts to throw the root cause.
    @VZKitActor func startInstallation(_ stateManager: VZKitObservableState) async throws {
                
        let installer = VZMacOSInstaller(
            virtualMachine: vzVirtualMachine,
            restoringFromImageAt: self.restoreImage
        )
        
        await stateManager.registerPublisher(
            installer.progress.publisher(for: \.fractionCompleted)
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            
            installer.install { result in
                switch result {
                case let .failure(error as NSError):
                    
                    if let underlying = error.underlyingErrors.first {
                        continuation.resume(throwing: underlying)
                        
                    } else { continuation.resume(throwing: error) }
                        
                default:
                    continuation.resume()
                }
            }
        }
    }
    
    /// Initializes a new `MachineInstaller` with the provided restore image and virtual machine instance.
    ///
    /// The initializer checks that the `restoreImage` URL is valid and points to an existing file. If the file is missing,
    /// it throws an error to indicate that the installation cannot proceed.
    ///
    /// - Parameters:
    ///   - restoreImage: A `URL` pointing to the location of the macOS restore image on the host file system.
    ///   - machine: The `VZVirtualMachine` instance where the installation will occur.
    ///
    /// - Throws: `VZKitError.missingMacImage` if the specified `restoreImage` URL is nil or does not point to an existing file.
    init(restoreImage: URL?, vzVirtualMachine: VZVirtualMachine) throws {
        
        guard let restoreImage, FileManager.default.fileExists(
            atPath: restoreImage.path(percentEncoded: false)
            
        ) else { throw VZKitError.missingMacImage }
        
        self.restoreImage = restoreImage
        self.vzVirtualMachine = vzVirtualMachine
    }
}
