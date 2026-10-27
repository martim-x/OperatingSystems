#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#include "console_ru.h"
#include "lab04_common.h"

typedef struct
{
    int iterations;
} THREAD_ARGS;

static DWORD WINAPI worker(LPVOID param)
{
    THREAD_ARGS *a = (THREAD_ARGS *)param;
    lab04x(a->iterations);
    return 0;
}

int main(void)
{
    lab04_init();

    THREAD_ARGS a1 = {55};
    THREAD_ARGS a2 = {130};

    HANDLE h[2];
    DWORD id[2];

    h[0] = CreateThread(NULL, 0, worker, &a1, 0, &id[0]);
    if (h[0] == NULL)
    {
        fprintf(stderr, "Ошибка CreateThread 1: %lu\n", GetLastError());
        lab04_done();
        return 1;
    }

    h[1] = CreateThread(NULL, 0, worker, &a2, 0, &id[1]);
    if (h[1] == NULL)
    {
        fprintf(stderr, "Ошибка CreateThread 2: %lu\n", GetLastError());
        CloseHandle(h[0]);
        lab04_done();
        return 1;
    }

    printf("Поток 1: TID=%lu, итераций 55\n", (unsigned long)id[0]);
    printf("Поток 2: TID=%lu, итераций 130\n", (unsigned long)id[1]);
    printf("Главный поток: итераций 100\n\n");
    fflush(stdout);

    lab04x(100);

    WaitForMultipleObjects(2, h, TRUE, INFINITE);
    CloseHandle(h[0]);
    CloseHandle(h[1]);

    printf("\nВсе потоки завершены.\n");
    lab04_done();
    return 0;
}
