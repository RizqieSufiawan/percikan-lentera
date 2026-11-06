"""Latar layar judul: pemandangan desa malam bergaya pixel art, dibuat berlapis untuk efek paralaks.

Digambar di kanvas 320x180 lalu diperbesar 4x (1280x720, NEAREST). Lapisan:
    title_sky.png   langit, bintang, bulan (tidak transparan)
    title_far.png   gunung jauh + gunung api + kabut
    title_mid.png   bukit, sawah terasering, desa, tiang listrik, panel surya, air terjun, danau
    title_near.png  siluet depan: pohon kelapa dan rumput
Baling-baling turbin, bintang berkelip, dan lentera digambar di Godot (title_screen.gd);
posisi turbin dicetak di akhir agar bisa disalin ke skrip.

Pakai:  python3 tools/make_title_bg.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")
W, H = 320, 180
SCALE = 4
R = random.Random(2026)

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

SKY = [(8, 10, 30), (14, 18, 46), (24, 28, 70), (40, 40, 98), (70, 56, 116), (122, 78, 120), (176, 104, 112)]
FAR0, FAR1, MIST = (44, 46, 100), (58, 60, 120), (86, 78, 136)
VOLC_RIM = (74, 70, 138)
HILL0, HILL1, HILL2 = (24, 40, 58), (32, 52, 68), (44, 66, 78)
LAKE0, LAKE1, LAKE2 = (14, 26, 60), (28, 46, 92), (60, 80, 140)
MOON, MOON2 = (240, 236, 210), (206, 202, 184)
LAMP, LAMP2, GLOW = (255, 206, 104), (255, 240, 176), (150, 112, 96)
WALL, WALL2, ROOF, ROOF2 = (104, 78, 70), (78, 58, 58), (70, 40, 44), (52, 30, 36)
STILT, METAL, PANEL, PANEL2 = (52, 38, 40), (150, 156, 178), (40, 70, 140), (80, 120, 196)
WATER_F, WATER_F2 = (150, 190, 226), (96, 140, 196)
NEAR, NEAR2 = (8, 10, 24), (20, 24, 46)


def new(opaque=False):
    im = Image.new("RGBA", (W, H), SKY[0] + (255,) if opaque else (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def px(im, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        im.putpixel((int(x), int(y)), c + (255,) if len(c) == 3 else c)


def dither_pick(x, y, t):
    """True jika piksel (x, y) memakai warna kedua untuk campuran t (0..1), pola Bayer 4x4."""
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


# ---------------------------------------------------------------- langit

def sky_layer():
    im, d = new(True)
    # Gradasi bertingkat: malam pekat di atas, sedikit hangat di cakrawala (fajar yang akan datang).
    stops = [0, 30, 58, 84, 104, 120, 134]
    for y in range(H):
        k = 0
        while k < len(stops) - 2 and y >= stops[k + 1]:
            k += 1
        t = min(1.0, max(0.0, (y - stops[k]) / (stops[k + 1] - stops[k])))
        for x in range(W):
            px(im, x, y, SKY[k + 1] if dither_pick(x, y, t) else SKY[k])
    # Pendar bulan: cincin dithering yang makin tipis.
    mx, my = 252, 38
    for y in range(0, 100):
        for x in range(190, 320):
            dist = math.hypot(x - mx, y - my)
            if 11 < dist < 40:
                t = (1 - (dist - 11) / 29) ** 1.6 * 0.55
                if dither_pick(x, y, t):
                    base = im.getpixel((x, y))[:3]
                    px(im, x, y, mix(base, (120, 120, 170), 0.35))
    # Bintang: kebanyakan redup, beberapa terang, segelintir berbentuk silang.
    for _ in range(170):
        x, y = R.randrange(W), R.randrange(0, 112)
        if math.hypot(x - mx, y - my) < 16:
            continue
        roll = R.random()
        if roll < 0.62:
            px(im, x, y, mix(im.getpixel((x, y))[:3], (170, 170, 210), 0.6))
        elif roll < 0.94:
            px(im, x, y, (220, 220, 236))
        else:
            px(im, x, y, (255, 250, 230))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px(im, x + dx, y + dy, (130, 130, 180))
    # Bulan dengan kawah.
    d.ellipse([mx - 11, my - 11, mx + 11, my + 11], fill=MOON)
    for cx, cy, r in ((-4, -3, 3), (4, 2, 2), (-1, 5, 2), (5, -5, 1)):
        d.ellipse([mx + cx - r, my + cy - r, mx + cx + r, my + cy + r], fill=MOON2)
    # Awan tipis berlapis (tepi bergelombang) di dekat cakrawala.
    for cy, x0, x1 in ((94, 140, 236), (101, 206, 304), (86, 14, 96), (104, 48, 132)):
        for x in range(x0, x1):
            edge = min(x - x0, x1 - x) / 14.0
            thick = 1.5 + 2.2 * math.sin((x - x0) / float(x1 - x0) * math.pi) + math.sin(x * 0.5) * 0.6
            for yy in range(int(cy - thick), int(cy + thick * 0.6) + 1):
                if dither_pick(x, yy, min(1.0, edge) * 0.6):
                    px(im, x, yy, mix(im.getpixel((x, yy))[:3], (150, 110, 160), 0.4))
    return im


# ---------------------------------------------------------------- gunung jauh

def ridge(seed, base, amp, step):
    rr = random.Random(seed)
    ys = []
    y = base - amp * 0.5
    for x in range(W):
        if x % step == 0:
            target = base - rr.uniform(0.2, 1.0) * amp
        y += (target - y) * 0.12
        ys.append(y)
    return ys


def far_layer():
    im, d = new()
    back = ridge(11, 120, 34, 18)
    front = ridge(23, 128, 22, 14)
    # Gunung api di tengah kanan (siluet khas Indonesia).
    vx, vtop = 196, 62
    for x in range(W):
        cone = vtop + abs(x - vx) * 0.62
        if abs(x - vx) <= 4:
            cone = vtop + 1 + (abs(x - vx) == 4)  # kawah datar
        back[x] = min(back[x], cone)
    for x in range(W):
        for y in range(int(back[x]), 152):
            px(im, x, y, FAR0)
        # Sisi yang menghadap bulan (kanan atas) sedikit lebih terang.
        if x > vx - 2 and x < vx + 40 and back[x] < 110:
            for y in range(int(back[x]), int(back[x]) + 2):
                px(im, x, y, VOLC_RIM)
    for x in range(W):
        for y in range(int(front[x]), 152):
            px(im, x, y, FAR1)
    # Asap tipis dari kawah, melebar dan condong ke kanan.
    for k in range(20):
        cx = vx + k * 0.55 + math.sin(k * 0.45) * 1.5
        cy = vtop - 2 - k * 0.9
        r = 1.0 + k * 0.2
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r), int(cx + r) + 1):
                if math.hypot(xx - cx, yy - cy) <= r and dither_pick(xx, yy, 0.5 * (1 - k / 20.0)):
                    px(im, xx, yy, (92, 86, 140))
    # Kabut di kaki gunung.
    for y in range(118, 140):
        t = (y - 118) / 22.0
        for x in range(W):
            if dither_pick(x, y, t * 0.75):
                px(im, x, y, MIST)
    return im


# ---------------------------------------------------------------- bukit, desa, danau

LAKE_Y = 148


def hill_y(x):
    return 144 - 32 * math.exp(-((x - 266) / 58.0) ** 2) - 9 * math.exp(-((x - 70) / 60.0) ** 2)


def rumah(im, d, x, y, lit=True, w=11):
    """Rumah panggung: badan di atas tiang, atap pelana, jendela menyala."""
    top = y - 9
    for sx in (x + 1, x + w - 2):
        d.line([(sx, y - 3), (sx, y)], fill=STILT)
    d.rectangle([x, top + 2, x + w - 1, y - 3], fill=WALL)
    d.rectangle([x + w - 3, top + 2, x + w - 1, y - 3], fill=WALL2)
    d.polygon([(x - 2, top + 2), (x + w // 2, top - 3), (x + w + 1, top + 2)], fill=ROOF)
    d.line([(x + w // 2, top - 3), (x + w + 1, top + 2)], fill=ROOF2)
    if lit:
        d.rectangle([x + 2, top + 4, x + 3, top + 5], fill=LAMP)
        px(im, x + 2, top + 4, LAMP2)
        d.rectangle([x + 6, top + 4, x + 7, top + 5], fill=LAMP)
        # Pendar jendela di dinding sekitarnya.
        for gx, gy in ((x + 1, top + 4), (x + 4, top + 5), (x + 5, top + 4), (x + 8, top + 5)):
            px(im, gx, gy, mix(WALL, LAMP, 0.35))
    else:
        d.rectangle([x + 2, top + 4, x + 3, top + 5], fill=(30, 30, 50))


def mid_layer():
    im, d = new()
    # Bukit dan tanah sampai tepi danau.
    for x in range(W):
        hy = int(hill_y(x))
        for y in range(hy, LAKE_Y):
            col = HILL1 if y < hy + 2 else HILL0
            px(im, x, y, col)
    # Sawah terasering di lereng kanan: garis kontur lebih terang.
    for x in range(180, W):
        hy = hill_y(x)
        for k in range(1, 8):
            y = int(hy + k * 3 + math.sin(x * 0.08 + k) * 0.8)
            if y < LAKE_Y - 2 and (x + k) % 9 != 0:
                px(im, x, y, HILL2)
    # Tebing kecil + air terjun (mikrohidro) di kiri desa.
    cliff = [(150, LAKE_Y), (152, 126), (158, 120), (170, 118), (176, 124), (178, LAKE_Y)]
    d.polygon(cliff, fill=(30, 46, 62))
    d.line([(152, 126), (158, 120), (170, 118)], fill=HILL2)
    for _ in range(40):
        rx, ry = R.randrange(152, 177), R.randrange(122, LAKE_Y - 1)
        if abs(rx - 164) > 2:
            px(im, rx, ry, (40, 58, 74))
    for y in range(119, LAKE_Y):
        for x in (163, 164, 165):
            px(im, x, y, WATER_F if (y + x * 3) % 5 else WATER_F2)
    for x in range(158, 171):  # buih di kaki air terjun
        if R.random() < 0.7:
            px(im, x, LAKE_Y - 1 - R.randrange(2), WATER_F)
    # Rumah turbin air kecil di samping air terjun.
    d.rectangle([170, LAKE_Y - 7, 176, LAKE_Y - 1], fill=WALL2)
    d.polygon([(169, LAKE_Y - 7), (173, LAKE_Y - 10), (177, LAKE_Y - 7)], fill=ROOF)
    px(im, 172, LAKE_Y - 5, LAMP)
    # Panel surya berjajar di lereng.
    for k, x in enumerate((206, 216, 226)):
        y = int(hill_y(x + 4)) + 1
        d.polygon([(x, y), (x + 8, y), (x + 10, y - 4), (x + 2, y - 4)], fill=PANEL)
        d.line([(x + 2, y - 2), (x + 9, y - 2)], fill=PANEL2)
        d.line([(x + 5, y), (x + 5, y + 2)], fill=METAL)
    # Rumah-rumah di lereng kanan.
    houses = (238, 252, 280, 296, 309)
    for x in houses:
        rumah(im, d, x, int(hill_y(x + 5)) + 1)
    # Beberapa rumah di kiri (akan tertutup bayangan menu, cukup sebagai siluet hangat).
    for x in (20, 46, 92):
        rumah(im, d, x, int(hill_y(x + 5)) + 1, lit=x != 46)
    # Tiang listrik dengan kabel melengkung dan lampu jalan.
    poles = [184, 212, 244, 272, 302]
    tops = []
    for x in poles:
        base = int(hill_y(x)) + 1
        top = base - 12
        d.line([(x, base), (x, top)], fill=STILT)
        d.line([(x - 2, top + 1), (x + 2, top + 1)], fill=STILT)
        px(im, x + 1, top, LAMP2)
        px(im, x + 2, top, LAMP)
        tops.append((x, top + 1))
    for (x0, y0), (x1, y1) in zip(tops, tops[1:]):
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0)
            y = y0 + (y1 - y0) * t + math.sin(t * math.pi) * 3
            px(im, x, int(y), (60, 50, 70))
    # Menara turbin angin di puncak bukit (baling-baling digambar di Godot).
    tx = 268
    tb = int(hill_y(tx)) + 1
    tt = tb - 30
    d.line([(tx, tb), (tx, tt)], fill=METAL)
    d.line([(tx + 1, tb), (tx + 1, tt + 6)], fill=(110, 116, 140))
    d.rectangle([tx - 1, tt - 1, tx + 2, tt + 1], fill=METAL)
    turbine_hub = (tx, tt)
    # Danau: riak, pantulan bulan, pantulan lampu rumah.
    for y in range(LAKE_Y, H):
        t = (y - LAKE_Y) / float(H - LAKE_Y)
        for x in range(W):
            px(im, x, y, LAKE1 if dither_pick(x, y, (1 - t) * 0.5) else LAKE0)
    for y in range(LAKE_Y + 1, H, 2):
        x = R.randrange(6)
        while x < W:
            ln = R.randint(2, 6)
            d.line([(x, y), (x + ln, y)], fill=LAKE2 if R.random() < 0.25 else LAKE1)
            x += ln + R.randint(6, 16)
    for y in range(LAKE_Y + 1, H):
        spread = 3 + (y - LAKE_Y) // 5
        if y % 2 == 0:
            x0 = 252 - spread + R.randint(-1, 1)
            d.line([(x0, y), (x0 + spread * 2 - R.randint(0, 3), y)], fill=(200, 200, 196) if y < 160 else (150, 156, 176))
    for x in houses:
        for y in range(LAKE_Y + 2, LAKE_Y + 14, 3):
            px(im, x + 3 + R.randint(-1, 1), y, (200, 160, 96))
            px(im, x + 4 + R.randint(-1, 1), y, (160, 126, 90))
    # Garis tepi danau.
    d.line([(0, LAKE_Y), (W, LAKE_Y)], fill=(40, 60, 96))
    return im, turbine_hub


# ---------------------------------------------------------------- siluet depan

def palm(im, d, x, base, h, lean):
    pts = []
    for k in range(h):
        t = k / float(h)
        pts.append((x + lean * t * t * h * 0.3, base - k))
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([(x0, y0), (x1, y1)], fill=NEAR, width=3 if y0 > base - h * 0.5 else 2)
    # Cincin batang kelapa (sedikit lebih terang).
    for k in range(4, h - 4, 4):
        px(im, pts[k][0] + 1, pts[k][1], NEAR2)
    cx, cy = pts[-1]
    # Pelepah: garis melengkung ke bawah dengan anak daun yang menggantung.
    for a, ln in ((-2.75, 17), (-2.3, 15), (-1.75, 11), (-1.25, 11), (-0.75, 15), (-0.3, 17), (0.35, 13), (2.8, 13)):
        prev = (cx, cy)
        for s_ in range(1, ln):
            fx = cx + math.cos(a) * s_ * 1.25
            fy = cy + math.sin(a) * s_ * 0.55 + s_ * s_ * 0.045
            d.line([prev, (fx, fy)], fill=NEAR, width=2 if s_ < ln * 0.6 else 1)
            if s_ > 2 and s_ % 2 == 0:
                drop = 2 + (s_ * 3) // ln
                d.line([(fx, fy), (fx + math.cos(a) * 0.8, fy + drop)], fill=NEAR)
            prev = (fx, fy)
    d.ellipse([cx - 2, cy - 1, cx + 2, cy + 2], fill=NEAR2)


def near_layer():
    im, d = new()
    # Tanah depan di kiri dan kanan bawah, dengan rumput.
    for x in range(W):
        left = 166 + 6 * math.sin(x * 0.03)
        y0 = int(left if x < 120 else (176 - 4 * math.sin(x * 0.05) if x < 270 else 166 + (320 - x) * 0.05))
        for y in range(y0, H):
            px(im, x, y, NEAR)
        if x % 3 == 0:
            for y in range(y0 - R.randint(1, 4), y0):
                px(im, x + R.randint(-1, 1), y, NEAR)
    palm(im, d, 24, 172, 96, 0.9)
    palm(im, d, 54, 172, 66, -0.5)
    # Semak di kanan bawah.
    for bx, by, br in ((296, 168, 7), (308, 166, 9), (318, 167, 6)):
        d.ellipse([bx - br, by - br * 0.7, bx + br, by + br], fill=NEAR)
    # Perahu kecil di danau.
    d.polygon([(120, 168), (142, 168), (138, 172), (124, 172)], fill=NEAR2)
    d.line([(131, 168), (131, 158)], fill=NEAR2)
    px(im, 132, 158, LAMP)
    return im


def save(im, name):
    im.resize((W * SCALE, H * SCALE), Image.NEAREST).save(os.path.join(OUT, name))
    print("tulis", name)


def main():
    sky, far = sky_layer(), far_layer()
    mid, hub = mid_layer()
    near = near_layer()
    for im, name in ((sky, "title_sky.png"), (far, "title_far.png"), (mid, "title_mid.png"), (near, "title_near.png")):
        save(im, name)
    print("hub turbin (layar):", (hub[0] * SCALE + SCALE // 2, hub[1] * SCALE + SCALE // 2))
    # Gabungan satu gambar (dipakai juga sebagai title_background.png untuk tempat lain).
    comp = sky.copy()
    for lay in (far, mid, near):
        comp.alpha_composite(lay)
    save(comp.convert("RGB"), "title_background.png")


if __name__ == "__main__":
    main()
