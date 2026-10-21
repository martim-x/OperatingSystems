#include <windows.h>
#include <stdio.h>

#include "console_ru.h"

static int should_pause(int argc, char *argv[])
{
    if (GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0)) return 1;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--pause") == 0) return 1;
    }
    return 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: press Enter to exit...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
    int pause = should_pause(argc, argv);

    char title[256];
    DWORD n = GetConsoleTitleA(title, sizeof(title));

    if (n == 0) {
        fprintf(stderr, "Child: failed to read console title (%lu)\n", GetLastError());
        return 1;
    }

    printf("Child (PID=%lu): received via STARTUPINFO: %s\n",
           (unsigned long)GetCurrentProcessId(), title);
    fflush(stdout);

    Sleep(4000);

    if (pause) pause_before_exit();
    return 0;
}