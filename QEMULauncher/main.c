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

/*
 * The process a guest runs in.
 *
 * The emulator is not a program of its own here: it is built as a dynamic
 * library and this small executable is what loads it. The launcher is started
 * by the helper service, inherits its sandbox, and receives everything it is
 * allowed to touch as already-open descriptors.
 *
 *     QEMULauncher <emulator library> [emulator arguments...]
 */

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/event.h>
#include <sys/socket.h>
#include <unistd.h>

extern char **environ;

/*
 * The software TPM. When the command line carries
 *
 *     -launcher-tpm <state descriptor>
 *
 * the launcher removes the option, starts the TPM executable that sits next to
 * it with the state descriptor as its storage, and places the emulator's end of
 * their control channel at kTPMControlDescriptor. The framework uses the same
 * option name and number.
 */
static const char *kTPMOption = "-launcher-tpm";
static const int kTPMControlDescriptor = 100;
static const char *kTPMExecutable = "QEMUTPM";

/* The entry points of a system emulator library. */
typedef void (*emulator_init_t)(int argc, char **argv, char **envp);
typedef int (*emulator_main_loop_t)(void);
typedef void (*emulator_cleanup_t)(int status);
typedef int (*emulator_main_t)(int argc, char **argv);

/*
 * Exits as soon as the parent does. The helper service ends its children when
 * it can, but it may itself be killed without notice, and a guest must never
 * be left running with nothing in control of it.
 */
static void *watch_parent(void *context) {

    pid_t parent = (pid_t)(intptr_t)context;
    int queue = kqueue();

    if (queue != -1) {
        struct kevent event;

        EV_SET(&event, parent, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, NULL);

        /* Fails right away if the parent is already gone, which is just as conclusive. */
        kevent(queue, &event, 1, &event, 1, NULL);
    }

    _exit(EXIT_FAILURE);
    return NULL;
}

/*
 * Starts the software TPM. The TPM inherits exactly two descriptors: its end of
 * the control channel as 3 and its state file as 4. It ends itself when the
 * emulator closes the control channel (--terminate), however the emulator exits.
 * Returns 0, or -1 after printing the reason.
 */
static int start_tpm(int state_descriptor) {

    char executable[PATH_MAX];
    uint32_t size = sizeof(executable);
    char *separator = NULL;

    if (_NSGetExecutablePath(executable, &size) != 0 || (separator = strrchr(executable, '/')) == NULL) {
        fprintf(stderr, "cannot locate the launcher executable\n");
        return -1;
    }

    /* The TPM executable sits in the same directory as this one. */
    *separator = '\0';

    char tpm[PATH_MAX];
    snprintf(tpm, sizeof(tpm), "%s/%s", executable, kTPMExecutable);

    if (access(tpm, X_OK) != 0) {
        fprintf(stderr, "the software TPM is missing from the helper service: %s\n", tpm);
        return -1;
    }

    if (fcntl(state_descriptor, F_GETFD) == -1) {
        fprintf(stderr, "the TPM state descriptor %d is not open\n", state_descriptor);
        return -1;
    }

    int channel[2] = { -1, -1 };

    if (socketpair(AF_UNIX, SOCK_STREAM, 0, channel) != 0) {
        fprintf(stderr, "socketpair: %s\n", strerror(errno));
        return -1;
    }

    /* The emulator's end, at the number its command line refers to. */
    if (dup2(channel[0], kTPMControlDescriptor) == -1) {
        fprintf(stderr, "dup2: %s\n", strerror(errno));
        close(channel[0]);
        close(channel[1]);
        return -1;
    }

    close(channel[0]);
    fcntl(kTPMControlDescriptor, F_SETFD, FD_CLOEXEC);

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_adddup2(&actions, channel[1], 3);
    posix_spawn_file_actions_adddup2(&actions, state_descriptor, 4);

    /* Nothing but stdout, stderr (shared with the emulator's diagnostics), 3 and 4. */
    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);

    char *tpm_argv[] = {
        (char *)kTPMExecutable,
        "socket",
        "--tpm2",
        "--terminate",
        "--ctrl", "type=unixio,clientfd=3",
        "--tpmstate", "backend-uri=file:///dev/fd/4",
        NULL
    };

    pid_t pid = 0;
    int result = posix_spawn(&pid, tpm, &actions, &attributes, tpm_argv, environ);

    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attributes);

    /* The TPM has its own copies now (or never will). */
    close(channel[1]);
    close(state_descriptor);

    if (result != 0) {
        fprintf(stderr, "cannot start the software TPM: %s\n", strerror(result));
        close(kTPMControlDescriptor);
        return -1;
    }

    return 0;
}

