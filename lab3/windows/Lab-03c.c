#include <windows.h>
#include <tlhelp32.h>
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

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error: CreateToolhelp32Snapshot (%lu)\n", GetLastError());
        return 1;
    }

    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);

    printf("%-38s %8s %8s\n", "Process Name", "PID", "PPID");
    printf("%-38s %8s %8s\n", "--------------------------------------", "--------", "--------");

    if (Process32First(snap, &pe)) {
        do {
            printf("%-38s %8lu %8lu\n",
                   pe.szExeFile, (unsigned long)pe.th32ProcessID,
                   (unsigned long)pe.th32ParentProcessID);
        } while (Process32Next(snap, &pe));
    }

    CloseHandle(snap);

    if (pause) pause_before_exit();
    return 0;
}