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

#import "QEMUHelperSession.h"

#import <errno.h>
#import <fcntl.h>
#import <signal.h>
#import <spawn.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/wait.h>
#import <unistd.h>

/* The descriptor numbers the emulator process is started with. The framework relies on the same layout. */
static const int32_t kControlDescriptor = 3;
static const int32_t kFirstBrokeredDescriptor = 4;
static const NSUInteger kMaximumBrokeredDescriptors = 32;

/*
 * Descriptors that are going to be handed to the child are first moved to this
 * number or above. The child's own numbers all lie well below it, so remapping a
 * descriptor can never overwrite one that has yet to be remapped.
 */
static const int kPrivateDescriptorFloor = 64;

/* How much of the emulator's output is kept for the exit report. */
static const NSUInteger kDiagnosticsLimit = 16 * 1024;

/* How long the emulator gets to honour a termination request. */
static const int64_t kTerminationGraceSeconds = 3;

@implementation QEMUHelperSession {

    /* Serializes every access to the state below. */
    dispatch_queue_t _queue;

    /* Duplicates of the staged files, in staging order. Closed once the child has its copies. */
    NSMutableArray<NSNumber *> *_staged;

    /* The emulator process, or 0 when there is none (not started yet, or reaped). */
    pid_t _child;

    BOOL _hasLaunched;
    BOOL _hasExited;
    int32_t _exitStatus;

    /* The tail of the emulator's output. Guarded by @synchronized, it is written off the queue. */
    NSMutableData *_diagnostics;

    /* The pending -waitForExitWithReply: block, if any. */
    void (^_exitReply)(int32_t, NSString *);
}

- (instancetype)init {

    self = [super init];

    if (self) {
        _queue = dispatch_queue_create("QEMUHelperSession", DISPATCH_QUEUE_SERIAL);
        _staged = [NSMutableArray array];
        _diagnostics = [NSMutableData data];
    }

    return self;
}

#pragma mark - QEMUHelperProtocol

- (void)stageFileHandle:(NSFileHandle *)fileHandle reply:(void (^)(int32_t))reply {

    /* The handle is only guaranteed to be valid during this call: duplicate before going asynchronous. */
    int descriptor = fcntl(fileHandle.fileDescriptor, F_DUPFD_CLOEXEC, kPrivateDescriptorFloor);

    dispatch_async(_queue, ^{

        if (descriptor < 0 || self->_hasLaunched || self->_staged.count >= kMaximumBrokeredDescriptors) {
            if (descriptor >= 0) {
                close(descriptor);
            }

            reply(-1);
            return;
        }

        [self->_staged addObject:@(descriptor)];

        reply(kFirstBrokeredDescriptor + (int32_t)(self->_staged.count - 1));
    });
}

- (void)launchWithLibraryName:(NSString *)libraryName
                    arguments:(NSArray<NSString *> *)arguments
                        reply:(void (^)(NSFileHandle * _Nullable, NSString * _Nullable))reply {

    dispatch_async(_queue, ^{

        NSString *failure = nil;
        int controlChannel = [self launchLibraryNamed:libraryName arguments:arguments failure:&failure];

        if (controlChannel < 0) {
            reply(nil, failure ?: @"the emulator could not be started");
            return;
        }

        /* The reply transfers a duplicate; this copy is closed together with the handle. */
        reply([[NSFileHandle alloc] initWithFileDescriptor:controlChannel closeOnDealloc:YES], nil);
    });
}

- (void)waitForExitWithReply:(void (^)(int32_t, NSString *))reply {

    dispatch_async(_queue, ^{

        if (!self->_hasLaunched) {
            reply(-1, @"no emulator has been launched on this connection");
            return;
        }

        if (self->_hasExited) {
            reply(self->_exitStatus, [self diagnosticsText]);
            return;
        }

        void (^superseded)(int32_t, NSString *) = self->_exitReply;
        self->_exitReply = [reply copy];

        if (superseded) {
            superseded(-1, @"superseded by a newer request");
        }
    });
}

- (void)terminateWithReply:(void (^)(void))reply {

    dispatch_async(_queue, ^{
        [self terminateChild];
        reply();
    });
}

- (void)invalidate {

    dispatch_async(_queue, ^{
        [self terminateChild];
        [self closeStagedDescriptors];
    });
}

#pragma mark - Launch

