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

    /// Emits a TPM 2.0 device backed by a software TPM, when the options ask for one.
    ///
    /// The software TPM is a process of its own, started by the launcher just before the emulator:
    ///
    /// 1. Its state file is opened here, like every other file of the machine, and handed over as a
    ///    plain descriptor. Neither the TPM nor the emulator ever opens a host path.
    /// 2. The launcher option `-launcher-tpm <descriptor>` tells the launcher to create a connected
    ///    socket pair, start the TPM with one end as its control channel and the state descriptor as
    ///    its storage, and place the other end at a fixed number in the emulator process.
    /// 3. The emulator reaches the TPM through a socket character device on that number. It hands the
    ///    TPM a data channel of its own over the control channel.
    ///
    /// The TPM ends itself when the emulator closes the control channel, however the emulator exits.
    func appendTPM(to plan: inout QEMULaunchPlan) throws {

        guard options.includesTPM else { return }

        let state = plan.stage(.init(url: try storage.prepareTPMState(), access: .readWrite))

        plan.append(QEMULaunchPlan.launcherTPMOption, "\(state)")
        plan.append("-chardev", "socket,id=tpm0chr,fd=\(QEMULaunchPlan.tpmControlDescriptor)")
        plan.append("-tpmdev", "emulator,id=tpm0,chardev=tpm0chr")

        switch options.architecture {
        case .aarch64: plan.append("-device", "tpm-tis-device,tpmdev=tpm0")
        case .x86_64: plan.append("-device", "tpm-crb,tpmdev=tpm0")
        }
    }
}
