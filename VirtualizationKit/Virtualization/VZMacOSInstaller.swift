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
//  VZMacOSInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 20/01/25.
//

import Virtualization

@VZKitActor
extension VZMacOSInstaller {
    
    /// Asynchronously installs the macOS installation image.
    ///
    /// This method bridges the callback-based `install(completion:)` API to Swift's async/await
    /// model by using `withCheckedThrowingContinuation`. The installation is executed within the
    /// VZKitActor's isolation context.
    ///
    /// - Throws: An error if the installation fails. If the underlying error is available from the
    ///   NSError's `underlyingErrors`, that error is thrown; otherwise, the original error is propagated.
    func install() async throws {
        return try await withCheckedThrowingContinuation(isolation: VZKitActor.shared) { continuation in
            
            self.install { result in
                switch result {
                case .failure(let error):
                    continuation.resume(
                        throwing: (error as NSError).underlyingErrors.first ?? error
                    )
                    
                case .success:
                    continuation.resume()
                }
            }
        }
    }
    
    /// Asynchronously initializes a new `VZMacOSInstaller` using the specified virtual machine.
    ///
    /// This convenience initializer performs several steps:
    /// - It checks if the provided virtual machine's template has an operating system other than Linux.
    ///   If the operating system is Linux, the initializer returns `nil` since macOS installation is not applicable.
    /// - It retrieves the bootable install media URL from the virtual machine's template.
    ///   If the URL is missing, it throws a `VZKitError.missingMacImage` error.
    /// - It calls the designated initializer with the underlying virtual machine (`vzVirtualMachine`)
    ///   and the restore image URL.
    /// - Finally, it registers a publisher with the virtual machine's state coordinator to track the
    ///   installation progress using the installer’s `fractionCompleted` property.
    ///
    /// - Parameter virtualMachine: An instance of `AppleVirtualMachine` parameterized over a `TransferableTemplate`.
    /// - Throws: An error if the bootable install media URL is missing or if any asynchronous operation fails.
    /// - Returns: An optional instance of `VZMacOSInstaller`. Returns `nil` if the virtual machine's template
    ///   operating system is Linux.
    convenience init?<Template: TransferableTemplate>(virtualMachine: AppleVirtualMachine<Template>) async throws {
        
        // Ensure that the operating system is appropriate for a macOS installer.
        guard virtualMachine.template.operatingSystem != .linux else {
            return nil
        }
        
        // Retrieve the URL for the bootable install media.
        let restoreImageURL = virtualMachine.template.bootableInstallMedia
        guard let restoreImageURL else {
            throw VZKitError.missingMacImage
        }
                
        // Initialize the installer with the underlying virtual machine and restore image.
        self.init(
            virtualMachine: virtualMachine.vzVirtualMachine,
            restoringFromImageAt: restoreImageURL
        )
        
        // Register a publisher for monitoring installation progress.
        await virtualMachine.stateCoordinator.registerPublisher(
            self.progress.publisher(for: \.fractionCompleted)
        )
    }
}
