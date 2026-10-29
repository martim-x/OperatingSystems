#!/usr/bin/env python3
"""Дописывает в report.json фигуры для новых кадров ЛР3.

Идемпотентно: блоки с уже существующими метками не добавляются.
Добавляет только те фигуры, чьи PNG реально лежат в скрины/уровень_*/.
Перед сборкой отчёта делает бэкап report.json.bak.

    python3 prepare_report_figures.py           # показать, что добавится
    python3 prepare_report_figures.py --apply   # записать в report.json
"""

import argparse
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LAB3 = os.path.normpath(os.path.join(HERE, "..", ".."))
REPORT = os.path.join(LAB3, "build", "report.json")
SHOTS = os.path.join(LAB3, "windows", "скрины")

# Группа 1 — уровень 4–5, встаёт после фигуры «три процесса»
GROUP_1 = {
    "anchor_label": "fig3_win_08_three_proc",
    "text": (
        "Те же процессы видны из консоли командой tasklist (рисунок @рис:fig3_win_13_cmd) "
        "и в Диспетчере задач (рисунок @рис:fig3_win_14_taskmgr). Дескрипторы родителя "
        "и дочерних процессов показаны на рисунках @рис:fig3_win_15_handles_45 "
        "и @рис:fig3_win_16_pipe_45."
    ),
    "figures": [
        ("уровень_4-5/task09_cmd.png", "fig3_win_13_cmd",
         "tasklist | findstr Lab-03: список процессов Lab-03a и дочерних Lab-03x"),
        ("уровень_4-5/task10_taskmgr.png", "fig3_win_14_taskmgr",
         "Диспетчер задач Windows: процессы Lab-03a и Lab-03x в списке"),
        ("уровень_4-5/task16_procexp_handles.png", "fig3_win_15_handles_45",
         "Process Explorer: дескрипторы родителя Lab-03a – дочерние процессы типа Process"),
        ("уровень_4-5/task15_procexp_pipe.png", "fig3_win_16_pipe_45",
         "Process Explorer: дескрипторы Lab-03a в нижней панели Handles – анонимного канала у него нет, видны Process, Thread и File"),
    ],
}

# Группа 2 — уровень 7–8, встаёт после абзаца про дескриптор канала
GROUP_2 = {
    "anchor_text_prefix": "В Process Explorer у детей виден дескриптор",
    "strip_suffix": " Уровень 7–8 на Windows выполнен.",
    "text": (
        "Нижняя панель Handles в Process Explorer показывает у клиента дескриптор канала "
        "(рисунок @рис:fig3_win_17_pipe_78), а у сервера – дескрипторы дочерних процессов "
        "(рисунок @рис:fig3_win_18_handles_78)."
    ),
    "figures": [
        ("уровень_7-8/task15_procexp_pipe.png", "fig3_win_17_pipe_78",
         "Process Explorer: дескриптор канала типа File (\\Device\\NamedPipe\\...) у Lab-03d-client"),
        ("уровень_7-8/task16_procexp_handles.png", "fig3_win_18_handles_78",
         "Process Explorer: дескрипторы дочерних процессов типа Process у Lab-03d-server"),
    ],
    "closing": (
        "Уровень 7–8 на Windows выполнен: канал анонимный, дескриптор наследуется потомком, "
        "сервер дождался всех детей и собрал результат."
    ),
}

def existing_labels(blocks):
    return {b.get("label") for b in blocks if b.get("type") == "figure"}


def make_figures(figures, have_labels):
    out = []
    for rel, label, caption in figures:
        if label in have_labels:
            continue
        path = os.path.join(SHOTS, rel)
        if not os.path.exists(path):
            continue
        if os.path.getsize(path) < 100_000:   # плейсхолдер, а не кадр
            continue
        out.append({"type": "figure", "file": "скрины/windows/" + rel,
                    "caption": caption, "label": label})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--only", default="", help="через запятую: какие метки добавлять (по умолчанию все)")
    args = ap.parse_args()
    only = {s.strip() for s in args.only.split(",") if s.strip()}

    data = json.load(open(REPORT, encoding="utf-8"))
    blocks = data["blocks"]
    labels = existing_labels(blocks)

    plan = []  # (index, [блоки для вставки])
    for group in (GROUP_1, GROUP_2):
        figs = make_figures(group["figures"], labels)
        if not figs:
            continue
        anchor = None
        if "anchor_label" in group:
            for i, b in enumerate(blocks):
                if b.get("label") == group["anchor_label"]:
                    anchor = i
                    break
        else:
            for i, b in enumerate(blocks):
                if b.get("type") == "p" and b.get("text", "").startswith(group["anchor_text_prefix"]):
                    anchor = i
                    break
        if anchor is None:
            print(f"!! не найден якорь для группы: {group.get('anchor_label') or group.get('anchor_text_prefix')}")
            continue
        suffix = group.get("strip_suffix")
        if only:
            figs = [f for f in figs if f["label"] in only]
            if not figs:
                continue
            plan.append((anchor + 1, figs))
            continue
        if suffix and blocks[anchor].get("text", "").endswith(suffix):
            blocks[anchor]["text"] = blocks[anchor]["text"][: -len(suffix)]
        new_blocks = [{"type": "p", "text": group["text"]}] + figs
        if group.get("closing"):
            new_blocks.append({"type": "p", "text": group["closing"]})
        plan.append((anchor + 1, new_blocks))

    if not plan:
        print("нечего добавлять: все метки на месте или файлов ещё нет")
        return 0

    for idx, new_blocks in sorted(plan, key=lambda x: -x[0]):
        for offset, b in enumerate(new_blocks):
            blocks.insert(idx + offset, b)

    print(f"добавится блоков: {sum(len(nb) for _, nb in plan)}")
    for _, nb in plan:
        for b in nb:
            print("  +", b.get("label") or b.get("text", "")[:60])

    if args.apply:
        shutil.copy(REPORT, REPORT + ".bak")
        with open(REPORT, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"записано: {REPORT} (бэкап: report.json.bak, блоков теперь {len(blocks)})")
    else:
        print("холостой прогон; для записи добавь --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
