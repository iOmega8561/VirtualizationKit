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

@Suite("Stored values")
struct CodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("QEMU options stored by 1.x decode; their removed keys are ignored")
    func legacyQEMUOptions() throws {
        let arm = try decode(QEMUMachineOptions.self, #"{"architecture":"aarch64","displayWidth":1280,"displayHeight":720,"includesTPM":true,"usesSecureBootFirmware":false,"displayDevice":"automatic"}"#)
        #expect(arm == QEMUMachineOptions(displayDevice: .virtioGPU))

        let x86 = try decode(QEMUMachineOptions.self, #"{"architecture":"x86_64","displayDevice":"automatic"}"#)
        #expect(x86 == QEMUMachineOptions(architecture: .x86_64, displayDevice: .virtioGPUWithFramebuffer))

        #expect(try decode(QEMUMachineOptions.self, "{}") == .default)
        #expect(throws: DecodingError.self) { try decode(QEMUMachineOptions.self, #"{"displayDevice":"voodoo"}"#) }
    }

    @Test("QEMU options survive encoding")
    func qemuOptionsRoundTrip() throws {
        let options = QEMUMachineOptions(architecture: .x86_64, displayDevice: .virtioGPUWithFramebuffer, clock: .localTime, guestDrawsPointer: true)
        #expect(try JSONDecoder().decode(QEMUMachineOptions.self, from: JSONEncoder().encode(options)) == options)
    }

    @Test("Apple options survive encoding")
    func appleOptionsRoundTrip() throws {
        let options = AppleMachineOptions(platform: .macOS(version: .init(major: 15, minor: 1, patch: 0), restoreImage: Data([1, 2])))
        #expect(try JSONDecoder().decode(AppleMachineOptions.self, from: JSONEncoder().encode(options)) == options)
        #expect(AppleMachineOptions.default.platform == .linux)
    }

    @Test("Presets stored by 1.x, with a disk size, still decode")
    func legacyPreset() throws {
        let preset = try decode(PerformancePreset.self, #"{"custom":{"desiredCoreCount":2,"desiredMemorySize":1024,"desiredDiskSize":5}}"#)
        #expect(preset == .custom(desiredCoreCount: 2, desiredMemorySize: 1024))
    }

    @Test("Display sizes are clamped when created and when decoded")
    func displaySize() throws {
        #expect(DisplaySize(width: 10, height: 99_999) == DisplaySize(width: 640, height: 4320))
        let decoded = try decode(DisplaySize.self, #"{"width":100000,"height":1}"#)
        #expect(decoded.width == DisplaySize.maximum.width && decoded.height == DisplaySize.minimum.height)
    }
}
