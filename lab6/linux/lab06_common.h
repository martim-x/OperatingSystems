#ifndef LAB06_COMMON_H
#define LAB06_COMMON_H

#include <errno.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

#define LAB06_ITERATIONS 100
#define LAB06_FIRST_EXCLUSIVE 30
#define LAB06_LAST_EXCLUSIVE 60
#define LAB06_DELAY_MS 100
#define LAB06_USER_NAME "User-6d4ec851"

static FILE *lab06_terminal;

static void lab06_print_iteration(const char *worker, int iteration)
{
    size_t user_length = sizeof(LAB06_USER_NAME) - 1;
    char symbol = LAB06_USER_NAME[(iteration - 1) % user_length];

    printf("ITER worker=%s pid=%ld i=%d user=%c\n",
           worker, (long)getpid(), iteration, symbol);
    fflush(stdout);
    if (lab06_terminal)
        fprintf(lab06_terminal, "ITER worker=%s pid=%ld i=%d user=%c\n",
                worker, (long)getpid(), iteration, symbol);
}

static void lab06_print_boundary(const char *kind, const char *worker, int iteration)
{
    printf("%s worker=%s pid=%ld i=%d\n", kind, worker, (long)getpid(), iteration);
    fflush(stdout);
    if (lab06_terminal)
        fprintf(lab06_terminal, "%s worker=%s pid=%ld i=%d\n", kind, worker, (long)getpid(), iteration);
}

static int lab06_delay(void)
{
    struct timespec remaining = {
        .tv_sec = LAB06_DELAY_MS / 1000,
        .tv_nsec = (LAB06_DELAY_MS % 1000) * 1000000L,
    };

    while (nanosleep(&remaining, &remaining) == -1)
    {
        if (errno != EINTR)
        {
            perror("nanosleep");
            return -1;
        }
    }
    return 0;
}

#endif
