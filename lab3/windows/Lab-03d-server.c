/*
 * Lab-03d-server.c — сервер: запускает K дочерних процессов поиска чисел,
 * взаимно простых с M, на поддиапазонах [L, R] (Windows).
 *
 * Структура вызова:
 *   Lab-03d-server <Количество процессов K> <Число M> <Нижний порог L> <Верхний порог R>
 *
 * Сервер создаёт анонимный канал (CreatePipe), дескриптор канала передаётся
 * дочерним процессам через структуру STARTUPINFO (STARTF_USESTDHANDLES,
 * hStdOutput), читает результаты из канала и выводит:
 *   число M, диапазон [L, R], количество процессов K, общее количество
 *   найденных чисел, сами числа и время работы.
 *
 * Программа не завершается, пока не завершены все дочерние процессы.
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

#define MAX_NUMBERS 1000000

static double now_seconds(void)
{
    LARGE_INTEGER freq, cnt;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&cnt);
    return (double)cnt.QuadPart / (double)freq.QuadPart;
}

/* Полный путь к Lab-03d-client.exe рядом с текущим исполняемым файлом */
static void client_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) {
        *(slash + 1) = '\0';
    } else {
        self[0] = '\0';
    }
    snprintf(out, cap, "%sLab-03d-client.exe", self);
}

int main(int argc, char *argv[])
{
    if (argc != 5) {
        fprintf(stderr,
                "Использование: %s <Количество процессов K> <Число M> <Нижний порог L> <Верхний порог R>\n",
                argv[0]);
        return 1;
    }

    int k = atoi(argv[1]);
    int m = atoi(argv[2]);
    int l = atoi(argv[3]);
    int r = atoi(argv[4]);

    if (k < 1 || m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Ошибка: требуется K >= 1, M > 0, L >= 1 и L <= R\n");
        return 1;
    }

    char client[MAX_PATH];
    client_path(client, sizeof(client));

    double t0 = now_seconds();

    /* Анонимный канал: конец для записи наследуется дочерними процессами */
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(sa);
    sa.lpSecurityDescriptor = NULL;
    sa.bInheritHandle = TRUE;

    HANDLE hRead, hWrite;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
        fprintf(stderr, "Ошибка: CreatePipe (%lu)\n", GetLastError());
        return 1;
    }
    /* Читающий конец дочерним процессам не нужен */
    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

    HANDLE *procs = malloc((size_t)k * sizeof(HANDLE));
    if (procs == NULL) {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }
    int created = 0;

    int total = r - l + 1;
    int chunk = total / k;
    int remainder = total % k;
    int subL = l;

    for (int i = 0; i < k; i++) {
        int subR = subL + chunk - 1 + (i < remainder ? 1 : 0);
        if (i == k - 1) {
            subR = r;
        }

        STARTUPINFOA si;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        si.hStdOutput = hWrite; /* дескриптор канала — через STARTUPINFO */
        si.hStdError = hWrite;

        PROCESS_INFORMATION pi;
        ZeroMemory(&pi, sizeof(pi));

        char cmd[MAX_PATH + 64];
        snprintf(cmd, sizeof(cmd), "\"%s\" %d %d %d", client, m, subL, subR);

        if (!CreateProcessA(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
            fprintf(stderr, "Ошибка: CreateProcess для поддиапазона [%d, %d] (%lu)\n",
                    subL, subR, GetLastError());
        } else {
            CloseHandle(pi.hThread);
            procs[created++] = pi.hProcess;
            printf("Запущен дочерний процесс %lu: поддиапазон [%d, %d]\n",
                   (unsigned long)pi.dwProcessId, subL, subR);
        }
        subL = subR + 1;
    }

    /* Закрываем конец для записи: канал закроется, когда завершатся все дети */
    CloseHandle(hWrite);

    /* Читаем данные от дочерних процессов до закрытия канала */
    size_t cap = 1 << 16;
    char *data = malloc(cap);
    if (data == NULL) {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }
    size_t used = 0;

    for (;;) {
        DWORD got = 0;
        if (used + 4096 >= cap) {
            cap *= 2;
            char *bigger = realloc(data, cap);
            if (bigger == NULL) {
                break;
            }
            data = bigger;
        }
        if (!ReadFile(hRead, data + used, (DWORD)(cap - used - 1), &got, NULL) || got == 0) {
            break;
        }
        used += got;
    }
    data[used] = '\0';
    CloseHandle(hRead);

    /* Дожидаемся завершения всех дочерних процессов */
    if (created > 0) {
        WaitForMultipleObjects((DWORD)created, procs, TRUE, INFINITE);
    }
    for (int i = 0; i < created; i++) {
        CloseHandle(procs[i]);
    }
    free(procs);

    /* Разбор ответов детей: строки «CHUNK <PID> <count> 0 <числа...>» */
    int *all = malloc(MAX_NUMBERS * sizeof(int));
    if (all == NULL) {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }
    int total_found = 0;

    char *line = data;
    while (line != NULL && *line != '\0') {
        char *nl = strchr(line, '\n');
        if (nl != NULL) {
            *nl = '\0';
        }
        if (strncmp(line, "CHUNK ", 6) == 0) {
            char *p = line + 6;
            (void)strtol(p, &p, 10);             /* PID */
            int count = (int)strtol(p, &p, 10);  /* количество чисел */
            (void)strtol(p, &p, 10);             /* служебное поле */
            for (int i = 0; i < count && total_found < MAX_NUMBERS; i++) {
                all[total_found++] = (int)strtol(p, &p, 10);
            }
        }
        line = (nl != NULL) ? nl + 1 : NULL;
    }
    free(data);

    double t1 = now_seconds();

    printf("Число M: %d\n", m);
    printf("Диапазон [L, R]: [%d, %d]\n", l, r);
    printf("Количество процессов K: %d\n", k);
    printf("Общее количество найденных чисел: %d\n", total_found);
    printf("Найденные числа:");
    for (int i = 0; i < total_found; i++) {
        printf(" %d", all[i]);
    }
    printf("\n");
    printf("Время работы: %.6f с\n", t1 - t0);

    free(all);
    return 0;
}
