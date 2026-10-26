#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

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
    int iterations;
    int pause = should_pause();

    if (argc > 1 && strcmp(argv[1], "--pause") != 0) {
        iterations = atoi(argv[1]);
    } else {
        const char *env = getenv("ITER_NUM");
        if (!env) {
            fprintf(stderr, "Error: no argument or ITER_NUM env var\n");
            return 1;
        }
        iterations = atoi(env);
    }

    printf("Iterations: %d\n", iterations);

    for (int i = 1; i <= iterations; i++) {
        printf("PID=%d iteration=%d\n", getpid(), i);
        fflush(stdout);
        usleep(500000);
    }

    if (pause) pause_before_exit();
    return 0;
}