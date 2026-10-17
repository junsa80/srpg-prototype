#!/usr/bin/env python3
"""Original 16x16 GBA-FE-spirit item icons (drawn from scratch, no ripped assets).
Writes assets/icons/<id>.png (16x16 RGBA) + build/icons_sheet.png (preview, 4x).
Shapes are rasterised in a rotated (u along the weapon, v across) frame -> diagonal weapons like GBA FE,
then auto-outlined. Tier = blade palette/detail: iron grey, steel darker+broader, silver bright+shine,
killer red edge+gem, brave doubled. Sword/lance/axe sit on their triangle tile (blue/green/red)."""
import math, os, json
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
K = (24, 16, 32, 255)
def C(*v): return tuple(v) + (255,) if len(v) == 3 else tuple(v)
BLADE = {  # l, m, d
 "iron":   [C(232,232,240), C(168,172,184), C(100,104,120)],
 "steel":  [C(168,184,210), C(104,120,150), C(60,70,98)],
 "silver": [C(255,255,255), C(214,228,248), C(140,164,206)],
 "killer": [C(236,236,244), C(172,176,188), C(208,40,48)],
 "brave":  [C(255,248,200), C(226,214,168), C(150,130,90)],
 "eff":    [C(220,248,220), C(120,196,140), C(52,120,76)],
 "wind":   [C(210,255,244), C(96,208,184), C(36,132,120)],
 "boss":   [C(214,150,255), C(132,64,176), C(70,24,104)],
}
G1, G2 = C(248,208,72), C(184,124,24)       # gold
H1, H2 = C(170,110,56), C(108,62,30)        # wood/leather
RED, RED2 = C(232,56,56), C(150,24,40)
WHITE = C(250,250,250)
TRI = {"sword": (56,120,248), "axe": (232,56,48), "lance": (40,184,80)}

class Cv:
    def __init__(s): s.p = {}
    def set(s, x, y, c):
        if 0 <= x < 16 and 0 <= y < 16: s.p[(x, y)] = c
    def shape(s, fn, O=(1.5, 14.5), d=(1, -1)):
        """fn(u, v) -> colour or None, u along d from O (pixel units along the diagonal), v across (+ = down-right)."""
        n = math.hypot(*d); dx, dy = d[0] / n, d[1] / n; nx, ny = -dy, dx
        for y in range(16):
            for x in range(16):
                px, py = x + 0.5 - O[0], y + 0.5 - O[1]
                u, v = px * dx + py * dy, px * nx + py * ny
                c = fn(u, v)
                if c: s.p[(x, y)] = c
    def outline(s):
        add = {}
        for (x, y) in s.p:
            for ox, oy in ((1,0),(-1,0),(0,1),(0,-1)):
                q = (x + ox, y + oy)
                if q not in s.p and 0 <= q[0] < 16 and 0 <= q[1] < 16: add[q] = K
        s.p.update(add)
    def img(s, tile=None):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        if tile:
            base = tuple(int(c * 0.62) for c in tile) + (255,)
            edge = tuple(min(255, int(c + (255 - c) * 0.35)) for c in tile) + (255,)
            for y in range(16):
                for x in range(16):
                    corner = (x in (0, 15) and y in (0, 15))
                    if corner: continue
                    im.putpixel((x, y), edge if x in (0, 15) or y in (0, 15) else base)
            # soft inner bevel
            for i in range(1, 15): im.putpixel((i, 1), tuple(int(c * 0.8) for c in tile) + (255,))
        for (x, y), c in s.p.items(): im.putpixel((x, y), c)
        return im

def blade_col(pal, v, half):
    if v < -half * 0.25: return pal[0]
    if v > half * 0.45: return pal[2]
    return pal[1]

# ---------------- swords ----------------
def sword(tier="iron", length=17.2, half=1.05, guard=2.6, dagger=False, rapier=False, double=False, gem=None):
    cv = Cv(); pal = BLADE[tier]
    def f(u, v, off=0.0):
        vv = v - off
        if u < 0.9: return G2 if abs(v) < 0.75 else None                    # pommel
        if u < 3.3: return (H1 if v < 0 else H2) if abs(v) < 0.6 else None  # grip
        if u < 4.4:                                                          # guard (perpendicular bar)
            if abs(v) < guard: return G1 if v < 0.3 else G2
            return None
        for o in ([-1.6, 1.6] if double else [0.0]):
            vv = v - o; h = half * (0.7 if double else 1.0)
            if rapier: h = 0.55
            tipw = h * max(0.0, (length - u)) / 1.6
            if 4.4 <= u < length and abs(vv) < min(h, tipw + 0.25):
                return blade_col(pal, vv, h)
        return None
    cv.shape(f, O=(1.0, 15.0))
    if gem: cv.set(3, 11, gem) if not dagger else cv.set(4, 10, gem)
    cv.outline(); return cv

