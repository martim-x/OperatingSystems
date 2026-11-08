#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#include "lab04_common.h"

#define CHILD1_ITERS 50
#define CHILD2_ITERS 125
#define MAIN_ITERS 100

static void *child1(void *arg)
{
    (void)arg;
    lab04x(CHILD1_ITERS);
    return NULL;
}

static void *child2(void *arg)
{
    (void)arg;
    lab04x(CHILD2_ITERS);
    return NULL;
}

int main(void)
{
    pthread_t t1, t2;
    int rc;

    rc = pthread_create(&t1, NULL, child1, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_create 1: %d\n", rc);
        return 1;
    }

    rc = pthread_create(&t2, NULL, child2, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_create 2: %d\n", rc);
        pthread_join(t1, NULL);
        return 1;
    }

    lab04x(MAIN_ITERS);

    rc = pthread_join(t1, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_join 1: %d\n", rc);
        return 1;
    }

    rc = pthread_join(t2, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "Ошибка pthread_join 2: %d\n", rc);
        return 1;
    }

    printf("Все потоки завершены.\n");
    return 0;
}
