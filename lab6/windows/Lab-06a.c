#include "lab06_common.h"

typedef struct Lab06ThreadContext {
    const char *role;
    DWORD delay_ms;
    CRITICAL_SECTION *critical_section;
    BOOL ok;
} Lab06ThreadContext;

static DWORD WINAPI lab06_thread_main(LPVOID parameter)
{
    Lab06ThreadContext *context = (Lab06ThreadContext *)parameter;
    context->ok = lab06_run_worker(context->role, LAB06_ITERATIONS, context->delay_ms,
                                   lab06_enter_critical, lab06_leave_critical,
                                   context->critical_section, NULL, NULL);
    return context->ok ? 0 : 1;
}

int main(int argc, char **argv)
{
    DWORD delay_ms;
    const char *log_path;
    CRITICAL_SECTION critical_section;
    Lab06ThreadContext contexts[2];
    HANDLE threads[2] = { NULL, NULL };
    BOOL ok = TRUE;
    int index;

    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleA("Lab-06a - Critical Section");
    if (!lab06_parse_options(argc, argv, 1, &delay_ms, &log_path))
        return 2;
    if (!lab06_log_init(log_path, TRUE))
        return 1;
    if (delay_ms != LAB06_DEFAULT_DELAY_MS)
        printf("[TEST ONLY] delay override: %lu ms (default: %u ms)\n",
               (unsigned long)delay_ms, LAB06_DEFAULT_DELAY_MS);

    InitializeCriticalSection(&critical_section);
    contexts[0].role = "A";
    contexts[0].delay_ms = delay_ms;
    contexts[0].critical_section = &critical_section;
    contexts[0].ok = FALSE;
    contexts[1].role = "B";
    contexts[1].delay_ms = delay_ms;
    contexts[1].critical_section = &critical_section;
    contexts[1].ok = FALSE;

    for (index = 0; index < 2; index++) {
        threads[index] = CreateThread(NULL, 0, lab06_thread_main, &contexts[index], 0, NULL);
        if (threads[index] == NULL) {
            fprintf(stderr, "CreateThread failed (Win32 error %lu)\n",
                    (unsigned long)GetLastError());
            ok = FALSE;
            break;
        }
    }

    if (ok)
        ok = lab06_run_worker("MAIN", LAB06_ITERATIONS, delay_ms,
                              lab06_enter_critical, lab06_leave_critical,
                              &critical_section, NULL, NULL);
    for (index = 0; index < 2; index++) {
        if (threads[index] != NULL) {
            if (WaitForSingleObject(threads[index], INFINITE) != WAIT_OBJECT_0)
                ok = FALSE;
            if (!contexts[index].ok)
                ok = FALSE;
            CloseHandle(threads[index]);
        }
    }

    DeleteCriticalSection(&critical_section);
    if (!lab06_log_done())
        ok = FALSE;
    return ok ? 0 : 1;
}