def sword_set():
    out = {}
    out["sword_iron"] = sword("iron")
    out["sword_steel"] = sword("steel", half=1.45, guard=2.8)
    s = sword("silver", guard=2.9); s.set(11, 4, WHITE); s.set(12, 3, WHITE); out["sword_silver"] = s
    out["sword_killer"] = sword("killer", guard=2.9, gem=RED)
    out["sword_brave"] = sword("brave", double=True, guard=3.6, length=16.6)
    out["dagger_iron"] = sword("iron", length=12.0, half=1.0, guard=1.9, dagger=True)
    out["dagger_steel"] = sword("steel", length=13.0, half=1.3, guard=2.1, dagger=True)
    r = sword("silver", length=17.6, rapier=True, guard=1.6)
    for q in [(2, 10), (3, 9), (1, 11)]: r.p[q] = G1
    r.outline(); out["rapier"] = r
    out["armorslayer"] = sword("eff", half=1.7, guard=3.0, length=16.4)
    w = sword("wind", guard=2.6); [w.set(x, y, WHITE) for x, y in [(9, 6), (12, 3)]]; out["windsword"] = w
    return out

# ---------------- lances ----------------
def lance(tier="iron", start=0.0, head=4.6, hw=1.5, length=17.4, tassel=False, hook=False, double=False):
    cv = Cv(); pal = BLADE[tier]
    def f(u, v):
        hs = length - head
        if hs <= u < length:
            t = (u - hs) / head                      # 0 base .. 1 tip
            w = hw * (math.sin(min(1.0, t * 1.6 + 0.15) * math.pi * 0.5) if t < 0.55 else (1 - t) / 0.45)
            if double:
                for o in (-1.3, 1.3):
                    if abs(v - o) < max(0.35, w * 0.7) : return blade_col(pal, v - o, w * 0.7 + 0.01)
            elif abs(v) < max(0.4, w): return blade_col(pal, v, w + 0.01)
        if hook and hs - 0.2 <= u < hs + 1.8 and 0.6 < -v < 2.6 and u - hs < 2.4 + v * 0.0: return pal[1]
        if hs - 0.9 <= u < hs: return G1 if abs(v) < 1.15 else None   # collar
        if start <= u < hs - 0.9 and abs(v) < 0.55: return H1 if v < 0 else H2
        return None
    cv.shape(f, O=(0.5, 15.5))
    if tassel:
        for q in [(10, 8), (10, 9), (11, 9), (11, 10)]: cv.p[q] = RED if q[1] < 10 else RED2
    cv.outline(); return cv

def lance_set():
    out = {}
    out["lance_iron"] = lance("iron")
    out["lance_steel"] = lance("steel", hw=1.9, head=5.2)
    s = lance("silver"); s.set(13, 2, WHITE); out["lance_silver"] = s
    out["lance_killer"] = lance("killer", tassel=True)
    out["lance_brave"] = lance("brave", double=True, hw=2.4, head=5.4)
    out["javelin"] = lance("iron", start=5.0, head=3.6, hw=1.2, tassel=False)
    out["horseslayer"] = lance("eff", hook=True)
    out["lance_boss"] = lance("boss", hw=2.0, head=5.6, tassel=True)
    return out

# ---------------- axes ----------------
def axe(tier="iron", r=6.0, top=16.0, start=0.0, hammer=False, double=False, edge_red=False):
    cv = Cv(); pal = BLADE[tier]
    hc = top - 3.0                                  # head centre along the haft
    def f(u, v):
        du = u - hc
        if hammer:
            if abs(du) < 1.9 and -3.6 < v < 3.0:
                return pal[0] if du > 0.9 else (pal[2] if du < -1.0 else pal[1])
        else:
            for side in ([-1, 1] if double else [-1]):
                vs = v * side
                if vs > 0.4:                         # blade fans out to the upper-left (side -1 = v<0)
                    pass
                dist = math.hypot(du * 0.95, v)
                if side * v > 0.3 and dist < r and abs(du) < 1.5 + (side * v) * 0.8:
                    rim = dist > r - 1.15
                    if rim: return RED if edge_red else pal[0]
                    return pal[1] if dist > r - 2.6 else pal[2]
        if start <= u < top and abs(v) < 0.6: return H1 if v < 0 else H2
        return None
    cv.shape(f, O=(1.0, 15.0))
    cv.outline(); return cv

