#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

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
    int iterations;
    int pause = should_pause(argc, argv);

    if (argc > 1 && strcmp(argv[1], "--pause") != 0) {
        iterations = atoi(argv[1]);
    } else {
        char buf[32];
        DWORD n = GetEnvironmentVariableA("ITER_NUM", buf, sizeof(buf));
        if (n == 0 || n >= sizeof(buf)) {
            fprintf(stderr, "Error: no argument or ITER_NUM env var\n");
            ExitProcess(1);
        }
        iterations = atoi(buf);
    }

    printf("Iterations: %d\n", iterations);

    for (int i = 1; i <= iterations; i++) {
        printf("PID=%lu iteration=%d\n", (unsigned long)GetCurrentProcessId(), i);
        fflush(stdout);
        Sleep(500);
    }

    if (pause) pause_before_exit();
    return 0;
}