/*
 * Starts the launcher with the emulator library and the staged files. Runs on the queue.
 * Returns the application's end of the control channel, or -1 with a reason.
 */
- (int)launchLibraryNamed:(NSString *)libraryName
                arguments:(NSArray<NSString *> *)arguments
                  failure:(NSString **)failure {

    if (_hasLaunched) {
        *failure = @"an emulator has already been launched on this connection";
        return -1;
    }

    /* The name selects a file inside this bundle. It must not be able to point anywhere else. */
    NSCharacterSet *permitted = [NSCharacterSet characterSetWithCharactersInString:
                                 @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];

    if (libraryName.length == 0 ||
        [libraryName rangeOfCharacterFromSet:permitted.invertedSet].location != NSNotFound) {
        *failure = @"the emulator library name is not valid";
        return -1;
    }

    NSBundle *bundle = NSBundle.mainBundle;
    NSFileManager *fileManager = NSFileManager.defaultManager;

    NSString *launcher = [bundle pathForAuxiliaryExecutable:@"QEMULauncher"];
    NSString *library = [bundle.privateFrameworksPath stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"lib%@.dylib", libraryName]];
    NSString *dataDirectory = [bundle.resourcePath stringByAppendingPathComponent:@"qemu"];

    if (launcher == nil || ![fileManager isExecutableFileAtPath:launcher]) {
        *failure = @"the emulator launcher is missing from the helper service";
        return -1;
    }

    if (library == nil || ![fileManager fileExistsAtPath:library]) {
        *failure = [NSString stringWithFormat:@"the emulator library '%@' is missing from the helper service", libraryName];
        return -1;
    }

    /* The control channel, and a pipe collecting whatever the emulator prints. */
    int sockets[2] = { -1, -1 };
    int output[2] = { -1, -1 };

    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) != 0) {
        *failure = [NSString stringWithFormat:@"socketpair: %s", strerror(errno)];
        return -1;
    }

    if (pipe(output) != 0) {
        *failure = [NSString stringWithFormat:@"pipe: %s", strerror(errno)];
        close(sockets[0]);
        close(sockets[1]);
        return -1;
    }

    int childControl = fcntl(sockets[1], F_DUPFD_CLOEXEC, kPrivateDescriptorFloor);
    int childOutput = fcntl(output[1], F_DUPFD_CLOEXEC, kPrivateDescriptorFloor);

    close(sockets[1]);
    close(output[1]);
    fcntl(sockets[0], F_SETFD, FD_CLOEXEC);
    fcntl(output[0], F_SETFD, FD_CLOEXEC);

    if (childControl < 0 || childOutput < 0) {
        *failure = [NSString stringWithFormat:@"fcntl: %s", strerror(errno)];

        if (childControl >= 0) {
            close(childControl);
        }

        if (childOutput >= 0) {
            close(childOutput);
        }

        close(sockets[0]);
        close(output[0]);
        return -1;
    }

    /*
     * Only what is listed here reaches the child: with CLOEXEC_DEFAULT every
     * other descriptor of this process is closed in it.
     */
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_adddup2(&actions, childOutput, STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, childOutput, STDERR_FILENO);
    posix_spawn_file_actions_adddup2(&actions, childControl, kControlDescriptor);

    for (NSUInteger index = 0; index < _staged.count; index++) {
        posix_spawn_file_actions_adddup2(&actions,
                                         _staged[index].intValue,
                                         kFirstBrokeredDescriptor + (int)index);
    }

    /* Start from a clean signal state, whatever this process has set up for itself. */
    sigset_t noSignals;
    sigset_t mostSignals;

    sigemptyset(&noSignals);
    sigfillset(&mostSignals);
    sigdelset(&mostSignals, SIGKILL);
    sigdelset(&mostSignals, SIGSTOP);

    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setsigmask(&attributes, &noSignals);
    posix_spawnattr_setsigdefault(&attributes, &mostSignals);
    posix_spawnattr_setflags(&attributes,
                             (short)(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF));

    /* launcher <library> -L <data directory> <arguments...> */
    NSMutableArray<NSString *> *commandLine = [NSMutableArray arrayWithObjects:launcher, library, nil];

    if ([fileManager fileExistsAtPath:dataDirectory]) {
        [commandLine addObject:@"-L"];
        [commandLine addObject:dataDirectory];
    }

    [commandLine addObjectsFromArray:arguments];

    NSMutableDictionary<NSString *, NSString *> *environment = [NSProcessInfo.processInfo.environment mutableCopy];
    environment[@"TMPDIR"] = NSTemporaryDirectory();

    char **argv = calloc(commandLine.count + 1, sizeof(char *));
    char **envp = calloc(environment.count + 1, sizeof(char *));
    NSUInteger position = 0;

    for (NSString *argument in commandLine) {
        argv[position++] = strdup(argument.UTF8String ?: "");
    }

    position = 0;

    for (NSString *name in environment) {
        envp[position++] = strdup([NSString stringWithFormat:@"%@=%@", name, environment[name]].UTF8String ?: "");
    }

    pid_t child = 0;
    int result = posix_spawn(&child, launcher.fileSystemRepresentation, &actions, &attributes, argv, envp);

    for (char **entry = argv; *entry != NULL; entry++) {
        free(*entry);
    }

    for (char **entry = envp; *entry != NULL; entry++) {
        free(*entry);
    }

    free(argv);
    free(envp);
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attributes);

    /* The child has its own copies now (or never will). */
    close(childControl);
    close(childOutput);
    [self closeStagedDescriptors];

    if (result != 0) {
        *failure = [NSString stringWithFormat:@"posix_spawn: %s", strerror(result)];
        close(sockets[0]);
        close(output[0]);
        return -1;
    }

    _hasLaunched = YES;
    _child = child;

    [self monitorChild:child output:output[0]];

    return sockets[0];
}

