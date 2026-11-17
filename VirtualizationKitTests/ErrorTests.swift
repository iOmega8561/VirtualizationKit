//
//  Copyright 2026 Giuseppe Rocco
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

import Foundation
import Testing
@testable import VirtualizationKit

@Suite("Errors")
struct ErrorTests {

    @Test("Every error has a localized message, not its key")
    func localized() {
        let errors: [VZKitError] = [
            .appleLimitExceeded, .missingMacImage, .macPlatformRequired, .internalVirtualizationError,
            .diskImageUnreachable("a.img"), .diskImageUnreachable(nil), .invalidDiskImage(UUID()),
            .unsupportedDiskInterface(.optical, .virtio), .featureNotEnabled(.xhciUSBHotSwap),
            .permissionDenied(.audioCaptureDevice), .qemuPayloadMissing("QEMUTPM"),
            .qemuCommandFailed("stop", "no reply from the emulator")
        ]
        for error in errors {
            let message = error.localizedDescription
            #expect(!message.isEmpty, "\(error)")
            #expect(!message.hasPrefix("error-"), "\(error) shows its key: \(message)")
        }
    }

    @Test("Each reason a capability cannot be provided has a message of its own")
    func reasons() {
        var messages = Set<String>()
        for limitation in CapabilitySupport.Limitation.allCases {
            messages.insert(VZKitError.unsupportedFeature(.rosetta, limitation).localizedDescription)
        }
        for missing in CapabilitySupport.MissingComponent.allCases {
            messages.insert(VZKitError.unavailableFeature(.rosetta, missing).localizedDescription)
        }
        messages.insert(VZKitError.featureNotEnabled(.rosetta).localizedDescription)
        #expect(messages.count == CapabilitySupport.Limitation.allCases.count + CapabilitySupport.MissingComponent.allCases.count + 1)
    }
}
