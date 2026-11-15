#define _GNU_SOURCE
#include <pthread.h>

#include "lab05_common.h"

struct lab05_thread_arg
{
    int id;
    int nice_value;
};

static void *lab05_thread_main(void *arg)
{
    struct lab05_thread_arg *a = (struct lab05_thread_arg *)arg;
    double t0 = lab05_mono();

    if (setpriority(PRIO_PROCESS, (id_t)lab05_tid(), a->nice_value) != 0)
    {
        fprintf(stderr, "Ошибка setpriority (поток %d): %s\n", a->id, strerror(errno));
        fflush(stderr);
    }

    printf("Поток %d: TID %d, nice %d, приоритет %d, CPU %d\n",
           a->id, lab05_tid(), lab05_nice(lab05_tid()),
           lab05_prio(lab05_nice(lab05_tid())), lab05_cpu());
    fflush(stdout);

    lab05_worker();

    printf("Поток %d завершён, t=%.3f с (CLOCK_MONOTONIC)\n", a->id, lab05_mono() - t0);
    fflush(stdout);
    return NULL;
}

int main(int argc, char **argv)
{
    pthread_t t1, t2;
    struct lab05_thread_arg a1, a2;
    char text[128];
    int width = lab05_ncpu();
    unsigned long mask;
    int nice1, nice2;
    int rc;

    if (argc != 4)
    {
        fprintf(stderr,
                "Использование: %s P1 P2 P3\n"
                "  P1 - маска родственности процессоров (0 - все процессоры)\n"
                "  P2 - nice первого дочернего потока\n"
                "  P3 - nice второго дочернего потока\n",
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

    printf("P1 (маска родственности): %s\n", text);
    printf("P2 (nice первого дочернего потока): %d\n", nice1);
    printf("P3 (nice второго дочернего потока): %d\n", nice2);
    printf("Процесс теста: PID %d, доступно процессоров: %d\n", (int)getpid(), width);
    fflush(stdout);

    if (lab05_affinity(mask) < 0)
    {
        perror("sched_setaffinity");
        return 1;
    }

    a1.id = 1;
    a1.nice_value = nice1;
    a2.id = 2;
    a2.nice_value = nice2;

    rc = pthread_create(&t1, NULL, lab05_thread_main, &a1);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_create 1: %s\n", strerror(rc));
        return 1;
    }

    rc = pthread_create(&t2, NULL, lab05_thread_main, &a2);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_create 2: %s\n", strerror(rc));
        return 1;
    }

    rc = pthread_join(t1, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_join 1: %s\n", strerror(rc));
        return 1;
    }

    rc = pthread_join(t2, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_join 2: %s\n", strerror(rc));
        return 1;
    }

    printf("Все потоки завершены\n");
    return 0;
}
