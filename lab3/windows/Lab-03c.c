/*
 * Lab-03c.c — вывод списка запущенных в системе процессов (Windows).
 *
 * Для каждого процесса выводится имя, идентификатор (PID) и идентификатор
 * родительского процесса (PPID). Список получается через Tool Help Library
 * (CreateToolhelp32Snapshot / Process32First / Process32Next).
 */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

int main(void)
{
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Ошибка: CreateToolhelp32Snapshot (%lu)\n", GetLastError());
        return 1;
    }

    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);

    printf("%-38s %8s %8s\n", "Имя процесса", "PID", "PPID");
    printf("%-38s %8s %8s\n", "--------------------------------------", "--------", "--------");

    if (Process32First(snap, &pe)) {
        do {
            printf("%-38s %8lu %8lu\n",
                   pe.szExeFile, (unsigned long)pe.th32ProcessID,
                   (unsigned long)pe.th32ParentProcessID);
        } while (Process32Next(snap, &pe));
    }

    CloseHandle(snap);
    return 0;
}
