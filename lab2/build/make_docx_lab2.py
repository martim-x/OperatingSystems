#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Сборка единого отчёта по ЛР2 (Linux + Windows) в формате lab1.docx.

Оформление берётся из эталонного файла lab1.docx: тот же styles.xml,
тот же numbering.xml, те же колонтитулы, те же поля страницы и тот же
формат подписей к рисункам. Меняется только содержимое.

Использование:
    python3 make_docx_lab2.py content.json out.docx
"""
import json
import os
import subprocess
import re
import shutil
import zipfile

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Emu

TEMPLATE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "lab1", "lab1.docx",
)
EMU_PER_CM = 360000
MAX_IMAGE_CM = 16.0
LINE = 240  # межстрочный интервал в twips, как в эталоне


# --------------------------------------------------------------------------
# низкоуровневые помощники OOXML
# --------------------------------------------------------------------------
def _el(tag, **attrs):
    """Создать w:-элемент с атрибутами в пространстве имён wordml."""
    el = OxmlElement(tag)
    for k, v in attrs.items():
        el.set(qn("w:" + k), str(v))
    return el


def add_run(par, text, *, bold=False, italic=False, size=None, mono=False):
    """Добавить прогон текста в абзац, сохраняя умолчания стиля."""
    run = par.add_run(text)
    if bold or italic or size or mono:
        run.bold = bold or None
        run.italic = italic or None
        if size:
            run.font.size = size
        if mono:
            rpr = run._element.get_or_add_rPr()
            fonts = _el("w:rFonts")
            for a in ("ascii", "hAnsi", "cs"):
                fonts.set(qn("w:" + a), "Consolas")
            rpr.append(fonts)
    return run


def strip_control(text):
    """Вырезать управляющие символы, которые lxml не принимает."""
    return "".join(
        ch for ch in text
        if ch in "\n\t" or ord(ch) >= 32
    ).replace("\x00", "")


STYLE = {"a0": "Глава_диплома", "a1": "Раздел_диплома",
         "aff2": "Для текста", "af0": "Normal (Web)"}


def paragraph(doc, style, text="", *, jc=None, mono=False, size=None):
    """Создать абзац со стилем эталонного отчёта."""
    p = doc.add_paragraph(style=STYLE.get(style, style))
    if jc:
        p._p.get_or_add_pPr().append(_el("w:jc", val=jc))
    if text:
        for i, chunk in enumerate(strip_control(text).split("\n")):
            if i:
                add_run(p, "", mono=mono).add_break()
            add_run(p, chunk, mono=mono, size=size)
    return p


def listing(doc, code, *, size=None):
    """Моноширинный листинг с одинарным интервалом и без отступа.

    Кегль 9 пт: при 10–11 пт длинные строки скриптов переносятся по
    ширине полосы и код перестаёт читаться.
    """
    from docx.shared import Pt
    size = size or Pt(9)
    p = doc.add_paragraph()
    ppr = p._p.get_or_add_pPr()
    # убрать красную строку основного текста
    ind = _el("w:ind", firstLine="0", left="284")
    ppr.append(ind)
    ppr.append(_el("w:spacing", line=str(LINE), lineRule="auto", before="0", after="0"))
    ppr.append(_el("w:jc", val="left"))
    lines = strip_control(code).split("\n")
    for i, ln in enumerate(lines):
        if i:
            add_run(p, "", mono=True).add_break()
        add_run(p, ln, mono=True, size=size)
    return p


def picture(doc, path, *, max_cm=MAX_IMAGE_CM):
    """Вставить рисунок по центру, шириной не больше max_cm, сохраняя пропорции."""
    from PIL import Image
    with Image.open(path) as im:
        px_w, px_h = im.size
    max_emu = Emu(int(max_cm * EMU_PER_CM))
    cx = max_emu
    cy = Emu(int(max_emu * px_h / px_w))
    par = doc.add_paragraph()
    par._p.get_or_add_pPr().append(_el("w:jc", val="center"))
    par.paragraph_format.space_before = None
    par.add_run().add_picture(path, width=cx, height=cy)
    return par


def caption(doc, text):
    """Подпись вида «Рисунок N.M – текст», как в эталоне."""
    p = doc.add_paragraph(style="af0")
    p._p.get_or_add_pPr().append(_el("w:jc", val="center"))
    add_run(p, text)
    return p


def page_break(doc):
    from docx.enum.text import WD_BREAK
    p = doc.add_paragraph()
    p.add_run().add_break(WD_BREAK.PAGE)
    return p


# --------------------------------------------------------------------------
# сборка
# --------------------------------------------------------------------------
def title_page(doc, data):
    for line in data["title_lines"]:
        p = doc.add_paragraph()
        p._p.get_or_add_pPr().append(_el("w:jc", val="center"))
        add_run(p, line, bold=True if ("ЛАБОРАТОРН" in line.upper() and "ОТЧЁТ" in line.upper()) else False)
    paragraph(doc, None, "")
    for line in data["title_tail"]:
        p = doc.add_paragraph(style="ad")
        p._p.get_or_add_pPr().append(_el("w:jc", val="right"))
        add_run(p, line)
    page_break(doc)


def bookmark(par, name, bid):
    """Закладка на заголовке — на неё ссылается оглавление."""
    st = OxmlElement("w:bookmarkStart")
    st.set(qn("w:id"), str(bid))
    st.set(qn("w:name"), name)
    en = OxmlElement("w:bookmarkEnd")
    en.set(qn("w:id"), str(bid))
    par._p.insert(0, st)
    par._p.append(en)
    return par


def _toc_line(anchor, text, page, style):
    """Строка оглавления: гиперссылка, табулятор, PAGEREF — как в lab1."""
    from xml.sax.saxutils import escape
    from docx.oxml.ns import nsdecls
    rpr = ('<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" '
           'w:cs="Times New Roman"/><w:noProof/><w:sz w:val="28"/>'
           '<w:szCs w:val="28"/>')
    hid = ('<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" '
           'w:cs="Times New Roman"/><w:noProof/><w:webHidden/><w:sz w:val="28"/>'
           '<w:szCs w:val="28"/>')
    return (
        f'<w:p {nsdecls("w")}><w:pPr><w:pStyle w:val="{style}"/>'
        f'<w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" '
        f'w:cs="Times New Roman"/><w:noProof/><w:sz w:val="28"/>'
        f'<w:szCs w:val="28"/></w:rPr></w:pPr>'
        f'<w:hyperlink w:anchor="{anchor}" w:history="1">'
        f'<w:r><w:rPr><w:rStyle w:val="a8"/>{rpr[1:]}</w:rPr>'
        f'<w:t xml:space="preserve">{escape(text)}</w:t></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr><w:tab/></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr>'
        f'<w:fldChar w:fldCharType="begin"/></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr>'
        f'<w:instrText xml:space="preserve"> PAGEREF {anchor} \\h </w:instrText></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr><w:fldChar w:fldCharType="separate"/></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr><w:t>{page}</w:t></w:r>'
        f'<w:r><w:rPr>{hid}</w:rPr><w:fldChar w:fldCharType="end"/></w:r>'
        f'</w:hyperlink></w:p>')


def toc_placeholder(doc):
    """Заголовок СОДЕРЖАНИЕ и пустой контейнер, который later заполнится."""
    p = doc.add_paragraph()
    p._p.get_or_add_pPr().append(_el("w:jc", val="center"))
    add_run(p, "СОДЕРЖАНИЕ", bold=True)
    ph = doc.add_paragraph()
    add_run(ph, "@@TOC@@")
    page_break(doc)
    return ph


def fill_toc(doc, placeholder, entries, pages):
    """Подставить в контейнер строки оглавления с реальными номерами страниц.

    Поле TOC остаётся «живым»: при обновлении в Word номера пересчитаются,
    но в готовом файле они уже проставлены, поэтому оглавление видно сразу.
    """
    from docx.oxml import parse_xml
    from docx.oxml.ns import nsdecls
    body = placeholder._p.getparent()
    idx = list(body).index(placeholder._p)
    body.remove(placeholder._p)

    xml = [f'<w:p {nsdecls("w")}><w:pPr><w:pStyle w:val="12"/></w:pPr>'
           '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>'
           '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText></w:r>'
           '<w:r><w:fldChar w:fldCharType="separate"/></w:r></w:p>']
    for e in entries:
        xml.append(_toc_line(e["anchor"], e["text"], pages.get(e["anchor"], ""),
                             "12" if e["level"] == 1 else "22"))
    xml.append(f'<w:p {nsdecls("w")}><w:r>'
               '<w:fldChar w:fldCharType="end"/></w:r></w:p>')
    for off, frag in enumerate(xml):
        body.insert(idx + off, parse_xml(frag))


def fix_numbering(doc):
    """Разделы нумеруются с 1, а не с 4.

    В эталонном lab1.docx у второго уровня стоит start=4 — автор правил
    начало нумерации вручную под свою структуру. Для нового отчёта
    разделы в каждой главе должны идти подряд с первого.
    """
    num = doc.part.numbering_part.element
    for lvl in num.iter(qn("w:lvl")):
        if lvl.get(qn("w:ilvl")) == "1":
            start = lvl.find(qn("w:start"))
            if start is not None:
                start.set(qn("w:val"), "1")


def build(data, out_path, pages=None):
    shutil.copy(TEMPLATE, out_path)
    doc = Document(out_path)

    # очистить тело, оставив единственный sectPr эталонной страницы
    body = doc.element.body
    sect = body.find(qn("w:sectPr"))
    for child in list(body):
        if child is not sect:
            body.remove(child)

    fix_numbering(doc)
    title_page(doc, data)
    placeholder = toc_placeholder(doc)

    entries = []          # строки будущего оглавления
    bid = [1000]

    def unnumbered(par):
        """Снять нумерацию: в эталоне так оформлены «Введение» и «Заключение»."""
        ppr = par._p.get_or_add_pPr()
        npr = _el("w:numPr")
        npr.append(_el("w:ilvl", val="0"))
        npr.append(_el("w:numId", val="0"))
        ppr.append(npr)
        return par

    def heading(text, level, page_break_before=False, number=""):
        """Заголовок с закладкой.

        Номер в абзац не вписывается — его проставляет стиль a0/a1.
        Для оглавления номер нужен явно, поэтому он считается здесь
        и подставляется только в строку оглавления.
        """
        if page_break_before:
            page_break(doc)
        p = paragraph(doc, "a0" if level == 1 else "a1", text)
        anchor = f"_Toc9{bid[0]:06d}"
        bid[0] += 1
        bookmark(p, anchor, bid[0])
        entries.append({"anchor": anchor, "level": level,
                        "text": f"{number} {text}".strip()})
        return p

    intro_h = heading("Введение", 1)
    unnumbered(intro_h)
    intro_h._p.get_or_add_pPr().append(_el("w:jc", val="center"))
    for par_text in data["introduction"]:
        raw = par_text if isinstance(par_text, str) else "\n\n".join(par_text)
        for chunk in raw.split("\n\n"):
            if chunk.strip():
                paragraph(doc, "aff2", chunk.strip())

    chap_no = 0
    sub_no = 0
    for ch in data["chapters"]:
        chap_no += 1
        sub_no = 0
        heading(ch["title"], 1, page_break_before=True, number=f"{chap_no}")
        for sub in ch["subsections"]:
            sub_no += 1
            heading(sub["title"], 2, number=f"{chap_no}.{sub_no}")
            for par_text in sub["content"]:
                if par_text.strip():
                    paragraph(doc, "aff2", par_text.strip())
            for fig in sub.get("figures", []):
                path = os.path.join(os.path.dirname(out_path) or ".",
                                    fig["file"]) \
                    if not os.path.exists(fig["file"]) else fig["file"]
                if os.path.exists(path):
                    picture(doc, path)
                    caption(doc, fig["caption"])

    page_break(doc)
    unnumbered(heading("Заключение", 1))
    for par_text in data["conclusion"]:
        paragraph(doc, "aff2", par_text)

    if data.get("listings"):
        page_break(doc)
        unnumbered(heading("Приложение А. Листинги скриптов", 1))
        for li, item in enumerate(data["listings"], 1):
            # каждый листинг — со своей страницы, иначе скрипты слипаются
            if li > 1:
                page_break(doc)
            # приложение в нумерацию глав не входит: «А.1», «А.2» и т.д.
            h = heading(item["title"], 2, number=f"А.{li}")
            unnumbered(h)
            listing(doc, item["code"])

    fill_toc(doc, placeholder, entries, pages or {})
    doc.save(out_path)
    return entries


def prune_media(path):
    """Выбросить картинки lab1, на которые новый отчёт не ссылается.

    Без этого шаблон тащит за собой все 105 снимков первой лабораторной
    и файл весит 135 МБ вместо реального размера отчёта.
    """
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        blobs = {n: z.read(n) for n in names}

    # картинки引用 могут быть не только в теле, но и в колонтитулах
    used = set()
    for n in names:
        if n.endswith(".xml") and n.startswith("word/"):
            used |= set(re.findall(r'r:embed="(rId\d+)"', blobs[n].decode("utf-8")))
    rels = blobs["word/_rels/document.xml.rels"].decode("utf-8")
    target = {
        rid: t for rid, t in re.findall(r'Id="(rId\d+)"[^>]*Target="([^"]+)"', rels)
    }
    keep_targets = {target[r] for r in used if r in target}

    # выкинуть неиспользуемые media и связи на них
    drop = [n for n in names
            if n.startswith("word/media/") and n[len("word/"):] not in keep_targets]
    drop_ids = {rid for rid, t in target.items()
                if t.startswith("media/") and t not in keep_targets}
    if drop_ids:
        # ElementTree здесь даёт префиксы ns0:, которые LibreOffice не
        # принимает, поэтому связи вырезаются текстово, по одному Id
        rels_txt = blobs["word/_rels/document.xml.rels"].decode("utf-8")
        for rid in drop_ids:
            rels_txt = re.sub(
                r'<Relationship\\b(?=[^>]*\\bId="%s")[^>]*/>' % re.escape(rid),
                "", rels_txt,
            )
        blobs["word/_rels/document.xml.rels"] = rels_txt.encode("utf-8")

    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            if n not in drop:
                z.writestr(n, blobs[n])
    return len(drop)


def page_numbers(entries, pdf_path):
    """Номера страниц заголовков по тексту уже свёрстанного PDF.

    LibreOffice не отдаёт закладки в PDF, поэтому страница ищется по
    положению заголовка в тексте. Текст всех страниц читается один раз:
    иначе на 117 страницах и 105 заголовках вышло бы больше тысячи
    запусков pdftotext.
    """
    import subprocess
    info = subprocess.run(["pdfinfo", pdf_path], capture_output=True, text=True)
    m = re.search(r"Pages:\s+(\d+)", info.stdout)
    total = int(m.group(1)) if m else 1

    # страницы самого оглавления не учитываем: иначе заголовок находится
    # в списке и все номера страниц схлопываются в страницу оглавления
    toc_pages = 0
    for pg in range(1, total + 1):
        out = subprocess.run(
            ["pdftotext", "-f", str(pg), "-l", str(pg), pdf_path, "-"],
            capture_output=True, text=True)
        if "СОДЕРЖАНИЕ" in out.stdout:
            toc_pages = pg
            break
    body_start = toc_pages + 1

    flat = {}
    for pg in range(1, total + 1):
        out = subprocess.run(
            ["pdftotext", "-f", str(pg), "-l", str(pg), pdf_path, "-"],
            capture_output=True, text=True)
        flat[pg] = " ".join(out.stdout.split())

    pages, cur, seen = {}, body_start, set()
    for e in entries:
        if e["anchor"] in seen:
            continue
        seen.add(e["anchor"])
        # в теле номер может отсутствовать (приложение, «Введение»),
        # поэтому пробуем и с номером, и без него
        head = re.sub(r"^[\d.]+\s+", "", e["text"])[:60]
        head = re.sub(r"^[А-Я]\.\d+\s+", "", head)
        for needle in (head, e["text"][:60]):
            if not needle:
                continue
            for pg in range(cur, total + 1):
                if needle in flat[pg]:
                    pages[e["anchor"]] = pg
                    cur = pg
                    break
            if e["anchor"] in pages:
                break
    return pages


def main():
    import sys
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    content_path, out_path = sys.argv[1], sys.argv[2]
    with open(content_path, encoding="utf-8") as f:
        data = json.load(f)

    # первый проход — вёрстка без номеров страниц в оглавлении
    entries = build(data, out_path)
    dropped = prune_media(out_path)

    # второй проход — с реальными номерами страниц
    pdf = os.path.splitext(out_path)[0] + ".pdf"
    soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
    if os.path.exists(soffice):
        subprocess.run([soffice, "--headless", "--convert-to", "pdf", out_path],
                       capture_output=True, timeout=1800)
    if os.path.exists(pdf):
        pages = page_numbers(entries, pdf)
        entries = build(data, out_path, pages)
        dropped = prune_media(out_path)
        print(f"номера страниц проставлены для {len(pages)} из {len(entries)} заголовков")

    print(f"готово: {out_path} — {os.path.getsize(out_path) // 1024} КБ, "
          f"удалено лишних картинок: {dropped}")


if __name__ == "__main__":
    main()
