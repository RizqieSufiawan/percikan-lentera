"""Gambar kartu SEMENTARA bergaya pixel art (160x90, diperbesar 2x -> 320x180).

Tujuannya memberi gambaran gaya akhir untuk artis, bukan aset final. Setiap kartu dirakit dari
potongan sederhana (langit, gunung, laut, rumah, panel surya, turbin, hujan, api, orang, dll.)
dengan palet malam yang sama dengan peta.

Pakai:
    python3 tools/make_card_art.py            # tulis semua kartu ke assets/images/
    python3 tools/make_card_art.py --sheet x.png   # plus satu lembar kontak untuk dilihat
"""
import argparse
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 160, 90

# Palet (malam, hangat untuk lampu). Sama nuansanya dengan peta.
C = {
    "night0": (14, 18, 42), "night1": (28, 36, 78), "night2": (46, 58, 112), "dusk": (120, 70, 96),
    "day0": (92, 150, 210), "day1": (150, 196, 230), "storm0": (30, 34, 48), "storm1": (60, 66, 84),
    "orange0": (96, 42, 40), "orange1": (196, 104, 56), "sun": (255, 214, 92), "moon": (236, 236, 210),
    "mount0": (40, 44, 86), "mount1": (58, 64, 110), "mount2": (78, 88, 134),
    "sea0": (20, 52, 96), "sea1": (34, 84, 140), "foam": (170, 214, 236),
    "ground": (58, 80, 52), "ground2": (76, 104, 60), "dry": (150, 116, 72), "dry2": (118, 88, 54),
    "mud": (110, 84, 56), "mud2": (138, 108, 70),
    "wall": (196, 160, 116), "wall2": (150, 118, 86), "roof": (150, 66, 52), "roof2": (110, 46, 40),
    "lamp": (255, 210, 110), "lamp2": (255, 238, 170), "dark_win": (34, 36, 58),
    "panel": (52, 92, 170), "panel2": (90, 140, 220), "metal": (170, 176, 190), "metal2": (110, 116, 132),
    "white": (236, 236, 228), "black": (12, 12, 20), "red": (210, 62, 52), "red2": (150, 36, 36),
    "green": (98, 196, 110), "gold": (240, 196, 72), "skin": (210, 156, 112), "shirt": (64, 120, 196),
    "shirt2": (226, 180, 60), "fire0": (255, 220, 96), "fire1": (240, 120, 40), "fire2": (180, 50, 30),
    "smoke": (90, 90, 100), "smoke2": (130, 130, 140), "ash": (70, 66, 72), "lava": (255, 110, 40),
    "leaf": (52, 120, 64), "leaf2": (82, 156, 80), "trunk": (96, 66, 44), "teal": (40, 200, 190),
    "paper": (232, 224, 200), "steam": (210, 214, 224), "grey": (120, 124, 140),
}


