#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#include "console_ru.h"

#define MAX_PRIMES 4000000

typedef struct
{
    int low;
    int high;
    int limit;
} RANGE;

static DWORD g_tls;
static int *g_all;
static volatile LONG g_count;

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

static DWORD WINAPI prime_worker(LPVOID param)
{
    RANGE *r = (RANGE *)param;
    int cap = r->high - r->low + 1;
    if (cap < 1) cap = 1;

    int *buf = (int *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)cap * sizeof(int));
    if (buf == NULL)
    {
        return 1;
    }
    TlsSetValue(g_tls, buf);

    int n = 0;
    for (int v = r->low; v <= r->high && n < r->limit; v++)
    {
        if (is_prime(v))
        {
            buf[n++] = v;
        }
    }

    int *local = (int *)TlsGetValue(g_tls);
    for (int i = 0; i < n; i++)
    {
        LONG pos = InterlockedIncrement(&g_count) - 1;
        if (pos < MAX_PRIMES)
        {
            g_all[pos] = local[i];
        }
    }

    return 0;
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

    g_all = (int *)malloc((SIZE_T)MAX_PRIMES * sizeof(int));
    if (g_all == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }

    g_tls = TlsAlloc();
    if (g_tls == TLS_OUT_OF_INDEXES)
    {
        fprintf(stderr, "Ошибка TlsAlloc: %lu\n", GetLastError());
        free(g_all);
        return 1;
    }

    HANDLE *handles = (HANDLE *)malloc((SIZE_T)threads * sizeof(HANDLE));
    RANGE *ranges = (RANGE *)malloc((SIZE_T)threads * sizeof(RANGE));
    if (handles == NULL || ranges == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        TlsFree(g_tls);
        free(g_all);
        return 1;
    }

    int total = high - low + 1;
    int chunk = total / threads;
    int rest = total % threads;
    int start = low;

    LARGE_INTEGER f, t0, t1;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&t0);

    for (int i = 0; i < threads; i++)
    {
        int part = chunk + (i < rest ? 1 : 0);
        int finish = start + part - 1;
        if (i == threads - 1) finish = high;

        ranges[i].low = start;
        ranges[i].high = finish;
        ranges[i].limit = part;

        handles[i] = CreateThread(NULL, 0, prime_worker, &ranges[i], 0, NULL);
        if (handles[i] == NULL)
        {
            fprintf(stderr, "Ошибка CreateThread %d: %lu\n", i + 1, GetLastError());
            for (int k = 0; k < i; k++) CloseHandle(handles[k]);
            TlsFree(g_tls);
            free(g_all);
            free(handles);
            free(ranges);
            return 1;
        }
        start = finish + 1;
    }

    WaitForMultipleObjects((DWORD)threads, handles, TRUE, INFINITE);
    for (int i = 0; i < threads; i++) CloseHandle(handles[i]);

    QueryPerformanceCounter(&t1);

    int found = (int)g_count;
    if (found > MAX_PRIMES) found = MAX_PRIMES;

    qsort(g_all, (size_t)found, sizeof(int), cmp_int);

    printf("Количество потоков: %d\n", threads);
    printf("Диапазон: [%d, %d]\n", low, high);
    printf("Найдено простых чисел: %d\n", found);
    printf("Время: %.6f с\n", (double)(t1.QuadPart - t0.QuadPart) / (double)f.QuadPart);
    printf("Простые числа:");
    for (int i = 0; i < found && i < 200; i++)
    {
        printf(" %d", g_all[i]);
    }
    if (found > 200) printf(" ... (всего %d)", found);
    printf("\n");

    TlsFree(g_tls);
    free(g_all);
    free(handles);
    free(ranges);
    return 0;
}
