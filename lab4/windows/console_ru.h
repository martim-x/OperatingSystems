#ifndef CONSOLE_RU_H
#define CONSOLE_RU_H

#include <windows.h>
#include <stdio.h>
#include <stdarg.h>

static const char *utf8_to_oem(const char *src, char *out, int cap)
{
    int wlen = MultiByteToWideChar(CP_UTF8, 0, src, -1, NULL, 0);
    if (wlen <= 0 || wlen > 4096) {
        return src;
    }
    wchar_t wbuf[4096];
    MultiByteToWideChar(CP_UTF8, 0, src, -1, wbuf, wlen);
    int olen = WideCharToMultiByte(866, 0, wbuf, -1, out, cap, NULL, NULL);
    if (olen <= 0) {
        return src;
    }
    return out;
}

static int rprintf(const char *fmt, ...)
{
    char tmp[4096];
    char conv[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    fputs(utf8_to_oem(tmp, conv, sizeof(conv)), stdout);
    fflush(stdout);
    return 0;
}

static int rfprintf(FILE *stream, const char *fmt, ...)
{
    char tmp[4096];
    char conv[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    fputs(utf8_to_oem(tmp, conv, sizeof(conv)), stream);
    fflush(stream);
    return 0;
}

#define printf  rprintf
#define fprintf rfprintf

#endif
