#include <sys/types.h>
#include <sys/wait.h>

static pid_t traced_waitpid(pid_t pid, int *status, int options);

/* Every ptrace wait for a thread in another thread group needs __WALL. */
#define waitpid(pid, status, options) traced_waitpid((pid), (status), (options))
#include "../ct3_ptrace_write_capture_v1_5/arm_write_capture.c"
#undef waitpid

static pid_t traced_waitpid(pid_t pid, int *status, int options)
{
    return wait4(pid, status, options | __WALL, 0);
}
