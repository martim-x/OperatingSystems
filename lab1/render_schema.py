#!/usr/bin/env python3
"""Рендер схемы аппаратной конфигурации (drawio/mxGraph XML) в PNG без drawio."""
import re
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

SCALE = 2.0
FONT_DIR = "/System/Library/Fonts/Supplemental/"

HEX_RE = re.compile(r'^#([0-9a-fA-F]{6})$')

def parse_color(s, default):
    if not s:
        return default
    m = HEX_RE.match(s)
    if m:
        return tuple(int(m.group(1)[i:i+2], 16) for i in (0, 2, 4)) + (255,)
    if s == "none":
        return None
    return default

def parse_style(style):
    st = {}
    for kv in (style or "").split(";"):
        if "=" in kv:
            k, v = kv.split("=", 1)
            st[k] = v
    return st

def value_to_lines(value):
    """mxGraph html value -> list of (text, bold) lines."""
    v = value or ""
    v = re.sub(r'<br\s*/?>', "\n", v, flags=re.I)
    parts = re.split(r'(<b>|</b>)', v, flags=re.I)
    lines = []
    cur = ""
    bold = False
    for p in parts:
        pl = p.lower()
        if pl == "<b>":
            bold = True
        elif pl == "</b>":
            bold = False
        else:
            cur += p
    # cur now has newlines; split preserving bold per segment is complex,
    # so do a simpler second pass: split by newline on the whole string.
    # To support per-line bold, rebuild: we lost segments. Use regex approach instead.
    return cur.split("\n"), [bold] * len(cur.split("\n"))

def value_segments(value):
    """Return list of (text, bold) kept in order across <b>...</b> and <br>."""
    if not value:
        return [("", False)]
    out = []
    i = 0
    segments = re.split(r'(<b>|</b>|<br\s*/?>)', value, flags=re.I)
    bold = False
    for seg in segments:
        s = seg.strip().lower()
        if s == "<b>":
            bold = True
        elif s == "</b>":
            bold = False
        elif s in ("<br>", "<br />", "<br/>"):
            out.append(("\n", bold))
        else:
            if seg:
                out.append((seg, bold))
    return out

def join_to_lines(segments):
    lines = []
    cur = ""
    for text, bold in segments:
        if text == "\n":
            lines.append((cur, bold))
            cur = ""
        else:
            cur += text
    if cur or not lines:
        lines.append((cur, bold))
    return lines

def wrap_line(draw, text, font, max_w):
    words = text.split(" ")
    if not words:
        return [text]
    lines = []
    cur = ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines

def draw_text(draw, bbox, segs, style, font_path):
    """Draw potentially multi-line text inside box bbox."""
    fsize = float(style.get("fontSize", 11)) * SCALE
    font = load_font(font_path, fsize, False)
    font_b = load_font(font_path, fsize, True)
    color = parse_color(style.get("fontColor"), (44, 62, 80, 255))
    x0, y0, x1, y1 = bbox
    spacing = int(4 * SCALE)
    v_align = style.get("verticalAlign", "middle")
    h_align = style.get("align", "left")

    lines = join_to_lines(value_segments(segs))
    # build wrapped lines preserving bold flag per original line
    rendered = []
    for text, bold in lines:
        f = font_b if bold else font
        for wl in wrap_line(draw, text, f, int((x1 - x0) - 2 * spacing)):
            rendered.append((wl, bold))
    line_h = int(fsize * 1.35)
    total_h = line_h * len(rendered)

    if v_align == "top":
        ty = y0 + spacing
    elif v_align == "bottom":
        ty = y1 - spacing - total_h
    else:
        ty = y0 + max(0, (y1 - y0 - total_h) / 2)

    for text, bold in rendered:
        f = font_b if bold else font
        tw = draw.textlength(text, font=f)
        if h_align == "center":
            tx = x0 + (x1 - x0 - tw) / 2
        elif h_align == "right":
            tx = x1 - spacing - tw
        else:
            tx = x0 + spacing
        draw.text((tx, ty), text, font=f, fill=(color[0], color[1], color[2], 255))
        ty += line_h

def load_font(font_path, size, bold):
    try:
        return ImageFont.truetype(font_path, int(size))
    except Exception:
        return ImageFont.load_default()

