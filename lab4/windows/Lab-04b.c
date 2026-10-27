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

    DWORD main_tid = GetCurrentThreadId();
    DWORD pid = GetCurrentProcessId();

    for (int i = 1; i <= 100; i++)
    {
        char user_sym = USER_NAME[(i - 1) % USER_LEN];
        const char *fio_sym = FIO_CHARS[(i - 1) % FIO_LEN];

        printf("%lu - %lu - %d - %c - %s\n", (unsigned long)pid, (unsigned long)main_tid, i, user_sym, fio_sym);
        fflush(stdout);

        if (i == 30)
        {
            SuspendThread(h[0]);
            printf("\n>>> Поток 1 приостановлен на итерации %d\n\n", i);
            fflush(stdout);
        }
        if (i == 70)
        {
            ResumeThread(h[0]);
            printf("\n>>> Поток 1 возобновлён на итерации %d\n\n", i);
            fflush(stdout);
        }
        if (i == 40)
        {
            SuspendThread(h[1]);
            printf("\n>>> Поток 2 приостановлен на итерации %d\n\n", i);
            fflush(stdout);
        }

        Sleep(ITER_DELAY_MS);
    }

    ResumeThread(h[1]);
    printf("\n>>> Поток 2 возобновлён после завершения цикла главного потока\n\n");
    fflush(stdout);

    WaitForMultipleObjects(2, h, TRUE, INFINITE);
    CloseHandle(h[0]);
    CloseHandle(h[1]);

    printf("\nВсе потоки завершены.\n");
    lab04_done();
    return 0;
}
