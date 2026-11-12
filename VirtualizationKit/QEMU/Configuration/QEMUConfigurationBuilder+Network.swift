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

extension QEMUConfigurationBuilder {

    /// Emits the network interface of the machine.
    ///
    /// - `none`: no interface at all.
    /// - `nat`: a paravirtualised interface behind the emulator's user-mode network stack, which needs
    ///   no privileges and no entitlement beyond outgoing connections.
    /// - `bridged`: not supported. Bridging needs a restricted entitlement that applications
    ///   distributed through the App Store do not generally receive.
    ///
    /// - Throws: `VZKitError.qemuUnsupportedNetwork` for bridged networking,
    ///   `VZKitError.invalidMacAddress` for a malformed hardware address.
    func appendNetwork(to plan: inout QEMULaunchPlan) throws {

        switch template.networkTopology {
        case .none:
            return

        case .nat(let macAddress):
            // Validation also guarantees that the value cannot inject further options.
            try NetworkTopology.macAddressValidation(macAddress)

            plan.append("-netdev", "user,id=net0")
            plan.append("-device", "virtio-net-pci,netdev=net0,mac=\(macAddress)")

        case .bridged:
            throw VZKitError.qemuUnsupportedNetwork(template.networkTopology.localizedName)
        }
    }
}
