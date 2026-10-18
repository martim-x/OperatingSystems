/*
 * Lab-03d-client.c — поиск чисел, взаимно простых с M, в диапазоне [L, R].
 *
 * Диапазон и число M задаются через аргументы командной строки:
 *   Lab-03d-client <Число M> <Нижний порог L> <Верхний порог R>
 *
 * Найденные числа сохраняются в промежуточном буфере и после завершения цикла
 * отправляются родительскому процессу по анонимному каналу (fd 1 — стандартный
 * вывод перенаправлен на канал сервером).
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

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
        perror("malloc");
        return 1;
    }
    int count = 0;

    for (int n = l; n <= r; n++) {
        if (gcd(n, m) == 1) {
            found[count++] = n;
        }
    }

    /* Отправка результата родителю по анонимному каналу (через stdout) */
    printf("CHUNK %d %d %d", getpid(), count, 0);
    for (int i = 0; i < count; i++) {
        printf(" %d", found[i]);
    }
    printf("\n");
    fflush(stdout);

    free(found);
    return 0;
}
