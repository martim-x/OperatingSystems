#define _GNU_SOURCE
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_PRIMES 4000000

typedef struct
{
    int low;
    int high;
} RANGE;

static pthread_once_t g_once = PTHREAD_ONCE_INIT;
static pthread_key_t g_key;
static int *g_all;
static atomic_int g_count;

static void make_key(void)
{
    pthread_key_create(&g_key, free);
}

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

static void *prime_worker(void *arg)
{
    RANGE *r = (RANGE *)arg;
    int cap = r->high - r->low + 1;
    if (cap < 1) cap = 1;

    pthread_once(&g_once, make_key);

    int *buf = (int *)malloc((size_t)cap * sizeof(int));
    if (buf == NULL)
    {
        return NULL;
    }
    pthread_setspecific(g_key, buf);

    int n = 0;
    for (int v = r->low; v <= r->high; v++)
    {
        if (is_prime(v))
        {
            buf[n++] = v;
        }
    }

    int *local = (int *)pthread_getspecific(g_key);
    for (int i = 0; i < n; i++)
    {
        int pos = atomic_fetch_add(&g_count, 1);
        if (pos < MAX_PRIMES)
        {
            g_all[pos] = local[i];
        }
    }

    return NULL;
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
        fprintf(stderr, "Использование: %s <Количество потоков> <Нижний порог> <Верхний порог>\n", argv[0]);
        return 1;
    }

    int threads = atoi(argv[1]);
    int low = atoi(argv[2]);
    int high = atoi(argv[3]);

    if (threads < 1 || low < 1 || low > high)
    {
        fprintf(stderr, "Ошибка: требуется потоков >= 1, 1 <= L <= R\n");
        return 1;
    }

    g_all = (int *)malloc((size_t)MAX_PRIMES * sizeof(int));
    if (g_all == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }

    atomic_store(&g_count, 0);

    pthread_t *tids = (pthread_t *)malloc((size_t)threads * sizeof(pthread_t));
    RANGE *ranges = (RANGE *)malloc((size_t)threads * sizeof(RANGE));
    if (tids == NULL || ranges == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        free(tids);
        free(ranges);
        free(g_all);
        return 1;
    }

    int total = high - low + 1;
    int chunk = total / threads;
    int rest = total % threads;
    int start = low;

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (int i = 0; i < threads; i++)
    {
        int part = chunk + (i < rest ? 1 : 0);
        int finish = start + part - 1;
        if (i == threads - 1) finish = high;

        ranges[i].low = start;
        ranges[i].high = finish;

        int rc = pthread_create(&tids[i], NULL, prime_worker, &ranges[i]);
        if (rc != 0)
        {
            fprintf(stderr, "Ошибка pthread_create %d: %d\n", i + 1, rc);
            for (int k = 0; k < i; k++)
            {
                pthread_join(tids[k], NULL);
            }
            free(tids);
            free(ranges);
            free(g_all);
            return 1;
        }
        start = finish + 1;
    }

    for (int i = 0; i < threads; i++)
    {
        pthread_join(tids[i], NULL);
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);

    int found = atomic_load(&g_count);
    if (found > MAX_PRIMES) found = MAX_PRIMES;

    qsort(g_all, (size_t)found, sizeof(int), cmp_int);

    double elapsed = (double)(t1.tv_sec - t0.tv_sec) + (double)(t1.tv_nsec - t0.tv_nsec) / 1e9;

    printf("Количество потоков: %d\n", threads);
    printf("Диапазон: [%d, %d]\n", low, high);
    printf("Найдено простых чисел: %d\n", found);
    printf("Время: %.6f с\n", elapsed);
    printf("Простые числа:");
    for (int i = 0; i < found && i < 200; i++)
    {
        printf(" %d", g_all[i]);
    }
    if (found > 200) printf(" ... (всего %d)", found);
    printf("\n");

    free(tids);
    free(ranges);
    free(g_all);
    return 0;
}
