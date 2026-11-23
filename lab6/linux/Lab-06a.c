#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <stdio.h>
#include <string.h>

#include "lab06_common.h"

typedef struct
{
    const char *name;
    pthread_mutex_t *mutex;
} worker_args;

static char worker_failed;

static void *run_worker(void *opaque)
{
    worker_args *args = opaque;

    for (int iteration = 1; iteration <= LAB06_ITERATIONS; ++iteration)
    {
        if (iteration == LAB06_FIRST_EXCLUSIVE)
        {
            int rc = pthread_mutex_lock(args->mutex);
            if (rc != 0)
            {
                fprintf(stderr, "pthread_mutex_lock: %s\n", strerror(rc));
                return &worker_failed;
            }
            lab06_print_boundary("ENTER", args->name, iteration);
        }

        lab06_print_iteration(args->name, iteration);
        if (lab06_delay() != 0)
        {
            if (iteration >= LAB06_FIRST_EXCLUSIVE && iteration <= LAB06_LAST_EXCLUSIVE)
                (void)pthread_mutex_unlock(args->mutex);
            return &worker_failed;
        }

        if (iteration == LAB06_LAST_EXCLUSIVE)
        {
            lab06_print_boundary("LEAVE", args->name, iteration);
            int rc = pthread_mutex_unlock(args->mutex);
            if (rc != 0)
            {
                fprintf(stderr, "pthread_mutex_unlock: %s\n", strerror(rc));
                return &worker_failed;
            }
        }
    }
    return NULL;
}

static int join_worker(pthread_t thread, const char *name)
{
    void *result = NULL;
    int rc = pthread_join(thread, &result);
    if (rc != 0)
    {
        fprintf(stderr, "pthread_join %s: %s\n", name, strerror(rc));
        return -1;
    }
    if (result != NULL)
    {
        fprintf(stderr, "worker %s failed\n", name);
        return -1;
    }
    return 0;
}

int main(void)
{
    pthread_mutex_t mutex;
    int rc = pthread_mutex_init(&mutex, NULL);
    if (rc != 0)
    {
        fprintf(stderr, "pthread_mutex_init: %s\n", strerror(rc));
        return 1;
    }

    worker_args args_a = {"A", &mutex};
    worker_args args_b = {"B", &mutex};
    worker_args args_main = {"main", &mutex};
    pthread_t thread_a;
    pthread_t thread_b;

    rc = pthread_create(&thread_a, NULL, run_worker, &args_a);
    if (rc != 0)
    {
        fprintf(stderr, "pthread_create A: %s\n", strerror(rc));
        (void)pthread_mutex_destroy(&mutex);
        return 1;
    }

    rc = pthread_create(&thread_b, NULL, run_worker, &args_b);
    if (rc != 0)
    {
        fprintf(stderr, "pthread_create B: %s\n", strerror(rc));
        int status = join_worker(thread_a, "A");
        (void)pthread_mutex_destroy(&mutex);
        return status == 0 ? 1 : status;
    }

    int status = run_worker(&args_main) == NULL ? 0 : 1;
    if (join_worker(thread_a, "A") != 0)
        status = 1;
    if (join_worker(thread_b, "B") != 0)
        status = 1;

    rc = pthread_mutex_destroy(&mutex);
    if (rc != 0)
    {
        fprintf(stderr, "pthread_mutex_destroy: %s\n", strerror(rc));
        status = 1;
    }
    return status;
}
