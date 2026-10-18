/*
 * Lab-03d-client.c — поиск чисел, взаимно простых с M, в диапазоне [L, R] (Windows).
 *
 * Диапазон и число M задаются через аргументы командной строки:
 *   Lab-03d-client <Число M> <Нижний порог L> <Верхний порог R>
 *
 * Найденные числа сохраняются в промежуточном буфере и после завершения цикла
 * отправляются родительскому процессу по анонимному каналу: дескриптор канала
 * передан сервером через STARTUPINFO (стандартный вывод процесса — это канал).
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#include "console_ru.h" /* вывод кириллицы в консоль (UTF-8 -> OEM 866) */

static int gcd(int a, int b)
{
    while (b != 0) {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}

int main(int argc, char *argv[])
{
    if (argc != 4) {
        fprintf(stderr, "Использование: %s <Число M> <Нижний порог L> <Верхний порог R>\n", argv[0]);
        return 1;
    }

    int m = atoi(argv[1]);
    int l = atoi(argv[2]);
    int r = atoi(argv[3]);

    if (m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Ошибка: требуется M > 0, L >= 1 и L <= R\n");
        return 1;
    }

    /* Промежуточный буфер: найденные числа */
    int *found = malloc((size_t)(r - l + 1) * sizeof(int));
    if (found == NULL) {
        fprintf(stderr, "Ошибка: не хватило памяти\n");
        return 1;
    }
    int count = 0;

    for (int n = l; n <= r; n++) {
        if (gcd(n, m) == 1) {
            found[count++] = n;
        }
    }

    /* Отправка результата родителю по анонимному каналу (через стандартный вывод) */
    printf("CHUNK %lu %d %d", (unsigned long)GetCurrentProcessId(), count, 0);
    for (int i = 0; i < count; i++) {
        printf(" %d", found[i]);
    }
    printf("\n");
    fflush(stdout);

    free(found);
    return 0;
}
