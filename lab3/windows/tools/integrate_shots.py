#!/usr/bin/env python3
"""Приём скринов ЛР3 с Windows-машины в репозиторий.

Забирает 7 целевых кадров из C:\\lab3_sync\\shots, проверяет их и раскладывает
в lab3/windows/скрины/уровень_*/ под финальными именами.

По умолчанию — холостой прогон (ничего не копирует). С --apply — копирует.

    python3 integrate_shots.py            # что уже готово, что ждём
    python3 integrate_shots.py --apply    # забрать и разложить
"""

import argparse
import os
import struct
import subprocess
import sys

HOST = "User-6d4ec851@192.168.31.23"
REMOTE_DIR = "C:/lab3_sync/shots"
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS_ROOT = os.path.normpath(os.path.join(HERE, "..", "скрины"))

# (путь в репозитории относительно скрины/, имя файла на Windows)
TARGETS = [
    ("уровень_4-5/task09_cmd.png", "task09_cmd.png"),
    ("уровень_4-5/task10_taskmgr.png", "task10_taskmgr.png"),
    ("уровень_4-5/task11_three_proc.png", "task11_three_proc.png"),
    ("уровень_4-5/task15_procexp_pipe.png", "task15_procexp_pipe.png"),
    ("уровень_4-5/task16_procexp_handles.png", "task16_procexp_handles.png"),
    ("уровень_7-8/task15_procexp_pipe.png", "task15_procexp_pipe.png"),
    ("уровень_7-8/task16_procexp_handles.png", "task16_procexp_handles.png"),
]

MIN_BYTES = 100_000   # меньше — значит плейсхолдер или обрезок
MIN_WIDTH = 2000      # ниже — кадр не дотянут до нормы


def png_size(path):
    """Ширина/высота из IHDR. Возвращает (w, h) или None, если это не PNG."""
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def ssh_reachable():
    r = subprocess.run(
        ["nc", "-z", "-G", "3", HOST.split("@")[1], "22"],
        capture_output=True,
    )
    return r.returncode == 0


def pull(remote_name, local_path):
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    r = subprocess.run(
        ["scp", "-o", "BatchMode=yes", "-q",
         f"{HOST}:{REMOTE_DIR}/{remote_name}", local_path],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        return False, (r.stderr or "").strip()[:200]
    return True, ""


def check(local_path):
    """Возвращает (ok, сообщение)."""
    if not os.path.exists(local_path):
        return False, "нет файла"
    size = os.path.getsize(local_path)
    dims = png_size(local_path)
    if dims is None:
        return False, "не PNG"
    w, h = dims
    if size < MIN_BYTES:
        return False, f"{size} байт < {MIN_BYTES} (плейсхолдер?)"
    if w < MIN_WIDTH:
        return False, f"ширина {w} < {MIN_WIDTH}"
    return True, f"{size} байт, {w}×{h}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="реально забирать и раскладывать")
    args = ap.parse_args()

    if not ssh_reachable():
        print(f"ВМ недоступна: {HOST}:22 не отвечает. Включи Windows и попробуй снова.")
        return 2

    todo, done, bad = [], [], []
    for rel, remote in TARGETS:
        local = os.path.join(SHOTS_ROOT, rel)
        if args.apply:
            ok, err = pull(remote, local)
            if not ok:
                bad.append((rel, f"scp: {err}"))
                continue
        if os.path.exists(local):
            ok, msg = check(local)
            (done if ok else bad).append((rel, msg))
        else:
            todo.append(rel)

    print(f"готово: {len(done)} | не готово: {len(todo)} | брак: {len(bad)}")
    for rel, msg in done:
        print(f"  OK   {rel} — {msg}")
    for rel in todo:
        print(f"  ждём {rel}")
    for rel, msg in bad:
        print(f"  БРАК {rel} — {msg}")

    return 0 if len(done) == len(TARGETS) and not bad else 1


if __name__ == "__main__":
    sys.exit(main())
