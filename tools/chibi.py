#!/usr/bin/env python3
"""Programmatic SD/chibi map sprites, 32x32 frames x2 (64x32 sheet). Run from repo root:
   python3 tools/chibi.py   -> assets/units/<클래스>.png, <이름>@<클래스>.png, enemy sheets, missing portraits, build/sprite_sheet.png
Class = silhouette + clothing colour + weapon; unit = hair colour/style + accent."""
from PIL import Image
import os
O = (20, 14, 28, 255)  # outline
def C(*a): return tuple(a) + (255,)
SKIN = C(248, 208, 168); SKIN_D = C(220, 168, 128)
STEEL = C(184, 192, 208); STEEL_D = C(112, 120, 144); GOLD = C(232, 192, 72); WOOD = C(128, 84, 44); WHITE = C(240, 240, 248)

class Px:
    def __init__(s): s.im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); s.p = s.im.load()
    def set(s, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32: s.p[x, y] = c
    def rect(s, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): s.set(x, y, c)
    def ell(s, cx, cy, rx, ry, c):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + .5)) ** 2 + ((y - cy) / (ry + .5)) ** 2 <= 1: s.set(x, y, c)
    def outline(s):
        a = [[s.p[x, y][3] > 0 for y in range(32)] for x in range(32)]
        for x in range(32):
            for y in range(32):
                if not a[x][y] and any(0 <= x + dx < 32 and 0 <= y + dy < 32 and a[x + dx][y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    s.p[x, y] = O

def dark(c, f=.68): return C(*[int(v * f) for v in c[:3]])
def light(c, f=1.3): return C(*[min(255, int(v * f)) for v in c[:3]])

# class -> (body type, cloth colour, weapon, extras)
CLASS = {
    "용병": ("tunic", C(56, 96, 200), "sword", {}), "영웅": ("tunic", C(40, 72, 176), "axe_sword", {"cape": C(200, 40, 40)}),
    "검성": ("tunic", C(176, 48, 64), "sword", {"cape": C(240, 240, 240)}),
    "궁수": ("tunic", C(56, 144, 72), "bow", {}), "스나이퍼": ("tunic", C(40, 112, 56), "bow", {"cape": C(200, 176, 96)}),
    "아머나이트": ("plate", C(64, 96, 184), "lance", {"helm": True}), "제네럴": ("plate", C(48, 64, 144), "lance", {"helm": True, "cape": C(176, 40, 48), "plume": GOLD}),
    "소셜나이트": ("tunic", C(200, 120, 48), "lance", {"mount": "horse"}),
    "비룡기사": ("armor", C(96, 120, 72), "lance", {"mount": "wyvern", "helm": True}),
    "드래곤마스터": ("armor", C(80, 104, 64), "lance", {"mount": "wyvern", "helm": True, "cape": C(144, 40, 40)}),
    "성기사": ("tunic", C(240, 236, 228), "lance", {"mount": "horse", "trim": GOLD}), "팔라딘": ("armor", C(64, 96, 184), "lance", {"mount": "horse"}),
    "발키리": ("robe", C(240, 236, 228), "tome", {"mount": "horse", "trim": GOLD}),
    "그레이트나이트": ("plate", C(56, 80, 160), "lance", {"helm": True, "mount": "horse", "plume": GOLD}), "레인저": ("tunic", C(56, 144, 72), "bow", {"mount": "horse", "cape": C(200, 176, 96)}),
    "메이지나이트": ("robe", C(120, 64, 192), "tome", {"mount": "horse", "trim": GOLD}), "로그": ("tunic", C(64, 112, 64), "dagger", {"hood": C(48, 80, 48)}),
    "드래곤나이트": ("armor", C(112, 136, 88), "lance", {"mount": "wyvern", "helm": True, "cape": C(48, 80, 160)}),
    "도적": ("tunic", C(40, 136, 136), "dagger", {"hood": C(40, 104, 104)}), "어쌔신": ("tunic", C(40, 40, 64), "dagger", {"hood": C(32, 32, 48), "scarf": C(176, 32, 48)}),
    "마법사": ("robe", C(120, 64, 192), "tome", {}), "세이지": ("robe", C(96, 48, 160), "tome", {"trim": GOLD, "cape": C(240, 236, 228)}),
    "시스터": ("robe", C(240, 240, 248), "staff", {"veil": C(64, 96, 192), "trim": C(64, 96, 192)}),
    "비숍": ("robe", C(240, 240, 248), "staff", {"mitre": True, "trim": GOLD}),
    "전사": ("bare", C(168, 72, 40), "axe", {}), "워리어": ("bare", C(144, 56, 32), "axe", {"cape": C(96, 64, 40)}), "버서커": ("bare", C(176, 40, 40), "axe", {}),
}
ENEMY = {  # shadow enemies without user sheets
    "그림자 중갑병": ("plate", "lance", {"helm": True}), "그림자 기병": ("tunic", "lance", {"mount": "horse"}),
    "그림자 비룡": ("armor", "lance", {"mount": "wyvern", "helm": True}), "그림자 기사": ("plate", "lance", {"mount": "horse", "helm": True}),
    "그림자 비룡기사": ("armor", "lance", {"mount": "wyvern", "helm": True}),
}
# unit -> hair colour, style, accent(optional cloth override), base class, promotions
UNITS = {
    "아린": (C(150, 90, 45), "spiky", None, "용병", ["영웅", "검성"]), "노아": (C(34, 34, 52), "short", C(40, 56, 120), "용병", ["영웅", "검성"]),
    "리나": (C(120, 78, 46), "pony", None, "궁수", ["스나이퍼"]), "세라": (C(240, 214, 140), "long", None, "시스터", ["성기사", "비숍", "발키리"]),
    "엘리아": (C(44, 44, 120), "long", None, "마법사", ["세이지"]), "카엘": (C(96, 64, 34), "short", None, "아머나이트", ["제네럴"]),
    "루크": (C(30, 30, 40), "short", None, "도적", ["어쌔신"]), "미라": (C(150, 80, 200), "long", C(176, 64, 144), "마법사", ["세이지"]),
    "보리스": (C(120, 78, 44), "beard", C(110, 72, 40), "전사", ["워리어", "버서커"]), "에일린": (C(236, 206, 120), "pony", C(200, 72, 104), "용병", ["영웅", "검성"]),
    "레온": (C(200, 168, 110), "short", C(56, 128, 120), "아머나이트", ["제네럴"]), "가렌": (C(150, 150, 164), "short", C(96, 80, 64), "용병", ["영웅", "검성"]),
    "카이": (C(64, 96, 54), "spiky", C(96, 120, 48), "궁수", ["스나이퍼"]), "리안": (C(160, 72, 40), "short", C(144, 48, 48), "소셜나이트", ["팔라딘"]),
    "다린": (C(96, 64, 40), "short", None, "용병", ["영웅", "검성"]), "소라": (C(240, 200, 96), "pony", None, "궁수", ["스나이퍼", "레인저"]),
    "엘렌": (C(64, 120, 200), "long", None, "마법사", ["세이지", "메이지나이트"]), "카린": (C(200, 56, 56), "pony", None, "도적", ["어쌔신", "로그"]),
    "브록": (C(80, 64, 48), "beard", None, "아머나이트", ["제네럴", "그레이트나이트"]), "라임": (C(232, 200, 96), "short", None, "소셜나이트", ["팔라딘", "그레이트나이트"]),
    "미르": (C(232, 216, 160), "long", None, "시스터", ["성기사", "비숍"]), "제드": (C(40, 40, 40), "spiky", None, "전사", ["워리어", "버서커"]),
    "카이린": (C(176, 72, 40), "spiky", None, "비룡기사", ["드래곤마스터", "드래곤나이트"]),
    "실라": (C(200, 56, 64), "pony", C(136, 40, 72), "도적", ["어쌔신"]), "아서": (C(224, 192, 110), "short", None, "성기사", []),
    "그렉": (C(72, 56, 40), "beard", C(96, 112, 56), "전사", ["워리어", "버서커"]), "카스": (C(30, 26, 30), "spiky", C(216, 136, 48), "전사", ["버서커", "워리어"]),
    "리엘": (C(120, 200, 176), "pony", None, "비룡기사", ["드래곤마스터"]),
}

def head(s, cx, cy, hair, style, eyes, skin, f, extras):
    r = 7
    s.ell(cx, cy, r, r - 1, skin)                                   # face
    s.rect(cx - r + 1, cy + 3, cx + r - 1, cy + r - 2, skin)
    # hair
    if extras.get("helm"):
        s.ell(cx, cy - 2, r + 1, r - 2, STEEL); s.rect(cx - r - 1, cy - 2, cx + r + 1, cy + 1, STEEL); s.rect(cx - r - 1, cy - 1, cx - r, cy + 4, STEEL_D); s.rect(cx + r, cy - 1, cx + r + 1, cy + 4, STEEL_D)
        s.rect(cx - 5, cy - 1, cx + 5, cy - 1, STEEL_D); s.rect(cx - 1, cy - r - 2, cx + 1, cy - r, extras.get("plume", C(200, 40, 40)))
    elif extras.get("hood") or extras.get("veil"):
        hc = extras.get("hood") or extras.get("veil")
        s.ell(cx, cy - 1, r + 1, r, hc); s.rect(cx - r - 1, cy, cx - r + 1, cy + r + 1, hc); s.rect(cx + r - 1, cy, cx + r + 1, cy + r + 1, hc)
        s.ell(cx, cy + 2, r - 2, r - 3, skin)
        s.rect(cx - 4, cy - 2, cx + 4, cy - 1, hair)                # fringe shows hair colour
        if extras.get("veil"): s.rect(cx - r, cy - 4, cx + r, cy - 4, WHITE)
    else:
        s.ell(cx, cy - 2, r + 1, r - 2, hair); s.rect(cx - r - 1, cy - 2, cx - r + 1, cy + 3, hair); s.rect(cx + r - 1, cy - 2, cx + r + 1, cy + 3, hair)
        s.rect(cx - 5, cy - 1, cx + 5, cy - 1, hair)
        if style == "spiky":
            for i, dx in enumerate((-6, -2, 2, 6)): s.rect(cx + dx, cy - r - 1 + (i % 2), cx + dx + 1, cy - r + 1, hair)
        if style == "long": s.rect(cx - r - 1, cy + 3, cx - r + 1, cy + r + 4, hair); s.rect(cx + r - 1, cy + 3, cx + r + 1, cy + r + 4, hair)
        if style == "pony": s.rect(cx + r, cy - 3, cx + r + 2, cy + 5, hair); s.rect(cx + r + 1, cy - 4, cx + r + 2, cy - 3, light(hair))
        if style == "beard": s.rect(cx - 4, cy + 4, cx + 4, cy + r - 1, hair); s.rect(cx - 2, cy + 3, cx + 2, cy + 3, hair)
        s.rect(cx - 3, cy - r + 1, cx - 1, cy - r + 1, light(hair))  # shine
    if extras.get("mitre"):
        s.rect(cx - 4, cy - r - 4, cx + 4, cy - r + 1, WHITE); s.rect(cx - 3, cy - r - 6, cx + 3, cy - r - 5, WHITE); s.rect(cx - 1, cy - r - 5, cx + 1, cy - r + 1, GOLD)
    # eyes (blink on frame 1 is too twitchy at map scale: keep open)
    for ex in (cx - 3, cx + 2):
        s.rect(ex, cy + 1, ex + 1, cy + 2, eyes); s.set(ex, cy + 1, light(eyes, 2.2) if eyes != C(255, 64, 64) else eyes)
    s.set(cx - 5, cy + 3, SKIN_D if skin == SKIN else skin); s.set(cx + 5, cy + 3, SKIN_D if skin == SKIN else skin)

def body(s, cx, top, btype, cloth, skin, extras, legs=True):
    cd = dark(cloth); trim = extras.get("trim")
    if extras.get("cape"): s.rect(cx - 7, top + 1, cx + 7, top + 11, extras["cape"])
    if btype == "robe":
        for i in range(0, 13):
            w = 4 + i // 2; s.rect(cx - w, top + i, cx + w, top + i, cloth)
        s.rect(cx + 1, top + 2, cx + 7, top + 12, cd) if False else None
        s.rect(cx - 1, top, cx + 1, top + 12, trim or cd)
    else:
        s.rect(cx - 5, top, cx + 5, top + 7, cloth)
        if btype == "plate":
            s.rect(cx - 6, top, cx + 6, top + 13, STEEL); s.rect(cx - 8, top - 1, cx + 8, top + 2, STEEL_D); s.rect(cx - 3, top + 3, cx + 3, top + 6, cloth)
            s.rect(cx - 1, top + 8, cx + 1, top + 13, (0, 0, 0, 0)); s.rect(cx - 6, top + 12, cx + 6, top + 13, STEEL_D)
            if trim: s.rect(cx - 6, top + 7, cx + 6, top + 7, trim)
            legs = False
        if btype == "armor": s.rect(cx - 7, top, cx + 7, top + 2, STEEL); s.rect(cx - 4, top + 3, cx + 4, top + 6, STEEL); s.rect(cx - 3, top + 4, cx + 3, top + 5, cloth)
        if btype == "bare": s.rect(cx - 2, top, cx + 2, top + 3, skin)
        if trim: s.rect(cx - 5, top + 6, cx + 5, top + 6, trim)
        if btype != "plate": s.rect(cx - 5, top + 7, cx + 5, top + 7, WOOD)            # belt
        if legs:
            s.rect(cx - 4, top + 8, cx - 1, top + 11, cd); s.rect(cx + 1, top + 8, cx + 4, top + 11, cd)
            s.rect(cx - 5, top + 12, cx - 1, top + 13, C(72, 48, 32)); s.rect(cx + 1, top + 12, cx + 5, top + 13, C(72, 48, 32))
    arm = skin if btype == "bare" else (STEEL if btype in ("armor", "plate") else cloth)
    s.rect(cx - 8, top + 1, cx - 6, top + 6, arm); s.rect(cx + 6, top + 1, cx + 8, top + 6, arm)
    s.rect(cx - 8, top + 7, cx - 6, top + 8, skin); s.rect(cx + 6, top + 7, cx + 8, top + 8, skin)  # hands
    if extras.get("scarf"): s.rect(cx - 5, top, cx + 5, top + 1, extras["scarf"]); s.rect(cx + 4, top + 1, cx + 6, top + 4, extras["scarf"])

def weapon(s, kind, hx, hy, f):
    up = -1 if f else 0; hy += up
    if kind in ("sword", "axe_sword"):
        s.rect(hx, hy - 11, hx + 1, hy - 1, WHITE); s.rect(hx + 1, hy - 11, hx + 1, hy - 1, STEEL); s.rect(hx - 2, hy, hx + 3, hy, GOLD); s.rect(hx, hy + 1, hx + 1, hy + 2, WOOD)
    elif kind == "dagger":
        s.rect(hx, hy - 5, hx + 1, hy - 1, WHITE); s.rect(hx - 1, hy, hx + 2, hy, GOLD)
    elif kind == "lance":
        s.rect(hx, hy - 17, hx, hy + 9, WOOD); s.rect(hx - 1, hy - 20, hx + 1, hy - 17, WHITE); s.set(hx, hy - 21, WHITE)
    elif kind == "axe":
        s.rect(hx, hy - 12, hx + 1, hy + 6, WOOD); s.ell(hx + 4, hy - 9, 3, 4, STEEL); s.rect(hx + 2, hy - 12, hx + 2, hy - 6, STEEL_D)
    elif kind == "bow":
        bx = hx
        for i in range(-10, 11):
            s.set(bx - (3 - abs(i) // 3), hy + i - 2, WOOD)
        s.rect(bx, hy - 12, bx, hy + 8, C(220, 220, 220))
    elif kind == "tome":
        s.rect(hx - 1, hy - 3, hx + 4, hy + 2, C(160, 40, 40)); s.rect(hx, hy - 2, hx + 3, hy + 1, C(240, 220, 180)); s.set(hx + 5, hy - 4 + up, C(255, 240, 120))
    elif kind == "staff":
        s.rect(hx, hy - 14, hx, hy + 9, WOOD); s.ell(hx, hy - 16, 2, 2, GOLD); s.set(hx, hy - 16, C(160, 230, 255))

def horse(s, col, f):
    hd = dark(col)
    s.ell(17, 23, 11, 4, col); s.rect(3, 15, 7, 22, col); s.ell(4, 15, 3, 2, col)   # body, neck, head
    s.rect(1, 15, 2, 17, col); s.set(3, 14, O); s.rect(7, 14, 8, 21, C(96, 64, 40))   # snout, mane
    for x in (8, 12, 22, 26): s.rect(x, 27, x + 1, 31 - (1 if f and x in (12, 26) else 0), hd)
    s.rect(28, 20, 30, 26, C(96, 64, 40))                                             # tail
def wyvern(s, col, f):
    cd = dark(col); wing = dark(col, .55)
    wy = 1 if f else 0
    for i in range(10):  # wings
        s.rect(0 + i // 2, 4 + i + wy, 10, 4 + i + wy, wing); s.rect(22, 4 + i + wy, 31 - i // 2, 4 + i + wy, wing)
    s.ell(16, 23, 10, 5, col); s.ell(5, 16, 4, 3, col); s.rect(4, 17, 9, 22, col)
    s.set(3, 15, C(255, 220, 64)); s.rect(0, 17, 2, 18, col)                         # eye, snout
    s.rect(26, 22, 31, 25, cd); s.rect(9, 27, 11, 31, cd); s.rect(20, 27, 22, 31, cd); s.rect(16, 25, 25, 26, light(col))

def draw(cls_body, cloth, wkind, extras, hair, style, f, dark_mode=False):
    s = Px()
    skin = C(72, 56, 88) if dark_mode else SKIN
    eyes = C(255, 64, 64) if dark_mode else C(30, 30, 60)
    m = extras.get("mount")
    if m == "horse": horse(s, C(56, 40, 64) if dark_mode else C(236, 228, 214), f)
    if m == "wyvern": wyvern(s, C(72, 56, 96) if dark_mode else C(96, 140, 80), f)
    if m:   # rider: smaller torso above the mount
        body(s, 16, 12, cls_body, cloth, skin, extras, legs=False)
        weapon(s, wkind, 24, 19, f); head(s, 16, 6, hair, style, eyes, skin, f, extras)
    else:
        body(s, 16, 16, cls_body, cloth, skin, extras)
        if wkind == "bow": weapon(s, "bow", 7, 22, f)
        elif wkind == "tome": weapon(s, "tome", 21, 22, f)
        else: weapon(s, "lance" if wkind == "lance" else ("sword" if wkind == "axe_sword" else wkind), 24, 23, f)
        head(s, 16, 9, hair, style, eyes, skin, f, extras)
    s.outline(); return s.im

def sheet(frames):
    sh = Image.new('RGBA', (32 * len(frames), 32))
    for i, fr in enumerate(frames): sh.paste(fr, (32 * i, 0))
    return sh

def class_sheet(cname, hair=C(70, 52, 40), style="short", cloth=None):
    b, cl, w, ex = CLASS[cname]
    return sheet([draw(b, cloth or cl, w, ex, hair, style, f) for f in (0, 1)])

def enemy_sheet(n):
    b, w, ex = ENEMY[n]; return sheet([draw(b, C(72, 40, 104), w, ex, C(40, 24, 56), "short", f, True) for f in (0, 1)])

def portrait(n):
    """Pixel bust 128x128 (4x of a 32px head-and-shoulders), matches the existing pixel portraits."""
    hair, style, acc, base, _ = UNITS[n]
    b, cl, w, ex = CLASS[base]
    s = Px(); ex2 = {k: v for k, v in ex.items() if k != "mount"}
    s.rect(4, 24, 27, 31, acc or cl)
    if b == "armor": s.rect(2, 23, 29, 26, STEEL)
    s.rect(13, 21, 18, 24, SKIN)
    # big head: draw at 2x by sampling a head-only sprite
    h = Px(); head(h, 16, 12, hair, style, C(30, 30, 60), SKIN, 0, ex2)
    hb = h.im.crop((4, 1, 28, 22)).resize((24 * 1, 21 * 1))
    s.im.alpha_composite(hb, (4, 0))
    bg = Image.new('RGBA', (32, 32), C(*[int(v * .45) + 30 for v in (acc or cl)[:3]]))
    bg.alpha_composite(s.im); return bg.resize((128, 128), Image.NEAREST)

if __name__ == "__main__":
    os.makedirs("assets/units", exist_ok=True); prev = []
    for c in CLASS: class_sheet(c).save("assets/units/%s.png" % c)
    for n, (hair, style, acc, base, promos) in UNITS.items():
        BR = {"용병": ["영웅", "검성"], "궁수": ["스나이퍼", "레인저"], "시스터": ["성기사", "비숍"], "마법사": ["세이지", "메이지나이트"],
              "아머나이트": ["제네럴", "그레이트나이트"], "소셜나이트": ["팔라딘", "그레이트나이트"], "비룡기사": ["드래곤마스터", "드래곤나이트"],
              "도적": ["어쌔신", "로그"], "전사": ["워리어", "버서커"]}
        for c in [base] + list(dict.fromkeys(promos + BR.get(base, []))):
            cloth = acc if c == base and acc else None
            im = class_sheet(c, hair, style, cloth); im.save("assets/units/%s@%s.png" % (n, c))
            if c == base: prev.append((n, im))
    for n in ENEMY: enemy_sheet(n).save("assets/units/%s.png" % n)
    for n in UNITS:
        if not os.path.exists("assets/portraits/%s.png" % n): portrait(n).save("assets/portraits/%s.png" % n); print("portrait", n)
    # preview sheet (x4)
    rows = prev + [(c, class_sheet(c)) for c in CLASS] + [(n, enemy_sheet(n)) for n in ENEMY]
    cols = 8; W = 64 * 4 + 8
    out = Image.new('RGBA', (cols * W, ((len(rows) + cols - 1) // cols) * (32 * 4 + 8)), C(48, 56, 72))
    for i, (n, im) in enumerate(rows):
        out.alpha_composite(im.resize((256, 128), Image.NEAREST), ((i % cols) * W, (i // cols) * 136))
    os.makedirs("build", exist_ok=True); out.save("build/sprite_sheet.png"); print(len(rows), "previews")
