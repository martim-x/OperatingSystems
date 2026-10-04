#!/usr/bin/env python3
"""lab2_capture.py — прогон лабораторной с автоматическими снимками окна ВМ.

Цикл для каждой команды:
    1. команда уходит в очередь драйвера в ВМ и выполняется в видимой консоли
    2. ждём, пока кадр отрисован
    3. снимаем ОКНО VMware Fusion средствами мака (screencapture -l<id>)
    4. отдаём драйверу сигнал «можно продолжать» и берём следующую команду
Снимок кладётся в ~/.hermes/cache/lab2_shots/ с именем <NN>_<задача>.png
"""
import os
import subprocess
import sys
import time

VM = "User-6d4ec851@192.168.78.154"
SYNC = f"{os.path.expanduser('~')}/lab2_sync"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.expanduser("~/.hermes/cache/lab2_shots")
os.makedirs(OUT, exist_ok=True)

WINID_CACHE = "/tmp/lab2_winid.txt"


def sh(cmd, timeout=60, check=False):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, check=check)


def win_id():
    """window id окна виртуальной машины в VMware Fusion (с кешем)."""
    if os.path.exists(WINID_CACHE):
        with open(WINID_CACHE) as f:
            v = f.read().strip()
            if v:
                return v
    r = sh(f"python3 {HERE}/winid.py ''", timeout=30)
    if os.environ.get("LAB2_DEBUG"):
        print("rc=", r.returncode, "err=", r.stderr[:300], "out=", r.stdout[:300])
    for line in r.stdout.splitlines():
        if "Windows 11 64-bit Arm" not in line:
            continue
        parts = line.split()
        if parts and parts[0].isdigit() and int(parts[0]) > 0:
            wid = parts[0]
            with open(WINID_CACHE, "w") as f:
                f.write(wid)
            return wid
    raise SystemExit("не найдено окно ВМ в VMware Fusion")


def run_cmd(num, slug, cmd, wid):
    n = f"{num:02d}"
    name = f"{n}_{slug}"
    # 1+2: отпускаем драйвер (touch go), снимаем прошлый сигнал, кладём команду
    sh(f"ssh -o BatchMode=yes {VM} 'touch {SYNC}/go; sleep 1; rm -f {SYNC}/go; "
       f"rm -f {SYNC}/done/{n}.ready; "
       f"printf %s {sh_quote(cmd)} > {SYNC}/queue/{n}_cmd.cmd'")
    for _ in range(40):
        r = sh(f"ssh -o BatchMode=yes {VM} 'test -f {SYNC}/done/{n}.ready'", timeout=30)
        if r.returncode == 0:
            break
        time.sleep(0.4)
    else:
        return False, "команда не выполнена"
    time.sleep(0.8)

    # 3: снимок окна средствами мака
    path = f"{OUT}/{name}.png"
    sh(f"screencapture -x -o -l{wid} {sh_quote(path)}", timeout=60)
    if not os.path.exists(path) or os.path.getsize(path) < 10000:
        return False, "снимок не создан"
    return True, f"{os.path.getsize(path)//1024} КБ"


def sh_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: lab2_capture.py <файл_команд>")
    wid = win_id()
    print(f"окно ВМ: id={wid}, снимки -> {OUT}\n")

    ok = fail = 0
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                print(f"  ПРОПУЩЕНО (формат): {line[:60]}")
                continue
            num, slug, cmd = parts[0], parts[1], parts[2]
            good, info = run_cmd(int(num), slug, cmd, wid)
            if good:
                ok += 1
                print(f"  [{num:>2}] {slug:<20} ок  {info}")
            else:
                fail += 1
                print(f"  [{num:>2}] {slug:<20} ОШИБКА: {info}")
            # 4: сигнал драйверу
            sh(f"ssh -o BatchMode=yes {VM} 'touch {SYNC}/go'")
            time.sleep(0.4)

    print(f"\nГотово: {ok} снимков, ошибок {fail}")


if __name__ == "__main__":
    main()
