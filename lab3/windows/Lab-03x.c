/*
 * Lab-03x.c — цикл с заданным количеством итераций (Windows).
 *
 * Количество итераций берётся из аргумента командной строки; если аргумент
 * не задан — из переменной окружения ITER_NUM. Если не задано ни то, ни другое,
 * программа завершается с ошибкой (ExitProcess).
 *
 * На каждой итерации выводится PID процесса, задержка между итерациями — 500 мс.
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

int main(int argc, char *argv[])
{
    int iterations;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    } else {
        char buf[32];
        DWORD n = GetEnvironmentVariableA("ITER_NUM", buf, sizeof(buf));
        if (n == 0 || n >= sizeof(buf)) {
            fprintf(stderr, "Ошибка: не задан аргумент командной строки и переменная ITER_NUM\n");
            ExitProcess(1);
        }
        iterations = atoi(buf);
    }

    printf("Количество итераций: %d\n", iterations);

    for (int i = 1; i <= iterations; i++) {
        printf("PID=%lu итерация=%d\n", (unsigned long)GetCurrentProcessId(), i);
        fflush(stdout);
        Sleep(500); /* 500 мс */
    }

    return 0;
}
