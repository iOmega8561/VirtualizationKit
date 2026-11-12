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

/// The interface vended by the helper service, as seen from the application.
///
/// The service is implemented in Objective-C and declares the same protocol in its own header. The two
/// declarations are independent, which keeps the service free of any dependency on this framework; what
/// ties them together is the selector and the argument types of each method, so the selectors are
/// spelled out here rather than derived from the Swift names.
///
/// One connection drives at most one emulator process:
///
/// 1. `stage` is called once per file the emulator needs. Each call hands over an open descriptor and
///    reports the number that descriptor will have inside the emulator process.
/// 2. `launch` starts the emulator and returns the application's end of the control channel.
/// 3. `waitForExit` stays pending until the process is gone. Besides reporting the outcome, the
///    outstanding reply keeps the service from being reclaimed as idle while a guest is running.
/// 4. `terminate` asks the service to end the process if it is still alive.
///
/// Invalidating the connection also ends the process.
@objc protocol QEMUHelperProtocol {

    /// Hands a file over to the service for the next launch.
    ///
    /// - Parameters:
    ///   - fileHandle: An open file. The service keeps its own duplicate.
    ///   - reply: Receives the descriptor number inside the emulator process, or `-1` on failure.
    @objc(stageFileHandle:reply:)
    func stage(fileHandle: FileHandle, reply: @escaping @Sendable (Int32) -> Void)

    /// Starts an emulator process with the staged files.
    ///
    /// - Parameters:
    ///   - libraryName: The name of the system emulator library, without prefix and extension.
    ///   - arguments: The command line of the emulator, without the program name.
    ///   - reply: Receives the control channel on success, or a description of the failure.
    @objc(launchWithLibraryName:arguments:reply:)
    func launch(
        libraryName: String,
        arguments: [String],
        reply: @escaping @Sendable (FileHandle?, String?) -> Void
    )

    /// Waits for the emulator process to exit.
    ///
    /// - Parameter reply: Receives the exit status (the negated signal number if the process was
    ///   killed by a signal) and the tail of what the process wrote to its standard error.
    @objc(waitForExitWithReply:)
    func waitForExit(reply: @escaping @Sendable (Int32, String) -> Void)

    /// Ends the emulator process, forcibly if it does not comply.
    ///
    /// - Parameter reply: Called once the request has been issued.
    @objc(terminateWithReply:)
    func terminate(reply: @escaping @Sendable () -> Void)
}
