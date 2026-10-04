#!/usr/bin/env python3
"""push_cmds.py — оператор прогона ЛР2 на Arch-машине.

Кладёт команды в очередь драйвера (~/lab2_sync/queue), ждёт метку
готовности (~/lab2_sync/done/NN.done) и забирает снимки экрана на мак.

Формат списка команд — TSV: <номер>\t<имя>\t<команда>
Опциональный ввод для интерактивных заданий — файл <имя>.in рядом
(одна или несколько строк), подставляется в очередь как NN_<имя>.in.

Использование:
    python3 push_cmds.py cmds_4-5.tsv [--reset]
"""
import os
import subprocess
import sys
import time

VM = "User-6d4ec851@192.168.78.154"
SYNC = "/home/User-6d4ec851/lab2_sync"
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "скрины")
TEXT = os.path.join(HERE, "выводы")
TIMEOUT = 90  # секунд на одну команду

# Снимки раскладываются по уровням, иначе имена 01_cd_abs и 01_path_count
# из разных уровней сталкиваются в одной папке.
LEVEL = {"cmds_4-5.tsv": "уровень_4-5",
         "cmds_6-7.tsv": "уровень_6-7",
         "cmds_8-9.tsv": "уровень_8-9"}


def sh(cmd, timeout=60):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)


def q(v):
    return "'" + str(v).replace("'", "'\\''") + "'"


def ssh(inner, timeout=60):
    return sh(f"ssh -o BatchMode=yes -o ConnectTimeout=10 {VM} {q(inner)}", timeout=timeout)


def load(path):
    """Читает TSV, рядом ищет <имя>.in с вводом."""
    items = []
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                print(f"  ПРОПУЩЕНО (формат): {line[:70]}")
                continue
            num, slug, cmd = parts[0], parts[1], "\t".join(parts[2:])
            infile = os.path.join(os.path.dirname(path), f"{slug}.in")
            data = None
            if os.path.exists(infile):
                with open(infile) as fh:
                    data = fh.read()
            items.append((num, slug, cmd, data))
    return items


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: push_cmds.py <файл_команд.tsv> [--reset]")
    tsv = os.path.basename(sys.argv[1])
    reset = "--reset" in sys.argv

    out = os.path.join(SHOTS, LEVEL.get(tsv, "прочее"))
    text = os.path.join(TEXT, LEVEL.get(tsv, "прочее"))
    os.makedirs(out, exist_ok=True)
    os.makedirs(text, exist_ok=True)

    if reset:
        ssh(f"rm -f {SYNC}/queue/* {SYNC}/done/* {SYNC}/shots/* 2>/dev/null; true")
        print("очередь очищена\n")

    items = load(sys.argv[1])
    print(f"команд: {len(items)}, снимки -> {out}\n")

    ok = fail = 0
    for num, slug, cmd, data in items:
        n = f"{int(num):02d}"
        payload = f"rm -f {SYNC}/done/{n}.done; printf %s {q(cmd)} > {SYNC}/queue/{n}_{slug}.cmd"
        if data is not None:
            payload += f"; printf %s {q(data)} > {SYNC}/queue/{n}_{slug}.in"
        ssh(payload)

        deadline = time.time() + TIMEOUT
        ready = False
        while time.time() < deadline:
            if ssh(f"test -f {SYNC}/done/{n}.done").returncode == 0:
                ready = True
                break
            time.sleep(0.5)
        if not ready:
            fail += 1
            print(f"  [{n}] {slug:<22} ТАЙМАУТ")
            ssh(f"rm -f {SYNC}/queue/{n}_{slug}.cmd {SYNC}/queue/{n}_{slug}.in")
            continue

        # забираем снимок и текстовый вывод на мак.
        # scp с двумя источниками требует общий каталог-приёмник, поэтому
        # снимок и текст тянем двумя вызовами в разные папки.
        dst = os.path.join(out, f"{n}_{slug}.png")
        txt = os.path.join(text, f"{n}_{slug}.txt")
        r1 = sh(f"scp -q {VM}:{SYNC}/shots/{n}_{slug}.png {q(dst)}", timeout=90)
        r2 = sh(f"scp -q {VM}:{SYNC}/done/{n}.txt {q(txt)}", timeout=90)
        r = r1 if r1.returncode else r2
        if r1.returncode == 0 and os.path.exists(dst) and os.path.getsize(dst) > 20000:
            ok += 1
            print(f"  [{n}] {slug:<22} ок  {os.path.getsize(dst)//1024} КБ")
        else:
            fail += 1
            print(f"  [{n}] {slug:<22} СНИМОК НЕ ПРИШЁЛ")

    print(f"\nГотово: {ok} снимков, ошибок {fail}")


if __name__ == "__main__":
    main()