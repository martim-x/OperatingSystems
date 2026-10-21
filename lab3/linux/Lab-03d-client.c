#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

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
    return getenv("PAUSE_ON_EXIT") != NULL;
}

static void pause_before_exit(void)
{
    printf("PID=%d: press Enter to exit...\n", getpid());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
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
        perror("malloc");
        return 1;
    }
    int count = 0;

    for (int n = l; n <= r; n++) {
        if (gcd(n, m) == 1) {
            found[count++] = n;
        }
    }

    printf("CHUNK %d %d %d", getpid(), count, 0);
    for (int i = 0; i < count; i++) {
        printf(" %d", found[i]);
    }
    printf("\n");
    fflush(stdout);

    free(found);

    if (should_pause()) pause_before_exit();
    return 0;
}