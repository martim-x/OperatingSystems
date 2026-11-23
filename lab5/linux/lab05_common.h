#ifndef LAB05_COMMON_H
#define LAB05_COMMON_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#define LAB05_ITERATIONS 1000000L
#define LAB05_PERIOD 1000L
#define LAB05_DELAY_US 50000L
#define LAB05_PRIO_BASE 20

static inline long lab05_iterations(void)
{
    const char *v = getenv("LAB05_ITERATIONS");
    long n = v ? atol(v) : 0;

    return n > 0 ? n : LAB05_ITERATIONS;
}

static inline long lab05_period(void)
{
    const char *v = getenv("LAB05_PERIOD");
    long n = v ? atol(v) : 0;

    return n > 0 ? n : LAB05_PERIOD;
}

static inline int lab05_tid(void)
{
    return (int)syscall(SYS_gettid);
}

static inline int lab05_nice(int who)
{
    errno = 0;
    return getpriority(PRIO_PROCESS, (id_t)who);
}

static inline int lab05_prio(int nice_value)
{
    return LAB05_PRIO_BASE + nice_value;
}

static inline int lab05_cpu(void)
{
    return sched_getcpu();
}

static inline int lab05_ncpu(void)
{
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 1;
}

static inline double lab05_mono(void)
{
    struct timespec t;

    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

static inline void lab05_mask_text(const cpu_set_t *set, int width, char *buf, size_t size)
{
    size_t pos = 0;

    buf[0] = '\0';
    if (width < 1)
        width = 1;
    for (int i = width - 1; i >= 0 && pos + 2 < size; i--)
        buf[pos++] = CPU_ISSET(i, set) ? '1' : '0';
    buf[pos] = '\0';
}

static inline void lab05_mask_arg_text(unsigned long mask, int width, char *buf, size_t size)
{
    size_t pos = 0;

    buf[0] = '\0';
    if (width < 1 || width > 62)
        width = 62;
    for (int i = width - 1; i >= 0 && pos + 2 < size; i--)
        buf[pos++] = (mask & (1UL << i)) ? '1' : '0';
    buf[pos] = '\0';
}

static inline int lab05_affinity(unsigned long mask)
{
    cpu_set_t set;
    int ncpu = lab05_ncpu();

    CPU_ZERO(&set);
    for (int i = 0; i < ncpu && i < CPU_SETSIZE; i++)
        if (mask & (1UL << i))
            CPU_SET(i, &set);
    if (CPU_COUNT(&set) == 0)
        return 0;
    if (sched_setaffinity(0, sizeof set, &set) != 0)
        return -1;
    return 1;
}

static inline void lab05_pause(void)
{
    struct timespec a, b;
    long elapsed;

    clock_gettime(CLOCK_MONOTONIC, &a);
    do
    {
        clock_gettime(CLOCK_MONOTONIC, &b);
        elapsed = (b.tv_sec - a.tv_sec) * 1000000L + (b.tv_nsec - a.tv_nsec) / 1000L;
    } while (elapsed < LAB05_DELAY_US);
}

static inline void lab05_worker(void)
{
    struct timespec t0, t1;
    clock_t c0 = clock();
    int pid = (int)getpid();
    int tid = lab05_tid();
    long iterations = lab05_iterations();
    long period = lab05_period();

    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long i = 0; i < iterations; i++)
    {
        if ((i + 1) % period == 0)
        {
            lab05_pause();
            printf("%9ld | PID %6d | TID %6d | nice %3d | CPU %d\n",
                   i + 1, pid, tid, lab05_nice(tid), lab05_cpu());
            fflush(stdout);
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);

    double wall = (double)(t1.tv_sec - t0.tv_sec) + (double)(t1.tv_nsec - t0.tv_nsec) / 1e9;
    double cpu_time = (double)(clock() - c0) / (double)CLOCKS_PER_SEC;

    printf("Итераций: %ld, CPU-время процесса (clock): %.3f с, стенное время (CLOCK_MONOTONIC): %.3f с\n",
           iterations, cpu_time, wall);
}

#endif
