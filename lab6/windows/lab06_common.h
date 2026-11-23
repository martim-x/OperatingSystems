#ifndef LAB06_COMMON_H
#define LAB06_COMMON_H

#define _CRT_SECURE_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define LAB06_ITERATIONS 100
#define LAB06_EVENT_ITERATIONS 1000
#define LAB06_DEFAULT_DELAY_MS 100
#define LAB06_FIRST_EXCLUSIVE_ITERATION 30
#define LAB06_LAST_EXCLUSIVE_ITERATION 60
#define LAB06_USER_NAME "User-6d4ec851"

typedef BOOL (*Lab06Action)(void *context);

static HANDLE g_lab06_log = INVALID_HANDLE_VALUE;
static HANDLE g_lab06_log_mutex = NULL;
static volatile LONG g_lab06_log_failed = 0;

static BOOL lab06_has_log_error(void)
{
    return InterlockedCompareExchange(&g_lab06_log_failed, 0, 0) != 0;
}

static BOOL lab06_log_init(const char *path, BOOL truncate_file)
{
    char mutex_name[64];
    unsigned long hash = 2166136261u;
    size_t index;
    LARGE_INTEGER zero;

    if (path == NULL)
        return TRUE;

    g_lab06_log = CreateFileA(path, GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (g_lab06_log == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Cannot open log file '%s' (Win32 error %lu)\n",
                path, (unsigned long)GetLastError());
        return FALSE;
    }
    if (truncate_file) {
        zero.QuadPart = 0;
        if (!SetFilePointerEx(g_lab06_log, zero, NULL, FILE_BEGIN) || !SetEndOfFile(g_lab06_log)) {
            fprintf(stderr, "Cannot clear log file (Win32 error %lu)\n",
                    (unsigned long)GetLastError());
            CloseHandle(g_lab06_log);
            g_lab06_log = INVALID_HANDLE_VALUE;
            return FALSE;
        }
    }
    for (index = 0; path[index] != '\0'; index++)
        hash = (hash ^ (unsigned char)path[index]) * 16777619u;
    _snprintf_s(mutex_name, sizeof(mutex_name), _TRUNCATE,
                "Local\\Lab06Log_%08lX", hash);
    g_lab06_log_mutex = CreateMutexA(NULL, FALSE, mutex_name);
    if (g_lab06_log_mutex == NULL) {
        fprintf(stderr, "Cannot create log mutex (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        CloseHandle(g_lab06_log);
        g_lab06_log = INVALID_HANDLE_VALUE;
        return FALSE;
    }
    return TRUE;
}

static void lab06_logf(const char *format, ...)
{
    char line[512];
    int length;
    DWORD written = 0;
    LARGE_INTEGER file_end;
    DWORD wait_result;
    va_list args;

    if (g_lab06_log == INVALID_HANDLE_VALUE || lab06_has_log_error())
        return;

    va_start(args, format);
    length = _vsnprintf_s(line, sizeof(line) - 2, _TRUNCATE, format, args);
    va_end(args);
    if (length < 0) {
        InterlockedExchange(&g_lab06_log_failed, 1);
        return;
    }
    line[length++] = '\r';
    line[length++] = '\n';
    wait_result = WaitForSingleObject(g_lab06_log_mutex, INFINITE);
    if (wait_result != WAIT_OBJECT_0 && wait_result != WAIT_ABANDONED) {
        InterlockedExchange(&g_lab06_log_failed, 1);
        return;
    }
    file_end.QuadPart = 0;
    if (!SetFilePointerEx(g_lab06_log, file_end, NULL, FILE_END) ||
        !WriteFile(g_lab06_log, line, (DWORD)length, &written, NULL) || written != (DWORD)length)
        InterlockedExchange(&g_lab06_log_failed, 1);
    if (!ReleaseMutex(g_lab06_log_mutex))
        InterlockedExchange(&g_lab06_log_failed, 1);
}

static BOOL lab06_log_done(void)
{
    BOOL ok = !lab06_has_log_error();
    if (g_lab06_log != INVALID_HANDLE_VALUE) {
        if (!FlushFileBuffers(g_lab06_log))
            ok = FALSE;
        CloseHandle(g_lab06_log);
        g_lab06_log = INVALID_HANDLE_VALUE;
    }
    if (g_lab06_log_mutex != NULL) {
        CloseHandle(g_lab06_log_mutex);
        g_lab06_log_mutex = NULL;
    }
    return ok;
}

static BOOL lab06_parse_options(int argc, char **argv, int first_option,
                                DWORD *delay_ms, const char **log_path)
{
    int index;
    *delay_ms = LAB06_DEFAULT_DELAY_MS;
    *log_path = NULL;
    for (index = first_option; index < argc; index++) {
        if (strcmp(argv[index], "--test-delay-ms") == 0 && index + 1 < argc) {
            char *end = NULL;
            unsigned long value = strtoul(argv[++index], &end, 10);
            if (end == argv[index] || *end != '\0' || value > 1000) {
                fprintf(stderr, "--test-delay-ms must be an integer from 0 through 1000\n");
                return FALSE;
            }
            *delay_ms = (DWORD)value;
        } else if (strcmp(argv[index], "--log-file") == 0 && index + 1 < argc) {
            *log_path = argv[++index];
        } else {
            fprintf(stderr, "Unknown or incomplete option: %s\n", argv[index]);
            return FALSE;
        }
    }
    return TRUE;
}

static BOOL lab06_write_quoted_arg(char *line, size_t capacity, const char *arg)
{
    size_t pos = strlen(line);
    size_t i = 0;
    if (pos + 2 >= capacity)
        return FALSE;
    if (pos != 0)
        line[pos++] = ' ';
    line[pos++] = '"';

    while (arg[i] != '\0') {
        size_t slashes = 0;
        while (arg[i] == '\\') {
            slashes++;
            i++;
        }
        if (arg[i] == '"' || arg[i] == '\0') {
            size_t repeat = slashes * 2 + (arg[i] == '"' ? 1 : 0);
            while (repeat-- > 0) {
                if (pos + 1 >= capacity)
                    return FALSE;
                line[pos++] = '\\';
            }
            if (arg[i] == '"') {
                if (pos + 1 >= capacity)
                    return FALSE;
                line[pos++] = arg[i++];
            }
        } else {
            while (slashes-- > 0) {
                if (pos + 1 >= capacity)
                    return FALSE;
                line[pos++] = '\\';
            }
            if (pos + 1 >= capacity)
                return FALSE;
            line[pos++] = arg[i++];
        }
    }
    if (pos + 2 > capacity)
        return FALSE;
    line[pos++] = '"';
    line[pos] = '\0';
    return TRUE;
}

static BOOL lab06_spawn_child(const char *role, const char *object_name,
                              DWORD delay_ms, const char *log_path, PROCESS_INFORMATION *process)
{
    char executable[MAX_PATH];
    char command_line[MAX_PATH * 2 + 1024];
    char delay_text[16];
    STARTUPINFOA startup;

    if (GetModuleFileNameA(NULL, executable, MAX_PATH) == 0) {
        fprintf(stderr, "GetModuleFileNameA failed (Win32 error %lu)\n",
                (unsigned long)GetLastError());
        return FALSE;
    }
    command_line[0] = '\0';
    _snprintf_s(delay_text, sizeof(delay_text), _TRUNCATE, "%lu", (unsigned long)delay_ms);
    if (!lab06_write_quoted_arg(command_line, sizeof(command_line), executable) ||
        !lab06_write_quoted_arg(command_line, sizeof(command_line), "--child") ||
        !lab06_write_quoted_arg(command_line, sizeof(command_line), role) ||
        !lab06_write_quoted_arg(command_line, sizeof(command_line), object_name) ||
        !lab06_write_quoted_arg(command_line, sizeof(command_line), "--test-delay-ms") ||
        !lab06_write_quoted_arg(command_line, sizeof(command_line), delay_text)) {
        fprintf(stderr, "Child command line is too long\n");
        return FALSE;
    }
    if (log_path != NULL &&
        (!lab06_write_quoted_arg(command_line, sizeof(command_line), "--log-file") ||
         !lab06_write_quoted_arg(command_line, sizeof(command_line), log_path))) {
        fprintf(stderr, "Child command line is too long\n");
        return FALSE;
    }

    ZeroMemory(&startup, sizeof(startup));
    startup.cb = sizeof(startup);
    ZeroMemory(process, sizeof(*process));
    if (!CreateProcessA(NULL, command_line, NULL, NULL, FALSE, CREATE_NEW_CONSOLE,
                        NULL, NULL, &startup, process)) {
        fprintf(stderr, "CreateProcessA for child %s failed (Win32 error %lu)\n",
                role, (unsigned long)GetLastError());
        return FALSE;
    }
    CloseHandle(process->hThread);
    process->hThread = NULL;
    return TRUE;
}

static BOOL lab06_wait_child(PROCESS_INFORMATION *process, const char *role)
{
    DWORD exit_code = 1;
    BOOL ok = WaitForSingleObject(process->hProcess, INFINITE) == WAIT_OBJECT_0;
    if (ok)
        ok = GetExitCodeProcess(process->hProcess, &exit_code) && exit_code == 0;
    if (!ok)
        fprintf(stderr, "Child %s failed (wait error %lu, exit code %lu)\n", role,
                (unsigned long)GetLastError(), (unsigned long)exit_code);
    CloseHandle(process->hProcess);
    process->hProcess = NULL;
    return ok;
}

static BOOL lab06_iteration(const char *role, int iteration, DWORD delay_ms)
{
    char user_char = LAB06_USER_NAME[(iteration - 1) % (sizeof(LAB06_USER_NAME) - 1)];
    DWORD pid = GetCurrentProcessId();
    DWORD tid = GetCurrentThreadId();
    lab06_logf("ITER role=%s pid=%lu tid=%lu iteration=%d user=%c",
               role, (unsigned long)pid, (unsigned long)tid, iteration, user_char);
    printf("%s pid=%lu tid=%lu iteration=%d user=%c\n",
           role, (unsigned long)pid, (unsigned long)tid, iteration, user_char);
    fflush(stdout);
    if (delay_ms != 0)
        Sleep(delay_ms);
    return !lab06_has_log_error();
}

static BOOL lab06_run_worker(const char *role, int iterations, DWORD delay_ms,
                             Lab06Action enter_exclusive, Lab06Action leave_exclusive,
                             void *sync_context, Lab06Action before_iteration_16,
                             void *event_context)
{
    int iteration;
    for (iteration = 1; iteration <= iterations; iteration++) {
        if (iteration == 16 && before_iteration_16 != NULL &&
            !before_iteration_16(event_context))
            return FALSE;
        if (iteration == LAB06_FIRST_EXCLUSIVE_ITERATION && enter_exclusive != NULL) {
            if (!enter_exclusive(sync_context))
                return FALSE;
            lab06_logf("ENTER role=%s iteration=%d", role, iteration);
        }
        if (!lab06_iteration(role, iteration, delay_ms))
            return FALSE;
        if (iteration == LAB06_LAST_EXCLUSIVE_ITERATION && leave_exclusive != NULL) {
            lab06_logf("LEAVE role=%s iteration=%d", role, iteration);
            if (!leave_exclusive(sync_context))
                return FALSE;
        }
    }
    return !lab06_has_log_error();
}

static BOOL lab06_enter_critical(void *context)
{
    EnterCriticalSection((CRITICAL_SECTION *)context);
    return TRUE;
}

static BOOL lab06_leave_critical(void *context)
{
    LeaveCriticalSection((CRITICAL_SECTION *)context);
    return TRUE;
}

static BOOL lab06_enter_mutex(void *context)
{
    DWORD result = WaitForSingleObject((HANDLE)context, INFINITE);
    if (result == WAIT_OBJECT_0 || result == WAIT_ABANDONED)
        return TRUE;
    fprintf(stderr, "WaitForSingleObject(mutex) failed (Win32 error %lu)\n",
            (unsigned long)GetLastError());
    return FALSE;
}

static BOOL lab06_leave_mutex(void *context)
{
    if (ReleaseMutex((HANDLE)context))
        return TRUE;
    fprintf(stderr, "ReleaseMutex failed (Win32 error %lu)\n", (unsigned long)GetLastError());
    return FALSE;
}

static BOOL lab06_enter_semaphore(void *context)
{
    if (WaitForSingleObject((HANDLE)context, INFINITE) == WAIT_OBJECT_0)
        return TRUE;
    fprintf(stderr, "WaitForSingleObject(semaphore) failed (Win32 error %lu)\n",
            (unsigned long)GetLastError());
    return FALSE;
}

static BOOL lab06_leave_semaphore(void *context)
{
    if (ReleaseSemaphore((HANDLE)context, 1, NULL))
        return TRUE;
    fprintf(stderr, "ReleaseSemaphore failed (Win32 error %lu)\n", (unsigned long)GetLastError());
    return FALSE;
}

#endif
