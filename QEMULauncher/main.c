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
#include <pthread.h>
#include <pthread/qos.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/event.h>
#include <unistd.h>

extern char **environ;

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

    /* The emulator sees the library path as its program name, followed by its own arguments. */
    int emulator_argc = argc - 1;
    char **emulator_argv = &argv[1];

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
