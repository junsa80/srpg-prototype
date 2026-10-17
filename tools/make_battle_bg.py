#!/usr/bin/env python3
"""Original 240x160 pixel battle backdrops (GBA screen size) + 64x16 terrain platforms. Drawn procedurally from
scratch (no ripped art). Shown at an integer scale (3x on a 720-wide screen). Units' feet stand at native y≈128."""
import os, random, math
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 240, 160
GROUND_Y = 104

def bands(dr, cols, y0, y1):
    n = len(cols); h = (y1 - y0) / n
    for i, c in enumerate(cols):
        dr.rectangle([0, int(y0 + i * h), W, int(y0 + (i + 1) * h)], fill=c)
    # 2px dither seams between bands (GBA-style)
    for i in range(1, n):
        y = int(y0 + i * h)
        for x in range(0, W, 2): dr.point((x + (y % 2), y - 1), fill=cols[i])

def cloud(dr, x, y, s, c=(240, 244, 255), sh=(200, 214, 240)):
    for dx, dy, r in [(0, 0, 6), (7, -3, 7), (15, 0, 6), (8, 2, 6)]:
        dr.ellipse([x + dx * s - r * s, y + dy * s - r * s * 0.7, x + dx * s + r * s, y + dy * s + r * s * 0.7], fill=c)
    dr.rectangle([x - 5 * s, y + 2 * s, x + 20 * s, y + 4 * s], fill=sh)

def hills(dr, y, amp, col, seed, step=1.0):
    rnd = random.Random(seed); ph = rnd.random() * 6
    pts = [(0, H)]
    for x in range(0, W + 8, 4):
        pts.append((x, y - amp * (0.5 + 0.5 * math.sin(x / 23.0 * step + ph)) - amp * 0.3 * math.sin(x / 9.0 + ph * 2)))
    pts.append((W, H)); dr.polygon(pts, fill=col)

def grass_ground(dr, rnd, base, dark, light, y0=GROUND_Y):
    dr.rectangle([0, y0, W, H], fill=base)
    for y in range(y0, H, 3):
        for x in range(rnd.randrange(0, 6), W, rnd.randrange(5, 11)):
            dr.point((x, y), fill=dark if rnd.random() < 0.6 else light)
    for _ in range(60):   # tufts
        x, y = rnd.randrange(W), rnd.randrange(y0 + 4, H)
        dr.line([(x, y), (x + 1, y - 2)], fill=dark); dr.line([(x + 2, y), (x + 2, y - 3)], fill=dark)

def tree_round(dr, x, y, s, c1, c2, trunk=(96, 60, 36)):
    dr.rectangle([x - 1, y, x + 1, y + 6 * s], fill=trunk)
    dr.ellipse([x - 7 * s, y - 9 * s, x + 7 * s, y + 3 * s], fill=c2)
    dr.ellipse([x - 6 * s, y - 10 * s, x + 4 * s, y], fill=c1)

