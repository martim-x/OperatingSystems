#!/usr/bin/env python3
import sys
from pathlib import Path

from PIL import Image


def is_black(px, limit=12):
    r, g, b = px[:3]
    return r <= limit and g <= limit and b <= limit


def panel_top(img):
    w, h = img.size
    step = max(1, w // 96)
    start = int(h * 0.80)
    y = h - 1
    while y > start:
        if all(is_black(img.getpixel((x, y))) for x in range(0, w, step)):
            return y
        y -= 1
    return None


def main():
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for path in sorted(src.glob("*.png")):
        img = Image.open(path).convert("RGB")
        top = panel_top(img)
        if top:
            img = img.crop((0, 0, img.size[0], top))
        img.save(dst / path.name)
        print(f"{path.name}: {img.size[0]}x{img.size[1]} панель={'да' if top else 'нет'}")


if __name__ == "__main__":
    main()
