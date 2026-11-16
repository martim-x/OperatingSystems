#include "lab05win_common.h"

int main(int argc, char *argv[])
{
    DWORD_PTR mask;
    LARGE_INTEGER frequency;
    LARGE_INTEGER start;
    LARGE_INTEGER finish;
    double wallSeconds = 0.0;

    SetConsoleOutputCP(65001);
    SetConsoleTitleA("Lab-05x.exe");

    if (argc > 1) {
        mask = lab_parse_mask(argv[1]);
        if (mask != 0 && !SetProcessAffinityMask(GetCurrentProcess(), mask)) {
            printf("Ошибка SetProcessAffinityMask(%llu): %lu\n",
                   (unsigned long long)mask,
                   (unsigned long)GetLastError());
            return 1;
        }
    }

    printf("=== Lab-05x: PID %lu, TID %lu, класс %s, итераций %d, задержка %d мс ===\n",
           (unsigned long)GetCurrentProcessId(),
           (unsigned long)GetCurrentThreadId(),
           lab_class_name(GetPriorityClass(GetCurrentProcess())),
           LAB05_ITERATIONS,
           LAB05_DELAY_MS);
    fflush(stdout);

    Sleep(LAB05_START_PAUSE_MS);

    if (QueryPerformanceFrequency(&frequency)) {
        QueryPerformanceCounter(&start);
    } else {
        start.QuadPart = 0;
        frequency.QuadPart = 0;
    }

    lab_worker_body();

    if (frequency.QuadPart != 0) {
        QueryPerformanceCounter(&finish);
        wallSeconds = (double)(finish.QuadPart - start.QuadPart) / (double)frequency.QuadPart;
    }
    printf("Стенное время: %.3f с\n", wallSeconds);
    fflush(stdout);

    Sleep(LAB05_FINAL_PAUSE_MS);
    return 0;
}
