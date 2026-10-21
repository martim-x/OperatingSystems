#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

#define MAX_NUMBERS 1000000

static double now_seconds(void)
{
    LARGE_INTEGER freq, cnt;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&cnt);
    return (double)cnt.QuadPart / (double)freq.QuadPart;
}

static void client_path(char *out, size_t cap)
{
    char self[MAX_PATH];
    GetModuleFileNameA(NULL, self, MAX_PATH);
    char *slash = strrchr(self, '\\');
    if (slash != NULL) *(slash + 1) = '\0';
    else self[0] = '\0';
    snprintf(out, cap, "%sLab-03d-client.exe", self);
}

static int should_pause(int argc, char *argv[])
{
    if (GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0)) return 1;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--pause") == 0) return 1;
    }
    return 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: press Enter to exit...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
    int pause = should_pause(argc, argv);

    if (argc != 5) {
        fprintf(stderr, "Usage: %s <K> <M> <L> <R>\n", argv[0]);
        return 1;
    }

    int k = atoi(argv[1]);
    int m = atoi(argv[2]);
    int l = atoi(argv[3]);
    int r = atoi(argv[4]);

    if (k < 1 || m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Error: K >= 1, M > 0, L >= 1, L <= R required\n");
        return 1;
    }

    char client[MAX_PATH];
    client_path(client, sizeof(client));

    double t0 = now_seconds();

    SECURITY_ATTRIBUTES sa = {0};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;

    HANDLE hRead, hWrite;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
        fprintf(stderr, "Error: CreatePipe (%lu)\n", GetLastError());
        return 1;
    }
    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

    HANDLE *procs = malloc((size_t)k * sizeof(HANDLE));
    if (!procs) {
        fprintf(stderr, "Error: malloc failed\n");
        return 1;
    }
    int created = 0;

    int total = r - l + 1;
    int chunk = total / k;
    int remainder = total % k;
    int subL = l;

    for (int i = 0; i < k; i++) {
        int subR = subL + chunk - 1 + (i < remainder ? 1 : 0);
        if (i == k - 1) subR = r;

        STARTUPINFOA si = {0};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        si.hStdOutput = hWrite;
        si.hStdError = hWrite;

        PROCESS_INFORMATION pi = {0};

        char cmd[MAX_PATH + 64];
        snprintf(cmd, sizeof(cmd), "\"%s\" %d %d %d", client, m, subL, subR);

        if (!CreateProcessA(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
            fprintf(stderr, "Error: CreateProcess for [%d, %d] (%lu)\n", subL, subR, GetLastError());
        } else {
            CloseHandle(pi.hThread);
            procs[created++] = pi.hProcess;
            printf("Started child %lu: range [%d, %d]\n",
                   (unsigned long)pi.dwProcessId, subL, subR);
        }
        subL = subR + 1;
    }

    CloseHandle(hWrite);

    size_t cap = 1 << 16;
    char *data = malloc(cap);
    if (!data) {
        fprintf(stderr, "Error: malloc failed\n");
        return 1;
    }
    size_t used = 0;

    for (;;) {
        DWORD got = 0;
        if (used + 4096 >= cap) {
            cap *= 2;
            char *bigger = realloc(data, cap);
            if (!bigger) break;
            data = bigger;
        }
        if (!ReadFile(hRead, data + used, (DWORD)(cap - used - 1), &got, NULL) || got == 0) {
            break;
        }
        used += got;
    }
    data[used] = '\0';
    CloseHandle(hRead);

    if (created > 0) {
        WaitForMultipleObjects((DWORD)created, procs, TRUE, INFINITE);
    }
    for (int i = 0; i < created; i++) CloseHandle(procs[i]);
    free(procs);

    int *all = malloc(MAX_NUMBERS * sizeof(int));
    if (!all) {
        fprintf(stderr, "Error: malloc failed\n");
        return 1;
    }
    int total_found = 0;

    char *line = data;
    while (line && *line) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';
        if (strncmp(line, "CHUNK ", 6) == 0) {
            char *p = line + 6;
            (void)strtol(p, &p, 10);
            int count = (int)strtol(p, &p, 10);
            (void)strtol(p, &p, 10);
            for (int i = 0; i < count && total_found < MAX_NUMBERS; i++) {
                all[total_found++] = (int)strtol(p, &p, 10);
            }
        }
        line = nl ? nl + 1 : NULL;
    }
    free(data);

    double t1 = now_seconds();

    printf("M: %d\n", m);
    printf("Range [L, R]: [%d, %d]\n", l, r);
    printf("Processes K: %d\n", k);
    printf("Total found: %d\n", total_found);
    printf("Numbers:");
    for (int i = 0; i < total_found; i++) printf(" %d", all[i]);
    printf("\n");
    printf("Time: %.6f s\n", t1 - t0);

    free(all);

    if (pause) pause_before_exit();
    return 0;
}