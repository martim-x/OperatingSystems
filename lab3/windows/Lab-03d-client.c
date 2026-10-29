#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

static int gcd(int a, int b)
{
    while (b != 0) {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}

static int should_pause(void)
{
    return GetEnvironmentVariableA("PAUSE_ON_EXIT", NULL, 0) != 0;
}

static void pause_before_exit(void)
{
    printf("PID=%lu: нажмите Enter для выхода...\n", (unsigned long)GetCurrentProcessId());
    fflush(stdout);
    getchar();
}

int main(int argc, char *argv[])
{
    int pause = should_pause();

    /* Структура вызова: Lab-03d-client <Число M> <Нижний порог> <Верхний порог> */
    if (argc != 4) {
        fprintf(stderr, "Использование: %s <M> <L> <R>\n", argv[0]);
        return 1;
    }

    int m = atoi(argv[1]);
    int l = atoi(argv[2]);
    int r = atoi(argv[3]);

    if (m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Ошибка: требуется M > 0, L >= 1, L <= R\n");
        return 1;
    }

    int *found = malloc((size_t)(r - l + 1) * sizeof(int));
    if (!found) {
        fprintf(stderr, "Ошибка: не удалось выделить память\n");
        return 1;
    }
    int count = 0;

    /* Числа, взаимно простые с M: НОД(n, M) == 1. */
    for (int n = l; n <= r; n++) {
        if (gcd(n, m) == 1) {
            found[count++] = n;
        }
    }

    /* Результат уходит в анонимный канал, который родитель передал
       через STARTUPINFO (hStdOutput). */
    printf("CHUNK %lu %d %d", (unsigned long)GetCurrentProcessId(), count, 0);
    for (int i = 0; i < count; i++) {
        printf(" %d", found[i]);
    }
    printf("\n");
    fflush(stdout);

    free(found);

    if (pause) pause_before_exit();
    return 0;
}
