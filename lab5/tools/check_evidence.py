#!/usr/bin/env python3
"""Сверка доказательств ЛР5: кадры, OCR, логи серий, дубли по SHA-256.

Использование:
    python3 tools/check_evidence.py --shots DIR --logs DIR --ocr OCR.txt

Проверки:
  1. число PNG совпадает с числом OCR-блоков (маркеры "==== <путь> ====");
  2. нет двух кадров с одинаковым SHA-256;
  3. для каждой серии PID/TID участников из сводки находятся в OCR кадров этой серии;
  4. параметры P1/P2/P3 из сводки присутствуют в OCR кадра *_a_params;
  5. код завершения серии либо 0, либо явно помечен как ПРЕРВАНО;
  6. кадр f_second есть тогда и только тогда, когда сводка сообщает, что участники
     завершились в разные моменты; при общем окне финиша f_second не должно быть.
"""

import argparse
import hashlib
import pathlib
import re
import sys
from typing import Any


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_ocr(path):
    blocks, current = {}, None
    for line in pathlib.Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"^==== (.+) ====$", line.strip())
        if m:
            current = pathlib.Path(m.group(1)).name
            blocks[current] = []
        elif current:
            blocks[current].append(line)
    return {k: "\n".join(v) for k, v in blocks.items()}


def parse_summary(path):
    text = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    data: dict[str, Any] = {"text": text, "path": str(path)}
    m = re.search(r"Параметры: P1=(\S+?) P2=(\S+?) P3=(\S+?)[,\s]", text)
    if m:
        data["params"] = m.groups()
    m = re.search(r"участники (\d+) и (\d+)", text)
    if m:
        data["pids"] = m.groups()
    m = re.search(r"PID (\d+), код возврата", text)
    if m:
        data["pids"] = (m.group(1),)
    m = re.search(r"Lab-05b/c завершился штатно, код (\d+)", text)
    m2 = re.search(r"код возврата (\d+)", text)
    data["ok_exit"] = bool((m and m.group(1) == "0") or (m2 and m2.group(1) == "0"))
    data["interrupted"] = "ПРЕРВАНО" in text
    data["frames"] = re.findall(r"^\s+((?:05b|05c|05x)_\w+)\t", text, re.M)
    data["iterations"] = dict(re.findall(r"PID/TID (\d+): последняя итерация (\d+)", text))
    data["one_window"] = "одном окне опроса" in text
    data["second_frame"] = "кадр f_second снимается" in text
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", required=True)
    ap.add_argument("--logs", required=True)
    ap.add_argument("--ocr", required=True)
    args = ap.parse_args()

    shots = pathlib.Path(args.shots)
    logs = pathlib.Path(args.logs)
    pngs = sorted(shots.glob("*.png"))
    ocr = parse_ocr(args.ocr)

    problems = []

    if len(pngs) != len(ocr):
        problems.append(f"кадров {len(pngs)}, OCR-блоков {len(ocr)}")
    missing = [p.name for p in pngs if p.name not in ocr]
    if missing:
        problems.append(f"нет OCR для: {', '.join(missing)}")
    names = {p.name for p in pngs}
    empty = [n for n in ocr if n in names and not ocr[n].strip()]
    required = ("_a_params", "_e_first", "_g_finish", "_f_second")
    empty_required = [n for n in empty if any(n.startswith("0") and r in n for r in required)]
    if empty_required:
        problems.append("пустой OCR у обязательного кадра: " + ", ".join(empty_required))

    by_hash = {}
    for p in pngs:
        by_hash.setdefault(sha256(p), []).append(p.name)
    dups = {h: names for h, names in by_hash.items() if len(names) > 1}
    for h, names in dups.items():
        problems.append("дубль SHA-256 " + h[:16] + ": " + ", ".join(names))

    print(f"кадров: {len(pngs)}, OCR-блоков: {len(ocr)}, уникальных SHA-256: {len(by_hash)}")
    if empty:
        print("OCR без текста (вспомогательные кадры, не обязательные этапы): "
              + ", ".join(empty))

    summaries = sorted(logs.glob("05*_summary.txt"))
    for s in summaries:
        info = parse_summary(s)
        tag = s.stem
        frames = [f for f in info["frames"] if f + ".png" in ocr]
        absent = [f for f in info["frames"] if f + ".png" not in ocr]
        status = "OK"
        if absent:
            status = "кадры из сводки отсутствуют в наборе: " + ", ".join(absent)
            problems.append(f"{tag}: {status}")
        pid_seen = {}
        for pid in info.get("pids", ()):
            pid_seen[pid] = [f for f in frames if re.search(rf"\b{pid}\b", ocr[f + ".png"])]
        if not info["ok_exit"] and not info["interrupted"]:
            status = "НЕТ ШТАТНОГО КОДА 0"
        if info.get("pids") and not all(pid_seen.values()):
            status = "PID/TID участника не найден в кадрах серии"
        params_ok = "-"
        params_frame = [f for f in frames if f.endswith("_a_params")]
        if params_frame and "params" in info:
            body = ocr[params_frame[0] + ".png"]
            banner = "P1={} P2={} P3={}".format(*info["params"])
            params_ok = "да" if banner in body else "НЕТ"
            if params_ok == "НЕТ":
                status = "баннер параметров не виден в кадре a_params"
        if info["one_window"]:
            has_second = any("_f_second" in f for f in info["frames"])
            if has_second:
                status = "при общем окне финиша в серии есть кадр f_second"
        if info["second_frame"]:
            if not any("_f_second" in f for f in info["frames"]):
                status = "сводка обещает кадр f_second, но его нет"
        single = tag.startswith("05x")
        finish_stage = "_d_finish" if single else "_e_first"
        if not any(f.endswith(finish_stage) for f in info["frames"]):
            status = "нет кадра завершения (" + finish_stage.lstrip("_") + ")"
        if not params_frame:
            status = "нет кадра с параметрами (a_params)"
        if status != "OK":
            problems.append(f"{tag}: {status}")
        print(f"\n{tag}: {status}")
        print(f"  параметры P1/P2/P3={info.get('params')}, баннер в a_params: {params_ok}")
        print(f"  участники {info.get('pids')}, кадров серии: {len(frames)}")
        for pid, hit in pid_seen.items():
            print(f"  PID/TID {pid}: " + (", ".join(hit) if hit else "не найден"))
        print(f"  итерации на момент финиша: {info['iterations']}")
        print(f"  финиш: " + ("одно окно опроса" if info["one_window"]
                              else "разные моменты, есть f_second" if info["second_frame"]
                              else "не указан"))
        print(f"  код 0: {'да' if info['ok_exit'] else 'нет'}"
              + (", ПРЕРВАНО" if info["interrupted"] else ""))

    print("\n=== проблемы ===")
    if problems:
        for p in problems:
            print(" -", p)
        return 1
    print("нет")
    return 0


if __name__ == "__main__":
    sys.exit(main())
