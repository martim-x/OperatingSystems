/*
 * console_ru.h — корректный вывод кириллицы в консоль cmd (Windows).
 *
 * Исходные файлы хранятся в UTF-8 и собираются с ключом /utf-8, поэтому
 * строковые литералы в программе — UTF-8. Консоль cmd работает в OEM-кодировке
 * (866), поэтому весь вывод перекодируется из UTF-8 в 866 через
 * MultiByteToWideChar + WideCharToMultiByte.
 *
 * Подключается после <stdio.h>. Заменяет printf/fprintf на варианты
 * rprintf/rfprintf, которые перекодируют уже сформированную строку вывода.
 * ASCII-данные (пути, идентификаторы, числа) при перекодировке не меняются.
 */
#ifndef CONSOLE_RU_H
#define CONSOLE_RU_H

#include <windows.h>
#include <stdio.h>
#include <stdarg.h>

/* UTF-8 -> OEM-кодировка консоли (866); буферы чередуются между вызовами */
static const char *utf8_to_oem(const char *src)
{
    static char buf[4][4096];
    static int idx = 0;
    char *out = buf[idx];
    idx = (idx + 1) & 3;

    int wlen = MultiByteToWideChar(CP_UTF8, 0, src, -1, NULL, 0);
    if (wlen <= 0 || wlen > 4096) {
        return src; /* на случай неожиданных данных */
    }
    wchar_t wbuf[4096];
    MultiByteToWideChar(CP_UTF8, 0, src, -1, wbuf, wlen);
    int olen = WideCharToMultiByte(866, 0, wbuf, -1, out, 4096, NULL, NULL);
    if (olen <= 0) {
        return src;
    }
    return out;
}

static int rprintf(const char *fmt, ...)
{
    char tmp[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    fputs(utf8_to_oem(tmp), stdout);
    fflush(stdout);
    return 0;
}

static int rfprintf(FILE *stream, const char *fmt, ...)
{
    char tmp[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    fputs(utf8_to_oem(tmp), stream);
    fflush(stream);
    return 0;
}

#define printf  rprintf
#define fprintf rfprintf

#endif /* CONSOLE_RU_H */
