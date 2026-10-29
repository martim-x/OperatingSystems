#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

#define MAX_NUMBERS 1000000

static double now_seconds(void)
{
    LARGE_INTEGER freq, cnt;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&cnt);
    return (double)cnt.QuadPart / (double)freq.QuadPart;
}

static void client_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) *(slash + 1) = '\0';
    else self[0] = '\0';
    snprintf(out, cap, "%sLab-03d-client.exe", self);
}

static int should_pause(void)
{
    return GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0) != 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: нажмите Enter для выхода...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
    int pause = should_pause();

    /* Структура вызова: Lab-03d-server <K> <Число M> <Нижний порог> <Верхний порог> */
    if (argc != 5) {
        fprintf(stderr, "Использование: %s <K> <M> <L> <R>\n", argv[0]);
        return 1;
    }

    int k = atoi(argv[1]);
    int m = atoi(argv[2]);
    int l = atoi(argv[3]);
    int r = atoi(argv[4]);

    if (k < 1 || m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Ошибка: требуется K >= 1, M > 0, L >= 1, L <= R\n");
        return 1;
    }

    char client[MAX_PATH];
    client_path(client, sizeof(client));

    double t0 = now_seconds();

    /* Анонимный канал: дескриптор записи наследуется дочерними процессами. */
    SECURITY_ATTRIBUTES sa = {0};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;

    HANDLE hRead, hWrite;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
        fprintf(stderr, "Ошибка: CreatePipe (%lu)\n", GetLastError());
        return 1;
    }
    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

    HANDLE *procs = malloc((size_t)k * sizeof(HANDLE));
    if (!procs) {
        fprintf(stderr, "Ошибка: не удалось выделить память\n");
        return 1;
    }
    int created = 0;

    int total = r - l + 1;
    int chunk = total / k;
    int remainder = total % k;
    int subL = l;

    /* Диапазон [L, R] делится на K равных частей, каждый дочерний процесс
       обрабатывает свой поддиапазон. */
    for (int i = 0; i < k; i++) {
        int subR = subL + chunk - 1 + (i < remainder ? 1 : 0);
        if (i == k - 1) subR = r;

        STARTUPINFOA si = {0};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        si.hStdOutput = hWrite;
        si.hStdError = hWrite;

        PROCESS_INFORMATION pi = {0};

        char cmd[MAX_PATH + 64];
        snprintf(cmd, sizeof(cmd), "\"%s\" %d %d %d", client, m, subL, subR);

        if (!CreateProcessA(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
            fprintf(stderr, "Ошибка: CreateProcess для [%d, %d] (%lu)\n", subL, subR, GetLastError());
        } else {
            CloseHandle(pi.hThread);
            procs[created++] = pi.hProcess;
            printf("Запущен дочерний процесс %lu: поддиапазон [%d, %d]\n",
                   (unsigned long)pi.dwProcessId, subL, subR);
        }
        subL = subR + 1;
    }

    CloseHandle(hWrite);

    size_t cap = 1 << 16;
    char *data = malloc(cap);
    if (!data) {
        fprintf(stderr, "Ошибка: не удалось выделить память\n");
        return 1;
    }
    size_t used = 0;

    /* Читаем канал до EOF: EOF наступает, когда все дочерние процессы
       закрыли унаследованный дескриптор записи. */
    for (;;) {
        DWORD got = 0;
        if (used + 4096 >= cap) {
            cap *= 2;
            char *bigger = realloc(data, cap);
            if (!bigger) break;
            data = bigger;
        }
        if (!ReadFile(hRead, data + used, (DWORD)(cap - used - 1), &got, NULL) || got == 0) {
            break;
        }
        used += got;
    }
    data[used] = '\0';
    CloseHandle(hRead);

    /* Программа не может быть завершена, пока не завершены все дочерние. */
    if (created > 0) {
        WaitForMultipleObjects((DWORD)created, procs, TRUE, INFINITE);
    }
    for (int i = 0; i < created; i++) CloseHandle(procs[i]);
    free(procs);

    int *all = malloc(MAX_NUMBERS * sizeof(int));
    if (!all) {
        fprintf(stderr, "Ошибка: не удалось выделить память\n");
        return 1;
    }
    int total_found = 0;

    /* Разбор строк CHUNK <PID> <количество> 0 <числа...> */
    char *line = data;
    while (line && *line) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';
        if (strncmp(line, "CHUNK ", 6) == 0) {
            char *p = line + 6;
            (void)strtol(p, &p, 10);
            int count = (int)strtol(p, &p, 10);
            (void)strtol(p, &p, 10);
            for (int i = 0; i < count && total_found < MAX_NUMBERS; i++) {
                all[total_found++] = (int)strtol(p, &p, 10);
            }
        }
        line = nl ? nl + 1 : NULL;
    }
    free(data);

    double t1 = now_seconds();

    printf("Число M: %d\n", m);
    printf("Диапазон [L, R]: [%d, %d]\n", l, r);
    printf("Количество процессов K: %d\n", k);
    printf("Общее количество найденных чисел: %d\n", total_found);
    printf("Найденные числа:");
    for (int i = 0; i < total_found; i++) printf(" %d", all[i]);
    printf("\n");
    printf("Время работы: %.6f с\n", t1 - t0);

    free(all);

    if (pause) pause_before_exit();
    return 0;
}
