/*
 * Lab-03a.c — родительский процесс создаёт три дочерних процесса (Windows).
 *
 * Все три процесса создаются для Lab-03x.exe с разными способами передачи
 * имени исполняемого файла и количества итераций через параметры CreateProcess:
 *   1) только первый параметр (lpApplicationName), количество итераций — в нём же;
 *   2) только второй параметр (lpCommandLine);
 *   3) первый параметр — имя программы, второй — количество итераций
 *      (с пробелом в начале строки).
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
    printf("Дочерняя программа: %s (количество итераций: %s)\n\n", child, iter);

    PROCESS_INFORMATION pi[3];
    BOOL ok[3];
    int i;

    for (i = 0; i < 3; i++) {
        ZeroMemory(&pi[i], sizeof(pi[i]));
        ok[i] = FALSE;
    }

    /* Процесс 1: только первый параметр; количество итераций — тоже в нём */
    {
        char app[MAX_PATH + 16];
        STARTUPINFOA si;
        snprintf(app, sizeof(app), "%s %s", child, iter);
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);

        printf("[1] lpApplicationName=\"%s\", lpCommandLine=NULL\n", app);
        ok[0] = CreateProcessA(app, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[0]);
        if (ok[0]) {
            printf("    процесс создан, PID=%lu\n\n", (unsigned long)pi[0].dwProcessId);
        } else {
            printf("    НЕ создан, код ошибки %lu\n\n", GetLastError());
        }
    }

    /* Процесс 2: только второй параметр */
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

    /* Процесс 3: имя программы — в первом параметре, итерации — во втором */
    {
        char cmd[MAX_PATH + 16];
        STARTUPINFOA si;
        snprintf(cmd, sizeof(cmd), " %s", iter); /* пробел в начале строки */
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);

        printf("[3] lpApplicationName=\"%s\", lpCommandLine=\"%s\"\n", child, cmd);
        ok[2] = CreateProcessA(child, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[2]);
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
