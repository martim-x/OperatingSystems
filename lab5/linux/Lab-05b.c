#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>

#include "lab05_common.h"

static pid_t lab05_spawn(unsigned long mask, int nice_value)
{
    pid_t pid = fork();

    if (pid < 0)
        return -1;
    if (pid == 0)
    {
        if (lab05_affinity(mask) < 0)
        {
            perror("sched_setaffinity");
            _exit(1);
        }
        if (setpriority(PRIO_PROCESS, 0, nice_value) != 0)
        {
            perror("setpriority");
            _exit(1);
        }
        execl("./Lab-05x", "Lab-05x", (char *)NULL);
        perror("execl");
        _exit(1);
    }
    return pid;
}

int main(int argc, char **argv)
{
    pid_t pids[2];
    char text[128];
    int status;
    int width = lab05_ncpu();
    unsigned long mask;
    int nice1, nice2;
    double t_start;

    if (argc != 4)
    {
        fprintf(stderr,
                "Использование: %s P1 P2 P3\n"
                "  P1 - маска родственности процессоров (0 - все процессоры)\n"
                "  P2 - nice первого дочернего процесса\n"
                "  P3 - nice второго дочернего процесса\n",
                argv[0]);
        return 1;
    }

    mask = strtoul(argv[1], NULL, 0);
    nice1 = atoi(argv[2]);
    nice2 = atoi(argv[3]);

    if (mask == 0)
        snprintf(text, sizeof text, "все процессоры");
    else
        lab05_mask_arg_text(mask, width, text, sizeof text);

    t_start = lab05_mono();

    printf("P1 (маска родственности): %s\n", text);
    printf("P2 (nice первого дочернего процесса): %d\n", nice1);
    printf("P3 (nice второго дочернего процесса): %d\n", nice2);
    printf("Родительский процесс: PID %d, доступно процессоров: %d\n", (int)getpid(), width);
    fflush(stdout);

    pids[0] = lab05_spawn(mask, nice1);
    if (pids[0] < 0)
    {
        perror("fork 1");
        return 1;
    }
    pids[1] = lab05_spawn(mask, nice2);
    if (pids[1] < 0)
    {
        perror("fork 2");
        return 1;
    }

    printf("Запущены дочерние процессы: PID %d (nice %d) и PID %d (nice %d), t=%.3f с\n",
           (int)pids[0], nice1, (int)pids[1], nice2, lab05_mono() - t_start);
    fflush(stdout);

    for (int done = 0; done < 2; done++)
    {
        pid_t who = waitpid(-1, &status, 0);

        if (who < 0)
        {
            perror("waitpid");
            return 1;
        }
        if (WIFEXITED(status))
            printf("Дочерний процесс %d (PID %d) завершён, код %d, t=%.3f с (CLOCK_MONOTONIC)\n",
                   who == pids[0] ? 1 : 2, (int)who, WEXITSTATUS(status),
                   lab05_mono() - t_start);
        else if (WIFSIGNALED(status))
            printf("Дочерний процесс %d (PID %d) прерван сигналом %d, t=%.3f с (CLOCK_MONOTONIC)\n",
                   who == pids[0] ? 1 : 2, (int)who, WTERMSIG(status),
                   lab05_mono() - t_start);
        else
            printf("Дочерний процесс %d (PID %d) завершён с ненулевым статусом 0x%x, t=%.3f с\n",
                   who == pids[0] ? 1 : 2, (int)who, status,
                   lab05_mono() - t_start);
        fflush(stdout);
    }

    printf("Оба дочерних процесса обработаны, t=%.3f с (CLOCK_MONOTONIC)\n",
           lab05_mono() - t_start);
    return 0;
}
