#include "lab06_common.h"

static int run_child(const char *role, const char *event_name, int argc, char **argv)
{
    DWORD delay_ms;
    const char *log_path;
    HANDLE event_handle;
    BOOL ok;

    if (!lab06_parse_options(argc, argv, 4, &delay_ms, &log_path))
        return 2;
    if (!lab06_log_init(log_path, FALSE))
        return 1;
    event_handle = OpenEventA(SYNCHRONIZE, FALSE, event_name);
    if (event_handle == NULL) {
        fprintf(stderr, "OpenEventA failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        lab06_log_done();
        return 1;
    }
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleA("Lab-06d child - manual-reset event");
    if (delay_ms != LAB06_DEFAULT_DELAY_MS)
        printf("[TEST ONLY] delay override: %lu ms (default: %u ms)\n",
               (unsigned long)delay_ms, LAB06_DEFAULT_DELAY_MS);
    if (WaitForSingleObject(event_handle, INFINITE) != WAIT_OBJECT_0) {
        fprintf(stderr, "Child event wait failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        CloseHandle(event_handle);
        lab06_log_done();
        return 1;
    }
    ok = lab06_run_worker(role, LAB06_EVENT_ITERATIONS, delay_ms,
                          NULL, NULL, NULL, NULL, NULL);
    CloseHandle(event_handle);
    if (!lab06_log_done())
        ok = FALSE;
    return ok ? 0 : 1;
}

static BOOL signal_children(void *context)
{
    HANDLE event_handle = (HANDLE)context;
    lab06_logf("EVENT_SET");
    printf("EVENT_SET: parent starts iteration 16; children released\n");
    fflush(stdout);
    if (!SetEvent(event_handle)) {
        fprintf(stderr, "SetEvent failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        return FALSE;
    }
    return TRUE;
}

int main(int argc, char **argv)
{
    DWORD delay_ms;
    const char *log_path;
    char event_name[96];
    HANDLE event_handle;
    PROCESS_INFORMATION child_a;
    PROCESS_INFORMATION child_b;
    BOOL spawned_a = FALSE;
    BOOL spawned_b = FALSE;
    BOOL ok = TRUE;

    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleA("Lab-06d - Manual-reset Event");
    if (argc > 1 && strcmp(argv[1], "--child") == 0) {
        if (argc < 4 || (strcmp(argv[2], "A") != 0 && strcmp(argv[2], "B") != 0)) {
            fprintf(stderr, "Child usage: --child A|B <event-name> [options]\n");
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

    _snprintf_s(event_name, sizeof(event_name), _TRUNCATE, "Local\\Lab06d_%lu",
                (unsigned long)GetCurrentProcessId());
    event_handle = CreateEventA(NULL, TRUE, FALSE, event_name);
    if (event_handle == NULL) {
        fprintf(stderr, "CreateEventA failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        lab06_log_done();
        return 1;
    }
    spawned_a = lab06_spawn_child("A", event_name, delay_ms, log_path, &child_a);
    spawned_b = lab06_spawn_child("B", event_name, delay_ms, log_path, &child_b);
    if (!spawned_a || !spawned_b) {
        ok = FALSE;
    } else {
        ok = lab06_run_worker("MAIN", LAB06_EVENT_ITERATIONS, delay_ms,
                              NULL, NULL, NULL, signal_children, event_handle);
    }
    if (!ok) {
        if (spawned_a)
            TerminateProcess(child_a.hProcess, 1);
        if (spawned_b)
            TerminateProcess(child_b.hProcess, 1);
    }
    if (spawned_a && !lab06_wait_child(&child_a, "A"))
        ok = FALSE;
    if (spawned_b && !lab06_wait_child(&child_b, "B"))
        ok = FALSE;
    CloseHandle(event_handle);
    if (!lab06_log_done())
        ok = FALSE;
    return ok ? 0 : 1;
}
