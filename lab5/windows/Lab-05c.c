#include "lab05win_common.h"

typedef struct LAB05_THREAD_PARAM {
    int index;
} LAB05_THREAD_PARAM;

static DWORD WINAPI thread_body(LPVOID parameter)
{
    LAB05_THREAD_PARAM *param = (LAB05_THREAD_PARAM *)parameter;
    printf("=== Lab-05c: поток %d, PID %lu, TID %lu, приоритет %s ===\n",
           param->index,
           (unsigned long)GetCurrentProcessId(),
           (unsigned long)GetCurrentThreadId(),
           lab_thread_name(GetThreadPriority(GetCurrentThread())));
    fflush(stdout);

    lab_worker_body();
    Sleep(LAB05_FINAL_PAUSE_MS);
    return 0;
}

static HANDLE start_thread(LAB05_THREAD_PARAM *param, int priority)
{
    HANDLE thread = CreateThread(NULL, 0, thread_body, param, CREATE_SUSPENDED, NULL);
    if (thread == NULL) {
        printf("Ошибка CreateThread: %lu\n", (unsigned long)GetLastError());
        return NULL;
    }
    if (!SetThreadPriority(thread, priority)) {
        printf("Ошибка SetThreadPriority: %lu\n", (unsigned long)GetLastError());
        TerminateThread(thread, 1);
        CloseHandle(thread);
        return NULL;
    }
    ResumeThread(thread);
    return thread;
}

int main(int argc, char *argv[])
{
    DWORD_PTR mask;
    DWORD processClass;
    int priority1;
    int priority2;
    char maskText[80];
    int cpus;
    LAB05_THREAD_PARAM param1;
    LAB05_THREAD_PARAM param2;
    HANDLE thread1;
    HANDLE thread2;

    SetConsoleOutputCP(65001);

    if (argc < 5) {
        printf("Использование: Lab-05c.exe <маска> <класс процесса> <приоритет P3> <приоритет P4>\n");
        return 2;
    }

    cpus = lab_cpu_count();
    mask = lab_parse_mask(argv[1]);
    processClass = lab_class_from_name(argv[2]);
    priority1 = lab_thread_from_name(argv[3]);
    priority2 = lab_thread_from_name(argv[4]);

    if (processClass == 0) {
        printf("Неизвестный класс процесса: %s\n", argv[2]);
        return 2;
    }
    if (priority1 == THREAD_PRIORITY_ERROR_RETURN || priority2 == THREAD_PRIORITY_ERROR_RETURN) {
        printf("Неизвестный приоритет потока: %s / %s\n", argv[3], argv[4]);
        return 2;
    }
    if (mask == 0) {
        printf("Маска не задана\n");
        return 2;
    }

    lab_mask_to_binary(mask, cpus, maskText, (int)sizeof(maskText));

    printf("=== Lab-05c: два потока с приоритетами (серия P1=%llu P2=%s P3=%s P4=%s) ===\n",
           (unsigned long long)mask, argv[2], argv[3], argv[4]);
    printf("Маска родственности: %s (%llu), процессов доступно: %d\n",
           maskText, (unsigned long long)mask, lab_popcount(mask));
    printf("Класс приоритета процесса: %s (%d)\n",
           lab_class_name(processClass), lab_class_base(processClass));
    printf("Приоритет потока 1: %s (%d), приведённый: %d\n",
           lab_thread_name(priority1), priority1,
           lab_class_base(processClass) + priority1);
    printf("Приоритет потока 2: %s (%d), приведённый: %d\n",
           lab_thread_name(priority2), priority2,
           lab_class_base(processClass) + priority2);
    printf("PID процесса %lu, TID главного потока %lu\n",
           (unsigned long)GetCurrentProcessId(),
           (unsigned long)GetCurrentThreadId());
    fflush(stdout);

    if (!SetProcessAffinityMask(GetCurrentProcess(), mask)) {
        printf("Ошибка SetProcessAffinityMask(%llu): %lu\n",
               (unsigned long long)mask, (unsigned long)GetLastError());
        return 1;
    }
    if (!SetPriorityClass(GetCurrentProcess(), processClass)) {
        printf("Ошибка SetPriorityClass: %lu\n", (unsigned long)GetLastError());
        return 1;
    }

    param1.index = 1;
    param2.index = 2;

    thread1 = start_thread(&param1, priority1);
    thread2 = start_thread(&param2, priority2);
    if (thread1 == NULL || thread2 == NULL) {
        return 1;
    }

    WaitForSingleObject(thread1, INFINITE);
    Sleep(50);
    WaitForSingleObject(thread2, INFINITE);

    printf("Поток 1 завершён\n");
    printf("Поток 2 завершён\n");
    printf("Оба потока завершены\n");
    fflush(stdout);

    CloseHandle(thread1);
    CloseHandle(thread2);
    return 0;
}
