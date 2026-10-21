#include <stdio.h>
#include <signal.h>
#include <unistd.h>

static volatile sig_atomic_t sigint_count = 0;

static void on_sigint(int sig)
{
    (void)sig;
    sigint_count++;
    signal(SIGINT, on_sigint);
    const char msg[] = "\n[!] SIGINT (Ctrl+C) caught - continuing\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
}

int main(void)
{
    signal(SIGINT, on_sigint);

    printf("Lab-03sig started (PID=%d)\n", getpid());
    printf("Ctrl+C cannot stop this application.\n");
    fflush(stdout);

    int second = 0;
    for (;;) {
        sleep(1);
        second++;
        printf("Running... %d s (SIGINT caught: %d)\n", second, (int)sigint_count);
        fflush(stdout);
    }

    return 0;
}