#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>

typedef void (*signal_handler_t)(int);
static pid_t safe_waitpid(pid_t pid, int *status, int options);
static signal_handler_t safe_signal(int sig, signal_handler_t handler);

#define waitpid(pid, status, options) safe_waitpid((pid), (status), (options))
#define signal(sig, handler) safe_signal((sig), (handler))
#include "../ct3_ptrace_write_capture_v1_5/arm_write_capture.c"
#undef signal
#undef waitpid

static signal_handler_t safe_signal(int sig, signal_handler_t handler)
{
    struct sigaction action;
    struct sigaction previous;
    action.sa_handler = handler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0; /* Deliberately no SA_RESTART. */
    if (sigaction(sig, &action, &previous) == -1)
        return SIG_ERR;
    return previous.sa_handler;
}

static pid_t safe_waitpid(pid_t pid, int *status, int options)
{
    pid_t result = wait4(pid, status, options | __WALL, 0);
    if (result == -1 && errno == EINTR && stop_requested) {
        /* PTRACE_DETACH requires a ptrace-stop. Force one, reap it, then the
         * caller leaves its loop and detaches explicitly. */
        kill(pid, SIGSTOP);
        do {
            result = wait4(pid, status, options | __WALL, 0);
        } while (result == -1 && errno == EINTR);
    }
    return result;
}
