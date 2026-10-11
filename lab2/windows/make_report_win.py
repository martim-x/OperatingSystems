#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_report_win.py - структур��тура содержимого Windows-части ЛР2.

Читает фактические выводы из lab2/windows/выводы/<уровень>/*.txt, сопоставляет их
со снимками из lab2/windows/скрины/<уровень>/*.png по таблице разметки и
формирует главы/разделы/пункты отчёта. Ничего не выдумывается: текст каждого
пункта берётся из реального вывода команды, а имя снимка — из разметки.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from снимки_разметка import LEVELS

SHOTS = os.path.join(HERE, "скрины")
TXT = os.path.join(HERE, "выводы")

LEVEL_TITLES = {
    "уровень_4-5": "Уровень 4-5. Работа в командной строке операционной системы Windows",
    "уровень_6-7": "Уровень 6-7. Копирование файлов, пакетные файлы и переменные окружения",
    "уровень_8-9": "Уровень 8-9. PowerShell: скрипты, калькулятор, конвертер, мониторинг",
}

LEVEL_INTRO = {
    "уровень_4-5": (
        "Ниже приведены кадры выполнения заданий уровней 4 и 5 в командной строке "
        "Windows. Рабочий каталог подготовлен скриптом prep.bat, который создаёт "
        "дерево каталогов OS2, повторяющее дерево, использованное в Linux-части, "
        "чтобы результаты уровней можно было сопоставить построчно."
    ),
    "уровень_6-7": (
        "В этом разделе приведены кадры выполнения заданий уровней 6 и 7: "
        "копирование файлов и каталогов средствами xcopy, replace и copy con, "
        "разработка и проверка пакетных файлов bat_01 - bat_05, а также анализ "
        "переменных окружения и состава PATH."
    ),
    "уровень_8-9": (
        "В этом разделе приведены кадры выполнения заданий уровней 8 и 9: "
        "скрипты на языке PowerShell (калькулятор, конвертер температур, подсчёт "
        "команд в PATH, дерево каталогов с размерами) и монитор топ-5 процессов "
        "по загрузке процессора и памяти."
    ),
}

MAX_BODY = 1400   # символов вывода в текстовый блок отчёта


def clean(text):
    """Убирает управляющие последовательности и служебные рамки."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
    text = text.replace("\x00", "")
    # двойные пустые строки в записи вывода
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def cut(text, limit=MAX_BODY):
    """Обрезает вывод по границе строки."""
    if len(text) <= limit:
        return text
    cut_at = text[:limit].rsplit("\n", 1)[0]
    return cut_at + "\n... (вывод показан сокращённо)"


def load_tsv(name):
    """slug -> команда, из tsv пакета."""
    p = os.path.join(HERE, name)
    out = {}
    for line in open(p, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            out[f"{int(parts[0]):02d}_{parts[1].strip()}"] = parts[2].strip()
    return out


TSV_BY_LEVEL = {
    "уровень_4-5": "cmds_4-5.tsv",
    "уровень_6-7": "cmds_6-7.tsv",
    "уровень_8-9": "cmds_8-9.tsv",
}


def gather(level):
    """Возвращает список (номер, slug, имя_снимка, пункт_ТЗ, команда, вывод, путь_к_png)."""
    mark = LEVELS.get(level, {})
    cmds = load_tsv(TSV_BY_LEVEL[level])
    rows = []
    for slug, (shot_name, tz, tool) in sorted(mark.items()):
        png = os.path.join(SHOTS, level, f"{slug}.png")
        txt = os.path.join(TXT, level, f"{slug}.txt")
        body = ""
        if os.path.exists(txt):
            body = clean(open(txt, encoding="utf-8", errors="replace").read())
        rows.append({
            "slug": slug,
            "shot": shot_name,
            "tz": tz,
            "tool": tool,
            "cmd": cmds.get(slug, ""),
            "body": body,
            "png": png if os.path.exists(png) else None,
        })
    return rows


def main():
    data = {}
    for level in ("уровень_4-5", "уровень_6-7", "уровень_8-9"):
        data[level] = gather(level)
        have = sum(1 for r in data[level] if r["png"])
        print(f"{level}: пунктов {len(data[level])}, снимков {have}")

    # печать диагностики: пункты без снимка
    for level, rows in data.items():
        missing = [r["slug"] for r in rows if not r["png"]]
        if missing:
            print(f"  ВНИМАНИЕ {level}: нет снимка для {missing}")
    return data


if __name__ == "__main__":
    main()