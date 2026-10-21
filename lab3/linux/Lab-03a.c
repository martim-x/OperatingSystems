#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#define FIRST_ITER  "5"
#define SECOND_ITER "8"

int main(void)
{
    pid_t pid1, pid2;

    pid1 = fork();
    if (pid1 < 0) {
        perror("fork (1)");
        return 1;
    }
    if (pid1 == 0) {
        execl("./Lab-03x", "Lab-03x", FIRST_ITER, (char *)NULL);
        perror("execl (1)");
        _exit(1);
    }

    setenv("ITER_NUM", SECOND_ITER, 1);
    pid2 = fork();
    if (pid2 < 0) {
        perror("fork (2)");
        return 1;
    }
    if (pid2 == 0) {
        execl("./Lab-03x", "Lab-03x", (char *)NULL);
        perror("execl (2)");
        _exit(1);
    }

    printf("Parent PID=%d waiting for children...\n", getpid());
    printf("  Child 1: PID=%d (5 iterations)\n", pid1);
    printf("  Child 2: PID=%d (8 iterations)\n", pid2);
    printf("  >>> Run 'ps -ef | grep Lab-03x' in another terminal <<<\n");
    fflush(stdout);

    int status;
    waitpid(pid1, &status, 0);
    printf("Child %d exited (code %d)\n", pid1, WEXITSTATUS(status));
    waitpid(pid2, &status, 0);
    printf("Child %d exited (code %d)\n", pid2, WEXITSTATUS(status));

    printf("All children done, parent exiting.\n");
    return 0;
}