/*
 * Lab-03b.c — родительский процесс создаёт три дочерних процесса (Windows),
 * вариант Lab-03a с работой через переменные окружения:
 *
 *   1) только имя файла (без количества итераций) — Lab-03x берёт итерации
 *      из глобальной переменной окружения ITER_NUM;
 *   2) только второй параметр (lpCommandLine) — количество итераций
 *      передаётся аргументом командной строки;
 *   3) NULL вместо второго параметра; перед созданием процесса устанавливается
 *      ЛОКАЛЬНАЯ переменная окружения ITER_NUM (значение отличается от
 *      глобальной переменной).
 *
 * Родитель дожидается завершения всех созданных дочерних процессов
 * (выполняются одновременно), затем освобождает ресурсы.
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

#define DEFAULT_ITER "5"
#define LOCAL_ITER   "3" /* локальное значение ITER_NUM, отличается от глобального */

/* Полный путь к Lab-03x.exe рядом с текущим исполняемым файлом */
static void child_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) {
        *(slash + 1) = '\0';
    } else {
        self[0] = '\0';
    }
    snprintf(out, cap, "%sLab-03x.exe", self);
}

int main(int argc, char *argv[])
{
    const char *iter = (argc > 1) ? argv[1] : DEFAULT_ITER;

    char child[MAX_PATH];
    child_path(child, sizeof(child));
    printf("Дочерняя программа: %s\n", child);
    printf("Глобальная ITER_NUM=%s, локальная ITER_NUM=%s\n\n",
           getenv("ITER_NUM") != NULL ? getenv("ITER_NUM") : "(не задана)", LOCAL_ITER);

    PROCESS_INFORMATION pi[3];
    BOOL ok[3];
    int i;

    for (i = 0; i < 3; i++) {
        ZeroMemory(&pi[i], sizeof(pi[i]));
        ok[i] = FALSE;
    }

    /* Процесс 1: только имя файла — итерации из глобальной ITER_NUM */
    {
        STARTUPINFOA si;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);

        printf("[1] lpApplicationName=\"%s\", lpCommandLine=NULL — итерации из глобальной ITER_NUM\n", child);
        ok[0] = CreateProcessA(child, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[0]);
        if (ok[0]) {
            printf("    процесс создан, PID=%lu\n\n", (unsigned long)pi[0].dwProcessId);
        } else {
            printf("    НЕ создан, код ошибки %lu\n\n", GetLastError());
        }
    }

    /* Процесс 2: только второй параметр — итерации аргументом командной строки */
    {
        char cmd[MAX_PATH + 16];
        STARTUPINFOA si;
        snprintf(cmd, sizeof(cmd), "%s %s", child, iter);
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);

        printf("[2] lpApplicationName=NULL, lpCommandLine=\"%s\"\n", cmd);
        ok[1] = CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[1]);
        if (ok[1]) {
            printf("    процесс создан, PID=%lu\n\n", (unsigned long)pi[1].dwProcessId);
        } else {
            printf("    НЕ создан, код ошибки %lu\n\n", GetLastError());
        }
    }

    /* Процесс 3: NULL вместо второго параметра; локальная ITER_NUM=%s */
    {
        STARTUPINFOA si;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);

        SetEnvironmentVariableA("ITER_NUM", LOCAL_ITER);

        printf("[3] lpApplicationName=\"%s\", lpCommandLine=NULL — локальная ITER_NUM=%s\n", child, LOCAL_ITER);
        ok[2] = CreateProcessA(child, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[2]);
        if (ok[2]) {
            printf("    процесс создан, PID=%lu\n\n", (unsigned long)pi[2].dwProcessId);
        } else {
            printf("    НЕ создан, код ошибки %lu\n\n", GetLastError());
        }
    }

    /* Ожидание завершения всех созданных дочерних процессов */
    {
        HANDLE h[3];
        DWORD count = 0;
        for (i = 0; i < 3; i++) {
            if (ok[i]) {
                h[count++] = pi[i].hProcess;
            }
        }

        printf("Родитель ожидает завершения дочерних процессов...\n");
        if (count > 0) {
            WaitForMultipleObjects(count, h, TRUE, INFINITE);
        }

        for (i = 0; i < 3; i++) {
            if (ok[i]) {
                DWORD code = 0;
                GetExitCodeProcess(pi[i].hProcess, &code);
                printf("Дочерний процесс %lu завершён (код %lu)\n",
                       (unsigned long)pi[i].dwProcessId, (unsigned long)code);
                CloseHandle(pi[i].hProcess);
                CloseHandle(pi[i].hThread);
            }
        }
    }

    printf("Все созданные дочерние процессы завершены, родитель завершает работу.\n");
    return 0;
}