def axe_set():
    out = {}
    out["axe_iron"] = axe("iron")
    out["axe_steel"] = axe("steel", r=6.8)
    out["axe_silver"] = axe("silver", r=6.3)
    out["axe_killer"] = axe("iron", edge_red=True)
    out["axe_brave"] = axe("brave", double=True, r=5.6)
    out["handaxe"] = axe("iron", r=4.6, top=13.5, start=3.0)
    out["hammer"] = axe("steel", hammer=True)
    out["axe_boss"] = axe("boss", double=True, r=5.6)
    return out

# ---------------- bows ----------------
def bow(tier="iron", limb=None):
    cv = Cv(); L = limb or {"iron": (H1, H2), "steel": (BLADE["steel"][1], BLADE["steel"][2]), "silver": (BLADE["silver"][0], BLADE["silver"][2]),
                         "killer": (RED, RED2)}[tier]
    cx, cy, R = 8.0, 8.0, 6.9         # D-shaped bow: semicircle limb on the upper-left, string = diagonal chord
    for y in range(16):
        for x in range(16):
            px, py = x + 0.5 - cx, y + 0.5 - cy; d = math.hypot(px, py)
            if px + py < 0.3 and R - 1.7 < d < R + 0.25:
                cv.p[(x, y)] = L[0] if d < R - 0.7 else L[1]
    for t in range(10):
        x, y = 3 + t, 12 - t
        if (x, y) not in cv.p: cv.p[(x, y)] = C(240,240,240)
    for q in [(2, 3), (3, 2), (2, 2), (3, 3)]: cv.p[q] = G1 if q != (2, 2) else G2   # grip wrap
    for q in [(12, 2), (2, 12)]: cv.p[q] = G1                                        # nocks
    cv.outline(); return cv

def bow_set():
    return {"bow_iron": bow("iron"), "bow_steel": bow("steel"), "bow_silver": bow("silver"), "bow_killer": bow("killer")}

# ---------------- tomes ----------------
EMBLEM = {
 "fire": ["..x..", ".xx..", ".xxx.", "xxyxx", ".xyx."],
 "thunder": ["...x.", "..x..", ".xxx.", "..x..", ".x..."],
 "wind": [".xxx.", "x...x", "..xx.", "x....", ".xxxx"],
 "light": ["..x..", "x.x.x", ".xyx.", "x.x.x", "..x.."],
 "dark": [".xxx.", "x.y.x", "xyyyx", "x.y.x", ".xxx."],
}
TOME = {  # cover, cover dark, emblem, emblem2, trim
 "fire": (C(212,60,40), C(140,30,28), C(255,200,80), C(255,248,200), G1),
 "elfire": (C(232,96,32), C(160,40,24), C(255,232,120), C(255,255,255), G1),
 "thunder": (C(236,200,48), C(168,128,24), C(255,255,255), C(255,255,255), C(120,90,20)),
 "bolt": (C(72,104,216), C(36,56,140), C(255,240,96), C(255,255,255), C(200,210,255)),
 "wind": (C(64,180,96), C(28,112,60), C(220,255,230), C(255,255,255), G1),
 "light": (C(244,240,220), C(196,180,130), C(240,184,40), C(255,255,255), G1),
 "dark": (C(104,48,140), C(56,20,84), C(232,80,96), C(255,180,200), C(200,170,230)),
}
def tome(kind, emblem):
    cov, cdk, e1, e2, trim = TOME[kind]; cv = Cv()
    PAGE, PAGE2 = C(244,236,212), C(196,180,150)
    for y in range(2, 14):
        for x in range(3, 13):
            cv.p[(x, y)] = cov
        cv.p[(3, y)] = cdk; cv.p[(4, y)] = cdk          # spine
    for x in range(4, 13): cv.p[(x, 14)] = PAGE; cv.p[(x, 15 - 0)] = PAGE2 if x > 4 else cdk
    cv.p.pop((4, 15), None)
    for x in range(5, 13): cv.p[(x, 15)] = PAGE2
    cv.p[(13, 14)] = PAGE2
    for y in range(3, 14): cv.p[(13, y)] = PAGE if y % 2 else PAGE2   # page edges
    for x in range(5, 13): cv.p[(x, 2)] = trim
    for (ex, ey) in [(0, 0)]: pass
    em = EMBLEM[emblem]
    for j, row in enumerate(em):
        for i, ch in enumerate(row):
            if ch == "x": cv.p[(6 + i, 5 + j)] = e1
            elif ch == "y": cv.p[(6 + i, 5 + j)] = e2
    if kind == "elfire":   # upgraded: gold corner studs
        for q in [(5, 3), (12, 3), (5, 12), (12, 12)]: cv.p[q] = G1
    cv.outline(); return cv

