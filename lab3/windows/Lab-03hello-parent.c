/*
 * Lab-03hello-parent.c — родительский процесс (Windows, уровень 9-10).
 *
 * Передаёт дочернему процессу строку «Hello, my dear child!» через структуру
 * STARTUPINFO (поле lpTitle). Запрещены переменные окружения, перенаправление
 * потоков, аргументы командной строки и стандартные механизмы IPC.
 *
 * Родитель дожидается завершения дочернего процесса.
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

#define PHRASE "Hello, my dear child!"

/* Полный путь к Lab-03hello-child.exe рядом с текущим исполняемым файлом */
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
    snprintf(out, cap, "%sLab-03hello-child.exe", self);
}

int main(void)
{
    char child[MAX_PATH];
    child_path(child, sizeof(child));

    printf("Родитель: передаю дочернему процессу через STARTUPINFO строку:\n");
    printf("          \"%s\"\n", PHRASE);

    STARTUPINFOA si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.lpTitle = (LPSTR)PHRASE; /* строка передаётся через структуру STARTUPINFO */

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    /* CREATE_NEW_CONSOLE: именно при создании новой консоли Windows применяет
       lpTitle — заголовок консоли дочернего процесса становится равным фразе. */
    if (!CreateProcessA(child, NULL, NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "Ошибка: CreateProcess (%lu)\n", GetLastError());
        return 1;
    }

    printf("Родитель: дочерний процесс создан, PID=%lu\n", (unsigned long)pi.dwProcessId);
    printf("Родитель: фраза передана через STARTUPINFO (lpTitle).\n");

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return 0;
}
