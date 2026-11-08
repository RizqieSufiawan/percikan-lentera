"""Langit atas untuk menu utama: dipasang tepat DI ATAS title_sky.png dan baru terlihat saat
kamera naik ke langit (klik Permainan Baru).

1 piksel = 1 piksel seni (diperbesar 4x di game). Baris paling bawah menyambung warna baris teratas
title_sky.png (8,10,30). Makin ke atas makin gelap, dengan pita Bima Sakti tipis miring
(dithering Bayer, gaya pixel art) dan bintang redup statis. Bintang yang berkelip digambar di game.

Hasil: assets/ui/title_sky_high.png (320 x HIGH_H).
Pakai:  python3 tools/make_title_sky_high.py
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "title_sky_high.png")
W, HIGH_H = 320, 220  # sama dengan HIGH_H di scripts/ui/title_screen.gd

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
BOTTOM = (8, 10, 30)  # = baris teratas title_sky.png
TOP = (4, 5, 17)
BAND = [(12, 14, 40), (17, 19, 50), (24, 25, 62), (34, 34, 78)]  # Bima Sakti, gelap -> terang


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def dith(x, y, t):
    return t * 16.0 > BAYER[y % 4][x % 4] + 0.5


def main():
    rnd = random.Random(7)
    im = Image.new("RGB", (W, HIGH_H))
    # Langit dasar: 5 nada dari bawah ke atas, peralihan antar-nada dengan dither.
    steps = 5
    tones = [mix(BOTTOM, TOP, k / (steps - 1)) for k in range(steps)]
    for y in range(HIGH_H):
        v = (1.0 - y / (HIGH_H - 1)) * (steps - 1)  # 0 di bawah, steps-1 di atas
        i = min(int(v), steps - 2)
        t = v - i
        for x in range(W):
            im.putpixel((x, y), tones[i + 1] if dith(x, y, t) else tones[i])
    # Bima Sakti: pita miring dari kiri bawah ke kanan atas, tebalnya bergelombang.
    noise = [[rnd.random() for _ in range(W)] for _ in range(HIGH_H)]

    def smooth(x, y):
        s = 0.0
        n = 0
        for dy in (-2, 0, 2):
            for dx in (-3, 0, 3):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < HIGH_H:
                    s += noise[yy][xx]
                    n += 1
        return s / n

    for y in range(HIGH_H):
        for x in range(W):
            cy = 175 - x * 0.48 + 10 * math.sin(x * 0.03)  # garis tengah pita
            half = 22 + 8 * math.sin(x * 0.05 + 1.3)
            d = abs(y - cy) / half
            if d >= 1.0:
                continue
            fade = min(1.0, y / 40.0)  # memudar di bawah agar sambungan ke title_sky bersih
            core = (1.0 - d) ** 1.6 * fade * (0.55 + 0.9 * (smooth(x, y) - 0.5))
            v = core * len(BAND)
            k = int(v)
            if k <= 0 and not dith(x, y, v):
                continue
            k = min(k, len(BAND) - 1)
            col = BAND[k] if (k == 0 or dith(x, y, v - k) or v - k > 0.5) else BAND[k - 1]
            im.putpixel((x, y), col)
    # Bintang redup statis (debu bintang), lebih rapat di dalam pita.
    for _ in range(420):
        x, y = rnd.randrange(W), rnd.randrange(4, HIGH_H - 6)
        cy = 175 - x * 0.48 + 10 * math.sin(x * 0.03)
        if abs(y - cy) > 30 and rnd.random() < 0.55:
            continue
        b = rnd.choice([(44, 48, 86), (56, 60, 100), (70, 74, 118)])
        im.putpixel((x, y), b)
    im.save(OUT)
    print("langit atas:", im.size, "->", OUT)


if __name__ == "__main__":
    main()
