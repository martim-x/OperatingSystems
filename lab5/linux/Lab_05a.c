#define _GNU_SOURCE
#include "lab05_common.h"

int main(void)
{
    cpu_set_t set;
    char text[128];
    int ncpu;

    CPU_ZERO(&set);
    if (sched_getaffinity(0, sizeof set, &set) != 0)
    {
        perror("sched_getaffinity");
        return 1;
    }

    ncpu = CPU_COUNT(&set);
    lab05_mask_text(&set, lab05_ncpu(), text, sizeof text);

    printf("Идентификатор процесса: %d\n", (int)getpid());
    printf("Идентификатор потока: %d\n", lab05_tid());
    printf("Уровень любезности процесса (nice): %d\n", lab05_nice((int)getpid()));
    printf("Уровень любезности потока (nice): %d\n", lab05_nice(lab05_tid()));
    printf("Приведённый приоритет потока: %d\n", lab05_prio(lab05_nice(lab05_tid())));
    printf("Маска родственности процесса: %s\n", text);
    printf("Количество процессоров, доступных процессу: %d\n", ncpu);
    printf("Номер процессора, назначенного потоку: %d\n", lab05_cpu());
    return 0;
}
