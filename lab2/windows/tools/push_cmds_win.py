#!/usr/bin/env python3
"""push_cmds_win.py - оператор прогона ЛР2 на Windows-машине.

Кладёт команды в очередь драйвера C:\\lab2_sync\\queue, ждёт метку
готовности C:\\lab2_sync\\done\\NN.done и забирает снимки экрана.

    python3 push_cmds_win.py cmds_4-5.tsv [--reset]

Windows отвечает только на cmd-скрипты (дефолтный шелл не исполняет `;`),
поэтому подготовка окружения идёт через scp .cmd + `cmd /c file.cmd`.
"""
import os, sys, time, shlex, subprocess

VM = os.environ.get("LAB_WIN", "User-6d4ec851@172.20.10.3")
SYNC = r"C:\lab2_sync"
QUEUE = r"C:\lab2_sync\queue"
DONE = r"C:\lab2_sync\done"
SHOTS = r"C:\lab2_sync\shots"

# Пути для scp/ssh. Обратный слэш там не разделитель пути, а буква имени:
# scp кладёт файл C:/lab2_sync/queue\00.cmd прямо в C:\lab2_sync как файл
# с обратным слэшем в имени, сообщая об успехе. Поэтому только прямые.
Q_DIR = "C:/lab2_sync/queue"
D_DIR = "C:/lab2_sync/done"
S_DIR = "C:/lab2_sync/shots"
HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.path.dirname(HERE)  # корень каталога лабы (скрины/выводы/сценарии)
TIMEOUT = 120  # секунд на команду

LEVELS = {
    "cmds_4-5.tsv": "уровень_4-5",
    "cmds_6-7.tsv": "уровень_6-7",
    "cmds_8-9.tsv": "уровень_8-9",
}

def sh(cmd, timeout=120, encoding="utf-8"):
    """Запуск команды. Вывод Windows приходит в однобайтовой копировке
    консоли (cp866), поэтому для удалённых вызовов decoding=cp866 с
    заменой нечитаемых байтов - иначе subprocess падает на UnicodeDecodeError."""
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          encoding=encoding, errors="replace", timeout=timeout)

def remote(script, timeout=180):
    """Выполняет .cmd на Windows: кладёт файл в C:/Windows/Temp и зовёт cmd /c."""
    tmp = "/tmp/_win_tmp.cmd"
    # chcp 65001 здесь не нужен и вреден: скрипт запускается в сессии SSH,
    # где нет интерактивной консоли, а переключение страницы портит вывод.
    with open(tmp, "w", encoding="ascii", errors="replace", newline="") as f:
        f.write("@echo off\r\n")
        f.write(script.replace("\r\n", "\n").replace("\n", "\r\n"))
    r = sh(f"scp -q {tmp} {VM}:C:/Windows/Temp/_run.cmd",
           timeout=timeout, encoding="cp866")
    if r.returncode != 0:
        return 1, f"scp failed: {r.stderr[:200]}"
    r = sh(f'ssh -o BatchMode=yes -o ConnectTimeout=15 {VM} "cmd /c C:\\\\Windows\\\\Temp\\\\_run.cmd" 2>&1',
           timeout=timeout, encoding="cp866")
    return r.returncode, r.stdout

def q(s):
    return shlex.quote(s) if s else "''"

