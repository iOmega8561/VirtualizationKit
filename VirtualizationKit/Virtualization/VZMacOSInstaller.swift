//
//  VZMacOSInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 20/01/25.
//

import Virtualization

@VZKitActor extension VZMacOSInstaller {
    
    func install() async throws {
        
        return try await withCheckedThrowingContinuation(isolation: VZKitActor.shared) { continuation in
            
            self.install { result in
                
                switch result {
                case .failure(let error): continuation.resume(
                    throwing: (error as NSError).underlyingErrors.first ?? error
                )
                     
                case .success: continuation.resume()
                }
            }
        }
    }
    
    convenience init?<Template: TransferableTemplate>(virtualMachine: AppleVirtualMachine<Template>) async throws {
        
        guard virtualMachine.template.operatingSystem != .linux else {
            return nil
        }
        
        let restoreImageURL = virtualMachine.template.bootableInstallMedia
        
        guard let restoreImageURL else {
            throw VZKitError.missingMacImage
        }
                
        self.init(
            virtualMachine: virtualMachine.vzVirtualMachine,
            restoringFromImageAt: restoreImageURL
        )
        
        await virtualMachine.stateCoordinator.registerPublisher(
            self.progress.publisher(for: \.fractionCompleted)
        )
    }
}
