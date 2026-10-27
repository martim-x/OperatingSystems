#ifndef LAB04_COMMON_H
#define LAB04_COMMON_H

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define ITER_DELAY_MS 400
#define USER_NAME "User-6d4ec851"

static const char *FIO_CHARS[] = {
    "\xd0\x9c", "\xd0\xb0", "\xd1\x80", "\xd1\x83", "\xd1\x81", "\xd0\xba", "\xd0\xbe",
    "\xd0\xa2", "\xd0\xb8", "\xd0\xbc", "\xd0\xbe", "\xd1\x84", "\xd0\xb5", "\xd0\xb9"
};
#define FIO_LEN ((int)(sizeof(FIO_CHARS) / sizeof(FIO_CHARS[0])))
#define USER_LEN ((int)(sizeof(USER_NAME) - 1))

static int g_current_iter[256];
static CRITICAL_SECTION g_iter_lock;

static void lab04_init(void)
{
    InitializeCriticalSection(&g_iter_lock);
    memset(g_current_iter, 0, sizeof(g_current_iter));
}

static void lab04_done(void)
{
    DeleteCriticalSection(&g_iter_lock);
}

static void lab04x(int iterations)
{
    DWORD pid = GetCurrentProcessId();
    DWORD tid = GetCurrentThreadId();

    for (int i = 1; i <= iterations; i++)
    {
        char user_sym = USER_NAME[(i - 1) % USER_LEN];
        const char *fio_sym = FIO_CHARS[(i - 1) % FIO_LEN];

        printf("%lu - %lu - %d - %c - %s\n", (unsigned long)pid, (unsigned long)tid, i, user_sym, fio_sym);
        fflush(stdout);

        EnterCriticalSection(&g_iter_lock);
        g_current_iter[tid & 0xFF] = i;
        LeaveCriticalSection(&g_iter_lock);

        Sleep(ITER_DELAY_MS);
    }
}

static int lab04x_iteration(DWORD tid)
{
    int v;
    EnterCriticalSection(&g_iter_lock);
    v = g_current_iter[tid & 0xFF];
    LeaveCriticalSection(&g_iter_lock);
    return v;
}

#endif
