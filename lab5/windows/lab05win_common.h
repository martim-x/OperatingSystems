#ifndef LAB05WIN_COMMON_H
#define LAB05WIN_COMMON_H

#define _CRT_SECURE_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LAB05_ITERATIONS 1000000
#define LAB05_REPORT_EVERY 1000
#define LAB05_DELAY_MS 50
#define LAB05_FINAL_PAUSE_MS 1500

const char *lab_class_name(DWORD code)
{
    switch (code) {
    case IDLE_PRIORITY_CLASS: return "Idle";
    case BELOW_NORMAL_PRIORITY_CLASS: return "BelowNormal";
    case NORMAL_PRIORITY_CLASS: return "Normal";
    case ABOVE_NORMAL_PRIORITY_CLASS: return "AboveNormal";
    case HIGH_PRIORITY_CLASS: return "High";
    case REALTIME_PRIORITY_CLASS: return "RealTime";
    default: return "Unknown";
    }
}

int lab_class_base(DWORD code)
{
    switch (code) {
    case IDLE_PRIORITY_CLASS: return 4;
    case BELOW_NORMAL_PRIORITY_CLASS: return 6;
    case NORMAL_PRIORITY_CLASS: return 8;
    case ABOVE_NORMAL_PRIORITY_CLASS: return 10;
    case HIGH_PRIORITY_CLASS: return 13;
    case REALTIME_PRIORITY_CLASS: return 24;
    default: return 8;
    }
}

DWORD lab_class_from_name(const char *name)
{
    if (_stricmp(name, "Idle") == 0) return IDLE_PRIORITY_CLASS;
    if (_stricmp(name, "BelowNormal") == 0) return BELOW_NORMAL_PRIORITY_CLASS;
    if (_stricmp(name, "Normal") == 0) return NORMAL_PRIORITY_CLASS;
    if (_stricmp(name, "AboveNormal") == 0) return ABOVE_NORMAL_PRIORITY_CLASS;
    if (_stricmp(name, "High") == 0) return HIGH_PRIORITY_CLASS;
    if (_stricmp(name, "RealTime") == 0) return REALTIME_PRIORITY_CLASS;
    return 0;
}

const char *lab_thread_name(int value)
{
    switch (value) {
    case THREAD_PRIORITY_IDLE: return "Idle";
    case THREAD_PRIORITY_LOWEST: return "Lowest";
    case THREAD_PRIORITY_BELOW_NORMAL: return "BelowNormal";
    case THREAD_PRIORITY_NORMAL: return "Normal";
    case THREAD_PRIORITY_ABOVE_NORMAL: return "AboveNormal";
    case THREAD_PRIORITY_HIGHEST: return "Highest";
    case THREAD_PRIORITY_TIME_CRITICAL: return "TimeCritical";
    default: return "Normal";
    }
}

int lab_thread_from_name(const char *name)
{
    if (_stricmp(name, "Idle") == 0) return THREAD_PRIORITY_IDLE;
    if (_stricmp(name, "Lowest") == 0) return THREAD_PRIORITY_LOWEST;
    if (_stricmp(name, "BelowNormal") == 0) return THREAD_PRIORITY_BELOW_NORMAL;
    if (_stricmp(name, "Normal") == 0) return THREAD_PRIORITY_NORMAL;
    if (_stricmp(name, "AboveNormal") == 0) return THREAD_PRIORITY_ABOVE_NORMAL;
    if (_stricmp(name, "Highest") == 0) return THREAD_PRIORITY_HIGHEST;
    if (_stricmp(name, "TimeCritical") == 0) return THREAD_PRIORITY_TIME_CRITICAL;
    return THREAD_PRIORITY_ERROR_RETURN;
}

int lab_priority_value(HANDLE process, HANDLE thread)
{
    int value = lab_class_base(GetPriorityClass(process)) + GetThreadPriority(thread);
    if (value < 0) value = 0;
    if (value > 31) value = 31;
    return value;
}

DWORD_PTR lab_parse_mask(const char *text)
{
    const char *tail;
    if (text == NULL || text[0] == '\0') return 0;
    tail = text;
    if (text[0] == '0' && (text[1] == 'x' || text[1] == 'X')) {
        return (DWORD_PTR)_strtoui64(text + 2, NULL, 16);
    }
    if (text[0] == '0' && (text[1] == 'b' || text[1] == 'B')) {
        return (DWORD_PTR)_strtoui64(text + 2, NULL, 2);
    }
    return (DWORD_PTR)_strtoui64(tail, NULL, 10);
}

DWORD_PTR lab_current_mask(void)
{
    DWORD_PTR processMask = 0;
    DWORD_PTR systemMask = 0;
    if (!GetProcessAffinityMask(GetCurrentProcess(), &processMask, &systemMask)) return 1;
    return processMask;
}

int lab_cpu_count(void)
{
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    return (int)info.dwNumberOfProcessors;
}

int lab_popcount(DWORD_PTR mask)
{
    int count = 0;
    while (mask) {
        mask &= (mask - 1);
        count++;
    }
    return count;
}

void lab_mask_to_binary(DWORD_PTR mask, int cpus, char *out, int size)
{
    int index;
    int bits = cpus;
    if (out == NULL || size <= 1) return;
    if (bits < 1) bits = 1;
    if (bits > size - 1) bits = size - 1;
    if (bits > (int)(8 * sizeof(DWORD_PTR))) bits = (int)(8 * sizeof(DWORD_PTR));
    for (index = 0; index < bits; index++) {
        out[index] = (char)(((mask >> (bits - 1 - index)) & (DWORD_PTR)1) ? '1' : '0');
    }
    out[bits] = '\0';
}

void lab_active_delay(DWORD milliseconds)
{
    LARGE_INTEGER frequency;
    LARGE_INTEGER start;
    LARGE_INTEGER now;
    double target;
    if (!QueryPerformanceFrequency(&frequency)) {
        Sleep(milliseconds);
        return;
    }
    QueryPerformanceCounter(&start);
    target = (double)milliseconds / 1000.0 * (double)frequency.QuadPart;
    do {
        QueryPerformanceCounter(&now);
    } while ((double)(now.QuadPart - start.QuadPart) < target);
}

void lab_worker_body(void)
{
    HANDLE process = GetCurrentProcess();
    HANDLE thread = GetCurrentThread();
    DWORD pid = GetCurrentProcessId();
    DWORD tid = GetCurrentThreadId();
    int iteration;

    for (iteration = 1; iteration <= LAB05_ITERATIONS; iteration++) {
        if (iteration % LAB05_REPORT_EVERY == 0) {
            lab_active_delay(LAB05_DELAY_MS);
            printf("%7d | %6lu | %6lu | %-12s | %-12s | %3d | %2lu\n",
                   iteration,
                   (unsigned long)pid,
                   (unsigned long)tid,
                   lab_class_name(GetPriorityClass(process)),
                   lab_thread_name(GetThreadPriority(thread)),
                   lab_priority_value(process, thread),
                   (unsigned long)GetCurrentProcessorNumber());
            fflush(stdout);
        }
    }

    printf("Итераций: %d, PID %lu, TID %lu, время с запуска (clock): %.3f с\n",
           LAB05_ITERATIONS,
           (unsigned long)pid,
           (unsigned long)tid,
           (double)clock() / (double)CLOCKS_PER_SEC);
    fflush(stdout);
}

#endif
