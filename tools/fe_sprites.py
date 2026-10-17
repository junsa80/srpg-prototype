"""GBA-FE-style class silhouettes for 32x32 map frames (original pixel art, drawn in code).
Facing LEFT (player side). Frame 0/1 = idle bob (GBA map units bob; fliers flap, horses step).
Families: foot sword / thief / fighter / archer / mage / healer / armor / cavalry / flier.
Conventions borrowed from FE6-8 map sprites (no ripped assets): big readable head, one dominant
weapon shape per class, mounts fill the whole tile, armour = wide box + shield, promoted = cape/crest/bigger weapon."""
from PIL import Image
NONE = (0, 0, 0, 0)
def C(*a): return tuple(a) + (255,)
SKIN = C(248, 208, 168); SKIN_D = C(214, 160, 120)
STEEL = C(196, 204, 220); STEEL_M = C(140, 150, 172); STEEL_D = C(88, 96, 120)
GOLD = C(240, 200, 72); WOOD = C(132, 86, 44); WOOD_D = C(88, 56, 28); WHITE = C(244, 244, 250); BOOT = C(70, 46, 30)
def dark(c, f=.68): return C(*[int(v * f) for v in c[:3]])
def light(c, f=1.3): return C(*[min(255, int(v * f)) for v in c[:3]])

