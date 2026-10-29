#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "console_ru.h"

#define PHRASE "Hello, my dear child!"

static void child_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) *(slash + 1) = '\0';
    else self[0] = '\0';
    snprintf(out, cap, "%sLab-03hello-child.exe", self);
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

int main(void)
{
    int pause = should_pause();

    char child[MAX_PATH];
    child_path(child, sizeof(child));

    printf("Родитель: передаю дочернему процессу через STARTUPINFO строку:\n");
    printf("          \"%s\"\n", PHRASE);

    /* Фраза уходит в поле lpTitle; Windows применяет его как заголовок окна
       только при создании новой консоли (CREATE_NEW_CONSOLE). */
    STARTUPINFOA si = {0};
    si.cb = sizeof(si);
    si.lpTitle = (LPSTR)PHRASE;

    PROCESS_INFORMATION pi = {0};

    if (!CreateProcessA(child, NULL, NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "Ошибка: CreateProcess (%lu)\n", GetLastError());
        return 1;
    }

    printf("Родитель: дочерний процесс создан, PID=%lu\n", (unsigned long)pi.dwProcessId);
    printf("Родитель: фраза передана через STARTUPINFO (lpTitle).\n");

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    if (pause) pause_before_exit();
    return 0;
}