def render(src, out, scale=SCALE):
    tree = ET.parse(src)
    root = tree.getroot()
    diagram = root.find(".//diagram")
    model = diagram.find(".//mxGraphModel")
    page_w = int(float(model.get("pageWidth", "1000")))
    page_h = int(float(model.get("pageHeight", "820")))

    cells = {}
    for cell in model.iter("mxCell"):
        cells[cell.get("id")] = cell

    def geom(cell):
        g = cell.find("mxGeometry")
        if g is None:
            return None
        return dict(x=float(g.get("x", 0)), y=float(g.get("y", 0)),
                    w=float(g.get("width", 0)), h=float(g.get("height", 0)))

    W = page_w * scale + 4
    H = page_h * scale + 4
    img = Image.new("RGBA", (int(W), int(H)), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    font_path = FONT_DIR + "Arial.ttf"

    boxes = {}
    for cid, cell in cells.items():
        g = geom(cell)
        if g is None:
            continue
        boxes[cid] = g

    # draw boxes
    for cid, cell in cells.items():
        if cell.get("edge") == "1":
            continue
        g = geom(cell)
        if g is None:
            continue
        style = parse_style(cell.get("style"))
        x, y, w, h = g["x"] * scale, g["y"] * scale, g["w"] * scale, g["h"] * scale
        fill = parse_color(style.get("fillColor"), (255, 255, 255, 255))
        stroke = parse_color(style.get("strokeColor"), (203, 213, 224, 255)) or fill
        sw = max(1, round(float(style.get("strokeWidth", 1)) * scale))
        dashed = style.get("dashed") == "1"
        if fill is None:
            fill = (255, 255, 255, 0)
        if dashed:
            dash = (4 * scale, 3 * scale)
            for i in range(int((w / (dash[0] + dash[1]))) + 1):
                sx = x + i * (dash[0] + dash[1])
                draw.line([(sx, y), (min(sx + dash[0], x + w), y)], fill=stroke, width=sw)
            for i in range(int((h / (dash[0] + dash[1]))) + 1):
                sy = y + i * (dash[0] + dash[1])
                draw.line([(x, sy), (x, min(sy + dash[0], y + h))], fill=stroke, width=sw)
            draw.line([(x + w, y), (x + w, y + h)], fill=stroke, width=sw)
            draw.line([(x, y + h), (x + w, y + h)], fill=stroke, width=sw)
        else:
            draw.rectangle([x, y, x + w, y + h], fill=fill, outline=stroke, width=sw)
        val = cell.get("value")
        if val:
            draw_text(draw, (x + 2, y, x + w - 2, y + h), val, style, font_path)

    # edges
    for cid, cell in cells.items():
        if cell.get("edge") != "1":
            continue
        style = parse_style(cell.get("style"))
        src_id, tgt_id = cell.get("source"), cell.get("target")
        if src_id not in boxes or tgt_id not in boxes:
            continue
        sb, tb = boxes[src_id], boxes[tgt_id]
        sx = (sb["x"] + sb["w"] * 0.5) * scale
        sy = (sb["y"] + sb["h"]) * scale
        tx = (tb["x"] + tb["w"] * 0.5) * scale
        ty = (tb["y"]) * scale
        midy = (sy + ty) / 2
        pts = [(sx, sy), (sx, midy), (tx, midy), (tx, ty)]
        stroke = parse_color(style.get("strokeColor"), (53, 99, 233, 255)) or (53, 99, 233, 255)
        sw = max(1, round(float(style.get("strokeWidth", 2)) * scale))
        draw.line(pts, fill=stroke, width=sw, joint="curve")
        val = cell.get("value")
        if val:
            f = load_font(font_path, int(float(style.get("fontSize", 10)) * scale), False)
            col = parse_color(style.get("fontColor"), (144, 163, 191, 255))
            lx, ly = (sx + tx) / 2, midy - 14 * scale
            draw.text((lx, ly), val, font=f, fill=(col[0], col[1], col[2], 255), anchor="ma")

    img = img.convert("RGB")
    img.save(out, "PNG")
    print(f"schema PNG written: {out} ({img.width}x{img.height})")

if __name__ == "__main__":
    import sys
    render(sys.argv[1], sys.argv[2])