#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>

#include "console_ru.h"

int main(void)
{
    DWORD pid = GetCurrentProcessId();

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE)
    {
        fprintf(stderr, "Ошибка CreateToolhelp32Snapshot: %lu\n", GetLastError());
        return 1;
    }

    THREADENTRY32 te;
    te.dwSize = sizeof(THREADENTRY32);

    printf("Процесс PID=%lu\n", (unsigned long)pid);

    if (!Thread32First(snap, &te))
    {
        fprintf(stderr, "Ошибка Thread32First: %lu\n", GetLastError());
        CloseHandle(snap);
        return 1;
    }

    int count = 0;
    do
    {
        if (te.th32OwnerProcessID == pid)
        {
            count++;
            printf("Поток %d: TID=%lu, приоритет=%ld\n", count, (unsigned long)te.th32ThreadID, (long)te.tpBasePri);
        }
        te.dwSize = sizeof(THREADENTRY32);
    } while (Thread32Next(snap, &te));

    CloseHandle(snap);

    printf("Всего потоков в процессе: %d\n", count);
    return 0;
}
