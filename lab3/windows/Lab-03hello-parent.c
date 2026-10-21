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

    char child[MAX_PATH];
    child_path(child, sizeof(child));

    printf("Parent: passing string via STARTUPINFO:\n");
    printf("          \"%s\"\n", PHRASE);

    STARTUPINFOA si = {0};
    si.cb = sizeof(si);
    si.lpTitle = (LPSTR)PHRASE;

    PROCESS_INFORMATION pi = {0};

    if (!CreateProcessA(child, NULL, NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "Error: CreateProcess (%lu)\n", GetLastError());
        return 1;
    }

    printf("Parent: child created, PID=%lu\n", (unsigned long)pi.dwProcessId);
    printf("Parent: phrase passed via STARTUPINFO (lpTitle).\n");

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    if (pause) pause_before_exit();
    return 0;
}