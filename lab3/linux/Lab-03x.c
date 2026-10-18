/*
 * Lab-03x.c — цикл с заданным количеством итераций (Linux-аналог Windows-версии).
 *
 * Количество итераций берётся из аргумента командной строки; если аргумент
 * не задан — из переменной окружения ITER_NUM. Если не задано ни то, ни другое,
 * программа завершается с ошибкой.
 *
 * На каждой итерации выводится PID процесса, задержка между итерациями — 500 мс.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    int iterations;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    } else {
        const char *env = getenv("ITER_NUM");
        if (env == NULL) {
            fprintf(stderr, "Ошибка: не задан аргумент командной строки и переменная ITER_NUM\n");
            return 1;
        }
        iterations = atoi(env);
    }

    printf("Количество итераций: %d\n", iterations);

    for (int i = 1; i <= iterations; i++) {
        printf("PID=%d итерация=%d\n", getpid(), i);
        fflush(stdout);
        usleep(500000); /* 500 мс */
    }

    return 0;
}
