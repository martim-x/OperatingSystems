#include "lab05win_common.h"

int main(void)
{
    DWORD_PTR processMask = 0;
    DWORD_PTR systemMask = 0;
    char processMaskText[80];
    char systemMaskText[80];
    int cpus;

    SetConsoleOutputCP(65001);
    cpus = lab_cpu_count();

    if (!GetProcessAffinityMask(GetCurrentProcess(), &processMask, &systemMask)) {
        printf("Ошибка GetProcessAffinityMask: %lu\n", (unsigned long)GetLastError());
        return 1;
    }
    lab_mask_to_binary(processMask, cpus, processMaskText, (int)sizeof(processMaskText));
    lab_mask_to_binary(systemMask, cpus, systemMaskText, (int)sizeof(systemMaskText));

    printf("=== Lab-05a: диспетчеризация и планирование ===\n");
    printf("Идентификатор процесса: %lu\n", (unsigned long)GetCurrentProcessId());
    printf("Идентификатор потока: %lu\n", (unsigned long)GetCurrentThreadId());
    printf("Класс приоритета процесса: %s (%d)\n",
           lab_class_name(GetPriorityClass(GetCurrentProcess())),
           lab_class_base(GetPriorityClass(GetCurrentProcess())));
    printf("Приоритет потока: %d (%s)\n",
           GetThreadPriority(GetCurrentThread()),
           lab_thread_name(GetThreadPriority(GetCurrentThread())));
    printf("Приведённый приоритет потока: %d\n",
           lab_priority_value(GetCurrentProcess(), GetCurrentThread()));
    printf("Маска родственности процесса: %s (%llu)\n",
           processMaskText,
           (unsigned long long)processMask);
    printf("Системная маска родственности: %s (%llu)\n",
           systemMaskText,
           (unsigned long long)systemMask);
    printf("Количество процессоров, доступных процессу: %d\n", lab_popcount(processMask));
    printf("Количество логических процессоров: %d\n", cpus);
    printf("Номер процессора, назначенного потоку: %lu\n",
           (unsigned long)GetCurrentProcessorNumber());

    return 0;
}
