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

/// Keeps a second virtual machine from using the files of a machine that is already in use.
///
/// Both backends keep the files of a machine (its managed disks, firmware variables, TPM state) in one
/// directory per template. Two machines created from the same template would open the same disks for
/// writing and corrupt them. This lock, a `flock` on a file in that directory, is held for as long as the
/// machine exists; a second machine for the same template, in this process or another one, is refused.
/// The system releases the lock when the machine goes away, or when its process ends, even by crashing.
///
/// - Note: External disk images live outside the directory and are not covered.
final class MachineLock: Sendable {

    /// The open lock file. Closing it releases the lock.
    private let descriptor: Int32

    /// Takes the lock of a machine directory.
    ///
    /// - Parameter directory: The directory holding the files of the machine. It must exist.
    /// - Throws: `VZKitError.machineInUse` if another machine holds the lock, or
    ///   `VZKitError.diskImageFailedSetup` if the lock file cannot be created.
    init(directory: URL) throws {
        let path = directory.appendingPathComponent(".lock", isDirectory: false).path(percentEncoded: false)
        let descriptor = unsafe open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)

        guard descriptor >= 0 else {
            VZKitLogger.default.error("The lock file of \(directory.lastPathComponent) cannot be created (\(errno))")
            throw VZKitError.diskImageFailedSetup
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(descriptor)
            if code == EWOULDBLOCK { throw VZKitError.machineInUse }
            VZKitLogger.default.error("The lock of \(directory.lastPathComponent) cannot be taken (\(code))")
            throw VZKitError.diskImageFailedSetup
        }

        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }
}