def tome_set():
    return {"tome_fire": tome("fire", "fire"), "tome_elfire": tome("elfire", "fire"), "tome_thunder": tome("thunder", "thunder"),
            "tome_bolt": tome("bolt", "thunder"), "tome_wind": tome("wind", "wind"), "tome_light": tome("light", "light"), "tome_dark": tome("dark", "dark")}

# ---------------- staves ----------------
def staff(head="heal", length=13.0):
    cv = Cv()
    def f(u, v):
        if u < length and abs(v) < 0.55: return C(236,226,196) if v < 0 else C(176,156,120)
        return None
    cv.shape(f, O=(1.5, 14.5))
    hx, hy = 1.5 + length / math.sqrt(2) + 0.2, 14.5 - length / math.sqrt(2) - 0.2
    if head == "heal":      # gold ring with a white gem
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - hx, y + 0.5 - hy)
                if 1.6 < d < 2.9: cv.p[(x, y)] = G1 if (x + y) % 3 else G2
                elif d <= 1.0: cv.p[(x, y)] = C(220,240,255)
    elif head == "mend":    # blue orb + gold wings
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - hx, y + 0.5 - hy)
                if d < 2.2: cv.p[(x, y)] = C(140,200,255) if d < 1.2 else C(56,112,216)
        ix, iy = int(hx), int(hy)
        for q in [(ix - 3, iy), (ix - 3, iy + 1), (ix - 2, iy + 2), (ix, iy + 3), (ix + 1, iy + 3)]: cv.set(*q, G1)
    elif head == "physic":  # long staff, green star
        ix, iy = int(hx), int(hy)
        for q in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0), (0, -2), (0, 2)]:
            cv.set(ix + q[0], iy + q[1], C(150,255,170) if abs(q[0]) + abs(q[1]) < 2 else C(48,176,96))
    elif head == "unlock":  # key-bit head
        ix, iy = int(hx), int(hy)
        for q in [(0, 0), (1, 0), (0, -1), (1, -1), (-1, 1), (2, 0), (2, -2), (0, -2)]: cv.set(ix + q[0], iy + q[1], G1)
        cv.set(ix, iy, G2)
    cv.outline(); return cv

def staff_set():
    return {"staff_heal": staff("heal"), "staff_mend": staff("mend"), "staff_physic": staff("physic", 14.0), "staff_unlock": staff("unlock")}

# ---------------- consumables ----------------
def grid(rows, pal):
    cv = Cv()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal: cv.p[(x, y)] = pal[ch]
    cv.outline(); return cv
VIAL = ["................", "................", "......cc........", ".....cwwc.......".replace("c", "."), "......gg........",
        "......ww........", ".....wllw.......", "....wllllw......", "...wlLLLLlw.....", "...wLLLLLLw.....",
        "...wLLSLLLw.....", "...wLLLLLLw.....", "....wLLLLw......", ".....wwww.......", "................", "................"]
VIAL = [r[1:] + "." for r in VIAL]   # nudge left by 1 -> centred
def potion(liq, liq2, cork=H1):
    return grid(["................", "................", ".....cc.........", ".....cc.........", "....gggg........".replace("g", "w"),
                 ".....ww.........", ".....ww.........", "....wllw........", "...wlLLlw.......", "..wLLLLLLw......",
                 "..wLLSLLLw......", "..wLLLLLLw......", "..wLLLLLLw......", "...wLLLLw.......", "....wwww........", "................"],
                {"c": cork, "w": C(220,236,248), "l": liq2, "L": liq, "S": WHITE, "g": G1})
def shift(cv, dx, dy):
    n = Cv(); n.p = {(x + dx, y + dy): c for (x, y), c in cv.p.items() if 0 <= x + dx < 16 and 0 <= y + dy < 16}; return n