class Card:
    def __init__(self, seed=1):
        self.im = Image.new("RGB", (W, H), C["night0"])
        self.d = ImageDraw.Draw(self.im)
        self.r = random.Random(seed)

    # ---------------------------------------------------------------- dasar
    def px(self, x, y, col):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((int(x), int(y)), C[col] if isinstance(col, str) else col)

    def rect(self, x0, y0, x1, y1, col):
        self.d.rectangle([x0, y0, x1, y1], fill=C[col] if isinstance(col, str) else col)

    def poly(self, pts, col):
        self.d.polygon(pts, fill=C[col] if isinstance(col, str) else col)

    def line(self, pts, col, w=1):
        self.d.line(pts, fill=C[col] if isinstance(col, str) else col, width=w)

    def sky(self, top, bottom, y1=H):
        """Gradasi bertingkat dengan dithering (khas pixel art)."""
        a, b = C[top], C[bottom]
        bands = 6
        for y in range(y1):
            t = y / max(1, y1 - 1) * bands
            k0 = int(t)
            frac = t - k0
            for x in range(W):
                k = k0 + (1 if frac > 0.5 and (x + y) % 2 == 0 else 0)
                f = min(1.0, k / bands)
                self.im.putpixel((x, y), tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3)))

    def stars(self, n=30, y1=40):
        for _ in range(n):
            self.px(self.r.randrange(W), self.r.randrange(y1), "white" if self.r.random() < 0.3 else "night2")

    def disc(self, cx, cy, r, col, glow=None):
        if glow:
            self.d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=C[glow])
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C[col])

    def mountains(self, base_y, height, col, step=14, seed=0):
        rr = random.Random(seed)
        pts = [(0, H)]
        x = -10
        while x < W + 20:
            pts.append((x, base_y - rr.randint(height // 2, height)))
            x += rr.randint(step // 2, step)
            pts.append((x, base_y - rr.randint(0, height // 3)))
            x += rr.randint(step // 2, step)
        pts.append((W, H))
        self.poly(pts, col)

    def ground(self, y, col="ground", col2="ground2"):
        self.rect(0, y, W, H, col)
        for _ in range(W):
            self.px(self.r.randrange(W), self.r.randrange(y, H), col2)

    def sea(self, y, rough=False):
        self.rect(0, y, W, H, "sea0")
        for yy in range(y, H, 3):
            for x in range(self.r.randrange(4), W, self.r.randint(6, 12) if not rough else 4):
                self.line([(x, yy), (x + (3 if rough else 2), yy)], "sea1" if not rough else "foam")

    # ---------------------------------------------------------------- benda
    def house(self, x, y, lit=True, s=1):
        w, h = 12 * s, 8 * s
        self.rect(x, y - h, x + w, y, "wall")
        self.rect(x + w - 2 * s, y - h, x + w, y, "wall2")
        self.poly([(x - 2, y - h), (x + w // 2, y - h - 6 * s), (x + w + 2, y - h)], "roof")
        self.line([(x + w // 2, y - h - 6 * s), (x + w + 2, y - h)], "roof2")
        self.rect(x + 2 * s, y - h + 2 * s, x + 4 * s, y - h + 4 * s, "lamp" if lit else "dark_win")
        self.rect(x + 7 * s, y - h + 2 * s, x + 8 * s, y - 1, "trunk")
        if lit:
            self.px(x + 2 * s - 1, y - h + 3 * s, "lamp2")

    def panel(self, x, y, broken=False):
        self.poly([(x, y), (x + 14, y), (x + 18, y - 7), (x + 4, y - 7)], "panel")
        for i in range(1, 4):
            self.line([(x + i * 4 + 1, y - 1), (x + i * 4 + 4, y - 6)], "panel2")
        self.line([(x + 2, y - 3), (x + 16, y - 3)], "panel2")
        self.line([(x + 7, y), (x + 7, y + 4)], "metal2")
        if broken:
            self.line([(x + 6, y - 6), (x + 9, y - 3), (x + 7, y - 1)], "black")
            self.line([(x + 12, y - 5), (x + 14, y - 2)], "black")

    def turbine(self, x, y, h=26, bent=False, t=0.0):
        self.line([(x, y), (x, y - h)], "metal", 2)
        cx, cy = x, y - h
        for k in range(3):
            a = t + k * 2.094 + (0.6 if bent else 0)
            self.line([(cx, cy), (cx + math.cos(a) * 11, cy + math.sin(a) * 11)], "white")
        self.px(cx, cy, "metal2")

    def hydro_hut(self, x, y):
        self.rect(x, y - 7, x + 9, y, "metal2")
        self.rect(x + 1, y - 6, x + 3, y - 4, "lamp")
        self.line([(x - 8, y - 12), (x, y - 3)], "metal", 2)

    def biomass(self, x, y):
        self.rect(x, y - 9, x + 14, y, "wall2")
        self.rect(x + 10, y - 16, x + 12, y - 9, "metal2")
        for i in range(4):
            self.px(x + 11 + i, y - 18 - i * 2, "smoke2")
            self.px(x + 12 + i, y - 19 - i * 2, "smoke")

    def geo(self, x, y):
        self.line([(x, y - 4), (x + 22, y - 4)], "metal", 2)
        self.rect(x + 22, y - 10, x + 30, y, "metal2")
        for i in range(5):
            self.px(x + 25 + (i % 2), y - 12 - i * 2, "steam")
            self.px(x + 27 - (i % 2), y - 13 - i * 2, "steam")

    def pole(self, x, y, h=18):
        self.line([(x, y), (x, y - h)], "trunk")
        self.line([(x - 3, y - h + 2), (x + 3, y - h + 2)], "trunk")

    def wire(self, x0, x1, y):
        for x in range(x0, x1):
            sag = int(2 * math.sin((x - x0) / max(1, x1 - x0) * math.pi))
            self.px(x, y + sag, "black")

    def person(self, x, y, shirt="shirt", arm_up=False):
        self.rect(x, y - 6, x + 1, y - 5, "skin")
        self.rect(x, y - 4, x + 1, y - 2, shirt)
        self.px(x, y - 1, "black")
        self.px(x + 1, y - 1, "black")
        if arm_up:
            self.px(x + 2, y - 6, "skin")
            self.px(x + 2, y - 5, shirt)

    def crowd(self, x, y, n, shirts=("shirt", "shirt2", "red", "green"), arm_up=False):
        for i in range(n):
            self.person(x + i * 4 + self.r.randint(0, 1), y + self.r.randint(-1, 1), self.r.choice(shirts), arm_up)

    def tree(self, x, y, dry=False, burning=False):
        self.line([(x, y), (x, y - 8)], "trunk", 2)
        if dry:
            self.line([(x, y - 6), (x - 4, y - 10)], "trunk")
            self.line([(x, y - 7), (x + 4, y - 11)], "trunk")
            return
        self.disc(x, y - 11, 5, "leaf")
        self.px(x - 2, y - 13, "leaf2")
        self.px(x + 1, y - 14, "leaf2")
        if burning:
            self.flame(x, y - 12, 5)

    def flame(self, x, y, s=4):
        for i in range(s * 3):
            dx = self.r.randint(-s, s)
            dy = self.r.randint(-s * 2, 0)
            self.px(x + dx, y + dy, self.r.choice(["fire0", "fire1", "fire1", "fire2"]))

    def smoke(self, x, y, n=20, col="smoke"):
        for i in range(n):
            self.disc(x + i * 1.2 + self.r.randint(-2, 2), y - i * 1.5, 2 + i // 6, col if i % 3 else "smoke2")

    def rain(self, n=120, col="foam"):
        for _ in range(n):
            x, y = self.r.randrange(W), self.r.randrange(H)
            self.line([(x, y), (x - 1, y + 2)], col)

    def lightning(self, x):
        pts = [(x, 0), (x - 3, 10), (x + 2, 12), (x - 4, 26)]
        self.line(pts, "lamp2", 1)

    def clouds(self, y, col="storm1", n=6):
        for i in range(n):
            self.disc(i * 30 + self.r.randint(-6, 6), y + self.r.randint(-3, 3), 10, col)

    def stamp(self, x, y, col="red"):
        self.d.ellipse([x, y, x + 16, y + 16], outline=C[col], width=2)
        self.line([(x + 3, y + 13), (x + 13, y + 3)], col, 2)

    def bars(self, x, y, vals, col="green", w=6):
        for i, v in enumerate(vals):
            self.rect(x + i * (w + 2), y - v, x + i * (w + 2) + w, y, col)

    def text(self, x, y, s, col="white", scale=1):
        """Huruf piksel 3x5 (angka dan beberapa huruf)."""
        font = {
            "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
            "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
            "8": "111101111101111", "9": "111101111001111", "%": "101001010100101", "!": "010010010000010",
            "X": "101101010101101", "+": "000010111010000", "-": "000000111000000", "?": "111001011000010",
        }
        cx = x
        for ch in s:
            g = font.get(ch)
            if g:
                for i, bit in enumerate(g):
                    if bit == "1":
                        self.rect(cx + (i % 3) * scale, y + (i // 3) * scale, cx + (i % 3) * scale + scale - 1,
                                  y + (i // 3) * scale + scale - 1, col)
            cx += 4 * scale

    def village(self, y, lit_frac=1.0, n=6, x0=10, gap=24):
        for i in range(n):
            self.house(x0 + i * gap + self.r.randint(-2, 2), y + self.r.randint(-1, 1), lit=self.r.random() < lit_frac)

    def save(self, rel):
        out = os.path.join(ROOT, "assets", "images", rel)
        self.im.resize((W * 2, H * 2), Image.NEAREST).save(out)
        return self.im


# ---------------------------------------------------------------- kartu

def night_village(c, lit=1.0, sea=False, panels=2, turb=False):
    c.sky("night0", "night2", 60)
    c.stars()
    c.disc(130, 14, 5, "moon")
    c.mountains(62, 22, "mount0", seed=3)
    c.mountains(66, 12, "mount1", seed=5)
    if sea:
        c.sea(72)
        c.ground(64, "ground", "ground2")
        c.rect(0, 72, W, H, "sea0")
        c.sea(74)
    else:
        c.ground(66)
    c.village(72 if not sea else 70, lit, n=6)
    for i in range(panels):
        c.panel(20 + i * 50, 82 if not sea else 72)
    if turb:
        c.turbine(140, 70)


def ev_badai(c):
    c.sky("storm0", "storm1", 60)
    c.clouds(8, "storm1")
    c.clouds(16, "smoke")
    c.lightning(110)
    c.sea(60, rough=True)
    c.ground(56, "ground", "ground2")
    c.rect(0, 62, W, H, "sea0")
    c.sea(64, rough=True)
    c.house(20, 56)
    c.house(48, 56, lit=False)
    c.turbine(96, 56, bent=True)
    c.panel(120, 55, broken=True)
    c.rain(160)


def ev_bakar(c):
    c.sky("orange0", "orange1", 55)
    c.disc(30, 20, 8, "sun", "fire1")
    c.ground(55, "dry2", "dry")
    for x in (40, 70, 100, 130):
        c.flame(x, 62, 5)
        c.smoke(x, 50, 14)
    c.person(20, 72)
    c.biomass(120, 82)
    c.text(10, 80, "!", "fire0", 2)


def ev_banjir(c):
    c.sky("storm0", "storm1", 50)
    c.clouds(10, "storm1")
    c.rain(140)
    c.mountains(50, 20, "mount1", seed=7)
    c.ground(52)
    c.house(14, 62)
    c.house(46, 64, lit=False)
    c.hydro_hut(100, 62)
    c.rect(0, 62, W, H, "mud")
    for y in range(64, H, 3):
        for x in range(c.r.randrange(4), W, 7):
            c.line([(x, y), (x + 3, y)], "mud2")
    c.person(80, 61, arm_up=True)


def ev_erupsi(c):
    c.sky("night0", "orange0", 70)
    c.poly([(30, 75), (80, 22), (92, 22), (140, 75)], "mount1")
    c.poly([(80, 22), (92, 22), (88, 30), (84, 34)], "lava")
    c.line([(86, 26), (78, 50), (74, 60)], "lava")
    c.smoke(86, 18, 26, "ash")
    for _ in range(40):
        c.px(c.r.randrange(W), c.r.randrange(40), "ash")
    c.ground(72)
    c.geo(10, 84)
    c.village(84, 0.5, n=3, x0=90, gap=20)


def ev_hoaks(c):
    night_village(c, 0.6, panels=1)
    c.rect(52, 16, 108, 86, "black")
    c.rect(55, 22, 105, 80, "night1")
    c.rect(60, 28, 100, 40, "red2")
    c.text(64, 31, "!!!", "white", 2)
    for i in range(4):
        c.rect(60, 46 + i * 7, 100 - c.r.randint(0, 20), 49 + i * 7, "grey")
    c.panel(70, 78, broken=True)


def ev_investor(c):
    c.sky("day0", "day1", 50)
    c.mountains(50, 26, "mount2", seed=2)
    c.ground(50)
    c.rect(55, 30, 105, 70, "metal")
    for x in range(58, 104, 6):
        c.line([(x, 32), (x, 68)], "metal2")
    c.rect(0, 70, W, H, "sea1")
    c.rect(78, 70, 82, H, "foam")
    c.person(30, 70, "black")
    c.person(36, 70, "black")
    c.rect(28, 58, 40, 62, "gold")
    c.crowd(118, 70, 6)


def ev_izin(c):
    c.sky("night1", "night2", 60)
    c.rect(14, 30, 70, 80, "wall2")
    for i in range(3):
        c.rect(18 + i * 18, 38, 28 + i * 18, 46, "lamp")
        c.rect(18 + i * 18, 54, 28 + i * 18, 62, "dark_win")
    c.rect(36, 66, 48, 80, "trunk")
    c.ground(80)
    c.rect(86, 18, 140, 84, "paper")
    for i in range(6):
        c.line([(92, 28 + i * 8), (134 - c.r.randint(0, 16), 28 + i * 8)], "grey")
    c.stamp(110, 58)


def ev_kemarau(c):
    c.sky("orange1", "sun", 44)
    c.disc(126, 16, 10, "sun", "fire0")
    c.ground(44, "dry", "dry2")
    for _ in range(26):
        x, y = c.r.randrange(W), c.r.randrange(48, H)
        c.line([(x, y), (x + c.r.randint(-6, 6), y + 3)], "dry2")
    c.line([(0, 70), (60, 64), (100, 72), (160, 66)], "mud2", 3)
    c.tree(30, 60, dry=True)
    c.tree(130, 62, dry=True)
    c.hydro_hut(70, 66)


def ev_lobi(c):
    c.sky("night0", "red2", 60)
    c.rect(110, 26, 140, 70, "metal2")
    c.rect(118, 6, 124, 26, "metal2")
    c.smoke(121, 4, 12, "smoke")
    c.ground(70)
    c.line([(20, 70), (20, 34)], "trunk")
    c.line([(80, 70), (80, 34)], "trunk")
    c.rect(20, 34, 80, 48, "paper")
    c.text(30, 38, "X!X", "red", 2)
    c.crowd(24, 84, 12, ("red", "red2", "black"), arm_up=True)


def ev_plts_rusak(c):
    c.sky("day0", "day1", 50)
    c.disc(30, 16, 7, "sun", "fire0")
    c.ground(50)
    for i in range(4):
        c.panel(14 + i * 36, 70, broken=(i % 2 == 0))
    for _ in range(30):
        c.px(c.r.randrange(10, 150), c.r.randrange(56, 70), "dry")
    c.person(80, 84, "shirt2")
    c.rect(84, 79, 87, 81, "metal")


def ev_solar(c):
    c.sky("night0", "night2", 60)
    c.ground(60)
    for i in range(4):
        x = 20 + i * 18
        c.rect(x, 50, x + 12, 76, "red2")
        c.line([(x, 56), (x + 12, 56)], "black")
        c.line([(x, 70), (x + 12, 70)], "black")
    c.rect(100, 56, 140, 76, "metal2")
    c.rect(104, 60, 112, 66, "lamp")
    c.smoke(140, 52, 10)
    c.rect(96, 20, 150, 40, "paper")
    c.text(102, 25, "-50%", "red", 2)


def ev_tawaran(c):
    c.sky("day0", "day1", 50)
    c.ground(70)
    c.rect(30, 30, 130, 70, "white")
    c.poly([(26, 30), (80, 12), (134, 30)], "metal")
    for x in range(38, 128, 14):
        c.rect(x, 36, x + 4, 70, "metal")
    c.line([(80, 12), (80, 0)], "metal2")
    c.rect(80, 0, 92, 4, "red")
    c.rect(80, 4, 92, 8, "white")
    c.person(70, 84, "black")
    c.person(86, 84, "shirt2")
    c.rect(73, 78, 85, 79, "skin")


def ev_titik_api(c):
    c.sky("night0", "night2", 50)
    c.stars(20)
    c.ground(60, "leaf", "leaf2")
    for i in range(9):
        c.tree(8 + i * 18, 70 + c.r.randint(-2, 2), burning=(i == 6))
    c.smoke(116, 46, 14)
    c.line([(30, 84), (30, 50)], "trunk", 2)
    c.rect(24, 44, 36, 50, "wall2")
    c.px(29, 46, "lamp")


def milestone(c, year, lit):
    c.sky("night0", "night2", 60)
    c.stars()
    c.mountains(62, 18, "mount0", seed=year)
    c.ground(66)
    c.village(76, lit, n=6)
    c.text(52, 14, str(year), "gold" if lit > 0.7 else "white", 3)
    c.bars(116, 56, [int(4 + lit * 20 * k / 4) for k in range(1, 5)], "green")


def news_airplane(c):
    c.sky("day0", "day1", 60)
    c.sea(60)
    for x, w in ((10, 40), (70, 30), (118, 34)):
        c.d.ellipse([x, 62, x + w, 72], fill=C["ground"])
    c.poly([(60, 30), (100, 26), (104, 28), (64, 34)], "white")
    c.poly([(78, 28), (86, 18), (90, 18), (86, 29)], "white")
    c.poly([(98, 26), (104, 20), (106, 21), (103, 27)], "red")


def news_kkn(c, start):
    c.sky("day0", "day1", 50)
    c.mountains(50, 20, "mount2", seed=11)
    c.ground(50)
    c.village(62, 0.0 if start else 1.0, n=4, x0=86, gap=18)
    c.rect(14, 60, 54, 78, "gold")
    c.rect(18, 63, 26, 69, "day1")
    c.rect(30, 63, 38, 69, "day1")
    c.rect(42, 63, 50, 69, "day1")
    c.disc(22, 80, 3, "black")
    c.disc(46, 80, 3, "black")
    c.crowd(58, 84, 5, ("shirt", "shirt2"), arm_up=not start)


def news_target_failed(c):
    c.sky("night0", "night1", 90)
    c.bars(30, 80, [40, 32, 22, 12], "grey", 14)
    c.line([(26, 20), (110, 76)], "red", 3)
    c.line([(110, 20), (26, 76)], "red", 3)


def news_first_lit(c):
    night_village(c, 0.0, panels=0)
    c.house(70, 74, lit=True, s=2)
    c.panel(104, 82)
    c.disc(78, 56, 2, "lamp2")
    c.crowd(40, 84, 4, arm_up=True)


def news_independent(c):
    night_village(c, 1.0, panels=3, turb=True)
    c.crowd(52, 86, 10, arm_up=True)
    for x, y in ((30, 18), (70, 10), (110, 22)):
        for k in range(8):
            a = k * 0.785
            c.px(x + math.cos(a) * 5, y + math.sin(a) * 5, "gold")


def news_red_high(c):
    c.sky("red2", "orange0", 70)
    for x in (30, 70, 110):
        c.rect(x, 30, x + 26, 72, "metal2")
        c.rect(x + 8, 10, x + 13, 30, "metal2")
        c.smoke(x + 10, 8, 10, "black")
    c.ground(72, "ash", "smoke")


def news_seed(c):
    night_village(c, 0.3, panels=1)
    for r in (6, 11, 16):
        c.d.arc([80 - r, 30 - r, 80 + r, 30 + r], 200, 340, fill=C["teal"], width=2)
    c.disc(80, 32, 2, "teal")
    c.line([(80, 84), (80, 74)], "leaf2", 2)
    c.disc(77, 72, 3, "leaf2")
    c.disc(83, 71, 3, "leaf")


def news_stage(c, k, label=None):
    c.sky("night0", "night1", 90)
    c.sea(0)
    islands = [(8, 30, 40, 12), (52, 40, 30, 10), (90, 34, 26, 14), (124, 44, 30, 12), (40, 66, 60, 8)]
    for i, (x, y, w, h) in enumerate(islands):
        c.d.ellipse([x, y, x + w, y + h], fill=C["dry2"])
        if i < k:
            for _ in range(10):
                c.px(x + c.r.randrange(4, w - 4), y + c.r.randrange(2, h - 2), "lamp")
    if label:
        c.text(74, 6, label, "gold", 3)


def news_village_down(c):
    night_village(c, 0.0, panels=1)
    c.line([(110, 84), (124, 64)], "trunk", 2)
    c.line([(118, 70), (126, 72)], "trunk")
    c.text(66, 20, "!", "red", 3)


def end_win(c):
    news_independent(c)


def end_lose(c):
    c.sky("storm0", "night0", 60)
    c.mountains(62, 18, "mount0", seed=13)
    c.ground(66, "ash", "smoke")
    c.village(76, 0.0, n=6)
    c.smoke(120, 50, 14, "black")


def guide(c, k):
    scenes = [
        lambda: news_stage(c, 2),
        lambda: night_village(c, 0.5, panels=2),
        lambda: (c.sky("day0", "day1", 50), c.ground(50), c.hydro_hut(20, 70), c.panel(60, 70), c.biomass(96, 74),
                 c.turbine(140, 70)),
        lambda: news_kkn(c, True),
        lambda: (c.sky("night0", "night2", 90), c.bars(20, 80, [10, 18, 26, 40, 56], "green", 16)),
        lambda: (night_village(c, 0.8, panels=1), c.crowd(40, 86, 10, arm_up=True)),
        lambda: ev_banjir(c),
        lambda: ev_lobi(c),
        lambda: news_airplane(c),
        lambda: end_win(c),
    ]
    scenes[k]()


def intro(c, k):
    [lambda: night_village(c, 0.0, panels=0),
     lambda: news_kkn(c, True),
     lambda: news_first_lit(c),
     lambda: news_independent(c)][k]()


CARDS = {
    "events/badai_pesisir.png": ev_badai, "events/bakar_lahan.png": ev_bakar, "events/banjir_bandang.png": ev_banjir,
    "events/erupsi.png": ev_erupsi, "events/hoaks_panel.png": ev_hoaks, "events/investor_plta.png": ev_investor,
    "events/izin_ditahan.png": ev_izin, "events/kemarau_panjang.png": ev_kemarau, "events/lobi_hoaks.png": ev_lobi,
    "events/plts_rusak.png": ev_plts_rusak, "events/solar_subsidi.png": ev_solar,
    "events/tawaran_pemerintah.png": ev_tawaran, "events/titik_api.png": ev_titik_api,
    "milestones/target_2030.png": lambda c: milestone(c, 2030, 0.2),
    "milestones/ken_2040.png": lambda c: milestone(c, 2040, 0.4),
    "milestones/emas_2045.png": lambda c: milestone(c, 2045, 0.6),
    "milestones/ken_2050.png": lambda c: milestone(c, 2050, 0.75),
    "milestones/ken_2060.png": lambda c: milestone(c, 2060, 1.0),
    "news/airplane_opened.png": news_airplane, "news/kkn_start.png": lambda c: news_kkn(c, True),
    "news/kkn_end.png": lambda c: news_kkn(c, False), "news/offer_target_failed.png": news_target_failed,
    "news/province_first_lit.png": news_first_lit, "news/province_independent.png": news_independent,
    "news/red_high.png": news_red_high, "news/seed_ignited.png": news_seed,
    "news/stage_3.png": lambda c: news_stage(c, 1, "3"), "news/stage_4.png": lambda c: news_stage(c, 2, "4"),
    "news/stage_5.png": lambda c: news_stage(c, 3, "5"), "news/stage_6.png": lambda c: news_stage(c, 5, "6"),
    "news/village_down.png": news_village_down,
    "end/win.png": end_win, "end/lose.png": end_lose,
}
for i in range(10):
    CARDS["slides/guide_%d.png" % (i + 1)] = (lambda k: lambda c: guide(c, k))(i)
for i in range(4):
    CARDS["slides/intro_%d.png" % (i + 1)] = (lambda k: lambda c: intro(c, k))(i)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet")
    a = ap.parse_args()
    thumbs = []
    for i, (rel, fn) in enumerate(sorted(CARDS.items())):
        c = Card(seed=i + 1)
        fn(c)
        thumbs.append((rel, c.save(rel)))
    if a.sheet:
        cols = 6
        rows = (len(thumbs) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (W * 2 + 8), rows * (H * 2 + 8)), (0, 0, 0))
        for i, (_, im) in enumerate(thumbs):
            sheet.paste(im.resize((W * 2, H * 2), Image.NEAREST), ((i % cols) * (W * 2 + 8), (i // cols) * (H * 2 + 8)))
        sheet.save(a.sheet)
    print("ok: %d kartu" % len(thumbs))


if __name__ == "__main__":
    main()
