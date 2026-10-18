/*
 * Lab-03sig.c — приложение, устойчивое к Ctrl+C (уровень 9-10, Linux).
 *
 * Приложение выводит отчёт о своей работе каждую секунду. Нажатие Ctrl+C
 * (сигнал SIGINT) не останавливает его: обработчик сигнала переустанавливается
 * и лишь выводит уведомление, а основной цикл продолжается.
 *
 * Остановить приложение можно только сигналом SIGTERM (kill) или SIGKILL.
 */
#include <stdio.h>
#include <signal.h>
#include <unistd.h>

static volatile sig_atomic_t sigint_count = 0;

static void on_sigint(int sig)
{
    (void)sig;
    sigint_count++;
    /* Переустанавливаем обработчик: SIGINT снова перехватывается */
    signal(SIGINT, on_sigint);
    const char msg[] = "\n[!] Получен SIGINT (Ctrl+C) — приложение продолжает работу\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
}

int main(void)
{
    signal(SIGINT, on_sigint);

    printf("Приложение Lab-03sig запущено (PID=%d)\n", getpid());
    printf("Ctrl+C не способно остановить это приложение.\n");
    fflush(stdout);

    int second = 0;
    for (;;) {
        sleep(1);
        second++;
        printf("Работаю... прошло %d с (перехвачено SIGINT: %d)\n",
               second, (int)sigint_count);
        fflush(stdout);
    }

    return 0;
}
