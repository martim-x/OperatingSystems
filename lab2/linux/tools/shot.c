/* shot.c — снимок экрана через DBus-интерфейс KWin ScreenShot2 (Wayland).
 *
 * Механизм: создаётся pipe, его write-end передаётся в KWin методом
 * CaptureScreen через GUnixFDList; PNG-данные читаются из read-end.
 *
 * Сборка: gcc -O2 -o shot shot.c $(pkg-config --cflags --libs gio-2.0 gio-unix-2.0)
 * Использование: ./shot out.png
 */
#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        g_printerr("usage: %s <out.png>\n", argv[0]);
        return 2;
    }
    const char *out = argv[1];

    /* 1. pipe: gp[0] читаем, gp[1] отдаём в KWin */
    int gp[2];
    if (pipe(gp) != 0) { perror("pipe"); return 1; }

    /* 2. шина сессии */
    GError *err = NULL;
    GDBusConnection *conn = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!conn) {
        g_printerr("bus: %s\n", err ? err->message : "нет ошибки");
        return 1;
    }

    /* 3. GUnixFDList с одним дескриптором */
    GUnixFDList *fdl = g_unix_fd_list_new();
    if (g_unix_fd_list_append(fdl, gp[1], &err) < 0) {
        g_printerr("fdlist: %s\n", err ? err->message : "нет ошибки");
        return 1;
    }

    /* 4. CaptureScreen(QString name, a{sv} options, h fd) */
    GVariant *body = g_variant_new(
        "(s@a{sv}h)",
        out,
        g_variant_new_array(G_VARIANT_TYPE("{sv}"), NULL, 0),
        0);

    GVariant *reply = g_dbus_connection_call_with_unix_fd_list_sync(
        conn,
        "org.kde.KWin",
        "/org/kde/KWin/ScreenShot2",
        "org.kde.KWin.ScreenShot2",
        "CaptureScreen",
        body,
        G_VARIANT_TYPE("(a{sv})"),
        G_DBUS_CALL_FLAGS_NONE,
        -1,
        fdl,
        NULL,
        NULL,
        &err);

    g_object_unref(fdl);
    close(gp[1]);

    if (!reply) {
        g_printerr("вызов не удался: %s\n", err ? err->message : "нет ошибки");
        close(gp[0]);
        return 1;
    }
    g_object_unref(reply);

    /* 5. читаем PNG до EOF */
    FILE *f = fopen(out, "wb");
    if (!f) { perror("fopen"); close(gp[0]); return 1; }

    long total = 0;
    char buf[65536];
    ssize_t n;
    while ((n = read(gp[0], buf, sizeof buf)) > 0) {
        if (fwrite(buf, 1, (size_t)n, f) != (size_t)n) break;
        total += n;
    }
    fclose(f);
    close(gp[0]);

    g_print("OK %ld байт -> %s\n", total, out);
    return total > 0 ? 0 : 1;
}