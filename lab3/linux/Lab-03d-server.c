/*
 * Lab-03d-server.c — сервер: запускает K дочерних процессов поиска чисел,
 * взаимно простых с M, на поддиапазонах [L, R].
 *
 * Структура вызова:
 *   Lab-03d-server <Количество процессов K> <Число M> <Нижний порог L> <Верхний порог R>
 *
 * Сервер создаёт анонимный канал, порождает K процессов Lab-03d-client,
 * каждому выдаёт свой поддиапазон, читает результаты из канала и выводит:
 *   число M, диапазон [L, R], количество процессов K, общее количество
 *   найденных чисел, сами числа и время работы.
 *
 * Программа не завершается, пока не завершены все дочерние процессы.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>

#define MAX_NUMBERS 100000

static double now_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char *argv[])
{
    if (argc != 5) {
        fprintf(stderr,
                "Использование: %s <Количество процессов K> <Число M> <Нижний порог L> <Верхний порог R>\n",
                argv[0]);
        return 1;
    }

    int k = atoi(argv[1]);
    int m = atoi(argv[2]);
    int l = atoi(argv[3]);
    int r = atoi(argv[4]);

    if (k < 1 || m <= 0 || l < 1 || l > r) {
        fprintf(stderr, "Ошибка: требуется K >= 1, M > 0, L >= 1 и L <= R\n");
        return 1;
    }

    double t0 = now_seconds();

    int fd[2];
    if (pipe(fd) < 0) {
        perror("pipe");
        return 1;
    }

    int total = r - l + 1;
    int chunk = total / k;
    int remainder = total % k;

    pid_t *pids = malloc((size_t)k * sizeof(pid_t));
    if (pids == NULL) {
        perror("malloc");
        return 1;
    }

    int sub_l = l;
    for (int i = 0; i < k; i++) {
        int sub_r = sub_l + chunk - 1 + (i < remainder ? 1 : 0);
        if (i == k - 1) {
            sub_r = r;
        }

        pid_t pid = fork();
        if (pid < 0) {
            perror("fork");
            return 1;
        }
        if (pid == 0) {
            /* Дочерний процесс: вывод направляем в канал */
            close(fd[0]);
            dup2(fd[1], STDOUT_FILENO);
            close(fd[1]);

            char ml[32], ll[32], rl[32];
            snprintf(ml, sizeof(ml), "%d", m);
            snprintf(ll, sizeof(ll), "%d", sub_l);
            snprintf(rl, sizeof(rl), "%d", sub_r);
            execl("./Lab-03d-client", "Lab-03d-client", ml, ll, rl, (char *)NULL);
            perror("execl");
            _exit(1);
        }
        pids[i] = pid;
        sub_l = sub_r + 1;
    }

    /* Родитель читает результаты из канала */
    close(fd[1]);
    FILE *in = fdopen(fd[0], "r");
    if (in == NULL) {
        perror("fdopen");
        return 1;
    }

    int *all = malloc(MAX_NUMBERS * sizeof(int));
    if (all == NULL) {
        perror("malloc");
        return 1;
    }
    int total_found = 0;

    char line[1 << 16];
    while (fgets(line, sizeof(line), in) != NULL) {
        if (line[0] != 'C') {
            continue;
        }
        int pid_val, count, reserved;
        if (sscanf(line, "CHUNK %d %d %d", &pid_val, &count, &reserved) != 3) {
            continue;
        }
        char *p = line;
        /* пропускаем четыре токена: CHUNK, PID, count, 0 */
        for (int i = 0; i < 4; i++) {
            p = strchr(p + 1, ' ');
            if (p == NULL) {
                break;
            }
        }
        if (p == NULL) {
            continue;
        }
        for (int i = 0; i < count && total_found < MAX_NUMBERS; i++) {
            all[total_found++] = (int)strtol(p, &p, 10);
        }
    }
    fclose(in);

    /* Дожидаемся завершения всех дочерних процессов */
    for (int i = 0; i < k; i++) {
        int status;
        waitpid(pids[i], &status, 0);
    }

    double t1 = now_seconds();

    printf("Число M: %d\n", m);
    printf("Диапазон [L, R]: [%d, %d]\n", l, r);
    printf("Количество процессов K: %d\n", k);
    printf("Общее количество найденных чисел: %d\n", total_found);
    printf("Найденные числа:");
    for (int i = 0; i < total_found; i++) {
        printf(" %d", all[i]);
    }
    printf("\n");
    printf("Время работы: %.6f с\n", t1 - t0);

    free(all);
    free(pids);
    return 0;
}
