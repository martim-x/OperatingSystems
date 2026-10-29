#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "console_ru.h"

/* Пауза перед выходом нужна только для съёмки кадров, где окно должно
   оставаться на экране; на поведение по методичке она не влияет. */
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
    int iterations;
    int pause = should_pause();

    /* Количество итераций: аргумент командной строки, иначе ITER_NUM,
       иначе — завершение с ошибкой через ExitProcess. */
    if (argc > 1) {
        iterations = atoi(argv[1]);
    } else {
        char buf[32];
        DWORD n = GetEnvironmentVariableA("ITER_NUM", buf, sizeof(buf));
        if (n == 0 || n >= sizeof(buf)) {
            fprintf(stderr, "Ошибка: не задан аргумент командной строки и переменная окружения ITER_NUM\n");
            ExitProcess(1);
        }
        iterations = atoi(buf);
    }

    printf("Количество итераций: %d\n", iterations);

    for (int i = 1; i <= iterations; i++) {
        printf("PID=%lu итерация=%d\n", (unsigned long)GetCurrentProcessId(), i);
        fflush(stdout);
        Sleep(500);
    }

    if (pause) pause_before_exit();
    return 0;
}