def load(tsv):
    """Читает tsv: номер, имя, команда, [файл с вводом]."""
    items = []
    for line in open(os.path.join(LAB, tsv), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        num, slug, cmd = parts[0].strip(), parts[1].strip(), parts[2].strip()
        infile = None
        if len(parts) >= 4 and parts[3].strip():
            # 4-й столбец: имя файла ввода. Для *_in.tsv берётся одноимённый
            # .in в кодировке консоли - сам tsv лежит в UTF-8.
            named = parts[3].strip()
            cand = os.path.join(LAB, named)
            if os.path.exists(cand):
                infile = cand
            else:
                cand = os.path.join(HERE, named.replace(".tsv", ".in"))
                if os.path.exists(cand):
                    infile = cand
        elif os.path.exists(os.path.join(LAB, f"{slug}.in")):
            infile = os.path.join(LAB, f"{slug}.in")
        items.append((num, slug, cmd, infile))
    return items

def push_cmd(num, slug, cmd):
    """Кладёт .cmd команды прямо в очередь драйвера, в кодировке cp866:
    cmd читает .cmd в однобайтовой копировке консоли, поэтому русский текст
    в командах иначе превращается в мусор."""
    tmp = f"/tmp/_q_{num}_{slug}.cmd"
    with open(tmp, "w", encoding="cp866", errors="replace", newline="\r\n") as f:
        f.write(cmd + "\n")
    dst = f"{Q_DIR}/{num}_{slug}.cmd"
    return sh(f"scp -q {shlex.quote(tmp)} {VM}:{dst}", timeout=120, encoding="cp866").returncode == 0

def push_in(num, slug, path):
    """Кладёт файл с вводимыми данными в очередь, в cp866 (кодировка консоли)."""
    tmp = f"/tmp/_q_{num}_{slug}.in"
    raw = open(path, "rb").read()
    text = None
    for enc in ("utf-8", "cp1251", "cp866"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        text = raw.decode("cp1251", "replace")
    with open(tmp, "w", encoding="cp866", errors="replace", newline="\r\n") as f:
        f.write(text)
    dst = f"{Q_DIR}/{num}_{slug}.in"
    return sh(f"scp -q {shlex.quote(tmp)} {VM}:{dst}", timeout=120, encoding="cp866").returncode == 0

def sync_scripts():
    """Заливает на машину скрипты задания, конвертируя .bat в кодировку консоли.

    Репозиторий хранит .bat в UTF-8, а cmd читает файл в OEM-кодовой странице:
    без конвертации mkdir "OS2\\task_01i\\Русский" создаёт каталог с
    испорченным именем, и cd в него падает с "path not found"."""
    for name in ("prep.bat", "bat_01.bat", "bat_02.bat", "bat_03.bat",
                 "bat_04.bat", "bat_05.bat"):
        src = os.path.join(HERE, name)
        if not os.path.exists(src):
            continue
        raw = open(src, "rb").read()
        text = None
        for enc in ("utf-8", "cp1251", "cp866"):
            try:
                text = raw.decode(enc)
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            text = raw.decode("cp1251", "replace")
        tmp = f"/tmp/cp866_{name}"
        with open(tmp, "w", encoding="cp866", errors="replace", newline="\r\n") as f:
            f.write(text)
        sh(f"scp -q {shlex.quote(tmp)} {VM}:C:/lab2_sync/{name}", timeout=120, encoding="cp866")

    # .ps1 с кириллицей должны уходить с BOM и CRLF: PowerShell 5.1 без BOM
    # читает файл как ANSI (cp1251) и рвёт парсер на русских словах.
    for name in ("run_lab.ps1", "path_count.ps1", "tree_sizes.ps1",
                 "top5.ps1", "calc.ps1", "tempconv.ps1"):
        src = os.path.join(HERE, name)
        if not os.path.exists(src):
            continue
        txt = open(src, "rb").read().decode("utf-8-sig").replace("\r\n", "\n")
        tmp = f"/tmp/bom_{name}"
        with open(tmp, "wb") as f:
            f.write(b"\xef\xbb\xbf" + txt.replace("\n", "\r\n").encode("utf-8"))
        sh(f"scp -q {shlex.quote(tmp)} {VM}:C:/lab2_sync/{name}", timeout=120, encoding="cp866")

    # Файлы ввода для калькулятора и конвертера лежат в репо в cp866 -
    # скрипты читают их именно в кодировке консоли.
    for name in ("calc.in", "temp.in"):
        src = os.path.join(HERE, name)
        if os.path.exists(src):
            sh(f"scp -q {shlex.quote(src)} {VM}:C:/lab2_sync/{name}", timeout=120, encoding="cp866")


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: push_cmds_win.py <tsv> [--reset]")
    tsv = os.path.basename(sys.argv[1])
    reset = "--reset" in sys.argv
    level = LEVELS.get(tsv, "прочее")
    out = os.path.join(HERE, "скрины", level)
    text_out = os.path.join(HERE, "выводы", level)
    os.makedirs(out, exist_ok=True)
    os.makedirs(text_out, exist_ok=True)

    sync_scripts()

    if reset:
        # Чистим содержимое, а не каталоги. del с маской *.* удаляет и сам
        # каталог, если он опустел: после этого scp создаёт "queue\\NN.cmd"
        # обычным файлом, драйвер очередь не видит, и прогон молча стоит.
        remote(f"del /q {QUEUE}\\*.cmd {QUEUE}\\*.in {DONE}\\*.txt "
               f"{DONE}\\*.done {SHOTS}\\*.png 2>nul")
        remote(f"if not exist {QUEUE} mkdir {QUEUE}")
        print("очередь очищена")

    items = load(tsv)
    print(f"команд: {len(items)}, снимки -> {out}\n")

    ok = fail = 0
    for num, slug, cmd, infile in items:
        n = f"{int(num):02d}"
        # сначала снимаем старую метку готовности, затем кладём команду в очередь
        remote(f"del /q {DONE}\\{n}.done 2>nul")
        # Файл с вводом кладём ПЕРЕД командой: драйвер забирает .cmd мгновенно,
        # и если .in ещё не в очереди, команда уходит без ввода и зависает.
        if infile:
            push_in(n, slug, infile)
        if not push_cmd(n, slug, cmd):
            fail += 1
            print(f"  [{n}] {slug:<22} НЕ УЛОЖИЛСЯ В ОЧЕРЕДЬ")
            continue

        # Ждём метку готовности короткими опросами по SSH. Раньше ожидание
        # делалось одним вызовом с циклом for /l внутри .cmd: такой цикл
        # через SSH отдаёт соединение и оператор зависал на нём, а цикл
        # в файле собирался с двойными CR, из-за чего goto не срабатывал.
        deadline = time.time() + TIMEOUT
        ready = False
        while time.time() < deadline:
            rc, so = remote(f"if exist {DONE}\\{n}.done echo READY")
            if "READY" in so:
                ready = True
                break
            time.sleep(2)
        if not ready:
            fail += 1
            print(f"  [{n}] {slug:<22} ТАЙМАУТ")
            continue

        dst = os.path.join(out, f"{n}_{slug}.png")
        txt = os.path.join(text_out, f"{n}_{slug}.txt")
        ok1 = sh(f"scp -q {VM}:{S_DIR}/{n}_{slug}.png {shlex.quote(dst)}", timeout=120, encoding="cp866")
        sh(f"scp -q {VM}:{D_DIR}/{n}.txt {shlex.quote(txt)}", timeout=120, encoding="cp866")
        if ok1.returncode == 0 and os.path.exists(dst) and os.path.getsize(dst) > 15000:
            ok += 1
            print(f"  [{n}] {slug:<22} ок  {os.path.getsize(dst)//1024} КБ")
        else:
            fail += 1
            print(f"  [{n}] {slug:<22} СНИМОК НЕ ПРИШЁЛ")

    print(f"\nГотово: {ok} снимков, ошибок {fail}")

if __name__ == "__main__":
    main()