#define _GNU_SOURCE

#include <errno.h>
#include <semaphore.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "lab06_common.h"

typedef struct
{
    sem_t mutex;
} shared_state;

static int lock_shared(sem_t *mutex)
{
    while (sem_wait(mutex) == -1)
    {
        if (errno != EINTR)
        {
            perror("sem_wait");
            return -1;
        }
    }
    return 0;
}

static int run_worker(sem_t *mutex, const char *name)
{
    for (int iteration = 1; iteration <= LAB06_ITERATIONS; ++iteration)
    {
        if (iteration == LAB06_FIRST_EXCLUSIVE)
        {
            if (lock_shared(mutex) != 0)
                return -1;
            lab06_print_boundary("ENTER", name, iteration);
        }

        lab06_print_iteration(name, iteration);
        if (lab06_delay() != 0)
        {
            if (iteration >= LAB06_FIRST_EXCLUSIVE && iteration <= LAB06_LAST_EXCLUSIVE &&
                sem_post(mutex) == -1)
                perror("sem_post after delay failure");
            return -1;
        }

        if (iteration == LAB06_LAST_EXCLUSIVE)
        {
            lab06_print_boundary("LEAVE", name, iteration);
            if (sem_post(mutex) == -1)
            {
                perror("sem_post");
                return -1;
            }
        }
    }
    return 0;
}

static int wait_for_child(pid_t child, const char *name)
{
    int child_status;
    pid_t result;
    do
    {
        result = waitpid(child, &child_status, 0);
    } while (result == -1 && errno == EINTR);

    if (result == -1)
    {
        perror("waitpid");
        return -1;
    }
    if (!WIFEXITED(child_status) || WEXITSTATUS(child_status) != 0)
    {
        fprintf(stderr, "child %s did not exit successfully\n", name);
        return -1;
    }
    return 0;
}

static int run_child(sem_t *mutex, const char *name, const char *tty)
{
    if (tty)
    {
        lab06_terminal = fopen(tty, "a");
        if (!lab06_terminal || !isatty(fileno(lab06_terminal)))
        {
            fprintf(stderr, "not a writable terminal: %s\n", tty);
            return 1;
        }
        setvbuf(lab06_terminal, NULL, _IOLBF, 0);
    }
    int rc = run_worker(mutex, name);
    if (lab06_terminal && fclose(lab06_terminal) != 0)
        rc = -1;
    return rc != 0;
}

int main(int argc, char **argv)
{
    if (argc != 1 && (argc != 3 || strcmp(argv[1], argv[2]) == 0 ||
                      strncmp(argv[1], "/dev/pts/", 9) || strncmp(argv[2], "/dev/pts/", 9)))
    {
        fprintf(stderr, "usage: Lab-06b [/dev/pts/A /dev/pts/B]\n");
        return 2;
    }
    (void)setvbuf(stdout, NULL, _IOLBF, 0);
    shared_state *shared = mmap(NULL, sizeof(*shared), PROT_READ | PROT_WRITE,
                                MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (shared == MAP_FAILED)
    {
        perror("mmap");
        return 1;
    }
    if (sem_init(&shared->mutex, 1, 1) == -1)
    {
        perror("sem_init");
        (void)munmap(shared, sizeof(*shared));
        return 1;
    }

    pid_t child_a = fork();
    if (child_a == -1)
    {
        perror("fork A");
        (void)sem_destroy(&shared->mutex);
        (void)munmap(shared, sizeof(*shared));
        return 1;
    }
    if (child_a == 0)
        _exit(run_child(&shared->mutex, "A", argc == 3 ? argv[1] : NULL));

    pid_t child_b = fork();
    if (child_b == -1)
    {
        perror("fork B");
        (void)wait_for_child(child_a, "A");
        (void)sem_destroy(&shared->mutex);
        (void)munmap(shared, sizeof(*shared));
        return 1;
    }
    if (child_b == 0)
        _exit(run_child(&shared->mutex, "B", argc == 3 ? argv[2] : NULL));

    int status = run_worker(&shared->mutex, "main");
    if (wait_for_child(child_a, "A") != 0)
        status = -1;
    if (wait_for_child(child_b, "B") != 0)
        status = -1;
    if (sem_destroy(&shared->mutex) == -1)
    {
        perror("sem_destroy");
        status = -1;
    }
    if (munmap(shared, sizeof(*shared)) == -1)
    {
        perror("munmap");
        status = -1;
    }
    return status == 0 ? 0 : 1;
}
