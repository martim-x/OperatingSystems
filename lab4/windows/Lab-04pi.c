#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "console_ru.h"

#define CHUNK_DEFAULT 2000

typedef struct
{
    LPVOID main_fiber;
    long long start;
    long long done;
    double sum;
    int id;
} FIBER_CTX;

static volatile LONG g_stop = 0;
static long long g_terms = 0;
static int g_chunk = CHUNK_DEFAULT;
static int g_fibers = 1;

static BOOL WINAPI ctrl_handler(DWORD type)
{
    if (type == CTRL_C_EVENT || type == CTRL_BREAK_EVENT || type == CTRL_CLOSE_EVENT)
    {
        InterlockedExchange(&g_stop, 1);
        return TRUE;
    }
    return FALSE;
}

static VOID CALLBACK fiber_proc(LPVOID param)
{
    FIBER_CTX *ctx = (FIBER_CTX *)param;
    int chunk = g_chunk;

    for (;;)
    {
        for (int i = 0; i < chunk; i++)
        {
            long long k = ctx->start + i;
            double term = 1.0 / (double)(2 * k + 1);
            if (k & 1LL)
            {
                ctx->sum -= term;
            }
            else
            {
                ctx->sum += term;
            }
        }
        ctx->start += (long long)chunk * g_fibers;
        ctx->done += chunk;
        InterlockedExchangeAdd64(&g_terms, chunk);
        SwitchToFiber(ctx->main_fiber);
    }
}

int main(int argc, char *argv[])
{
    int fibers_count = 4;
    int chunk = CHUNK_DEFAULT;

    if (argc >= 2)
    {
        fibers_count = atoi(argv[1]);
    }
    if (argc >= 3)
    {
        chunk = atoi(argv[2]);
    }
    if (fibers_count < 1 || chunk < 1)
    {
        fprintf(stderr, "Использование: %s <Количество волокон> <Элементов на переключение>\n", argv[0]);
        return 1;
    }

    g_fibers = fibers_count;

    if (!SetConsoleCtrlHandler(ctrl_handler, TRUE))
    {
        fprintf(stderr, "Ошибка SetConsoleCtrlHandler: %lu\n", GetLastError());
        return 1;
    }

    LPVOID main_fiber = ConvertThreadToFiber(NULL);
    if (main_fiber == NULL)
    {
        fprintf(stderr, "Ошибка ConvertThreadToFiber: %lu\n", GetLastError());
        return 1;
    }

    FIBER_CTX *ctx = (FIBER_CTX *)calloc((size_t)fibers_count, sizeof(FIBER_CTX));
    LPVOID *workers = (LPVOID *)calloc((size_t)fibers_count, sizeof(LPVOID));
    if (ctx == NULL || workers == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        ConvertFiberToThread();
        return 1;
    }

    for (int i = 0; i < fibers_count; i++)
    {
        ctx[i].main_fiber = main_fiber;
        ctx[i].start = (long long)i * chunk;
        ctx[i].sum = 0.0;
        ctx[i].id = i;

        workers[i] = CreateFiber(0, fiber_proc, &ctx[i]);
        if (workers[i] == NULL)
        {
            fprintf(stderr, "Ошибка CreateFiber %d: %lu\n", i + 1, GetLastError());
            for (int k = 0; k < i; k++) DeleteFiber(workers[k]);
            ConvertFiberToThread();
            free(ctx);
            free(workers);
            return 1;
        }
    }

    printf("Волокон: %d, элементов на переключение: %d\n", fibers_count, chunk);
    printf("Нажмите Ctrl+C для завершения и вывода приближения числа Пи\n\n");
    fflush(stdout);

    long long rounds = 0;
    while (g_stop == 0)
    {
        for (int i = 0; i < fibers_count && g_stop == 0; i++)
        {
            SwitchToFiber(workers[i]);
        }

        rounds++;
        if ((rounds % 5000) == 0)
        {
            double sum = 0.0;
            for (int i = 0; i < fibers_count; i++) sum += ctx[i].sum;
            printf("раундов %lld, слагаемых %lld, пи ~ %.15f\n", rounds, g_terms, 4.0 * sum);
            fflush(stdout);
        }
    }

    double total = 0.0;
    for (int i = 0; i < fibers_count; i++)
    {
        total += ctx[i].sum;
    }

    printf("\nОбработано слагаемых: %lld\n", g_terms);
    for (int i = 0; i < fibers_count; i++)
    {
        printf("  волокно %d: слагаемых %lld, частичная сумма %.15f\n", i + 1, ctx[i].done, ctx[i].sum);
    }
    printf("Приближение числа Пи: %.15f\n", 4.0 * total);
    printf("Эталон:                %.15f\n", 3.141592653589793);
    printf("Погрешность:           %.6e\n", fabs(4.0 * total - 3.141592653589793));

    for (int i = 0; i < fibers_count; i++)
    {
        DeleteFiber(workers[i]);
    }
    ConvertFiberToThread();
    free(ctx);
    free(workers);

    return 0;
}
