/*
 *  Copyright 2026 Giuseppe Rocco
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * The interface this service vends to the application.
 *
 * The framework declares the same protocol in Swift. The two declarations are
 * independent of each other; what has to match is the selector and the argument
 * types of every method. Change them on both sides or not at all.
 *
 * One connection drives at most one emulator process:
 *
 *   1. -stageFileHandle:reply: is called once per file the emulator needs.
 *   2. -launchWithLibraryName:arguments:reply: starts the emulator.
 *   3. -waitForExitWithReply: stays pending until the process is gone. The
 *      outstanding reply also keeps the service from being reclaimed as idle.
 *   4. -terminateWithReply: ends the process if it is still alive.
 *
 * Invalidating the connection ends the process as well.
 */
@protocol QEMUHelperProtocol

/*
 * Keeps a duplicate of an open file for the next launch and reports the
 * descriptor number the file will have inside the emulator process, or -1.
 */
- (void)stageFileHandle:(NSFileHandle *)fileHandle
                  reply:(void (^)(int32_t descriptor))reply;

/*
 * Starts the emulator library with the given command line. On success the reply
 * carries the application's end of the control channel; on failure, a reason.
 */
- (void)launchWithLibraryName:(NSString *)libraryName
                    arguments:(NSArray<NSString *> *)arguments
                        reply:(void (^)(NSFileHandle * _Nullable controlChannel,
                                        NSString * _Nullable failure))reply;

/*
 * Replies once the emulator process has exited, with its exit status (the
 * negated signal number if it was killed by a signal) and the tail of what it
 * wrote to its standard output and error.
 */
- (void)waitForExitWithReply:(void (^)(int32_t status, NSString *diagnostics))reply;

/*
 * Sends the emulator a termination request, followed by a kill if it has not
 * exited after a grace period.
 */
- (void)terminateWithReply:(void (^)(void))reply;

@end

NS_ASSUME_NONNULL_END