/*
 * Collects the output of the child and waits for it to exit, off the queue. The
 * exit is only reported once the output has been read to its end, so that the
 * diagnostics of a failed start are complete.
 */
- (void)monitorChild:(pid_t)child output:(int)output {

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t background = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    NSMutableData *diagnostics = _diagnostics;

    __block int32_t status = -1;

    dispatch_group_async(group, background, ^{

        char buffer[4096];

        for (;;) {
            ssize_t count = read(output, buffer, sizeof(buffer));

            if (count > 0) {
                @synchronized (diagnostics) {
                    [diagnostics appendBytes:buffer length:(NSUInteger)count];

                    if (diagnostics.length > kDiagnosticsLimit) {
                        [diagnostics replaceBytesInRange:NSMakeRange(0, diagnostics.length - kDiagnosticsLimit)
                                               withBytes:NULL
                                                  length:0];
                    }
                }
            } else if (count < 0 && errno == EINTR) {
                continue;
            } else {
                break;
            }
        }

        close(output);
    });

    dispatch_group_async(group, background, ^{

        int raw = 0;
        pid_t reaped;

        do {
            reaped = waitpid(child, &raw, 0);
        } while (reaped < 0 && errno == EINTR);

        if (reaped == child && WIFEXITED(raw)) {
            status = WEXITSTATUS(raw);
        } else if (reaped == child && WIFSIGNALED(raw)) {
            status = -WTERMSIG(raw);
        }
    });

    dispatch_group_notify(group, _queue, ^{

        self->_child = 0;
        self->_hasExited = YES;
        self->_exitStatus = status;

        void (^reply)(int32_t, NSString *) = self->_exitReply;
        self->_exitReply = nil;

        if (reply) {
            reply(status, [self diagnosticsText]);
        }
    });
}

#pragma mark - Helpers

/* Asks the child to exit, and kills it if it is still there after the grace period. Runs on the queue. */
- (void)terminateChild {

    pid_t child = _child;

    if (child <= 0) {
        return;
    }

    kill(child, SIGTERM);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kTerminationGraceSeconds * NSEC_PER_SEC), _queue, ^{

        /* The identifier is cleared when the child is reaped, so a recycled one is never signalled. */
        if (self->_child == child) {
            kill(child, SIGKILL);
        }
    });
}

/* Closes this process's duplicates of the staged files. Runs on the queue. */
- (void)closeStagedDescriptors {

    for (NSNumber *descriptor in _staged) {
        close(descriptor.intValue);
    }

    [_staged removeAllObjects];
}

/* The collected output as text, tolerating a multi-byte sequence cut at the truncation point. */
- (NSString *)diagnosticsText {

    @synchronized (_diagnostics) {
        NSString *text = [[NSString alloc] initWithData:_diagnostics encoding:NSUTF8StringEncoding];

        if (text == nil) {
            text = [[NSString alloc] initWithData:_diagnostics encoding:NSISOLatin1StringEncoding];
        }

        return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    }
}

@end