int main(int argc, char *argv[]) {

    if (argc < 2) {
        fprintf(stderr, "usage: %s <emulator library> [emulator arguments...]\n", argv[0]);
        return EXIT_FAILURE;
    }

    pid_t parent = getppid();

    /* Already re-parented: the service died between spawning this process and now. */
    if (parent == 1) {
        return EXIT_FAILURE;
    }

    pthread_t watcher;

    if (pthread_create(&watcher, NULL, watch_parent, (void *)(intptr_t)parent) == 0) {
        pthread_detach(watcher);
    }

    /* A guest is interactive work, whatever the priority this process was started with. */
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    /* RTLD_FIRST confines the lookups below to the library itself: this executable has a main() too. */
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL | RTLD_FIRST);

    if (library == NULL) {
        fprintf(stderr, "cannot load %s: %s\n", argv[1], dlerror());
        return EXIT_FAILURE;
    }

    emulator_init_t emulator_init = (emulator_init_t)dlsym(library, "qemu_init");
    emulator_main_loop_t emulator_main_loop = (emulator_main_loop_t)dlsym(library, "qemu_main_loop");
    emulator_cleanup_t emulator_cleanup = (emulator_cleanup_t)dlsym(library, "qemu_cleanup");
    emulator_main_t emulator_main = (emulator_main_t)dlsym(library, "main");

    /*
     * The emulator sees the library path as its program name, followed by its
     * own arguments. Options meant for the launcher are taken out on the way.
     */
    char **emulator_argv = calloc((size_t)argc, sizeof(char *));
    int emulator_argc = 0;

    if (emulator_argv == NULL) {
        fprintf(stderr, "out of memory\n");
        return EXIT_FAILURE;
    }

    for (int index = 1; index < argc; index++) {

        if (strcmp(argv[index], kTPMOption) == 0) {

            if (index + 1 >= argc) {
                fprintf(stderr, "%s needs a descriptor\n", kTPMOption);
                return EXIT_FAILURE;
            }

            char *end = NULL;
            long descriptor = strtol(argv[++index], &end, 10);

            if (end == NULL || *end != '\0' || descriptor < 3 || descriptor >= kTPMControlDescriptor) {
                fprintf(stderr, "%s: invalid descriptor '%s'\n", kTPMOption, argv[index]);
                return EXIT_FAILURE;
            }

            if (start_tpm((int)descriptor) != 0) {
                return EXIT_FAILURE;
            }

            continue;
        }

        emulator_argv[emulator_argc++] = argv[index];
    }

    if (emulator_init != NULL && emulator_main_loop != NULL && emulator_cleanup != NULL) {

        /*
         * Initialisation, main loop and cleanup all run on this thread. The
         * emulator's global lock is taken during initialisation and is expected
         * to still be held by whoever runs the main loop.
         */
        emulator_init(emulator_argc, emulator_argv, environ);

        int status = emulator_main_loop();

        emulator_cleanup(status);
        exit(status);
    }

    if (emulator_main != NULL) {
        exit(emulator_main(emulator_argc, emulator_argv));
    }

    fprintf(stderr, "%s does not export the emulator entry points\n", argv[1]);
    return EXIT_FAILURE;
}
