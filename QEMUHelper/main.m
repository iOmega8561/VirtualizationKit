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

#import "QEMUHelperProtocol.h"
#import "QEMUHelperSession.h"

/*
 * Accepts the connections of the embedding application. Every connection gets a
 * session of its own, so several virtual machines can run side by side inside
 * this one service process, each in a separate emulator process.
 */
@interface QEMUHelperListenerDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation QEMUHelperListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)connection {

    QEMUHelperSession *session = [[QEMUHelperSession alloc] init];

    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(QEMUHelperProtocol)];
    connection.exportedObject = session;

    /* The application went away or released the machine: the guest must not outlive it. */
    connection.invalidationHandler = ^{ [session invalidate]; };
    connection.interruptionHandler = ^{ [session invalidate]; };

    [connection resume];

    return YES;
}

@end

int main(int argc, const char *argv[]) {

    static QEMUHelperListenerDelegate *delegate;

    delegate = [[QEMUHelperListenerDelegate alloc] init];

    NSXPCListener *listener = [NSXPCListener serviceListener];
    listener.delegate = delegate;

    /* Never returns for a service listener. */
    [listener resume];

    return 0;
}