class Px:
    def __init__(s): s.im = Image.new('RGBA', (32, 32), NONE); s.p = s.im.load()
    def set(s, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32: s.p[x, y] = c
    def rect(s, x0, y0, x1, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1): s.set(x, y, c)
    def ell(s, cx, cy, rx, ry, c):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + .5)) ** 2 + ((y - cy) / (ry + .5)) ** 2 <= 1: s.set(x, y, c)
    def line(s, x0, y0, x1, y1, c, w=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
            s.rect(x, y, x + w - 1, y, c)
    def outline(s, col):
        a = [[s.p[x, y][3] > 0 for y in range(32)] for x in range(32)]
        for x in range(32):
            for y in range(32):
                if not a[x][y] and any(0 <= x + dx < 32 and 0 <= y + dy < 32 and a[x + dx][y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    s.p[x, y] = col

# ---------- head (r=5: 11px wide, GBA-ish big head but adult proportions on 32px) ----------
def head(s, cx, cy, hair, style, eyes, skin, hw):
    s.ell(cx, cy, 4, 4, skin); s.rect(cx - 3, cy + 3, cx + 2, cy + 4, skin)
    s.rect(cx - 4, cy + 1, cx - 4, cy + 2, SKIN_D if skin == SKIN else skin)
    kind = hw.get("head", "hair")
    if kind == "helm":       # closed great-helm: steel dome, visor slit, cheek plates
        s.ell(cx, cy - 1, 5, 5, STEEL); s.rect(cx - 5, cy - 1, cx + 5, cy + 4, STEEL); s.rect(cx + 2, cy - 1, cx + 5, cy + 4, STEEL_M)
        s.rect(cx - 5, cy + 1, cx + 1, cy + 1, STEEL_D); s.rect(cx - 4, cy + 3, cx - 1, cy + 4, skin)
        if hw.get("plume"): s.rect(cx - 1, cy - 8, cx + 3, cy - 6, hw["plume"]); s.rect(cx + 3, cy - 7, cx + 5, cy - 4, hw["plume"])
        return
    if kind == "kettle":     # open helm for riders: face visible
        s.ell(cx, cy - 2, 5, 3, STEEL); s.rect(cx - 6, cy - 1, cx + 5, cy - 1, STEEL_M); s.rect(cx + 3, cy - 1, cx + 5, cy + 3, STEEL_M)
        if hw.get("plume"): s.rect(cx, cy - 7, cx + 3, cy - 5, hw["plume"])
    elif kind in ("hood", "veil"):
        hc = hw["hc"]; s.ell(cx, cy - 1, 5, 5, hc); s.rect(cx + 1, cy - 1, cx + 5, cy + 5, hc)
        s.ell(cx - 1, cy + 1, 3, 3, skin); s.rect(cx - 3, cy - 2, cx + 1, cy - 2, hair)
        if kind == "veil": s.rect(cx - 5, cy - 4, cx + 4, cy - 4, WHITE)
        if kind == "hood": s.rect(cx + 4, cy + 4, cx + 6, cy + 6, hc)   # hood tail
    elif kind == "hat":      # mage's pointed hat (brim + tip leaning back)
        hc = hw["hc"]; s.ell(cx, cy - 1, 5, 3, hair); s.rect(cx - 7, cy - 3, cx + 6, cy - 2, hc)
        for i in range(6): s.rect(cx - 3 + i // 2, cy - 4 - i, cx + 3 - i // 3, cy - 4 - i, hc)
        s.rect(cx + 2, cy - 10, cx + 4, cy - 9, hc); s.rect(cx - 6, cy - 2, cx + 5, cy - 2, hw.get("band", GOLD))
    elif kind == "mitre":
        s.ell(cx, cy - 1, 5, 3, hair); s.rect(cx - 3, cy - 8, cx + 3, cy - 3, WHITE); s.rect(cx - 2, cy - 10, cx + 2, cy - 9, WHITE); s.rect(cx, cy - 9, cx, cy - 3, GOLD)
    else:
        s.ell(cx, cy - 2, 5, 3, hair); s.rect(cx + 1, cy - 2, cx + 5, cy + 3, hair); s.rect(cx - 5, cy - 2, cx - 4, cy, hair)
        if style == "spiky":
            for dx, h in ((-4, 2), (-1, 3), (2, 3), (5, 2)): s.rect(cx + dx, cy - 5 - h, cx + dx + 1, cy - 5, hair)
        if style == "long": s.rect(cx + 2, cy + 3, cx + 6, cy + 9, hair)
        if style == "pony": s.rect(cx + 5, cy - 3, cx + 7, cy + 4, hair); s.set(cx + 7, cy + 5, hair)
        if style == "beard": s.rect(cx - 4, cy + 3, cx + 2, cy + 5, hair)
        s.rect(cx - 2, cy - 4, cx, cy - 4, light(hair))
        if kind == "bandana": s.rect(cx - 5, cy - 3, cx + 5, cy - 2, hw["hc"]); s.rect(cx + 5, cy - 2, cx + 8, cy, hw["hc"])
        if kind == "horns": s.rect(cx - 5, cy - 3, cx + 5, cy - 3, STEEL_D); s.rect(cx - 6, cy - 6, cx - 5, cy - 3, WHITE); s.rect(cx + 5, cy - 6, cx + 6, cy - 3, WHITE)
    if hw.get("crest"): s.rect(cx - 1, cy - 5, cx, cy - 4, hw["crest"])   # promoted circlet gem
    s.rect(cx - 3, cy, cx - 2, cy + 1, eyes); s.rect(cx, cy, cx, cy + 1, eyes)

def cape(s, x0, y0, x1, y1, col, f):
    s.rect(x0, y0, x1, y1, col); s.rect(x0, y1 + 1, x1 - 1 - f, y1 + 1, col)
    s.rect(x1 - 1, y0, x1, y1, dark(col))

def legs(s, cx, top, col, wide=0, crouch=False):
    if crouch:
        s.rect(cx - 6 - wide, top + 3, cx - 2, top + 5, col); s.rect(cx - 7 - wide, top + 6, cx - 4, top + 7, BOOT)
        s.rect(cx + 1, top + 2, cx + 5 + wide, top + 5, col); s.rect(cx + 3, top + 6, cx + 6 + wide, top + 7, BOOT)
    else:
        s.rect(cx - 3 - wide, top, cx - 1, top + 4, col); s.rect(cx + 1, top, cx + 3 + wide, top + 4, col)
        s.rect(cx - 4 - wide, top + 5, cx - 1, top + 6, BOOT); s.rect(cx + 1, top + 5, cx + 4 + wide, top + 6, BOOT)

def torso(s, cx, top, cloth, h=8, w=4, trim=None, belt=True):
    s.rect(cx - w, top, cx + w, top + h, cloth); s.rect(cx + w - 1, top, cx + w, top + h, dark(cloth))
    if trim: s.rect(cx - w, top, cx + w, top, trim)
    if belt: s.rect(cx - w, top + h - 2, cx + w, top + h - 2, WOOD_D)

# ---------- weapons ----------
def sword(s, hx, hy, big=False, katana=False):
    L = 12 if big else 10; w = 2 if big else 1
    s.rect(hx, hy - L, hx + w - 1, hy - 1, WHITE if not katana else C(220, 228, 240)); s.rect(hx + w, hy - L + 1, hx + w, hy - 1, STEEL_M)
    if big: s.set(hx, hy - L - 1, WHITE)
    s.rect(hx - 2, hy, hx + w + 1, hy, GOLD if not katana else C(40, 40, 48)); s.rect(hx, hy + 1, hx + w - 1, hy + 2, WOOD_D)
def dagger(s, hx, hy):
    s.rect(hx - 4, hy, hx - 1, hy, WHITE); s.set(hx - 5, hy, STEEL_M); s.rect(hx, hy - 1, hx, hy + 1, GOLD)
def lance(s, x0, y0, x1, y1, big=False):
    s.line(x0, y0, x1, y1, WOOD); tip = (x0, y0)
    s.rect(tip[0] - 1, tip[1] - 1, tip[0] + 1, tip[1] + 1, WHITE); s.set(tip[0] - 2 if x0 < x1 else tip[0], tip[1] - 2, WHITE)
    if big: s.rect(tip[0] - 2, tip[1] - 2, tip[0] + 2, tip[1] - 1, WHITE)
def axe_over_shoulder(s, hx, hy, big=False):
    s.line(hx, hy, hx + 14, hy - 14, WOOD, 2)                # haft from front hand over the back shoulder
    ax, ay = hx + 13, hy - 15
    s.ell(ax + 2, ay + 2, 4 if big else 3, 4 if big else 3, STEEL); s.rect(ax - 1, ay - 2, ax, ay + 6, STEEL_D)
    if big: s.ell(ax - 3, ay + 2, 2, 3, STEEL)               # double-bit for promoted
def bow(s, hx, hy, gold=False):
    c = GOLD if gold else WOOD
    for i in range(-9, 10): s.set(hx - (3 - abs(i) // 3), hy + i, c)
    s.rect(hx, hy - 9, hx, hy + 9, C(230, 230, 230)); s.rect(hx - 1, hy, hx + 5, hy, WHITE)   # string + nocked arrow
def tome(s, hx, hy, col=C(176, 40, 48), glow=C(255, 236, 120)):
    s.rect(hx - 4, hy - 2, hx, hy + 2, col); s.rect(hx - 3, hy - 1, hx - 1, hy + 1, C(240, 222, 180)); s.set(hx - 5, hy - 4, glow); s.set(hx - 6, hy - 3, glow)
def staff(s, hx, hy, top_y, head="ring"):
    s.rect(hx, top_y, hx, hy + 7, WOOD)
    if head == "ring": s.ell(hx, top_y - 2, 2, 2, GOLD); s.set(hx, top_y - 2, C(160, 236, 255))
    elif head == "cross": s.rect(hx - 2, top_y - 3, hx + 2, top_y - 3, GOLD); s.rect(hx, top_y - 5, hx, top_y - 1, GOLD)
    else: s.ell(hx, top_y - 2, 2, 2, C(150, 90, 230)); s.set(hx - 1, top_y - 3, WHITE)
def shield(s, x0, y0, w, h, face, trim):
    s.rect(x0, y0, x0 + w, y0 + h, trim); s.rect(x0 + 1, y0 + 1, x0 + w - 1, y0 + h - 2, face)
    s.rect(x0 + 1, y0 + h - 1, x0 + w - 1, y0 + h - 1, trim); s.rect(x0 + w // 2, y0 + 2, x0 + w // 2, y0 + h - 3, light(face, 1.5))
    s.rect(x0 + 2, y0 + h // 2 - 1, x0 + w - 2, y0 + h // 2 - 1, light(face, 1.5))

# ---------- mounts ----------
def horse(s, col, f, barding=None, heavy=False):
    hd = dark(col); mane = C(80, 56, 40) if col[0] > 150 else C(30, 24, 30)
    s.ell(17, 20, 10 if not heavy else 11, 4 if not heavy else 5, col)                 # barrel
    s.rect(4, 11, 8, 18, col); s.ell(4, 10, 3, 2, col); s.rect(0, 10, 3, 13, col)      # neck, head, muzzle
    s.set(0, 13, hd); s.set(3, 10, C(20, 14, 28)); s.rect(6, 7, 7, 8, col)            # nostril, eye, ear
    s.rect(8, 9, 9, 17, mane); s.rect(26, 16, 29, 25 - f, mane); s.set(30, 17, mane)   # mane, tail swish
    step = (0, 1) if f == 0 else (1, 0)
    for i, x in enumerate((8, 11, 22, 25)):                                            # four legs, alternating step
        lift = step[i % 2]; lc = col if i in (1, 3) else hd
        s.rect(x, 24, x + 1, 29 - lift, lc); s.rect(x, 30 - lift, x + 2, 30 - lift, C(40, 32, 30))
    if barding:
        s.rect(10, 17, 26, 21, barding); s.rect(10, 22, 26, 22, light(barding)); s.rect(4, 11, 7, 13, barding)
        if heavy: s.rect(1, 9, 5, 11, STEEL); s.rect(10, 16, 26, 16, STEEL)
def wyvern(s, col, f, rider_x=16):
    cd = dark(col); wing = dark(col, .6); mem = light(col, 1.15)
    s.ell(17, 21, 10, 5, col); s.rect(4, 12, 8, 20, col); s.ell(4, 10, 4, 3, col); s.rect(-1, 11, 2, 13, col)
    s.set(3, 9, C(255, 220, 64)); s.rect(5, 6, 6, 7, cd); s.rect(1, 13, 3, 13, WHITE)        # eye, horn, teeth
    s.rect(26, 20, 31, 23, cd); s.set(31, 19, cd)                                           # tail
    for x in (10, 21): s.rect(x, 25, x + 2, 30, cd); s.rect(x - 1, 30, x + 3, 30, C(40, 32, 30))
    s.rect(9, 22, 25, 23, mem)                                                              # belly
    if f == 0:   # wings UP: tall bat wings over the back, clearly flapping vs frame 1
        for i in range(10): s.rect(18 + i // 3, 1 + i, 30 - i // 2 + (i > 6) * 0, 1 + i, wing)
        s.line(18, 11, 30, 0, cd); s.line(22, 11, 31, 3, cd)
    else:        # wings DOWN: spread low and wide
        for i in range(6): s.rect(16 + i, 13 + i, 31, 13 + i, wing)
        s.line(16, 13, 31, 19, cd); s.rect(29, 19, 31, 21, wing)
def pegasus(s, col, f):
    horse(s, col, f)
    wy = 0 if f == 0 else 6
    for i in range(7): s.rect(16 + i // 2, 3 + i + wy, 28 - i, 3 + i + wy, WHITE)
    s.line(16, 10 + wy, 28, 3 + wy, C(200, 210, 230))

# ---------- class bodies ----------
def foot_sword(s, P, f):
    cx, top = 16, 15
    if P.get("cape"): cape(s, cx - 2, top, cx + 7, top + 10, P["cape"], f)
    legs(s, cx, top + 9, P["legc"]); torso(s, cx, top, P["cloth"], trim=P.get("trim"))
    s.rect(cx - 6, top + 1, cx - 5, top + 5, P["cloth"]); s.rect(cx + 5, top + 1, cx + 6, top + 6, dark(P["cloth"]))
    s.rect(cx - 7, top + 4, cx - 5, top + 6, SKIN)                     # front fist raised
    sword(s, cx - 6, top + 4, big=P.get("big"), katana=P.get("katana"))
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], P["hw"])
def thief(s, P, f):
    cx, top = 15, 18                                                    # crouched, lower and leaner
    if P.get("scarf"): s.rect(cx + 2, top, cx + 9, top + 2, P["scarf"]); s.rect(cx + 7, top + 2, cx + 9, top + 3 + f, P["scarf"])
    legs(s, cx, top + 5, P["legc"], crouch=True); torso(s, cx, top, P["cloth"], h=6, w=3)
    s.rect(cx - 6, top + 2, cx - 3, top + 3, P["cloth"]); s.rect(cx - 7, top + 3, cx - 6, top + 4, SKIN); dagger(s, cx - 7, top + 3)
    s.rect(cx + 3, top + 1, cx + 4, top + 4, dark(P["cloth"]))
    if P.get("big"): dagger(s, cx + 9, top + 5); s.set(cx + 5, top + 5, SKIN)
    head(s, cx - 1, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], P["hw"])
def fighter(s, P, f):
    cx, top = 16, 15
    if P.get("cape"): cape(s, cx, top, cx + 8, top + 10, P["cape"], f)
    legs(s, cx, top + 9, P["legc"], wide=1)
    s.rect(cx - 5, top, cx + 5, top + 8, P["skin"]); s.rect(cx - 5, top + 5, cx + 5, top + 8, P["cloth"])   # bare chest, broad
    s.rect(cx - 3, top, cx + 3, top + 1, P["cloth"]) if not P.get("bare_chest") else None
    s.rect(cx - 5, top + 7, cx + 5, top + 7, WOOD_D)
    s.rect(cx - 8, top + 1, cx - 6, top + 6, P["skin"]); s.rect(cx + 6, top, cx + 8, top + 5, P["skin"])     # thick bare arms
    s.rect(cx - 8, top + 3, cx - 6, top + 3, P["cloth"])                                                      # wrist band
    axe_over_shoulder(s, cx - 7, top + 6, big=P.get("big"))
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], P["hw"])
def archer(s, P, f):
    cx, top = 17, 15
    if P.get("cape"): cape(s, cx, top, cx + 7, top + 10, P["cape"], f)
    s.rect(cx + 3, top - 3, cx + 5, top + 6, WOOD_D); s.rect(cx + 3, top - 4, cx + 3, top - 3, WHITE); s.rect(cx + 5, top - 5, cx + 5, top - 3, WHITE)  # quiver + fletching
    legs(s, cx, top + 9, P["legc"]); torso(s, cx, top, P["cloth"], trim=P.get("trim"))
    s.rect(cx - 8, top + 2, cx - 4, top + 3, P["cloth"]); s.rect(cx - 9, top + 2, cx - 8, top + 3, SKIN)       # bow arm extended
    bow(s, cx - 9, top + 3, gold=P.get("big"))
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], P["hw"])
def robed(s, P, f):
    cx, top = 16, 15; c = P["cloth"]; heal = P.get("healer")
    if P.get("cape"): cape(s, cx, top, cx + 7, top + 13, P["cape"], f)
    for i in range(15): w = 3 + i // 3; s.rect(cx - w, top + i, cx + w, top + i, c); s.rect(cx + w - 1, top + i, cx + w, top + i, dark(c))
    tr = P.get("trim") or dark(c)
    s.rect(cx - 1, top, cx, top + 14, tr); s.rect(cx - 7, top + 14, cx + 7, top + 14, tr)
    if heal: s.rect(cx - 3, top + 3, cx - 1, top + 3, P.get("trim", GOLD)); s.rect(cx - 2, top + 2, cx - 2, top + 5, P.get("trim", GOLD))  # cross on chest
    s.rect(cx - 6, top + 2, cx - 4, top + 5, c); s.rect(cx - 7, top + 5, cx - 6, top + 6, SKIN)
    if heal: staff(s, cx - 7, top + 5, top - 9, "cross" if P.get("big") else "ring")
    elif P.get("staff_mage"): staff(s, cx - 7, top + 5, top - 9, "orb"); tome(s, cx + 9, top + 7, P.get("tome", C(176, 40, 48)))
    else: tome(s, cx - 5, top + 6, P.get("tome", C(176, 40, 48)))
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], P["hw"])
def armor(s, P, f):
    cx, top = 17, 14; c = P["cloth"]
    if P.get("cape"): cape(s, cx, top, cx + 9, top + 13, P["cape"], f)
    lance(s, cx + 8, 1, cx + 8, 30, big=P.get("big"))                                            # tall lance held upright at the back
    s.rect(cx - 5, top + 10, cx - 1, top + 16, STEEL_M); s.rect(cx + 1, top + 10, cx + 5, top + 16, STEEL_M)   # boxy greaves
    s.rect(cx - 6, top + 15, cx - 1, top + 16, STEEL_D); s.rect(cx + 1, top + 15, cx + 6, top + 16, STEEL_D)
    s.rect(cx - 6, top, cx + 6, top + 10, STEEL); s.rect(cx + 3, top, cx + 6, top + 10, STEEL_M)
    s.rect(cx - 3, top + 2, cx + 2, top + 6, c); s.rect(cx - 6, top + 8, cx + 6, top + 9, P.get("trim") or STEEL_D)
    s.rect(cx - 9, top - 1, cx + 9, top + 2, STEEL_M); s.rect(cx + 6, top + 2, cx + 8, top + 6, STEEL)           # huge pauldrons
    s.rect(cx + 7, top + 5, cx + 8, top + 6, SKIN)
    sw = 9 if P.get("big") else 8
    shield(s, cx - 13, top - 1, sw, 14 if P.get("big") else 12, c, P.get("trim") or STEEL_D)                    # big tower shield in front
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], dict(P["hw"], head="helm"))
def cavalry(s, P, f):
    m = P.get("mountcol")
    horse(s, m, f, barding=P.get("barding"), heavy=P.get("heavy"))
    cx, top = 17, 9; c = P["cloth"]
    if P.get("cape"): cape(s, cx + 1, top, cx + 7, top + 8, P["cape"], f)
    if P.get("heavy"):
        s.rect(cx - 5, top, cx + 5, top + 7, STEEL); s.rect(cx - 2, top + 2, cx + 2, top + 5, c); s.rect(cx - 7, top - 1, cx + 7, top + 1, STEEL_M)
    else:
        torso(s, cx, top, c, h=7, trim=P.get("trim"), belt=False)
        if P.get("plate"): s.rect(cx - 5, top - 1, cx + 5, top + 1, STEEL); s.rect(cx - 3, top + 2, cx + 3, top + 4, STEEL)
    s.rect(cx - 2, top + 7, cx + 3, top + 10, dark(c)); s.rect(cx - 1, top + 11, cx + 1, top + 14, BOOT)      # leg over the flank
    w = P["weapon"]
    s.rect(cx - 7, top + 3, cx - 5, top + 4, SKIN)
    if w == "lance": lance(s, cx - 15 if P.get("big") else cx - 13, top - 8, cx + 2, top + 8, big=P.get("big"))  # couched lance pointing forward-up
    elif w == "axe": axe_over_shoulder(s, cx - 6, top + 4, big=True)
    elif w == "bow": bow(s, cx - 7, top + 3, gold=P.get("big"))
    elif w == "tome": tome(s, cx - 5, top + 4, P.get("tome", C(176, 40, 48)))
    elif w == "staff": staff(s, cx - 6, top + 4, top - 8, "cross")
    elif w == "sword": sword(s, cx - 6, top + 3, big=P.get("big"))
    hk = dict(P["hw"]);
    if hk.get("head", "hair") == "hair" and P.get("rider_helm"): hk["head"] = "kettle"
    if P.get("heavy"): hk["head"] = "helm"
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], hk)
def flier(s, P, f):
    wyvern(s, P["mountcol"], f)
    cx, top = 14, 8; c = P["cloth"]
    if P.get("cape"): cape(s, cx + 1, top, cx + 6, top + 7, P["cape"], f)
    s.rect(cx - 4, top, cx + 4, top + 6, STEEL); s.rect(cx - 2, top + 1, cx + 2, top + 4, c); s.rect(cx - 6, top - 1, cx + 6, top + 1, STEEL_M)
    s.rect(cx - 2, top + 7, cx + 2, top + 9, dark(c))
    s.rect(cx - 7, top + 2, cx - 5, top + 3, SKIN)
    if P["weapon"] == "axe": axe_over_shoulder(s, cx - 6, top + 3, big=P.get("big"))
    else: lance(s, cx - 13, top - 7, cx + 1, top + 7, big=P.get("big"))
    hk = dict(P["hw"]); hk.setdefault("head", "kettle")
    if hk["head"] == "hair": hk["head"] = "kettle"
    head(s, cx, top - 6, P["hair"], P["style"], P["eyes"], P["skin"], hk)

FAMILY = {"sword": foot_sword, "thief": thief, "fighter": fighter, "archer": archer, "robe": robed,
          "armor": armor, "cav": cavalry, "flier": flier}

def render(fam, P, f, outline_col):
    s = Px(); FAMILY[fam](s, P, f); s.outline(outline_col); return s.im
