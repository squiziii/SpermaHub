#!/usr/bin/env python3
"""bake_msdf_atlas.py — MSDF-атлас иконок -> обычный bitmap-лист для Roblox.

MSDF хранит в RGB не цвет, а расстояние до края глифа (в превью это и есть
радужная каша), поэтому ImageLabel в Roblox покажет мусор. Скрипт:

  1. декодирует поле: median(R,G,B) -> coverage (0 снаружи, 1 внутри);
  2. режет атлас на отдельные иконки (по метрикам msdf-atlas-gen или по белым
     промежуткам между рядками/столбцами);
  3. запекает каждую иконку с альфой в ячейку cell x cell и пакует всё в один
     PNG-лист, который можно загрузить в Roblox как обычную картинку;
  4. печатает готовую Lua-таблицу прямоугольников для neverlose_gui.lua.

Зависимость: pillow
    tools/.venv/bin/pip install pillow
    # или: python3 -m pip install --user pillow

Примеры:
    tools/.venv/bin/python tools/bake_msdf_atlas.py icons_nurik.png
    tools/.venv/bin/python tools/bake_msdf_atlas.py icons_nurik.png -j icons_nurik.json
    tools/.venv/bin/python tools/bake_msdf_atlas.py icons_nurik.png --map ragebot=1,antiaim=2

Результат: icons_atlas.png + icons_atlas_rects.lua + список иконок в консоли.
"""

import argparse
import json
import math
import sys

from PIL import Image, ImageDraw

WHITE = (255, 255, 255, 255)


def median3(a, b, c):
    return max(min(a, b), min(max(a, b), c))


def cov_from_msdf(img):
    """RGBA -> список строк float coverage (1.0 = внутри глифа)."""
    img = img.convert("RGBA")
    w, h = img.size
    raw = img.tobytes()
    flat = []
    for i in range(0, len(raw), 4):
        r, g, b = raw[i], raw[i + 1], raw[i + 2]
        # median of R,G,B — стандартное декодирование MSDF-края
        flat.append(1.0 - median3(r, g, b) / 255.0)
    return [flat[y * w:(y + 1) * w] for y in range(h)]


def bands(flags):
    """Список (start, end) подряд идущих True."""
    out = []
    start = None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(flags)))
    return out


