#ifndef LAB04_COMMON_H
#define LAB04_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/types.h>

#define ITER_DELAY_US 400000
#define USER_NAME "User-6d4ec851"

static const char *FIO_CHARS[] = {
    "М", "а", "р", "у", "ш", "к", "о",
    "Т", "и", "м", "о", "ф", "е", "й"
};
#define FIO_LEN ((int)(sizeof(FIO_CHARS) / sizeof(FIO_CHARS[0])))
#define USER_LEN ((int)(sizeof(USER_NAME) - 1))

static void lab04x(int iterations)
{
    pid_t pid = getpid();
    pid_t tid = (pid_t)syscall(SYS_gettid);

    for (int i = 1; i <= iterations; i++)
    {
        char user_sym = USER_NAME[(i - 1) % USER_LEN];
        const char *fio_sym = FIO_CHARS[(i - 1) % FIO_LEN];

        printf("%d - %d - %d - %c - %s\n", (int)pid, (int)tid, i, user_sym, fio_sym);
        fflush(stdout);
        usleep(ITER_DELAY_US);
    }
}

#endif
