"""Awan malam untuk menu utama: beberapa gumpal awan pixel art dalam satu lembar sprite.

1 piksel di sini = 1 piksel seni (layar 320x180, diperbesar 4x di game). Bentuk awan dibuat dari
medan "metaball" (jumlah r^2/d^2 beberapa bola) sehingga tepinya membulat halus, dasarnya diratakan.
Cahaya bulan datang dari kanan atas: bayangan dihitung dari arah gradien medan, lalu dipecah ke
5 nada warna dengan dithering Bayer 4x4 (gaya pixel art, bukan gradasi halus). Tepi bawah memudar
dengan pola dither, dan ada ekor tipis (serat awan) yang memanjang di dasar.

Hasil: assets/ui/title_clouds.png (sprite ditumpuk ke bawah). Kotak tiap sprite dicetak ke layar;
salin ke CLOUD_RECTS di scripts/ui/title_screen.gd bila SPECS diubah.

Pakai:  python3 tools/make_title_clouds.py [--preview]
"""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PNG = os.path.join(ROOT, "assets", "ui", "title_clouds.png")

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
# Nada awan dari bayangan ke tepi yang disinari bulan (selaras langit ungu-navy title_sky).
TONES = [
    (40, 40, 86),
    (52, 50, 102),
    (68, 64, 120),
    (94, 88, 148),
    (138, 132, 188),
]
LIGHT = (0.55, -0.83)  # arah datangnya cahaya (kanan atas), y ke bawah


def dith(x, y, t):
    """True jika piksel (x,y) memakai nada atas untuk campuran t (0..1)."""
    return t * 16.0 > BAYER[y % 4][x % 4] + 0.5


