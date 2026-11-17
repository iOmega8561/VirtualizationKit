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

    /// Emits a sound card playing through the host's default output device, when the template asks
    /// for audio output.
    ///
    /// Only output is supported; validation rejects audio capture. Playing sound needs no entitlement.
    func appendAudio(to plan: inout QEMULaunchPlan) {

        guard template.optionalCapabilities.contains(.audioOutputDevice) else { return }

        plan.append("-audiodev", "coreaudio,id=audio0")
        plan.append("-device", "intel-hda")
        plan.append("-device", "hda-output,audiodev=audio0")
    }
}