KEY = ["................", "................", "...rrr..........", "..r...r.........", "..r...r.........", "..r...r.........",
       "...rrrr.........", "......rr........", ".......rr.......", "........rr......", ".........rr.....", "........rrrr....",
       "........r.rr....", "...........rr...", "............r...", "................"]
RING = ["................", "................", "......sss.......", ".....sSSSs......", "......sss.......", ".....gGGGg......",
        "....g.....g.....", "...g.......g....", "...g.......g....", "...g.......g....", "....g.....g.....", ".....gGGGg......",
        "................", "................", "................", "................"]
STATUE = ["................", "......gg........", ".....gGGg.......", ".....gGGg.......", "......gg........", "...gggGGggg.....",
          "..g..gGGg..g....", ".....gGGg.......", ".....gGGg.......", "....gGGGGg......", "....gGGGGg......", "...gGGGGGGg.....",
          "..dddddddddd....", "..DDDDDDDDDD....", "................", "................"]
SHIELD = ["................", "..ssssssssss....", "..sGGGGGGGGs....", "..sGggRRggGs....", "..sGgRRRRgGs....", "..sGgRRRRgGs....",
          "..sGggRRggGs....", "..sGgggggggs....", "...sGgggggs.....", "...sGgggggs.....", "....sGgggs......", ".....sGgs.......",
          "......ss........", "................", "................", "................"]
def items():
    out = {}
    out["vulnerary"] = shift(potion(C(224,56,72), C(255,140,150)), 2, 0)
    out["elixir"] = shift(potion(C(240,184,40), C(255,236,150), G2), 2, 0)
    out["key_door"] = shift(grid(KEY, {"r": C(176,180,192)}), 0, 0)
    out["key_chest"] = grid(KEY, {"r": G1})
    mk = grid(KEY, {"r": C(232,240,255)}); mk.p[(4, 4)] = C(80,200,255); out["key_master"] = mk
    out["ring_str"] = shift(grid(RING, {"s": RED2, "S": RED, "g": G2, "G": G1}), 1, 1)
    out["ring_spd"] = shift(grid(RING, {"s": C(30,120,90), "S": C(80,230,170), "g": G2, "G": G1}), 1, 1)
    out["goddess"] = shift(grid(STATUE, {"g": C(200,200,224), "G": C(250,250,255), "d": C(150,120,90), "D": C(100,76,56)}), 1, 0)
    out["dragon_shield"] = shift(grid(SHIELD, {"s": C(36,90,60), "G": C(150,220,170), "g": C(64,160,100), "R": G1}), 1, 1)
    return out

TYPE_OF = {}
def build():
    groups = [("sword", sword_set()), ("lance", lance_set()), ("axe", axe_set()), ("bow", bow_set()), ("tome", tome_set()), ("staff", staff_set()), ("item", items())]
    os.makedirs(os.path.join(ROOT, "assets/icons"), exist_ok=True)
    rendered = []
    for g, d in groups:
        row = []
        for k, cv in d.items():
            im = cv.img(TRI.get(g))
            im.save(os.path.join(ROOT, "assets/icons/%s.png" % k)); row.append((k, im))
        rendered.append((g, row))
    # preview sheet: each icon at 4x (integer) + its id
    S = 4; cell = 16 * S + 16
    cols = max(len(r) for _, r in rendered)
    W, H = 110 + cols * (cell + 30), len(rendered) * (cell + 34) + 60
    sheet = Image.new("RGBA", (W, H), (20, 22, 40, 255)); dr = ImageDraw.Draw(sheet)
    try:
        fnt = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/NanumGothic-Bold.ttf"), 13); big = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/NanumGothic-Bold.ttf"), 20)
    except Exception: fnt = big = None
    dr.text((10, 12), "원본 16x16 아이콘 (4배 미리보기) — 검 파랑 · 창 초록 · 도끼 빨강 타일, 등급: 철/강철/은/킬러/용사", fill=(240, 228, 160), font=big)
    for j, (g, row) in enumerate(rendered):
        y = 54 + j * (cell + 34)
        dr.text((10, y + 24), g, fill=(200, 210, 240), font=big)
        for i, (k, im) in enumerate(row):
            x = 110 + i * (cell + 30)
            sheet.alpha_composite(im.resize((16 * S, 16 * S), Image.NEAREST), (x, y))
            dr.text((x - 4, y + 16 * S + 4), k, fill=(220, 220, 230), font=fnt)
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    sheet.save(os.path.join(ROOT, "build/icons_sheet.png"))
    print("icons:", sum(len(r) for _, r in rendered))

if __name__ == "__main__": build()
