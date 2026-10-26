#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

#define DEFAULT_ITER "5"
#define LOCAL_ITER "3"

static void child_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) *(slash + 1) = '\0';
    else self[0] = '\0';
    snprintf(out, cap, "%sLab-03x.exe", self);
}

static int should_pause(void)
{
    return GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0) != 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: press Enter to exit...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(void)
{
    const char *iter = DEFAULT_ITER;
    int pause = should_pause();

    char child[MAX_PATH];
    child_path(child, sizeof(child));
    printf("Child program: %s\n", child);
    printf("Global ITER_NUM=%s, Local ITER_NUM=%s\n\n",
           getenv("ITER_NUM") ? getenv("ITER_NUM") : "(unset)", LOCAL_ITER);

    PROCESS_INFORMATION pi[3] = {0};
    BOOL ok[3] = {0};
    STARTUPINFOA si = {0};
    si.cb = sizeof(si);

    /* Process 1: only exe name - iterations from global ITER_NUM */
    {
        printf("[1] lpApplicationName=\"%s\", lpCommandLine=NULL - global ITER_NUM\n", child);
        ok[0] = CreateProcessA(child, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[0]);
        if (ok[0]) printf("    created, PID=%lu\n\n", (unsigned long)pi[0].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    /* Process 2: lpCommandLine with argument */
    {
        char cmd[MAX_PATH + 16];
        snprintf(cmd, sizeof(cmd), "%s %s", child, iter);
        printf("[2] lpApplicationName=NULL, lpCommandLine=\"%s\"\n", cmd);
        ok[1] = CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[1]);
        if (ok[1]) printf("    created, PID=%lu\n\n", (unsigned long)pi[1].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    /* Process 3: lpCommandLine=NULL, local ITER_NUM set before CreateProcess */
    {
        SetEnvironmentVariableA("ITER_NUM", LOCAL_ITER);
        printf("[3] lpApplicationName=\"%s\", lpCommandLine=NULL - local ITER_NUM=%s\n", child, LOCAL_ITER);
        ok[2] = CreateProcessA(child, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi[2]);
        if (ok[2]) printf("    created, PID=%lu\n\n", (unsigned long)pi[2].dwProcessId);
        else printf("    FAILED, error %lu\n\n", GetLastError());
    }

    HANDLE h[3];
    DWORD count = 0;
    for (int i = 0; i < 3; i++) if (ok[i]) h[count++] = pi[i].hProcess;

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