def auto_boxes(cov, min_side=5):
    """Режем по пустым рядкам и столбцам (атлас упакован с зазорами)."""
    h = len(cov)
    w = len(cov[0]) if h else 0
    rows = [any(c > 0.5 for c in cov[y]) for y in range(h)]
    boxes = []
    for y0, y1 in bands(rows):
        cols = [any(cov[y][x] > 0.5 for y in range(y0, y1)) for x in range(w)]
        for x0, x1 in bands(cols):
            if x1 - x0 >= min_side and y1 - y0 >= min_side:
                boxes.append((x0, y0, x1, y1))
    boxes.sort(key=lambda b: (b[1] // 24, b[0]))
    return boxes


def json_boxes(path, sheet_w, sheet_h):
    """Прямоугольники из msdf-atlas-gen JSON (y снизу) или своего формата."""
    data = json.load(open(path, encoding="utf-8"))
    glyphs = data.get("glyphs") or data.get("icons") or []
    boxes = []
    for g in glyphs:
        if all(k in g for k in ("x", "y", "w", "h")):
            boxes.append((int(g["x"]), int(g["y"]), int(g["x"]) + int(g["w"]), int(g["y"]) + int(g["h"])))
            continue
        ab = g.get("atlasBounds")
        if not ab:
            continue
        x0 = int(math.floor(ab["left"]))
        x1 = int(math.ceil(ab["right"]))
        y0 = int(math.floor(sheet_h - ab["top"]))
        y1 = int(math.ceil(sheet_h - ab["bottom"]))
        if x1 > x0 and y1 > y0:
            boxes.append((x0, y0, x1, y1))
    boxes.sort(key=lambda b: (b[1] // 24, b[0]))
    return boxes


def bake(cov, boxes, cell, pad):
    """Каждая иконка -> RGBA cell x cell (белая, альфа = coverage)."""
    h = len(cov)
    w = len(cov[0])
    tiles = []
    for (x0, y0, x1, y1) in boxes:
        bw, bh = x1 - x0, y1 - y0
        k = cell / float(max(bw, bh))
        tw = max(1, int(round(bw * k)))
        th = max(1, int(round(bh * k)))
        # поле как float, чтобы ресайз сохранил мягкий край
        field = Image.new("F", (bw, bh))
        fpx = field.load()
        for y in range(bh):
            src = cov[y0 + y]
            for x in range(bw):
                fpx[x, y] = min(1.0, max(0.0, src[x0 + x]))
        field = field.resize((tw, th), Image.LANCZOS)
        vals = getattr(field, "get_flattened_data", None)
        vals = list(vals() if vals else field.getdata())
        alpha = Image.frombytes(
            "L", (tw, th), bytes(min(255, max(0, int(v * 255 + 0.5))) for v in vals))
        tile = Image.new("RGBA", (cell, cell), (255, 255, 255, 0))
        tile.paste(Image.merge("RGBA", (
            Image.new("L", (tw, th), 255),
            Image.new("L", (tw, th), 255),
            Image.new("L", (tw, th), 255),
            alpha,
        )), ((cell - tw) // 2, (cell - th) // 2))
        tiles.append(tile)
    return tiles


def pack(tiles, cols, cell, pad, pow2):
    rows = max(1, int(math.ceil(len(tiles) / float(cols))))
    slot = cell + pad * 2
    sw, sh = cols * slot, rows * slot
    if pow2:
        sw = 1 << (sw - 1).bit_length()
        sh = 1 << (sh - 1).bit_length()
    sheet = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    rects = []
    for i, tile in enumerate(tiles):
        cx = (i % cols) * slot + pad
        cy = (i // cols) * slot + pad
        sheet.paste(tile, (cx, cy), tile)
        # обрезаем прозрачные края ячейки в прямоугольник иконки
        bbox = tile.getbbox()
        if bbox:
            bx0, by0, bx1, by1 = bbox
            rects.append((cx + bx0, cy + by0, bx1 - bx0, by1 - by0))
        else:
            rects.append((cx, cy, cell, cell))
    return sheet, rects, sw, sh


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("atlas", help="MSDF-атлас (PNG)")
    ap.add_argument("-j", "--json", help="метрики msdf-atlas-gen (иначе режем по зазорам)")
    ap.add_argument("-o", "--out", default="icons_atlas.png", help="куда писать лист")
    ap.add_argument("--lua", default="icons_atlas_rects.lua", help="куда писать Lua-таблицу")
    ap.add_argument("--cell", type=int, default=96, help="размер иконки в листе (по умолчанию 96)")
    ap.add_argument("--pad", type=int, default=6, help="отступ между иконками")
    ap.add_argument("--cols", type=int, default=6, help="иконок в ряд")
    ap.add_argument("--no-pow2", dest="pow2", action="store_false", help="не округлять лист до степеней двойки")
    ap.add_argument("--names", help="список имён через запятую (по порядку иконок)")
    ap.add_argument("--map", default="", help="переименование: ragebot=1,antiaim=2,...")
    ap.add_argument("--preview", help="нарисовать превью с номерами иконок")
    a = ap.parse_args()

    img = Image.open(a.atlas)
    cov = cov_from_msdf(img)
    ih, iw = len(cov), len(cov[0])
    boxes = json_boxes(a.json, iw, ih) if a.json else auto_boxes(cov)
    if not boxes:
        sys.exit("не нашёл ни одной иконки — проверь атлас или передай --json с метриками")
    print("иконок найдено: %d (атлас %dx%d)" % (len(boxes), iw, ih))

    names = []
    if a.names:
        names = [n.strip() for n in a.names.split(",")]
    for i in range(len(boxes)):
        names.append(names[i] if i < len(names) and names[i] else "icon_%02d" % (i + 1))
    for item in [s for s in a.map.split(",") if s.strip()]:
        key, _, idx = item.partition("=")
        idx = int(idx) - 1
        if 0 <= idx < len(names):
            names[idx] = key.strip()

    tiles = bake(cov, boxes, a.cell, a.pad)
    sheet, rects, sw, sh = pack(tiles, a.cols, a.cell, a.pad, a.pow2)
    sheet.save(a.out)
    print("лист: %s (%dx%d)" % (a.out, sw, sh))

    for i, ((x, y, w, h), box) in enumerate(zip(rects, boxes)):
        print("  %2d  %-10s  x=%-4d y=%-4d %dx%d" % (i + 1, names[i], x, y, w, h))

    with open(a.lua, "w", encoding="utf-8") as f:
        f.write("-- Сгенерировано tools/bake_msdf_atlas.py из %s\n" % a.atlas)
        f.write("-- 1) загрузи %s в Roblox (Create -> Images) и вставь id в ICON_ATLAS_*\n" % a.out)
        f.write("-- 2) вставь ICON_ATLAS_RECTS ниже в neverlose_gui.lua\n")
        f.write('local ICON_ATLAS_ASSET = "" -- rbxassetid://...\n')
        f.write("local ICON_ATLAS_RECTS = {\n")
        for name, (x, y, w, h) in zip(names, rects):
            f.write('    %-10s = { x = %d, y = %d, w = %d, h = %d, sheet = %d },\n' % (name, x, y, w, h, sw))
        f.write("}\n")
    print("lua: %s" % a.lua)

    if a.preview:
        prev = sheet.copy()
        d = ImageDraw.Draw(prev)
        for i, (x, y, w, h) in enumerate(rects):
            d.rectangle([x, y, x + w, y + h], outline=(255, 0, 0, 255))
            d.text((x + 2, y + 2), str(i + 1), fill=(255, 0, 0, 255))
        prev.save(a.preview)
        print("превью: %s" % a.preview)


if __name__ == "__main__":
    main()
