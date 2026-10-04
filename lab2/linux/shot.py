#!/usr/bin/env python3
"""Снимок экрана через DBus-интерфейс KWin ScreenShot2 (Wayland, без spectacle).

Использование: shot.py <выходной_файл.png>
Механизм: создаётся pipe, write-end передаётся в KWin через UnixFDList,
данные читаются из read-end до получения маркера конца файла.
"""
import os
import sys
import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shot.png"

r_fd, w_fd = os.pipe()
ufd = Gio.UnixFileDescriptor.new(w_fd)
fdlist = Gio.UnixFDList.new()
fdlist.append(ufd)

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
proxy = Gio.DBusProxy.new_sync(
    bus,
    Gio.DBusProxyFlags.NONE,
    None,
    "org.kde.KWin",
    "/org/kde/KWin/ScreenShot2",
    "org.kde.KWin.ScreenShot2",
    None,
)

# CaptureScreen(QString name, a{sv} options, h fd)
proxy.call_with_unix_fd_list_sync(
    "CaptureScreen",
    GLib.Variant("(sa{sv}h)", (OUT, {}, 1)),
    GLib.VariantType("(a{sv})"),
    Gio.DBusCallFlags.NONE,
    -1,
    None,
    fdlist,
)

os.close(w_fd)
data = b""
with os.fdopen(r_fd, "rb") as f:
    while True:
        chunk = f.read(65536)
        if not chunk:
            break
        data += chunk

if data:
    with open(OUT, "wb") as f:
        f.write(data)
    print(f"OK {len(data)} байт -> {OUT}")
else:
    print("ПУСТО — данные не пришли")
    sys.exit(1)