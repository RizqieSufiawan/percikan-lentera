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

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 160, 90
BAYER = [[(v + 0.5) / 16.0 for v in row] for row in ([0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5])]

# Palet (malam, hangat untuk lampu). Sama nuansanya dengan peta.
C = {
    "night0": (10, 12, 34), "night1": (24, 28, 70), "night2": (56, 48, 108), "dusk": (122, 78, 120),
    "day0": (92, 150, 210), "day1": (150, 196, 230), "storm0": (30, 34, 48), "storm1": (60, 66, 84),
    "orange0": (96, 42, 40), "orange1": (196, 104, 56), "sun": (255, 214, 92), "moon": (236, 236, 210),
    "mount0": (44, 46, 100), "mount1": (58, 60, 120), "mount2": (86, 78, 136), "mist": (86, 78, 136),
    "hill0": (24, 40, 58), "hill1": (32, 52, 68), "hill2": (48, 70, 82), "stilt": (52, 38, 40),
    "sea0": (14, 30, 66), "sea1": (40, 62, 116), "foam": (170, 214, 236), "sea2": (72, 96, 156),
    "ground": (58, 80, 52), "ground2": (76, 104, 60), "dry": (150, 116, 72), "dry2": (118, 88, 54),
    "mud": (110, 84, 56), "mud2": (138, 108, 70),
    "wall": (104, 78, 70), "wall2": (78, 58, 58), "roof": (70, 40, 44), "roof2": (52, 30, 36),
    "wallday": (196, 160, 116), "wallday2": (150, 118, 86), "roofday": (150, 66, 52), "roofday2": (110, 46, 40),
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
    @staticmethod
    def _c(col):
        return C[col] if isinstance(col, str) else col

    def is_night(self):
        top = self.im.getpixel((0, 0))
        return sum(top) < 200

    def mixpx(self, x, y, col, t):
        """Campur warna piksel (x, y) ke col sebesar t, bertingkat + dithering (halus, tetap pixel art)."""
        if not (0 <= x < W and 0 <= y < H):
            return
        q = max(0.0, min(1.0, t)) * 4
        lvl = int(q)
        if lvl < 4 and q - lvl > BAYER[y % 4][x % 4]:
            lvl += 1
        if lvl == 0:
            return
        a = self.im.getpixel((int(x), int(y)))
        b = self._c(col)
        f = lvl / 4.0
        self.im.putpixel((int(x), int(y)), tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3)))

    def glow(self, cx, cy, r, col, strength=0.5):
        """Pendar bulat berdithering (lampu, bulan, api)."""
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                d = math.hypot(x - cx, y - cy)
                if d < r:
                    self.mixpx(x, y, col, (1 - d / r) ** 1.6 * strength)

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
        """Gradasi halus: 4 tingkat antara tiap pasang warna + dithering Bayer (sama dengan menu)."""
        a, b = self._c(top), self._c(bottom)
        steps = 14
        for y in range(y1):
            t = y / max(1, y1 - 1)
            q = t * steps
            lvl = int(q)
            for x in range(W):
                k = lvl + (1 if lvl < steps and q - lvl > BAYER[y % 4][x % 4] else 0)
                f = k / steps
                self.im.putpixel((x, y), tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3)))
        self.moon_x = None

    def stars(self, n=30, y1=40):
        """Bintang: kebanyakan redup, sebagian terang, segelintir berbentuk silang."""
        for _ in range(n):
            x, y = self.r.randrange(W), self.r.randrange(max(1, y1))
            roll = self.r.random()
            if roll < 0.6:
                self.mixpx(x, y, (170, 170, 210), 0.6)
            elif roll < 0.93:
                self.px(x, y, (220, 220, 236))
            else:
                self.px(x, y, (255, 250, 230))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    self.mixpx(x + dx, y + dy, (150, 150, 200), 0.75)

    def disc(self, cx, cy, r, col, glow=None):
        if col == "moon":
            # Bulan: pendar bertingkat, kawah, dan ingat posisinya untuk pantulan di laut.
            self.glow(cx, cy, r * 3.2, (120, 120, 170), 0.55)
            self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C["moon"])
            for ox, oy, rr in ((-0.35, -0.25, 0.28), (0.35, 0.2, 0.2), (-0.1, 0.45, 0.18)):
                x0, y0, q = cx + ox * r, cy + oy * r, max(1.0, rr * r)
                self.d.ellipse([x0 - q, y0 - q, x0 + q, y0 + q], fill=(206, 202, 184))
            self.moon_x = cx
            return
        if col == "sun":
            self.glow(cx, cy, r * 2.6, (255, 220, 140), 0.45)
        if glow:
            self.d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=C[glow])
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=self._c(col))

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
        # Tepi atas sedikit terang (cahaya bulan/langit), lalu kabut tipis di kaki gunung.
        base = self._c(col)
        rim = tuple(min(255, v + 18) for v in base)
        for x in range(W):
            for y in range(H):
                if self.im.getpixel((x, y)) == base:
                    self.px(x, y, rim)
                    break
        if self.is_night():
            for y in range(base_y - height // 2, min(H, base_y + 2)):
                t = (y - (base_y - height // 2)) / max(1, height // 2 + 2)
                for x in range(W):
                    if self.im.getpixel((x, y)) in (base, rim):
                        self.mixpx(x, y, "mist", t * 0.55)

    def ground(self, y, col="ground", col2="ground2"):
        """Tanah: malam = bukit hijau kebiruan bergaris teras (seperti menu); siang = rumput."""
        night = self.is_night() and col == "ground"
        c0 = "hill0" if night else col
        c1 = "hill1" if night else col2
        self.rect(0, y, W, H, c0)
        self.line([(0, y), (W, y)], c1)
        line_col = "hill2" if night else col2
        for k, yy in enumerate(range(y + 3, H, 3)):
            for x in range(W):
                if (x + k * 3) % 11 != 0 and int(math.sin(x * 0.09 + k) * 0.8 + 0.5) == 0:
                    self.px(x, yy, line_col)

    def sea(self, y, rough=False):
        """Laut/danau: gradasi halus, riak jarang, pantulan bulan bila ada bulan."""
        top, bot = C["sea1"], C["sea0"]
        for yy in range(y, H):
            t = (yy - y) / max(1, H - y)
            for x in range(W):
                q = t * 4
                lvl = int(q) + (1 if q - int(q) > BAYER[yy % 4][x % 4] else 0)
                f = min(1.0, lvl / 4.0)
                self.im.putpixel((x, yy), tuple(int(top[i] + (bot[i] - top[i]) * f) for i in range(3)))
        for yy in range(y + 1, H, 2):
            x = self.r.randrange(6)
            while x < W:
                ln = self.r.randint(2, 4 if not rough else 6)
                self.line([(x, yy), (x + ln, yy)], "foam" if rough and self.r.random() < 0.5 else ("sea2" if self.r.random() < 0.3 else "sea1"))
                x += ln + self.r.randint(5 if rough else 7, 14)
        mx = getattr(self, "moon_x", None)
        if mx is not None and not rough:
            for k, yy in enumerate(range(y + 1, H, 2)):
                hw = 2 + k // 2
                self.line([(mx - hw + self.r.randint(-1, 1), yy), (mx + hw, yy)], (206, 204, 196) if k < 4 else (150, 156, 176))

    # ---------------------------------------------------------------- benda
    def house(self, x, y, lit=True, s=1):
        """Rumah panggung (seperti menu): tiang, dinding, atap pelana bersisi gelap, jendela menyala
        dengan pendar. Siang hari memakai warna dinding terang."""
        night = self.is_night()
        wall, wall2 = ("wall", "wall2") if night else ("wallday", "wallday2")
        roof, roof2 = ("roof", "roof2") if night else ("roofday", "roofday2")
        w, h = 11 * s, 6 * s
        top = y - h - 2 * s
        for sx in (x + 1, x + w - 2):
            self.line([(sx, y - 2 * s), (sx, y)], "stilt")
        self.rect(x, top, x + w - 1, y - 2 * s, wall)
        self.rect(x + w - 3 * s, top, x + w - 1, y - 2 * s, wall2)
        self.poly([(x - 2, top), (x + w // 2, top - 5 * s), (x + w + 1, top)], roof)
        self.line([(x + w // 2, top - 5 * s), (x + w + 1, top)], roof2)
        for wx in (x + 2 * s, x + 6 * s):
            if lit:
                if night:
                    self.glow(wx + 0.5 * s, top + 2.5 * s, 4.5 * s, (255, 206, 104), 0.35)
                self.rect(wx, top + 2 * s, wx + s, top + 3 * s, "lamp")
                self.px(wx, top + 2 * s, "lamp2")
            else:
                self.rect(wx, top + 2 * s, wx + s, top + 3 * s, "dark_win")

    def panel(self, x, y, broken=False):
        self.poly([(x - 1, y + 1), (x + 15, y + 1), (x + 19, y - 8), (x + 3, y - 8)], (24, 34, 66))
        self.poly([(x, y), (x + 14, y), (x + 18, y - 7), (x + 4, y - 7)], "panel")
        for i in range(1, 4):
            self.line([(x + i * 4 + 1, y - 1), (x + i * 4 + 4, y - 6)], (34, 60, 120))
        self.line([(x + 2, y - 3), (x + 16, y - 3)], (34, 60, 120))
        self.line([(x + 5, y - 6), (x + 17, y - 6)], "panel2")
        self.line([(x + 7, y + 1), (x + 7, y + 4)], "metal2")
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
        """Huruf piksel 3x5 (angka, A-Z, beberapa tanda). Spasi = 4 piksel."""
        font = {
            "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
            "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
            "8": "111101111101111", "9": "111101111001111", "%": "101001010100101", "!": "010010010000010",
            "X": "101101010101101", "+": "000010111010000", "-": "000000111000000", "?": "111001011000010",
            "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
            "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
            "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
            "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
            "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
            "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "Y": "101101010010010",
            "Z": "111001010100111", ".": "000000000000010", ":": "000010000010000", "/": "001001010100100",
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

    # ---------------------------------------------------------------- tokoh besar & penanda cerita
    def hero(self, x, y, shirt="shirt", pose="stand", hat=None, pants=(44, 48, 78), skin="skin",
             hair=(34, 26, 26), face=1, prop=None):
        """Tokoh besar (+-16 piksel) dengan garis tepi gelap supaya terbaca di latar apa pun.
        pose: stand, wave, cheer, work, run, sad, point, hold. hat: helmet, peci, cap, None.
        face: 1 menghadap kanan, -1 kiri. prop: wrench, phone, torch, case, sign, rope, money."""
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        col = lambda c: (C[c] if isinstance(c, str) else c) + (255,)
        suit = shirt == "suit"
        sk, sh, pa, ha = col(skin), col((36, 38, 54) if suit else shirt), col((30, 30, 42) if suit else pants), col(hair)
        ink = (16, 16, 26, 255)
        R = lambda x0, y0, x1, y1, cc: d.rectangle([x0, y0, x1, y1], fill=cc)
        hy = y - 16 + (1 if pose == "sad" else 0)
        # Kaki & sepatu
        if pose == "run":
            R(x, y - 5, x + 1, y - 2, pa); R(x - 2, y - 2, x - 1, y, ink)
            R(x + 3, y - 5, x + 4, y - 3, pa); R(x + 4, y - 3, x + 5, y - 1, pa); R(x + 5, y - 1, x + 6, y, ink)
        else:
            R(x, y - 5, x + 1, y - 1, pa); R(x + 3, y - 5, x + 4, y - 1, pa)
            R(x - 1 if face < 0 else x, y, x + 1 if face < 0 else x + 2, y, ink)
            R(x + 2 if face < 0 else x + 3, y, x + 4 if face < 0 else x + 5, y, ink)
        # Badan
        R(x - 1, y - 11, x + 5, y - 6, sh)
        if suit:
            R(x + 2, y - 11, x + 2, y - 7, (200, 40, 40, 255))
            R(x + 1, y - 11, x + 1, y - 10, (230, 230, 230, 255)); R(x + 3, y - 11, x + 3, y - 10, (230, 230, 230, 255))
        # Lengan. Sisi depan (arah hadap) = fx, sisi belakang = bx.
        fx = x + 6 if face > 0 else x - 2
        bx = x - 2 if face > 0 else x + 6

        def arm_down(ax):
            R(ax, y - 11, ax, y - 7, sh)
            R(ax, y - 6, ax, y - 6, sk)

        def arm_up(ax):
            R(ax, y - 15, ax, y - 10, sh)
            R(ax, y - 17, ax, y - 16, sk)

        def arm_fwd(ax):
            x0, x1 = (ax, ax + 3) if face > 0 else (ax - 3, ax)
            R(x0, y - 10, x1, y - 9, sh)
            R(ax + 4 * face, y - 10, ax + 4 * face, y - 9, sk)

        if pose == "cheer":
            arm_up(fx); arm_up(bx)
        elif pose == "wave":
            arm_up(fx); arm_down(bx)
        elif pose in ("work", "point", "hold"):
            arm_fwd(fx); arm_down(bx)
        else:
            arm_down(fx); arm_down(bx)
        sx = fx
        # Kepala
        R(x, hy, x + 4, hy + 4, sk)
        R(x, hy - 1, x + 4, hy, ha)
        R(x if face > 0 else x + 4, hy, x if face > 0 else x + 4, hy + 2, ha)
        ex = x + 3 if face > 0 else x + 1
        R(ex, hy + 2, ex, hy + 2, ink)
        if pose == "sad":
            R(x + 1, hy + 4, x + 3, hy + 4, (150, 100, 80, 255))
        if hat == "helmet":
            R(x - 1, hy - 2, x + 5, hy, col("gold")); R(x - 2, hy, x + 6, hy, col("gold"))
        elif hat == "peci":
            R(x, hy - 2, x + 4, hy, (24, 24, 30, 255))
        elif hat == "cap":
            R(x, hy - 2, x + 4, hy - 1, sh); R(x + 4 if face > 0 else x - 2, hy - 1, x + 6 if face > 0 else x, hy - 1, sh)
        # Benda di tangan (di ujung lengan depan)
        hx = sx + face * 4 if pose in ("work", "point", "hold") else sx
        if prop == "wrench":
            R(hx, y - 13, hx, y - 9, col("metal")); R(hx - 1, y - 14, hx + 1, y - 13, col("metal"))
        elif prop == "phone":
            R(hx, y - 12, hx + face, y - 9, ink); R(hx, y - 11, hx, y - 10, col("teal"))
        elif prop == "torch":
            R(hx, y - 13, hx, y - 8, col("trunk")); R(hx - 1, y - 16, hx + 1, y - 14, col("fire1")); R(hx, y - 17, hx, y - 16, col("fire0"))
        elif prop == "case":
            R(bx - face * 2 - 1, y - 7, bx - face * 2 + 2, y - 4, (90, 60, 40, 255))
        elif prop == "money":
            R(hx - 1, y - 11, hx + 2, y - 9, col("green")); R(hx, y - 10, hx + 1, y - 10, (200, 240, 200, 255))
        elif prop == "rope":
            d.line([(hx, y - 9), (hx + face * 8, y - 2)], fill=(200, 170, 120, 255))
        # Garis tepi: piksel kosong di samping tokoh diberi warna gelap.
        a_ = lay.split()[3]
        grown = a_.filter(ImageFilter.MaxFilter(3))
        edge = Image.new("RGBA", (W, H), (10, 10, 20, 0))
        edge.putalpha(ImageChops.subtract(grown, a_).point(lambda v: 200 if v else 0))
        base = self.im.convert("RGBA")
        base.alpha_composite(edge)
        base.alpha_composite(lay)
        self.im = base.convert("RGB")
        self.d = ImageDraw.Draw(self.im)

    def bubble(self, x, y, w, h, text=None, col="paper", ink="black", tail=-1):
        """Gelembung bicara: kotak terang bertepi gelap dengan ekor ke bawah (tail = arah x ekor).
        Lebar menyesuaikan teks bila teks lebih panjang dari w."""
        if text:
            w = max(w, len(text) * 4 + 3)
        self.rect(x - 1, y - 1, x + w + 1, y + h + 1, ink)
        self.rect(x, y, x + w, y + h, col)
        tx = x + (3 if tail < 0 else w - 4)
        self.poly([(tx, y + h + 1), (tx + 4, y + h + 1), (tx + (0 if tail < 0 else 4), y + h + 4)], ink)
        self.poly([(tx + 1, y + h), (tx + 3, y + h), (tx + (1 if tail < 0 else 3), y + h + 2)], col)
        if text:
            self.text(x + 2, y + 2, text, ink)

    def rays(self, cx, cy, r0, r1, n=10, col="lamp2"):
        for k in range(n):
            a = k / n * math.tau
            for t in range(r0, r1):
                if t % 2 == 0:
                    self.px(cx + math.cos(a) * t, cy + math.sin(a) * t, col)

    def label(self, x, y, s, col="white", bg=None, scale=1):
        """Tulisan dengan latar kotak (tanda/papan)."""
        w = len(s) * 4 * scale
        if bg:
            self.rect(x - 2, y - 2, x + w, y + 5 * scale + 1, "black")
            self.rect(x - 1, y - 1, x + w - 1, y + 5 * scale, bg)
        self.text(x, y, s, col, scale)

    def palm(self, x, y, lean=0, h=22):
        for k in range(h):
            t = k / h
            self.px(x + lean * t * t * 8, y - k, "trunk")
            self.px(x + 1 + lean * t * t * 8, y - k, "trunk")
        tx, ty = x + lean * 8, y - h
        for a, ln in ((-2.6, 9), (-2.0, 8), (-1.2, 7), (-0.6, 8), (0.1, 9), (2.8, 8)):
            a2 = a + lean * 0.35
            for t in range(1, ln):
                self.px(tx + math.cos(a2) * t, ty + math.sin(a2) * t * 0.6 + t * t * 0.03, "leaf")
        self.px(tx, ty, "leaf2")

    def village(self, y, lit_frac=1.0, n=6, x0=10, gap=24):
        for i in range(n):
            self.house(x0 + i * gap + self.r.randint(-2, 2), y + self.r.randint(-1, 1), lit=self.r.random() < lit_frac)

    def save(self, rel):
        # Bingkai tipis: tepi gelap 1 piksel dan garis terang tipis di dalam tepi atas.
        self.d.rectangle([0, 0, W - 1, H - 1], outline=(12, 14, 30))
        for x in range(1, W - 1):
            self.mixpx(x, 1, (246, 240, 222), 0.25)
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


KKN = (178, 40, 52)  # jaket almamater mahasiswa KKN


def ev_badai(c):
    """Badai pesisir: ombak besar menghantam pantai, kelapa & turbin miring, warga mengikat panel."""
    c.sky("storm0", "storm1", 52)
    c.clouds(6, "storm1")
    c.clouds(14, "smoke")
    c.lightning(120)
    c.ground(56)
    c.sea(64, rough=True)
    for x in range(0, W, 14):  # puncak ombak putih menghantam pantai
        c.poly([(x, 66), (x + 6, 59), (x + 11, 62), (x + 14, 66)], "foam")
    c.palm(18, 58, lean=1.6)
    c.house(36, 57, lit=False)
    c.turbine(70, 56, bent=True)
    c.panel(100, 56)
    c.hero(124, 57, pose="work", prop="rope", face=-1, shirt="shirt2")
    c.rain(170)


def ev_bakar(c):
    """Bakar lahan: warga membakar lahan untuk membuka kebun; api menjalar & asap tebal."""
    c.sky("orange0", "orange1", 56)
    c.disc(136, 14, 7, "sun")
    c.ground(56, "dry2", "dry")
    for x in range(50, 160, 12):
        c.flame(x, 64 + (x // 12) % 3, 5)
        c.smoke(x, 52, 10)
    for x in (60, 92, 128):
        c.line([(x, 70), (x, 62)], "ash", 2)
    c.hero(28, 82, pose="hold", prop="torch", shirt="shirt")
    c.label(8, 8, "ASAP!", "fire0", "red2")


def ev_banjir(c):
    """Banjir bandang: air coklat setinggi jendela, warga di atap minta tolong, puing hanyut."""
    c.sky("storm0", "storm1", 50)
    c.clouds(8, "storm1")
    c.mountains(48, 18, "mount1", seed=7)
    c.ground(50)
    c.house(16, 66, s=2)
    c.house(70, 64, lit=False)
    c.hydro_hut(118, 64)
    c.rect(0, 58, W, H, "mud")
    for y in range(60, H, 3):
        for x in range(c.r.randrange(5), W, 9):
            c.line([(x, y), (x + 4, y)], "mud2")
    c.rect(96, 62, 110, 64, "trunk")  # batang kayu hanyut
    c.rect(132, 66, 137, 71, "red2")  # drum
    c.hero(26, 42, pose="wave", shirt="shirt2")
    c.bubble(38, 20, 22, 8, "TOLONG", tail=-1)
    c.rain(150)


def ev_erupsi(c):
    """Erupsi: gunung memuntahkan lava & abu, warga mengungsi, pembangkit panas bumi berhenti."""
    c.sky("night0", "orange0", 70)
    c.poly([(40, 76), (86, 24), (100, 24), (150, 76)], "mount1")
    c.poly([(86, 24), (100, 24), (96, 32), (90, 36)], "lava")
    c.line([(93, 28), (84, 52), (78, 66)], "lava", 2)
    c.line([(95, 30), (108, 54)], "lava")
    for k in range(10):
        c.px(93 + c.r.randint(-8, 8), 18 - c.r.randint(0, 10), "fire0")
    c.smoke(93, 18, 26, "ash")
    for _ in range(60):
        c.px(c.r.randrange(W), c.r.randrange(60), "ash")
    c.ground(74)
    c.geo(110, 86)
    c.hero(12, 86, pose="run", face=-1, shirt="shirt2")
    c.hero(28, 86, pose="run", face=-1)
    c.hero(44, 86, pose="run", face=-1, shirt="green")
    c.label(54, 6, "AWAS", "white", "red2")


def ev_hoaks(c):
    """Hoaks panel surya: ponsel besar menampilkan pesan HOAKS, warga saling berbisik ragu."""
    night_village(c, 0.6, panels=1)
    c.rect(56, 10, 104, 84, "black")
    c.rect(59, 15, 101, 78, "night1")
    c.rect(62, 19, 98, 30, "red2")
    c.text(66, 22, "HOAKS", "white")
    c.text(64, 35, "PANEL", "white")
    c.text(64, 43, "BIKIN", "white")
    c.text(64, 51, "SAKIT?", "fire0")
    c.panel(70, 72, broken=True)
    c.hero(16, 86, pose="hold", prop="phone")
    c.hero(34, 86, pose="stand", face=-1, shirt="shirt2")
    c.bubble(18, 54, 10, 8, "?", tail=1)
    c.hero(124, 86, pose="stand", face=-1, shirt="green")
    c.bubble(118, 54, 10, 8, "!", tail=1)


def ev_investor(c):
    """Investor PLTA: pria berjas membawa koper & kontrak, bersalaman dengan kepala desa di depan bendungan."""
    c.sky("day0", "day1", 50)
    c.mountains(48, 24, "mount2", seed=2)
    c.ground(48)
    c.rect(56, 26, 112, 62, "metal")
    for x in range(60, 110, 6):
        c.line([(x, 28), (x, 60)], "metal2")
    c.rect(0, 62, W, H, "sea1")
    c.rect(80, 62, 86, H, "foam")
    c.hero(30, 84, pose="hold", shirt="suit", prop="case")
    c.hero(46, 84, pose="hold", face=-1, hat="peci", shirt="green")
    c.rect(120, 64, 146, 84, "paper")
    for k in range(4):
        c.line([(123, 68 + k * 4), (143 - c.r.randint(0, 8), 68 + k * 4)], "grey")
    c.label(122, 56, "KONTRAK", "black", "gold")


def ev_izin(c):
    """Izin ditahan: berkas dicap DITAHAN, mahasiswa KKN menunggu di kantor dengan jam berputar."""
    c.sky("night1", "night2", 60)
    c.rect(8, 28, 64, 80, "wall2")
    for k in range(3):
        c.rect(12 + k * 18, 36, 22 + k * 18, 44, "lamp")
    c.rect(30, 64, 42, 80, "trunk")
    c.ground(80)
    c.rect(84, 14, 146, 78, "paper")
    for k in range(5):
        c.line([(90, 22 + k * 7), (140 - c.r.randint(0, 16), 22 + k * 7)], "grey")
    c.label(92, 60, "DITAHAN", "red", None, 1)
    c.d.rectangle([89, 57, 124, 66], outline=C["red"])
    c.d.ellipse([130, 52, 144, 66], fill=C["white"], outline=C["black"])
    c.line([(137, 59), (137, 55)], "black")
    c.line([(137, 59), (141, 59)], "black")
    c.hero(66, 86, pose="sad", shirt=KKN)


def ev_kemarau(c):
    """Kemarau panjang: tanah retak, sungai kering, kincir mikrohidro berhenti, petani kepanasan."""
    c.sky("orange1", "sun", 44)
    c.disc(130, 14, 9, "sun")
    for y in range(30, 44, 3):
        for x in range(0, W, 9):
            c.px(x + (y // 3) % 3, y, "fire0")
    c.ground(44, "dry", "dry2")
    for _ in range(40):
        x, y = c.r.randrange(W), c.r.randrange(48, H)
        c.line([(x, y), (x + c.r.randint(-6, 6), y + 3)], "dry2")
    c.line([(0, 66), (50, 62), (96, 70), (160, 64)], "mud", 4)
    for x in range(4, 160, 10):
        c.px(x, 64 + (x * 7) % 5, "grey")
    c.tree(24, 58, dry=True)
    c.hydro_hut(96, 62)
    c.label(84, 44, "KERING", "red2", "paper")
    c.hero(46, 86, pose="sad", hat="cap", shirt="shirt2")


def ev_lobi(c):
    """Lobi & hoaks bayaran: pemilik PLTU membagi uang, papan TOLAK PLTS, kerumunan termakan isu."""
    c.sky("night0", "red2", 60)
    c.rect(116, 24, 150, 70, "metal2")
    c.rect(124, 4, 130, 24, "metal2")
    c.label(119, 30, "PLTU", "white", None)
    c.smoke(127, 2, 12, "smoke")
    c.ground(70)
    c.line([(12, 70), (12, 30)], "trunk")
    c.line([(68, 70), (68, 30)], "trunk")
    c.rect(10, 26, 70, 42, "paper")
    c.text(14, 31, "TOLAK PLTS", "red")
    c.hero(94, 86, pose="hold", shirt="suit", prop="money", face=-1)
    c.crowd(14, 86, 10, ("red", "red2", "black"), arm_up=True)


def ev_plts_rusak(c):
    """PLTS rusak: panel besar retak & berpercik, teknisi berhelm memperbaiki dengan kunci."""
    c.sky("day0", "day1", 46)
    c.disc(24, 14, 6, "sun")
    c.ground(46)
    c.poly([(30, 76), (110, 76), (124, 44), (44, 44)], (24, 34, 66))
    c.poly([(32, 74), (108, 74), (121, 46), (46, 46)], "panel")
    for k in range(1, 5):
        c.line([(32 + k * 16, 74), (46 + k * 15, 46)], (34, 60, 120))
    c.line([(38, 60), (114, 60)], (34, 60, 120))
    c.line([(70, 48), (78, 58), (72, 64), (84, 72)], "black", 2)
    c.line([(78, 58), (92, 56)], "black")
    for k in range(10):
        c.px(80 + c.r.randint(-6, 6), 54 + c.r.randint(-6, 6), "fire0")
    c.rays(80, 56, 3, 9, 8, "lamp2")
    c.hero(132, 84, pose="work", hat="helmet", prop="wrench", shirt="gold", face=-1)
    c.rect(140, 80, 150, 86, "red2")


def ev_solar(c):
    """Solar disubsidi murah: harga solar turun, genset diesel kembali dinyalakan, panel ditinggal."""
    c.sky("night0", "night2", 60)
    c.ground(60)
    for k in range(3):
        x = 12 + k * 16
        c.rect(x, 52, x + 12, 76, "red2")
        c.line([(x, 58), (x + 12, 58)], "black")
        c.line([(x, 70), (x + 12, 70)], "black")
    c.label(14, 44, "SOLAR", "white", "black")
    c.rect(66, 58, 100, 78, "metal2")
    c.rect(70, 62, 78, 68, "lamp")
    c.smoke(98, 54, 12, "black")
    c.rect(106, 14, 150, 34, "paper")
    c.text(112, 20, "-50%", "red", 2)
    c.panel(124, 80, broken=False)
    c.hero(54, 86, pose="work", face=1, shirt="shirt2")


def ev_tawaran(c):
    """Tawaran kerja sama pemerintah: pejabat & mahasiswa KKN bersalaman di depan gedung pemerintahan."""
    c.sky("day0", "day1", 50)
    c.ground(70)
    c.rect(30, 30, 130, 70, "white")
    c.poly([(26, 30), (80, 12), (134, 30)], "metal")
    for x in range(38, 128, 14):
        c.rect(x, 36, x + 4, 70, "metal")
    c.line([(80, 12), (80, 0)], "metal2")
    c.rect(80, 0, 92, 4, "red")
    c.rect(80, 4, 92, 8, "white")
    c.hero(66, 86, pose="hold", shirt="suit")
    c.hero(82, 86, pose="hold", face=-1, shirt=KKN)
    c.bubble(96, 54, 22, 8, "MOU", tail=-1)


def ev_titik_api(c):
    """Titik api: dari menara pantau, petugas melihat titik-titik api di hutan malam (seperti citra satelit)."""
    c.sky("night0", "night2", 50)
    c.stars(20)
    c.ground(56, "leaf", "leaf2")
    for i in range(9):
        c.tree(46 + i * 13, 70 + c.r.randint(-2, 2), burning=(i in (3, 6)))
    for x, y in ((86, 52), (125, 50), (150, 60)):
        c.glow(x, y, 9, (255, 120, 60), 0.5)
        c.d.ellipse([x - 5, y - 5, x + 5, y + 5], outline=C["red"])
        c.px(x, y, "fire0")
    c.smoke(86, 40, 12)
    c.line([(18, 86), (18, 44)], "trunk", 2)
    c.line([(30, 86), (30, 44)], "trunk", 2)
    c.rect(14, 38, 34, 44, "wall2")
    c.hero(20, 38, pose="point", shirt="green", hat="cap")


def milestone(c, year, lit):
    """Tonggak waktu: kepulauan menyala sesuai capaian, tahun besar, bar kemajuan ke target 100%."""
    c.sky("night0", "night1", 90)
    c.sea(0)
    islands = [(6, 40, 34, 11), (44, 48, 28, 9), (78, 42, 24, 12), (108, 50, 28, 10), (138, 44, 18, 9), (36, 68, 56, 8)]
    for x, y, w, h in islands:
        c.d.ellipse([x - 3, y - 2, x + w + 3, y + h + 2], fill=(62, 130, 174))
        c.d.ellipse([x - 1, y - 1, x + w + 1, y + h + 1], fill=(92, 156, 196))
    n_lit = round(lit * len(islands))
    order = [5, 1, 3, 0, 2, 4]
    for i, (x, y, w, h) in enumerate(islands):
        on = i in order[:n_lit]
        c.d.ellipse([x, y, x + w, y + h], fill=(118, 90, 66))
        c.d.ellipse([x + 1, y + 1, x + w - 1, y + h - 1], fill=(196, 160, 72) if on else (150, 116, 84))
        for _ in range(5 if on else 2):
            lx, ly = x + c.r.randrange(3, max(4, w - 3)), y + c.r.randrange(2, max(3, h - 2))
            if on:
                c.glow(lx, ly, 3, (255, 226, 140), 0.35)
            c.px(lx, ly, "lamp2" if on else (255, 190, 110))
    c.label(8, 8, str(year), "gold" if lit >= 1.0 else "white", None, 3)
    # Bar kemajuan menuju target.
    c.rect(80, 10, 152, 20, "black")
    c.rect(81, 11, 151, 19, (40, 44, 70))
    c.rect(81, 11, 81 + int(70 * lit), 19, "green")
    c.label(83, 13, "%d%%" % int(lit * 100), "white", None)
    c.label(120, 24, "TARGET", "white", None)


def news_airplane(c):
    """Rute pesawat dibuka: pesawat terbang antarpulau, pulau tujuan mulai menyala."""
    c.sky("day0", "day1", 58)
    c.sea(58)
    for x, w, on in ((6, 44, False), (110, 46, True)):
        c.d.ellipse([x - 2, 59, x + w + 2, 74], fill=(170, 214, 236))
        c.d.ellipse([x, 60, x + w, 72], fill=C["ground"])
        c.d.ellipse([x + 4, 62, x + w - 4, 70], fill=C["ground2"])
    for x in range(30, 130, 5):
        c.px(x, 52 - int(16 * math.sin((x - 30) / 100 * math.pi)), "white")
    c.poly([(66, 30), (102, 26), (106, 28), (70, 34)], "white")
    c.poly([(82, 28), (90, 18), (94, 18), (90, 29)], "white")
    c.poly([(100, 26), (106, 20), (108, 21), (105, 27)], "red")
    for x in (120, 130, 140):
        c.glow(x, 64, 5, (255, 226, 140), 0.6)
        c.px(x, 64, "lamp2")
    c.house(124, 66, lit=True)
    c.label(104, 44, "RUTE BARU", "white", (40, 90, 160))


def news_kkn(c, start):
    """Tim KKN tiba (pagi, bus datang, warga menyambut) atau pulang (senja, bus pergi, warga melambai)."""
    if start:
        c.sky("day0", "day1", 50)
    else:
        c.sky("dusk", "orange1", 50)
        c.disc(130, 30, 7, "sun")
    c.mountains(50, 20, "mount2", seed=11)
    c.ground(50)
    c.village(62, 0.0 if start else 1.0, n=3, x0=104, gap=18)
    bx = 16 if start else 40
    c.rect(bx, 58, bx + 40, 76, "gold")
    for k in range(3):
        c.rect(bx + 4 + k * 12, 61, bx + 12 + k * 12, 67, "day1")
    c.disc(bx + 8, 78, 3, "black")
    c.disc(bx + 32, 78, 3, "black")
    if start:
        c.hero(60, 86, pose="wave", shirt=KKN)
        c.hero(72, 86, pose="stand", shirt=KKN)
        c.hero(92, 86, pose="wave", face=-1, hat="peci", shirt="green")
    else:
        for k in range(3):  # garis gerak: bus melaju
            c.line([(bx - 12, 62 + k * 5), (bx - 3, 62 + k * 5)], "white")
        c.hero(100, 86, pose="wave", face=-1, shirt="shirt2")
        c.hero(114, 86, pose="wave", face=-1, hat="peci", shirt="green")
        c.hero(128, 86, pose="stand", face=-1)


def news_target_failed(c):
    """Target kerja sama gagal: grafik turun dicoret, pejabat kecewa."""
    c.sky("night0", "night1", 90)
    c.bars(24, 76, [40, 32, 22, 12], "grey", 12)
    c.line([(20, 20), (82, 72)], "red", 3)
    c.line([(82, 20), (20, 72)], "red", 3)
    c.hero(112, 84, pose="sad", shirt="suit")
    c.label(96, 20, "GAGAL", "white", "red2")


def news_first_lit(c):
    """Desa pertama menyala: satu rumah bersinar terang di tengah desa gelap, warga bersorak."""
    night_village(c, 0.0, panels=0)
    c.glow(78, 60, 22, (255, 220, 140), 0.45)
    c.rays(78, 58, 13, 21, 12, "lamp2")
    c.house(70, 74, lit=True, s=2)
    c.panel(104, 82)
    c.hero(36, 88, pose="cheer", shirt=KKN)
    c.hero(52, 88, pose="cheer", shirt="shirt2")
    c.hero(122, 88, pose="cheer", face=-1, shirt="green")


def news_independent(c):
    """Desa mandiri: warga sendiri merawat panel (tanpa tim KKN), semua lampu menyala."""
    night_village(c, 1.0, panels=2, turb=True)
    c.hero(60, 88, pose="work", hat="helmet", prop="wrench", shirt="green")
    c.hero(78, 88, pose="point", face=-1, shirt="shirt2")
    c.hero(94, 88, pose="stand", face=-1, shirt="shirt")
    c.label(54, 44, "MANDIRI", "white", (40, 120, 70))
    for x, y in ((30, 18), (124, 12)):
        for k in range(8):
            a = k * 0.785
            c.px(x + math.cos(a) * 5, y + math.sin(a) * 5, "gold")


def news_red_high(c):
    """Kepentingan lama menguat: PLTU berasap tebal, pemodal berjas, meteran tekanan di zona merah."""
    c.sky("red2", "orange0", 70)
    for x in (70, 110):
        c.rect(x, 30, x + 26, 72, "metal2")
        c.rect(x + 8, 10, x + 13, 30, "metal2")
        c.smoke(x + 10, 8, 10, "black")
    c.label(76, 40, "PLTU", "white", None)
    c.ground(72, "ash", "smoke")
    # Meteran: busur hijau-kuning-merah, jarum di merah.
    cx, cy, r = 30, 40, 18
    for k in range(0, 181, 3):
        a = math.radians(180 + k)
        col = "green" if k < 70 else ("gold" if k < 120 else "red")
        for t in (r - 3, r - 2, r - 1):
            c.px(cx + math.cos(a) * t, cy + math.sin(a) * t, col)
    a = math.radians(180 + 160)
    c.line([(cx, cy), (cx + math.cos(a) * (r - 4), cy + math.sin(a) * (r - 4))], "white", 2)
    c.rect(cx - 2, cy - 2, cx + 2, cy + 1, "white")
    c.label(12, 46, "TEKANAN", "white", "red2")
    c.hero(24, 86, pose="hold", shirt="suit", prop="money")
    c.hero(40, 86, pose="hold", shirt="suit", face=-1, prop="case")


def news_seed(c):
    """Benih internet: menara sinyal di desa, warga belajar merawat panel lewat video di ponsel."""
    night_village(c, 0.3, panels=1)
    c.line([(120, 80), (120, 34)], "metal", 2)
    c.line([(114, 80), (120, 40), (126, 80)], "metal2")
    for r in (6, 11, 16):
        c.d.arc([120 - r, 34 - r, 120 + r, 34 + r], 200, 340, fill=C["teal"], width=2)
    c.hero(54, 88, pose="hold", prop="phone", shirt="shirt2")
    c.bubble(64, 46, 22, 10, None, col="night1", ink="teal")
    c.panel(68, 54)
    c.line([(36, 88), (36, 80)], "leaf2", 2)
    c.disc(33, 78, 3, "leaf2")
    c.disc(39, 77, 3, "leaf")
def news_stage(c, k, label=None):
    c.sky("night0", "night1", 90)
    c.sea(0)
    islands = [(8, 30, 40, 12), (52, 40, 30, 10), (90, 34, 26, 14), (124, 44, 30, 12), (40, 66, 60, 8)]
    # Gaya peta: paparan dangkal + buih di sekitar pulau, tepi daratan lebih gelap, lampu desa.
    for x, y, w, h in islands:
        c.d.ellipse([x - 4, y - 3, x + w + 4, y + h + 3], fill=(62, 130, 174))
        c.d.ellipse([x - 2, y - 1, x + w + 2, y + h + 1], fill=(92, 156, 196))
    for i, (x, y, w, h) in enumerate(islands):
        lit = i < k
        c.d.ellipse([x, y, x + w, y + h], fill=(118, 90, 66))
        c.d.ellipse([x + 1, y + 1, x + w - 1, y + h - 1], fill=(150, 116, 84) if not lit else (196, 160, 72))
        if lit:
            # Pulau yang sudah bersih: warna energi bergaris & lampu terang berpendar.
            for yy in range(y + 1, y + h):
                for xx in range(x + 1, x + w):
                    if (xx + yy) % 3 == 0 and c.im.getpixel((xx, yy)) == (196, 160, 72):
                        c.px(xx, yy, (150, 120, 50))
            for _ in range(8):
                lx, ly = x + c.r.randrange(4, w - 4), y + c.r.randrange(2, h - 2)
                c.glow(lx, ly, 3, (255, 226, 140), 0.35)
                c.px(lx, ly, "lamp2")
        else:
            for _ in range(3):
                c.px(x + c.r.randrange(4, w - 4), y + c.r.randrange(2, h - 2), (255, 190, 110))
    if label:
        c.text(74, 6, label, "gold", 3)


def news_village_down(c):
    """Desa padam: rumah besar dengan jendela gelap, panel retak memercik, keluarga duduk sedih."""
    c.sky("night0", "night2", 66)
    c.stars(26, 40)
    c.disc(140, 12, 5, "moon")
    c.mountains(60, 14, "mount0", seed=21)
    c.ground(66)
    c.house(14, 82, lit=False, s=2)
    c.house(116, 74, lit=True)
    c.house(138, 74, lit=True)
    c.poly([(58, 86), (98, 86), (104, 72), (64, 72)], (24, 34, 66))
    c.poly([(59, 85), (97, 85), (102, 73), (65, 73)], "panel")
    c.line([(76, 74), (82, 80), (78, 84)], "black", 2)
    c.line([(82, 80), (92, 78)], "black")
    for k in range(9):
        c.px(82 + c.r.randint(-5, 5), 76 + c.r.randint(-5, 3), "fire0")
    c.rays(82, 78, 3, 8, 8, "lamp2")
    c.smoke(86, 66, 8)
    c.hero(36, 88, pose="sad", shirt="shirt2")
    c.hero(46, 88, pose="sad", face=-1, shirt="green")
    c.label(54, 10, "PADAM", "white", "red2", 2)


def end_win(c):
    """Menang: pesta lampu desa, kembang api, warga bersorak."""
    night_village(c, 1.0, panels=2, turb=True)
    for x, y, col in ((30, 20, "gold"), (80, 12, "teal"), (128, 22, "fire0")):
        for k in range(12):
            a = k / 12 * math.tau
            for t in (3, 6):
                c.px(x + math.cos(a) * t, y + math.sin(a) * t, col)
        c.px(x, y, "white")
    for k, x in enumerate((40, 56, 72, 88, 104)):
        c.hero(x, 88, pose="cheer", shirt=(KKN, "shirt2", "green", "shirt", "gold")[k], face=1 if k % 2 else -1)


def end_lose(c):
    """Kalah: PLTU besar berasap menaungi desa yang padam; panel rusak, warga kecewa."""
    c.sky("red2", "night0", 66)
    c.mountains(60, 16, "mount0", seed=13)
    for x in (98, 128):
        c.rect(x, 22, x + 22, 70, "metal2")
        c.rect(x + 7, 4, x + 12, 22, "metal2")
        c.smoke(x + 9, 2, 14, "black")
    c.label(104, 34, "PLTU", "white", None)
    c.ground(68, "ash", "smoke")
    for i, x in enumerate((6, 30, 54)):
        c.house(x, 78, lit=False)
    c.panel(14, 86, broken=True)
    c.panel(60, 86, broken=True)
    c.smoke(68, 80, 6)
    c.hero(80, 88, pose="sad", shirt="shirt2")
    c.hero(90, 88, pose="sad", face=-1)
    c.label(10, 10, "PADAM", "white", "red2", 2)


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
    def dark_village():
        """Desa yang gelap: anak belajar di bawah pelita di depan rumah, genset desa mati."""
        c.sky("night0", "night2", 66)
        c.stars(40, 50)
        c.disc(136, 14, 6, "moon")
        c.mountains(62, 18, "mount0", seed=3)
        c.ground(66)
        c.village(76, 0.0, n=4, x0=72, gap=22)
        c.house(14, 80, lit=False, s=2)
        # Pelita: nyala kecil + pendar hangat menerangi anak & buku.
        c.glow(52, 74, 14, (255, 190, 100), 0.5)
        c.rect(51, 76, 53, 80, (120, 90, 60))
        c.px(52, 74, "fire0")
        c.px(52, 75, "fire1")
        c.hero(42, 88, pose="hold", shirt="shirt2")
        c.rect(46, 80, 50, 82, "paper")
        # Genset mati berdebu.
        c.rect(128, 78, 150, 88, "metal2")
        c.rect(131, 80, 136, 84, "dark_win")
        c.label(122, 66, "MATI", "white", "red2")
    [dark_village,
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
