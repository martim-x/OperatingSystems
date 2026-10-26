#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

static int gcd(int a, int b)
{
    while (b != 0) {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}

static int should_pause(void)
{
    return GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0) != 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: press Enter to exit...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
    int pause = should_pause();

    if (argc != 4) {
        fprintf(stderr, "Usage: %s <M> <L> <R>\n", argv[0]);
        return 1;
    }

    int m = atoi(argv[1]);
    int l = atoi(argv[2]);
    int r = atoi(argv[3]);

    if (m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Error: M > 0, L >= 1, L <= R required\n");
        return 1;
    }

    int *found = malloc((size_t)(r - l + 1) * sizeof(int));
    if (!found) {
        fprintf(stderr, "Error: malloc failed\n");
        return 1;
    }
    int count = 0;

    for (int n = l; n <= r; n++) {
        if (gcd(n, m) == 1) {
            found[count++] = n;
        }
    }

    printf("CHUNK %lu %d %d", (unsigned long)GetCurrentProcessId(), count, 0);
    for (int i = 0; i < count; i++) {
        printf(" %d", found[i]);
    }
    printf("\n");
    fflush(stdout);

    free(found);

    if (pause) pause_before_exit();
    return 0;
}