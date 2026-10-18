/*
 * Lab-03a.c — родительский процесс создаёт двух дочерних с загрузкой Lab-03x.
 *
 * Первый дочерний процесс получает количество итераций как аргумент командной
 * строки. Второй — через переменную окружения ITER_NUM, которая создаётся
 * непосредственно в родительском процессе перед созданием второго ребёнка.
 *
 * Родитель дожидается завершения обоих процессов (выполняются одновременно).
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#define FIRST_ITER  "5"
#define SECOND_ITER "8"

int main(void)
{
    pid_t pid1, pid2;

    /* Первый дочерний процесс: итерации передаются аргументом командной строки */
    pid1 = fork();
    if (pid1 < 0) {
        perror("fork (1)");
        return 1;
    }
    if (pid1 == 0) {
        printf("[родитель] создан дочерний процесс %d — итерации через аргумент\n", getpid());
        execl("./Lab-03x", "Lab-03x", FIRST_ITER, (char *)NULL);
        perror("execl (1)");
        _exit(1);
    }

    /* Второй дочерний процесс: итерации передаются через ITER_NUM */
    setenv("ITER_NUM", SECOND_ITER, 1);
    pid2 = fork();
    if (pid2 < 0) {
        perror("fork (2)");
        return 1;
    }
    if (pid2 == 0) {
        printf("[родитель] создан дочерний процесс %d — итерации через ITER_NUM=%s\n",
               getpid(), SECOND_ITER);
        execl("./Lab-03x", "Lab-03x", (char *)NULL);
        perror("execl (2)");
        _exit(1);
    }

    printf("Родитель ожидает завершения обоих дочерних процессов...\n");

    int status;
    waitpid(pid1, &status, 0);
    printf("Дочерний процесс %d завершён (код %d)\n", pid1, WEXITSTATUS(status));
    waitpid(pid2, &status, 0);
    printf("Дочерний процесс %d завершён (код %d)\n", pid2, WEXITSTATUS(status));

    printf("Оба дочерних процесса завершены, родитель завершает работу.\n");
    return 0;
}
