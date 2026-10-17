#!/usr/bin/env python3
"""Sample dominant hair + outfit colours from assets/portraits/<name>.png for every chibi.py UNITS entry.
Writes tools/portrait_palette.json, which chibi.py uses so map/battle sprites match the portraits.
Run from repo root: python3 tools/portrait_palette.py && python3 tools/chibi.py"""
from PIL import Image
import json, os, sys, colorsys
sys.path.insert(0, os.path.dirname(__file__))

def is_skin(c):
    r, g, b = c; h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return r > g > b and 0.02 <= h <= 0.11 and 0.18 <= s <= 0.6 and v > 0.55

def dominant(im, box, bg, avoid_skin=True, min_sat=0.0, sat_w=1.5):
    """Most representative colour of a region: big clusters win, saturated ones get a bonus (shadows/outline lose)."""
    reg = im.crop(box).convert('RGB').quantize(colors=12, method=Image.Quantize.MEDIANCUT)
    pal = reg.getpalette(); best = None
    for n, idx in reg.getcolors():
        c = tuple(pal[idx * 3: idx * 3 + 3])
        if sum(abs(a - b) for a, b in zip(c, bg)) < 60: continue   # background
        if max(c) < 24: continue                                   # outline
        if avoid_skin and is_skin(c): continue
        h, s, v = colorsys.rgb_to_hsv(*[x / 255 for x in c])
        if s < min_sat and v < 0.7: continue
        score = n * (0.35 + sat_w * s) * (0.4 + v)
        if best is None or score > best[0]: best = (score, c)
    return best[1] if best else None

def sprite_tone(c, kind):
    """Portrait shading is dark; lift to the brighter flat tones the 32px sprites use (neutrals stay neutral)."""
    if c is None: return None
    h, s, v = colorsys.rgb_to_hsv(*[x / 255 for x in c])
    if kind == "hair":
        v = min(1.0, v * 1.45 + 0.05) if v > 0.16 else v * 1.2      # black hair stays black
        s = min(1.0, s * 1.15)
    else:
        if s < 0.14: v = min(1.0, max(v * 1.3, 0.55))               # grey/white cloth or steel
        else: v = min(1.0, max(v * 1.5, 0.62)); s = min(1.0, max(s, 0.45))
    return [int(round(x * 255)) for x in colorsys.hsv_to_rgb(h, s, v)]

def sample(path):
    im = Image.open(path).convert('RGB').resize((128, 128))
    corners = [im.getpixel(p) for p in ((2, 2), (125, 2), (2, 60), (125, 60))]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    hair = dominant(im, (34, 6, 94, 34), bg)                    # crown of the head
    outfit = dominant(im, (16, 100, 112, 127), bg, min_sat=0.12)  # chest / shoulders
    return hair, outfit

# Hand fixes where the automatic sample grabs a strap/veil/shadow instead of the hair or main outfit (checked on build/palette_compare.png).
OVERRIDE = {
    "노아": {"outfit": [44, 60, 120]},    # navy coat (sample hit the leather strap)
    "루크": {"outfit": [64, 120, 64]},    # green hood/cloak
    "레온": {"outfit": [56, 128, 120]},   # teal plate trim
    "미르": {"hair": [232, 216, 160]},    # cream hair (sample hit the blue veil)
    "세라": {"hair": [236, 204, 124]},    # golden hair
    "아서": {"hair": [216, 200, 160]},    # greying gold
    "보리스": {"outfit": [124, 84, 52]},  # brown leather (lift made it orange)
    "리안": {"outfit": [160, 52, 52]},    # crimson cape/cloth
    "리나": {"outfit": [76, 124, 60]},    # green hunter's tunic
    "가렌": {"outfit": [112, 86, 62]},    # leather vest
    "카린": {"outfit": [52, 100, 68]},    # dark green scarf/cloak
    "브록": {"hair": [112, 80, 56]},      # dark brown hair + beard
}

if __name__ == "__main__":
    import chibi
    out = {}
    for n in chibi.UNITS:
        p = "assets/portraits/%s.png" % n
        if not os.path.exists(p): continue
        hair, outfit = sample(p)
        out[n] = {"hair": sprite_tone(hair, "hair"), "outfit": sprite_tone(outfit, "outfit"), "raw": [hair, outfit]}
        out[n].update(OVERRIDE.get(n, {}))
        print(n, out[n]["hair"], out[n]["outfit"])
    json.dump(out, open("tools/portrait_palette.json", "w"), ensure_ascii=False, indent=1)
