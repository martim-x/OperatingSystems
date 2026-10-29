#include <windows.h>
#include <stdio.h>

#include "console_ru.h"

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

    /* Единственный источник данных — заголовок консоли, который родитель
       задал через STARTUPINFO.lpTitle. */
    char title[256];
    DWORD n = GetConsoleTitleA(title, sizeof(title));

    if (n == 0) {
        fprintf(stderr, "Дочерний процесс: не удалось прочитать заголовок консоли (%lu)\n", GetLastError());
        return 1;
    }

    printf("Дочерний процесс (PID=%lu): получено через STARTUPINFO: %s\n",
           (unsigned long)GetCurrentProcessId(), title);
    fflush(stdout);

    Sleep(4000);

    if (pause) pause_before_exit();
    return 0;
}