def cloud(seed, w, h):
    """Satu gerombolan awan: beberapa gumpal yang saling menumpuk; tiap gumpal = bola induk + bola kecil di punggungnya
    (bentuk kembang kol khas cumulus). Tiap piksel diwarnai seperti bola yang paling dominan di sana,
    disinari bulan dari kanan atas, sehingga lekuk antar-gumpal muncul sendiri sebagai bayangan."""
    rnd = random.Random(seed)
    base = h - 3.0
    balls = []
    # Gumpal-gumpal saling menumpuk menjadi satu gerombolan: jarak antar-pusat lebih kecil dari
    # jumlah jari-jarinya. Gumpal tengah paling tinggi, makin ke pinggir makin rendah.
    tallest = (h - 4) * 0.56
    clumps = []
    x = 4.0
    while True:
        u = len(clumps)
        big = tallest * rnd.uniform(0.7, 1.0)
        if clumps:
            x += (clumps[-1] + big) * rnd.uniform(0.72, 0.9)
        else:
            x += big * 1.75  # ruang untuk bahu kiri
        if x + big * 1.85 > w - 2:  # ruang untuk bahu kanan
            break
        clumps.append(big)
        balls.append((x, 0.0, big))  # y diisi nanti
    # Profil lonceng: gumpal di tengah gerombolan dibuat paling besar.
    n = len(balls)
    shaped = []
    for k, (cx, _, big) in enumerate(balls):
        mid = 1.0 - abs((k + 0.5) / n - 0.5) * 1.1
        big = max(2.5, big * (0.7 + 0.45 * mid))
        shaped.append((cx, base - big * 0.55, big))
    balls = []
    for cx, cy, big in shaped:
        balls.append((cx, cy, big))
        for side in (-1, 1):
            r = big * rnd.uniform(0.6, 0.78)
            balls.append((cx + side * big * rnd.uniform(0.8, 1.05), base - r * 0.5, r))
        # Tingkat kedua: gumpal yang menumpang di atas gumpal tengah (kesan menggerombol ke atas).
        if cy < base - tallest * 0.5 and rnd.random() < 0.8:
            r = big * rnd.uniform(0.55, 0.7)
            balls.append((cx + rnd.uniform(-big * 0.3, big * 0.3), cy - big * rnd.uniform(0.5, 0.7), r))
        for _ in range(rnd.randint(2, 4)):
            ang = math.radians(rnd.uniform(-160, -20))
            r = big * rnd.uniform(0.35, 0.55)
            d = big * rnd.uniform(0.55, 0.8)
            balls.append((cx + math.cos(ang) * d, cy + math.sin(ang) * d * 0.9, r))
    # Jaga semua bola di dalam kotak sprite.
    balls = [(min(max(bx, r + 1), w - r - 2), max(by, r * 0.7 + 1), r) for bx, by, r in balls]
    # Urutan depan-belakang: bola yang lebih rendah (dasarnya lebih ke bawah) ada di depan.
    order = sorted(range(len(balls)), key=lambda i: balls[i][1] + balls[i][2])

    def contrib(i, x, y):
        bx, by, r = balls[i]
        R2 = (r * 1.35) ** 2
        d2 = (x - bx) ** 2 + ((y - by) * 1.1) ** 2
        if d2 >= R2:
            return 0.0
        q = 1.0 - d2 / R2
        return q * q * q

    def field(x, y):
        f = sum(contrib(i, x, y) for i in range(len(balls)))
        if y > base:
            f *= math.exp(-((y - base) ** 2) / 1.2)
        return f

    TH = 0.3
    L = (0.55, -0.62, 0.56)  # arah cahaya bulan (kanan atas, sedikit dari depan)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inside = [[field(x + 0.5, y + 0.5) >= TH for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if not inside[y][x]:
                continue
            fx, fy = x + 0.5, y + 0.5
            # Bola terdepan yang menutupi piksel ini (di dalam bola itu sendiri).
            own = None
            for i in reversed(order):
                bx, by, r = balls[i]
                if (fx - bx) ** 2 + ((fy - by) * 1.1) ** 2 <= (r * 1.12) ** 2:
                    own = i
                    break
            if own is None:
                own = max(range(len(balls)), key=lambda i: contrib(i, fx, fy))
            bx, by, r = balls[own]
            nx = (fx - bx) / (r * 1.12)
            ny = (fy - by) * 1.1 / (r * 1.12)
            nn = nx * nx + ny * ny
            if nn > 1.0:
                k = 1.0 / math.sqrt(nn)
                nx, ny, nn = nx * k, ny * k, 1.0
            nz = math.sqrt(max(0.0, 1.0 - nn))
            lit = nx * L[0] + ny * L[1] + nz * L[2]  # -1..1
            low = max(0.0, (fy - (base - 2.5)) / 2.5)  # dasar awan lebih gelap
            # Lekuk: bayangan tipis di gumpal belakang, tepat di luar tepi gumpal yang di depannya.
            crease = 0.0
            pos = order.index(own)
            for j in order[pos + 1:]:
                jx, jy, jr = balls[j]
                dj = math.sqrt((fx - jx) ** 2 + ((fy - jy) * 1.1) ** 2) - jr * 1.12
                if 0.0 <= dj < 1.6 and fy > jy - jr * 0.9:
                    crease = max(crease, 0.18 * (1.0 - dj / 1.6))
            v = 0.18 + 0.78 * max(0.0, lit) - 0.3 * low - crease
            v = min(0.999, max(0.0, v)) * (len(TONES) - 1)
            i = int(v)
            t = v - i
            # Dither hanya di pita peralihan supaya bidang warna tetap bersih.
            if t < 0.3:
                tone = TONES[i]
            elif t > 0.7:
                tone = TONES[min(i + 1, len(TONES) - 1)]
            else:
                tone = TONES[min(i + 1, len(TONES) - 1)] if dith(x, y, (t - 0.3) / 0.4) else TONES[i]
            # Tepi atas yang menghadap bulan: satu piksel paling terang.
            top_edge = y == 0 or not inside[y - 1][x]
            if top_edge and lit > 0.25:
                tone = TONES[-1]
            a = 240
            if y + 1 >= h or not inside[y + 1][x]:
                if (x + y) % 2 == 0:
                    continue  # tepi bawah tipis
                a = 190
            img.putpixel((x, y), tone + (a,))
    # Serat tipis di dasar: garis putus-putus memanjang ke kiri dan kanan.
    by = int(base)
    for side in (-1, 1):
        edge = None
        xs = range(w) if side < 0 else range(w - 1, -1, -1)
        for x in xs:
            if inside[by][x]:
                edge = x
                break
        if edge is None:
            continue
        ln = rnd.randint(4, 9)
        for k in range(1, ln):
            x = edge + side * k
            if 0 <= x < w and (k < ln * 0.5 or k % 2 == 0):
                img.putpixel((x, by), TONES[1] + (170 if k < ln * 0.5 else 110,))
    return img


SPECS = [(11, 96, 28), (23, 78, 25), (37, 112, 30), (41, 64, 23), (53, 100, 28), (67, 86, 26)]


def main():
    sprites = [cloud(seed, w, h) for seed, w, h in SPECS]
    W = max(s.width for s in sprites)
    H = sum(s.height + 1 for s in sprites)
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    y = 0
    rows = []
    for s in sprites:
        sheet.alpha_composite(s, (0, y))
        rows.append("%d %d %d %d" % (0, y, s.width, s.height))
        y += s.height + 1
    sheet.save(OUT_PNG)
    print("awan: %d sprite -> %s" % (len(sprites), OUT_PNG))
    print("CLOUD_RECTS := [" + ", ".join("Rect2(%s)" % r.replace(" ", ", ") for r in rows) + "]")
    if "--preview" in sys.argv:
        pv = Image.new("RGBA", (W + 8, H + 8), (34, 36, 90, 255))
        for yy in range(pv.height):
            for xx in range(pv.width):
                if yy > pv.height * 0.6:
                    pv.putpixel((xx, yy), (40, 40, 98, 255))
        pv.alpha_composite(sheet, (4, 4))
        pv = pv.resize((pv.width * 6, pv.height * 6), Image.NEAREST)
        pv.save("/home/claude/scratch/clouds_preview.png")


if __name__ == "__main__":
    main()
