/*
 * Lab-03hello-child.c — дочерний процесс (Windows, уровень 9-10).
 *
 * Получает строку, переданную родителем через структуру STARTUPINFO, и выводит
 * её на консоль. Строка читается из заголовка консоли (GetConsoleTitle) —
 * это единственный строковый канал, доступный через STARTUPINFO без
 * переменных окружения, аргументов командной строки, перенаправления
 * потоков и стандартных механизмов IPC.
 */
#include <windows.h>
#include <stdio.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

int main(void)
{
    char title[256];
    DWORD n = GetConsoleTitleA(title, sizeof(title));

    if (n == 0) {
        fprintf(stderr, "Дочерний процесс: не удалось прочитать заголовок консоли (%lu)\n",
                GetLastError());
        return 1;
    }

    printf("Дочерний процесс (PID=%lu): получено через STARTUPINFO: %s\n",
           (unsigned long)GetCurrentProcessId(), title);
    fflush(stdout);

    /* Пауза, чтобы окно дочернего процесса успело попасть в снимок экрана */
    Sleep(4000);
    return 0;
}
