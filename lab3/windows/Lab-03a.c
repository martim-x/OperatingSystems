#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

#define DEFAULT_ITER "5"

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
    const char *iter = (argc > 1 && strcmp(argv[1], "--pause") != 0) ? argv[1] : DEFAULT_ITER;
    int pause = should_pause(argc, argv);

    char child[MAX_PATH];
    child_path(child, sizeof(child));
    printf("Child program: %s (iterations: %s)\n\n", child, iter);

    PROCESS_INFORMATION pi[3];
    BOOL ok[3] = {0};
    STARTUPINFOA si = {0};
    si.cb = sizeof(si);

    /* Process 1: only lpApplicationName with arg (fails - error 2) */
    {
        char app[MAX_PATH + 16];
        snprintf(app, sizeof(app), "%s %s", child, iter);
        printf("[1] lpApplicationName=\"%s\", lpCommandLine=NULL\n", app);
        ok[0] = CreateProcessA(app, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[0]);
        if (ok[0]) printf("    created, PID=%lu\n\n", (unsigned long)pi[0].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    /* Process 2: only lpCommandLine */
    {
        char cmd[MAX_PATH + 16];
        snprintf(cmd, sizeof(cmd), "%s %s", child, iter);
        printf("[2] lpApplicationName=NULL, lpCommandLine=\"%s\"\n", cmd);
        ok[1] = CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[1]);
        if (ok[1]) printf("    created, PID=%lu\n\n", (unsigned long)pi[1].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    /* Process 3: lpApplicationName + lpCommandLine with leading space */
    {
        char cmd[MAX_PATH + 16];
        snprintf(cmd, sizeof(cmd), " %s", iter);
        printf("[3] lpApplicationName=\"%s\", lpCommandLine=\"%s\"\n", child, cmd);
        ok[2] = CreateProcessA(child, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[2]);
        if (ok[2]) printf("    created, PID=%lu\n\n", (unsigned long)pi[2].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    HANDLE h[3];
    DWORD count = 0;
    for (int i = 0; i < 3; i++) {
        if (ok[i]) h[count++] = pi[i].hProcess;
    }

    printf("Parent waiting for %lu children...\n", count);
    if (count > 0) WaitForMultipleObjects(count, h, TRUE, INFINITE);

    for (int i = 0; i < 3; i++) {
        if (ok[i]) {
            DWORD code = 0;
            GetExitCodeProcess(pi[i].hProcess, &code);
            printf("Child %lu exited (code %lu)\n",
                   (unsigned long)pi[i].dwProcessId, (unsigned long)code);
            CloseHandle(pi[i].hProcess);
            CloseHandle(pi[i].hThread);
        }
    }

    printf("All children done, parent exiting.\n");
    if (pause) pause_before_exit();
    return 0;
}