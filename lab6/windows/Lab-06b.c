#include "lab06_common.h"

static int run_child(const char *role, const char *object_name, int argc, char **argv)
{
    DWORD delay_ms;
    const char *log_path;
    HANDLE mutex;
    BOOL ok;

    if (!lab06_parse_options(argc, argv, 4, &delay_ms, &log_path))
        return 2;
    if (!lab06_log_init(log_path, FALSE))
        return 1;
    mutex = OpenMutexA(SYNCHRONIZE | MUTEX_MODIFY_STATE, FALSE, object_name);
    if (mutex == NULL) {
        fprintf(stderr, "OpenMutexA failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        lab06_log_done();
        return 1;
    }
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleA("Lab-06b child - named mutex");
    if (delay_ms != LAB06_DEFAULT_DELAY_MS)
        printf("[TEST ONLY] delay override: %lu ms (default: %u ms)\n",
               (unsigned long)delay_ms, LAB06_DEFAULT_DELAY_MS);
    ok = lab06_run_worker(role, LAB06_ITERATIONS, delay_ms,
                          lab06_enter_mutex, lab06_leave_mutex, mutex, NULL, NULL);
    CloseHandle(mutex);
    if (!lab06_log_done())
        ok = FALSE;
    return ok ? 0 : 1;
}

int main(int argc, char **argv)
{
    DWORD delay_ms;
    const char *log_path;
    char object_name[96];
    HANDLE mutex;
    PROCESS_INFORMATION child_a;
    PROCESS_INFORMATION child_b;
    BOOL spawned_a = FALSE;
    BOOL spawned_b = FALSE;
    BOOL ok = TRUE;

    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleA("Lab-06b - Named Mutex");
    if (argc > 1 && strcmp(argv[1], "--child") == 0) {
        if (argc < 4 || (strcmp(argv[2], "A") != 0 && strcmp(argv[2], "B") != 0)) {
            fprintf(stderr, "Child usage: --child A|B <mutex-name> [options]\n");
            return 2;
        }
        return run_child(argv[2], argv[3], argc, argv);
    }
    if (!lab06_parse_options(argc, argv, 1, &delay_ms, &log_path))
        return 2;
    if (!lab06_log_init(log_path, TRUE))
        return 1;
    if (delay_ms != LAB06_DEFAULT_DELAY_MS)
        printf("[TEST ONLY] delay override: %lu ms (default: %u ms)\n",
               (unsigned long)delay_ms, LAB06_DEFAULT_DELAY_MS);

    _snprintf_s(object_name, sizeof(object_name), _TRUNCATE, "Local\\Lab06b_%lu",
                (unsigned long)GetCurrentProcessId());
    mutex = CreateMutexA(NULL, FALSE, object_name);
    if (mutex == NULL) {
        fprintf(stderr, "CreateMutexA failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        lab06_log_done();
        return 1;
    }
    spawned_a = lab06_spawn_child("A", object_name, delay_ms, log_path, &child_a);
    spawned_b = lab06_spawn_child("B", object_name, delay_ms, log_path, &child_b);
    if (!spawned_a || !spawned_b) {
        ok = FALSE;
    } else {
        ok = lab06_run_worker("MAIN", LAB06_ITERATIONS, delay_ms,
                              lab06_enter_mutex, lab06_leave_mutex, mutex, NULL, NULL);
    }
    if (spawned_a && !lab06_wait_child(&child_a, "A"))
        ok = FALSE;
    if (spawned_b && !lab06_wait_child(&child_b, "B"))
        ok = FALSE;
    CloseHandle(mutex);
    if (!lab06_log_done())
        ok = FALSE;
    return ok ? 0 : 1;
}
