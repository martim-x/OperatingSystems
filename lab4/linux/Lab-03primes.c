#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>

#define MAX_PRIMES 4000000

typedef struct
{
    int low;
    int high;
} RANGE;

static int is_prime(int n)
{
    if (n < 2) return 0;
    if (n % 2 == 0) return n == 2;
    for (int d = 3; (long long)d * d <= n; d += 2)
    {
        if (n % d == 0) return 0;
    }
    return 1;
}

static void child_run(int fd, RANGE r)
{
    for (int v = r.low; v <= r.high; v++)
    {
        if (is_prime(v))
        {
            int x = v;
            if (write(fd, &x, sizeof(x)) != (ssize_t)sizeof(x))
            {
                _exit(1);
            }
        }
    }
    _exit(0);
}

static int cmp_int(const void *a, const void *b)
{
    int x = *(const int *)a;
    int y = *(const int *)b;
    return (x > y) - (x < y);
}

int main(int argc, char *argv[])
{
    if (argc != 4)
    {
        fprintf(stderr, "Использование: %s <Количество процессов> <Нижний порог> <Верхний порог>\n", argv[0]);
        return 1;
    }

    int procs = atoi(argv[1]);
    int low = atoi(argv[2]);
    int high = atoi(argv[3]);

    if (procs < 1 || low < 1 || low > high)
    {
        fprintf(stderr, "Ошибка: требуется процессов >= 1, 1 <= L <= R\n");
        return 1;
    }

    int *all = (int *)malloc((size_t)MAX_PRIMES * sizeof(int));
    int (*pipes)[2] = (int (*)[2])malloc((size_t)procs * sizeof(int[2]));
    RANGE *ranges = (RANGE *)malloc((size_t)procs * sizeof(RANGE));
    pid_t *pids = (pid_t *)malloc((size_t)procs * sizeof(pid_t));

    if (all == NULL || pipes == NULL || ranges == NULL || pids == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        free(all);
        free(pipes);
        free(ranges);
        free(pids);
        return 1;
    }

    int total = high - low + 1;
    int chunk = total / procs;
    int rest = total % procs;
    int start = low;

    for (int i = 0; i < procs; i++)
    {
        int part = chunk + (i < rest ? 1 : 0);
        int finish = start + part - 1;
        if (i == procs - 1) finish = high;

        ranges[i].low = start;
        ranges[i].high = finish;
        start = finish + 1;

        if (pipe(pipes[i]) != 0)
        {
            perror("pipe");
            for (int k = 0; k < i; k++)
            {
                close(pipes[k][0]);
                close(pipes[k][1]);
            }
            free(all);
            free(pipes);
            free(ranges);
            free(pids);
            return 1;
        }
    }

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (int i = 0; i < procs; i++)
    {
        pid_t pid = fork();
        if (pid < 0)
        {
            perror("fork");
            for (int k = 0; k < procs; k++)
            {
                close(pipes[k][0]);
                close(pipes[k][1]);
            }
            free(all);
            free(pipes);
            free(ranges);
            free(pids);
            return 1;
        }

        if (pid == 0)
        {
            for (int k = 0; k < procs; k++)
            {
                close(pipes[k][0]);
                if (k != i) close(pipes[k][1]);
            }
            child_run(pipes[i][1], ranges[i]);
        }

        pids[i] = pid;
    }

    for (int i = 0; i < procs; i++)
    {
        close(pipes[i][1]);
    }

    int found = 0;
    for (int i = 0; i < procs; i++)
    {
        int v;
        while (read(pipes[i][0], &v, sizeof(v)) == (ssize_t)sizeof(v))
        {
            if (found < MAX_PRIMES)
            {
                all[found++] = v;
            }
        }
        close(pipes[i][0]);
    }

    for (int i = 0; i < procs; i++)
    {
        waitpid(pids[i], NULL, 0);
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);

    qsort(all, (size_t)found, sizeof(int), cmp_int);

    double elapsed = (double)(t1.tv_sec - t0.tv_sec) + (double)(t1.tv_nsec - t0.tv_nsec) / 1e9;

    printf("Количество процессов: %d\n", procs);
    printf("Диапазон: [%d, %d]\n", low, high);
    printf("Найдено простых чисел: %d\n", found);
    printf("Время: %.6f с\n", elapsed);
    printf("Простые числа:");
    for (int i = 0; i < found && i < 200; i++)
    {
        printf(" %d", all[i]);
    }
    if (found > 200) printf(" ... (всего %d)", found);
    printf("\n");

    free(all);
    free(pipes);
    free(ranges);
    free(pids);
    return 0;
}
