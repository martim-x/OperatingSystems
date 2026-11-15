#include "lab05win_common.h"

static void build_x_path(char *path, int size)
{
    char *slash;
    GetModuleFileNameA(NULL, path, (DWORD)size);
    slash = strrchr(path, '\\');
    if (slash != NULL) {
        strcpy(slash + 1, "Lab-05x.exe");
    } else {
        strcpy(path, "Lab-05x.exe");
    }
}

static HANDLE spawn_child(const char *exePath, DWORD priorityClass, DWORD *childPid)
{
    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    char commandLine[MAX_PATH + 8];

    ZeroMemory(&startup, sizeof(startup));
    startup.cb = sizeof(startup);
    snprintf(commandLine, sizeof(commandLine), "\"%s\"", exePath);

    if (!CreateProcessA(NULL, commandLine, NULL, NULL, FALSE,
                        CREATE_NEW_CONSOLE | CREATE_SUSPENDED, NULL, NULL,
                        &startup, &process)) {
        printf("Ошибка CreateProcessA: %lu\n", (unsigned long)GetLastError());
        return NULL;
    }
    if (!SetPriorityClass(process.hProcess, priorityClass)) {
        printf("Ошибка SetPriorityClass: %lu\n", (unsigned long)GetLastError());
        TerminateProcess(process.hProcess, 1);
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        return NULL;
    }
    ResumeThread(process.hThread);
    CloseHandle(process.hThread);
    *childPid = process.dwProcessId;
    return process.hProcess;
}

int main(int argc, char *argv[])
{
    DWORD_PTR mask;
    DWORD class1;
    DWORD class2;
    DWORD child1Pid = 0;
    DWORD child2Pid = 0;
    HANDLE child1;
    HANDLE child2;
    char exePath[MAX_PATH];
    char maskText[80];
    int cpus;

    SetConsoleOutputCP(65001);

    if (argc < 4) {
        printf("Использование: Lab-05b.exe <маска> <класс P2> <класс P3>\n");
        return 2;
    }

    cpus = lab_cpu_count();
    mask = lab_parse_mask(argv[1]);
    class1 = lab_class_from_name(argv[2]);
    class2 = lab_class_from_name(argv[3]);
    if (class1 == 0 || class2 == 0) {
        printf("Неизвестный класс приоритета: %s / %s\n", argv[2], argv[3]);
        return 2;
    }
    if (mask == 0) {
        printf("Маска не задана\n");
        return 2;
    }

    lab_mask_to_binary(mask, cpus, maskText, (int)sizeof(maskText));

    printf("=== Lab-05b: два процесса с приоритетами (серия P1=%llu P2=%s P3=%s) ===\n",
           (unsigned long long)mask, argv[2], argv[3]);
    printf("Маска родственности: %s (%llu), процессов доступно: %d\n",
           maskText, (unsigned long long)mask, lab_popcount(mask));
    printf("Класс приоритета процесса 1: %s (%d)\n", lab_class_name(class1), lab_class_base(class1));
    printf("Класс приоритета процесса 2: %s (%d)\n", lab_class_name(class2), lab_class_base(class2));
    printf("PID родителя %lu, TID родителя %lu\n",
           (unsigned long)GetCurrentProcessId(),
           (unsigned long)GetCurrentThreadId());
    fflush(stdout);

    if (!SetProcessAffinityMask(GetCurrentProcess(), mask)) {
        printf("Ошибка SetProcessAffinityMask(%llu): %lu\n",
               (unsigned long long)mask, (unsigned long)GetLastError());
        return 1;
    }

    build_x_path(exePath, (int)sizeof(exePath));
    printf("Дочерние процессы запускаются: %s\n", exePath);
    fflush(stdout);

    child1 = spawn_child(exePath, class1, &child1Pid);
    child2 = spawn_child(exePath, class2, &child2Pid);
    if (child1 == NULL || child2 == NULL) {
        return 1;
    }
    printf("Запущен процесс 1: PID %lu, класс %s\n", (unsigned long)child1Pid, lab_class_name(class1));
    printf("Запущен процесс 2: PID %lu, класс %s\n", (unsigned long)child2Pid, lab_class_name(class2));
    fflush(stdout);

    WaitForSingleObject(child1, INFINITE);
    Sleep(50);
    WaitForSingleObject(child2, INFINITE);

    printf("Процесс 1 (PID %lu) завершён, код %lu\n",
           (unsigned long)child1Pid, (unsigned long)0);
    printf("Процесс 2 (PID %lu) завершён, код %lu\n",
           (unsigned long)child2Pid, (unsigned long)0);
    printf("Оба дочерних процесса завершены\n");
    fflush(stdout);

    CloseHandle(child1);
    CloseHandle(child2);
    return 0;
}