def pine(dr, x, y, h, c1, c2, snow=None):
    for i in range(4):
        w = (i + 1) * h // 6; yy = y - h + i * h // 4
        dr.polygon([(x, yy), (x - w, yy + h // 3), (x + w, yy + h // 3)], fill=c2 if i % 2 else c1)
        if snow: dr.polygon([(x, yy), (x - w // 2, yy + h // 7), (x + w // 2, yy + h // 7)], fill=snow)
    dr.rectangle([x - 1, y - 2, x + 1, y + 3], fill=(80, 52, 36))

SKY = [(56, 96, 184), (72, 116, 204), (96, 144, 220), (128, 172, 232), (164, 200, 240)]

def plain():
    rnd = random.Random(1); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, SKY, 0, GROUND_Y); cloud(dr, 30, 22, 1); cloud(dr, 150, 14, 1); cloud(dr, 205, 40, 0.7)
    hills(dr, 86, 14, (110, 150, 190), 3); hills(dr, 98, 10, (72, 132, 88), 5, 1.6)
    grass_ground(dr, rnd, (100, 168, 72), (72, 136, 56), (140, 200, 96))
    return im

def forest():
    rnd = random.Random(2); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, SKY[1:], 0, 70)
    hills(dr, 64, 10, (64, 108, 96), 7)
    for i in range(14): tree_round(dr, i * 19 + rnd.randrange(-3, 4), 80 + rnd.randrange(-6, 4), 1.3, (44, 112, 60), (28, 78, 44))
    for i in range(10): tree_round(dr, i * 26 + 10, 98 + rnd.randrange(-4, 3), 1.6, (60, 140, 72), (34, 96, 52))
    grass_ground(dr, rnd, (76, 140, 60), (52, 108, 44), (110, 172, 80))
    return im

def fort():
    rnd = random.Random(3); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, SKY, 0, GROUND_Y); cloud(dr, 180, 18, 1)
    st, st2, st3 = (150, 140, 132), (112, 104, 100), (184, 176, 166)
    dr.rectangle([0, 40, W, GROUND_Y], fill=st)
    for x in range(0, W, 16): dr.rectangle([x, 32, x + 9, 40], fill=st)   # crenellations
    for y in range(44, GROUND_Y, 8):
        off = 8 if (y // 8) % 2 else 0
        dr.line([(0, y), (W, y)], fill=st2)
        for x in range(off, W, 16): dr.line([(x, y), (x, y + 7)], fill=st2)
    for x in range(0, W, 16): dr.line([(x + 1, 41), (x + 1, GROUND_Y)], fill=st3) if False else None
    for tx in (30, 200):   # towers
        dr.rectangle([tx - 14, 18, tx + 14, GROUND_Y], fill=st2); dr.rectangle([tx - 12, 20, tx + 12, GROUND_Y], fill=st)
        for x in range(tx - 14, tx + 15, 8): dr.rectangle([x, 12, x + 4, 18], fill=st2)
        dr.rectangle([tx - 3, 40, tx + 3, 52], fill=(40, 36, 48))
        dr.polygon([(tx, 0), (tx, 12), (tx + 12, 6)], fill=(200, 48, 48)) if tx == 200 else None
    dr.rectangle([102, 62, 138, GROUND_Y], fill=(52, 40, 36)); dr.ellipse([102, 50, 138, 76], fill=(52, 40, 36))   # gate
    for x in range(106, 138, 6): dr.line([(x, 60), (x, GROUND_Y)], fill=(92, 72, 52))
    dr.rectangle([0, GROUND_Y, W, H], fill=(150, 124, 92))
    for _ in range(300): dr.point((rnd.randrange(W), rnd.randrange(GROUND_Y, H)), fill=(122, 100, 74) if rnd.random() < 0.7 else (176, 150, 112))
    return im

def castle():
    rnd = random.Random(4); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    dr.rectangle([0, 0, W, GROUND_Y], fill=(60, 54, 76))
    for y in range(0, GROUND_Y, 10):
        off = 10 if (y // 10) % 2 else 0
        dr.line([(0, y), (W, y)], fill=(44, 40, 58))
        for x in range(off, W, 20): dr.line([(x, y), (x, y + 9)], fill=(44, 40, 58))
    for px in (20, 80, 160, 220):   # pillars
        dr.rectangle([px - 9, 0, px + 9, GROUND_Y], fill=(132, 124, 148)); dr.rectangle([px - 9, 0, px - 6, GROUND_Y], fill=(170, 164, 186))
        dr.rectangle([px + 6, 0, px + 9, GROUND_Y], fill=(96, 88, 112)); dr.rectangle([px - 12, GROUND_Y - 6, px + 12, GROUND_Y], fill=(112, 104, 128))
    for bx in (50, 190):   # banners
        dr.rectangle([bx - 10, 10, bx + 10, 66], fill=(168, 32, 48)); dr.polygon([(bx - 10, 66), (bx, 74), (bx + 10, 66)], fill=(168, 32, 48))
        dr.rectangle([bx - 10, 10, bx + 10, 13], fill=(232, 184, 48)); dr.ellipse([bx - 5, 30, bx + 5, 40], fill=(232, 184, 48))
    for x in (118, 122):   # window light
        pass
    dr.rectangle([108, 14, 132, 60], fill=(36, 32, 52)); dr.ellipse([108, 6, 132, 26], fill=(36, 32, 52))
    dr.rectangle([112, 16, 128, 58], fill=(120, 150, 210)); dr.line([(120, 12), (120, 58)], fill=(36, 32, 52)); dr.line([(112, 34), (128, 34)], fill=(36, 32, 52))
    for y in range(GROUND_Y, H, 8):   # floor tiles
        for x in range((y // 8) % 2 * 8 - 16, W, 16):
            dr.rectangle([x, y, x + 7, y + 7], fill=(104, 96, 116)); dr.rectangle([x + 8, y, x + 15, y + 7], fill=(88, 80, 100))
    dr.rectangle([80, GROUND_Y, 160, H], fill=(150, 36, 52)); dr.rectangle([84, GROUND_Y, 156, H], fill=(176, 48, 64))   # carpet
    dr.line([(84, GROUND_Y), (84, H)], fill=(232, 184, 48)); dr.line([(156, GROUND_Y), (156, H)], fill=(232, 184, 48))
    return im

def village():
    rnd = random.Random(5); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, SKY, 0, GROUND_Y); cloud(dr, 100, 16, 1)
    hills(dr, 82, 10, (108, 150, 184), 9)
    for i, hx in enumerate((16, 74, 138, 196)):
        wall = [(232, 216, 176), (220, 196, 150)][i % 2]; roof = [(184, 64, 48), (140, 84, 52)][i % 2]
        dr.rectangle([hx, 70, hx + 36, GROUND_Y], fill=wall); dr.rectangle([hx, 70, hx + 2, GROUND_Y], fill=tuple(c - 30 for c in wall))
        dr.polygon([(hx - 5, 72), (hx + 18, 52), (hx + 41, 72)], fill=roof); dr.line([(hx - 5, 72), (hx + 41, 72)], fill=tuple(c - 50 for c in roof), width=2)
        dr.rectangle([hx + 14, 86, hx + 22, GROUND_Y], fill=(104, 64, 40)); dr.rectangle([hx + 26, 78, hx + 32, 84], fill=(96, 140, 200))
        dr.rectangle([hx + 4, 78, hx + 10, 84], fill=(96, 140, 200))
    for x in range(0, W, 6): dr.rectangle([x, 96, x + 1, GROUND_Y + 2], fill=(150, 104, 60))   # fence
    dr.line([(0, 99), (W, 99)], fill=(150, 104, 60))
    grass_ground(dr, rnd, (112, 168, 76), (84, 140, 60), (150, 200, 100))
    dr.polygon([(90, H), (110, GROUND_Y), (130, GROUND_Y), (150, H)], fill=(196, 168, 120))   # path
    return im

def desert():
    rnd = random.Random(6); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, [(120, 160, 220), (156, 188, 232), (204, 212, 228), (240, 224, 196)], 0, GROUND_Y)
    dr.ellipse([180, 10, 204, 34], fill=(255, 248, 210))
    hills(dr, 88, 16, (212, 172, 112), 11, 0.8); hills(dr, 100, 10, (228, 192, 128), 13, 1.2)
    dr.rectangle([0, GROUND_Y, W, H], fill=(232, 200, 136))
    for y in range(GROUND_Y + 3, H, 6):
        for x in range(0, W, 2): dr.point((x, y + int(2 * math.sin(x / 11 + y))), fill=(208, 172, 108))
    for cx in (40, 210): dr.rectangle([cx, 84, cx + 3, 102], fill=(72, 140, 72)); dr.rectangle([cx - 4, 90, cx - 2, 96], fill=(72, 140, 72)); dr.rectangle([cx + 5, 88, cx + 7, 94], fill=(72, 140, 72))
    return im

def snow():
    rnd = random.Random(7); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, [(120, 136, 168), (148, 164, 192), (176, 190, 214), (204, 214, 232)], 0, GROUND_Y)
    for mx, mh in ((40, 60), (120, 74), (200, 56)):
        dr.polygon([(mx - 60, GROUND_Y), (mx, GROUND_Y - mh - 20), (mx + 60, GROUND_Y)], fill=(132, 144, 176))
        dr.polygon([(mx - 16, GROUND_Y - mh + 6), (mx, GROUND_Y - mh - 20), (mx + 16, GROUND_Y - mh + 6)], fill=(244, 248, 255))
    for i in range(12): pine(dr, i * 21 + rnd.randrange(-3, 4), 102, 26 + rnd.randrange(-4, 6), (40, 96, 80), (28, 72, 64), (236, 244, 252))
    dr.rectangle([0, GROUND_Y, W, H], fill=(232, 238, 248))
    for _ in range(260): dr.point((rnd.randrange(W), rnd.randrange(GROUND_Y, H)), fill=(196, 208, 228))
    for _ in range(70): dr.point((rnd.randrange(W), rnd.randrange(0, GROUND_Y)), fill=(255, 255, 255))   # falling snow
    return im

def mountain():
    rnd = random.Random(8); im = Image.new("RGB", (W, H)); dr = ImageDraw.Draw(im)
    bands(dr, SKY, 0, GROUND_Y); cloud(dr, 60, 16, 0.8)
    for mx, mh, c in ((30, 70, (116, 104, 96)), (120, 86, (140, 124, 108)), (210, 64, (124, 110, 98))):
        dr.polygon([(mx - 70, GROUND_Y), (mx, GROUND_Y - mh), (mx + 70, GROUND_Y)], fill=c)
        dr.polygon([(mx, GROUND_Y - mh), (mx + 70, GROUND_Y), (mx + 20, GROUND_Y)], fill=tuple(v - 24 for v in c))
    dr.rectangle([0, GROUND_Y, W, H], fill=(150, 128, 100))
    for _ in range(40):
        x, y = rnd.randrange(W), rnd.randrange(GROUND_Y + 4, H)
        dr.ellipse([x, y, x + 6, y + 3], fill=(120, 104, 86)); dr.point((x + 1, y), fill=(184, 164, 136))
    return im

# -------- platforms: 64x16 slab, top surface + front face, dark outline --------
PLAT = {  # top, top-dark, face, face-dark
 "grass": ((112, 184, 80), (80, 148, 60), (128, 96, 64), (92, 66, 44)),
 "forest": ((72, 140, 64), (48, 108, 48), (112, 84, 56), (80, 58, 40)),
 "stone": ((176, 168, 160), (140, 132, 126), (120, 112, 108), (88, 82, 80)),
 "floor": ((128, 120, 144), (100, 92, 116), (84, 76, 100), (60, 54, 74)),
 "sand": ((236, 208, 144), (212, 180, 116), (184, 148, 96), (150, 118, 76)),
 "snow": ((244, 248, 255), (208, 218, 236), (150, 162, 190), (116, 128, 160)),
 "wood": ((176, 128, 80), (140, 96, 60), (112, 76, 48), (80, 54, 34)),
 "rock": ((164, 144, 116), (132, 114, 92), (112, 96, 78), (84, 72, 58)),
}
def platform(kind):
    top, tdk, face, fdk = PLAT[kind]; im = Image.new("RGBA", (64, 16), (0, 0, 0, 0)); dr = ImageDraw.Draw(im)
    K = (24, 16, 32, 255)
    dr.rounded_rectangle([0, 2, 63, 15], radius=4, fill=K)
    dr.rounded_rectangle([1, 3, 62, 14], radius=3, fill=face)
    dr.rectangle([2, 12, 61, 13], fill=fdk)
    dr.rounded_rectangle([1, 3, 62, 9], radius=3, fill=top)
    dr.line([(3, 9), (60, 9)], fill=tdk)
    rnd = random.Random(kind)
    for _ in range(26):
        x, y = rnd.randrange(4, 60), rnd.randrange(4, 9)
        dr.point((x, y), fill=tdk)
    if kind == "wood":
        for x in range(8, 60, 9): dr.line([(x, 3), (x, 14)], fill=fdk)
    if kind in ("stone", "floor"):
        for x in range(10, 60, 12): dr.line([(x, 10), (x, 13)], fill=fdk)
    dr.line([(4, 3), (59, 3)], fill=tuple(min(255, c + 30) for c in top[:3]))
    return im

def main():
    out = os.path.join(ROOT, "assets/battle/bg"); os.makedirs(out, exist_ok=True)
    bgs = {"plain": plain, "forest": forest, "fort": fort, "castle": castle, "village": village, "desert": desert, "snow": snow, "mountain": mountain}
    for k, f in bgs.items(): f().save(os.path.join(out, k + ".png"))
    pd = os.path.join(ROOT, "assets/battle/platform"); os.makedirs(pd, exist_ok=True)
    for k in PLAT: platform(k).save(os.path.join(pd, k + ".png"))
    # contact sheet at 2x
    sh = Image.new("RGB", (4 * 480 + 50, 2 * 320 + 160), (16, 18, 32))
    for i, k in enumerate(bgs):
        im = Image.open(os.path.join(out, k + ".png")).resize((480, 320), Image.NEAREST)
        sh.paste(im, (10 + (i % 4) * 490, 10 + (i // 4) * 330))
    for i, k in enumerate(PLAT):
        im = Image.open(os.path.join(pd, k + ".png")).resize((192, 48), Image.NEAREST)
        sh.paste(im, (10 + i * 240, 690), im)
    sh.save(os.path.join(ROOT, "build/battle_bg_sheet.png"))
    print("bg", len(bgs), "platforms", len(PLAT))
main()
