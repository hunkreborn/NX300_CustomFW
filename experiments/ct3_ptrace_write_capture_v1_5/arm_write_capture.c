#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <asm/ptrace.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t stop_requested;

static void request_stop(int sig)
{
    (void)sig;
    stop_requested = 1;
}

static int copy_tracee(pid_t tid, unsigned long address, unsigned char *out,
                       size_t length)
{
    size_t offset;
    for (offset = 0; offset < length; offset += sizeof(long)) {
        long word;
        size_t chunk = length - offset;
        if (chunk > sizeof(long))
            chunk = sizeof(long);
        errno = 0;
        word = ptrace(PTRACE_PEEKDATA, tid, (void *)(address + offset), 0);
        if (word == -1 && errno)
            return -1;
        memcpy(out + offset, &word, chunk);
    }
    return 0;
}

static void dump_write(FILE *output, unsigned long sequence,
                       const struct pt_regs *regs, const unsigned char *data,
                       size_t length)
{
    size_t i;
    fprintf(output, "WRITE seq=%lu fd=%ld ptr=0x%08lx count=%ld r0=%ld pc=0x%08lx\n",
            sequence, regs->ARM_r0, (unsigned long)regs->ARM_r1,
            regs->ARM_r2, regs->ARM_r0, (unsigned long)regs->ARM_pc);
    fprintf(output, "HEX ");
    for (i = 0; i < length; ++i)
        fprintf(output, "%02x", data[i]);
    fprintf(output, "\nASCII ");
    for (i = 0; i < length; ++i)
        fputc(data[i] >= 32 && data[i] < 127 ? data[i] : '.', output);
    fprintf(output, "\n");
    fflush(output);
}

int main(int argc, char **argv)
{
    pid_t tid;
    FILE *output;
    unsigned long sequence = 0;
    int status;

    if (argc != 3) {
        fprintf(stderr, "usage: %s TID OUTPUT\n", argv[0]);
        return 2;
    }
    tid = (pid_t)strtol(argv[1], 0, 10);
    output = fopen(argv[2], "w");
    if (!output) {
        perror("fopen");
        return 3;
    }
    signal(SIGINT, request_stop);
    signal(SIGTERM, request_stop);

    if (ptrace(PTRACE_ATTACH, tid, 0, 0) == -1) {
        perror("PTRACE_ATTACH");
        fclose(output);
        return 4;
    }
    if (waitpid(tid, &status, 0) == -1) {
        perror("waitpid attach");
        fclose(output);
        return 5;
    }
    ptrace(PTRACE_SETOPTIONS, tid, 0, PTRACE_O_TRACESYSGOOD);

    while (!stop_requested) {
        struct pt_regs regs;
        int deliver = 0;
        if (ptrace(PTRACE_SYSCALL, tid, 0, deliver) == -1)
            break;
        if (waitpid(tid, &status, 0) == -1)
            break;
        if (WIFEXITED(status) || WIFSIGNALED(status))
            break;
        if (!WIFSTOPPED(status))
            continue;
        if (WSTOPSIG(status) != (SIGTRAP | 0x80))
            continue;
        if (ptrace(PTRACE_GETREGS, tid, 0, &regs) == -1)
            continue;
        if (regs.ARM_r7 == 4 && (unsigned long)regs.ARM_r1 > 4096UL &&
            regs.ARM_r2 > 0 && regs.ARM_r2 <= 4096) {
            unsigned char data[4096];
            if (copy_tracee(tid, (unsigned long)regs.ARM_r1, data,
                            (size_t)regs.ARM_r2) == 0)
                dump_write(output, ++sequence, &regs, data,
                           (size_t)regs.ARM_r2);
        }
    }

    ptrace(PTRACE_DETACH, tid, 0, 0);
    fclose(output);
    return 0;
}
