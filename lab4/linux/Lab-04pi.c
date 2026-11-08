#define _GNU_SOURCE
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>

#define STACK_SIZE (256 * 1024)

static volatile sig_atomic_t g_stop = 0;
static int g_fibers = 0;
static long g_chunk = 5000;
static double *g_sums = NULL;
static unsigned long long *g_terms = NULL;
static int *g_done = NULL;
static ucontext_t g_main_ctx;
static ucontext_t *g_ctx = NULL;
static char **g_stacks = NULL;

static void on_sigint(int sig)
{
    (void)sig;
    g_stop = 1;
}

static void fiber_main(int id)
{
    unsigned long long i = (unsigned long long)id;
    unsigned long long count = 0;
    double sum = 0.0;

    while (!g_stop)
    {
        for (long k = 0; k < g_chunk && !g_stop; k++)
        {
            double term = 1.0 / (2.0 * (double)i + 1.0);
            if (i & 1ULL)
            {
                sum -= term;
            }
            else
            {
                sum += term;
            }
            i += (unsigned long long)g_fibers;
            count++;
        }
        g_sums[id] = sum;
        g_terms[id] = count;
        swapcontext(&g_ctx[id], &g_main_ctx);
    }

    g_sums[id] = sum;
    g_terms[id] = count;
    g_done[id] = 1;
    swapcontext(&g_ctx[id], &g_main_ctx);

    for (;;)
    {
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2 || argc > 3)
    {
        fprintf(stderr, "Использование: %s <Количество волокон> [элементов на переключение]\n", argv[0]);
        return 1;
    }

    g_fibers = atoi(argv[1]);
    if (g_fibers < 1)
    {
        fprintf(stderr, "Ошибка: количество волокон должно быть >= 1\n");
        return 1;
    }

    if (argc == 3)
    {
        g_chunk = atol(argv[2]);
        if (g_chunk < 1)
        {
            fprintf(stderr, "Ошибка: количество элементов должно быть >= 1\n");
            return 1;
        }
    }

    g_sums = (double *)calloc((size_t)g_fibers, sizeof(double));
    g_terms = (unsigned long long *)calloc((size_t)g_fibers, sizeof(unsigned long long));
    g_done = (int *)calloc((size_t)g_fibers, sizeof(int));
    g_ctx = (ucontext_t *)calloc((size_t)g_fibers, sizeof(ucontext_t));
    g_stacks = (char **)calloc((size_t)g_fibers, sizeof(char *));

    if (g_sums == NULL || g_terms == NULL || g_done == NULL || g_ctx == NULL || g_stacks == NULL)
    {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        free(g_sums);
        free(g_terms);
        free(g_done);
        free(g_ctx);
        free(g_stacks);
        return 1;
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = on_sigint;
    sigemptyset(&sa.sa_mask);

    if (sigaction(SIGINT, &sa, NULL) != 0)
    {
        perror("sigaction");
        free(g_sums);
        free(g_terms);
        free(g_done);
        free(g_ctx);
        free(g_stacks);
        return 1;
    }

    for (int i = 0; i < g_fibers; i++)
    {
        g_stacks[i] = (char *)malloc(STACK_SIZE);
        if (g_stacks[i] == NULL)
        {
            fprintf(stderr, "Ошибка: не хватило памяти под стек\n");
            for (int k = 0; k < i; k++) free(g_stacks[k]);
            free(g_sums);
            free(g_terms);
            free(g_done);
            free(g_ctx);
            free(g_stacks);
            return 1;
        }

        if (getcontext(&g_ctx[i]) != 0)
        {
            perror("getcontext");
            return 1;
        }

        g_ctx[i].uc_stack.ss_sp = g_stacks[i];
        g_ctx[i].uc_stack.ss_size = STACK_SIZE;
        g_ctx[i].uc_link = &g_main_ctx;

        makecontext(&g_ctx[i], (void (*)(void))fiber_main, 1, i);
    }

    printf("Волокон: %d, элементов на переключение: %ld\n", g_fibers, g_chunk);
    printf("Нажмите Ctrl+C для завершения.\n");
    fflush(stdout);

    int running = g_fibers;
    while (running > 0)
    {
        for (int i = 0; i < g_fibers; i++)
        {
            if (!g_done[i])
            {
                swapcontext(&g_main_ctx, &g_ctx[i]);
                if (g_done[i]) running--;
            }
        }
    }

    double total = 0.0;
    unsigned long long terms = 0;

    for (int i = 0; i < g_fibers; i++)
    {
        total += g_sums[i];
        terms += g_terms[i];
    }

    double pi = 4.0 * total;
    double err = fabs(pi - 3.14159265358979323846);

    printf("Слагаемых: %llu\n", terms);
    printf("Приближение числа Пи: %.15f\n", pi);
    printf("Погрешность: %.2e\n", err);

    for (int i = 0; i < g_fibers; i++) free(g_stacks[i]);
    free(g_sums);
    free(g_terms);
    free(g_done);
    free(g_ctx);
    free(g_stacks);
    return 0;
}
