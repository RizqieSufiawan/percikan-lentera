"""Membuat latar peta (assets/map/map_background.png, 1280x720): laut berwarna sesuai kedalaman,
daratan negara tetangga, dan nama laut. Proyeksinya sama dengan tools/make_map.py, jadi sejajar
persis dengan wilayah di game.

Data: Natural Earth 1:10m (domain publik), dari github.com/nvkelso/natural-earth-vector:
  10m_physical/ne_10m_bathymetry_all/*.shp   (kontur kedalaman 0, 200, 1000, ... 10000 m)
  10m_cultural/ne_10m_admin_0_countries.shp  (daratan negara)

Gaya bawaan: peta relief halus. --pixel = gaya pixel art (1 piksel seni = 4 piksel layar, pita
kedalaman dengan dithering, buih pantai, kilau ombak, huruf piksel).

Pakai (versi yang dipakai game: pixel art malam yang rapi):
  python3 tools/make_sea.py --ne <folder natural-earth-vector> --refined
Pilihan lain: --pixel (pixel art terang), tanpa opsi (relief halus).
Butuh: pip install pyshp
"""
import argparse
import os
import sys

import numpy as np
import shapefile
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from make_map import geo_projection, W, H  # noqa: E402

SS = 2  # supersampling
BBOX = (78.0, -30.0, 160.0, 24.0)  # lon0, lat0, lon1, lat1 (lebih luas dari layar)
# Gambar pixel art dibuat lebih lebar dari peta 1280x720 (EXT_X/EXT_Y di tiap sisi), supaya layar lebar
# atau peta yang di-zoom tetap menampilkan laut dan negara tetangga yang benar, bukan tepi gambar.
EXT_X, EXT_Y = 320, 180
OUT_W, OUT_H = 1280 + 2 * EXT_X, 720 + 2 * EXT_Y
LEVELS = [("L", 0), ("K", 200), ("J", 1000), ("I", 2000), ("H", 3000), ("G", 4000), ("F", 5000),
          ("E", 6000), ("D", 7000), ("C", 8000), ("B", 9000), ("A", 10000)]
# Warna per kedalaman (meter): dangkal = biru muda, dalam = biru tua. Mirip peta relief.
DEPTH_COLORS = [
    (0, (186, 226, 238)), (200, (160, 210, 234)), (1000, (128, 189, 224)), (2000, (108, 172, 215)),
    (3000, (92, 157, 206)), (4000, (78, 142, 196)), (5000, (66, 128, 186)), (6000, (56, 114, 175)),
    (8000, (44, 98, 160)), (10000, (36, 86, 148)),
]
LAND = (205, 199, 176)
LAND_EDGE = (150, 142, 118)
SEA_NAMES = [  # (nama, lon, lat)
    ("SAMUDRA HINDIA", 103.5, -10.6), ("LAUT JAWA", 111.0, -5.2), ("LAUT BANDA", 128.0, -5.3),
    ("LAUT SULAWESI", 122.0, 3.6), ("LAUT CINA SELATAN", 110.5, 6.5), ("SAMUDRA PASIFIK", 134.5, 3.2),
    ("LAUT ARAFURA", 135.5, -9.6), ("LAUT FLORES", 123.9, -6.6), ("LAUT NATUNA", 106.6, 2.3),
]


def in_bbox(bbox):
    x0, y0, x1, y1 = bbox
    return not (x1 < BBOX[0] or x0 > BBOX[2] or y1 < BBOX[1] or y0 > BBOX[3])


def signed_area(pts):
    a = 0.0
    for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]):
        a += x1 * y2 - x2 * y1
    return a / 2.0


def rasterize(shp_path, proj, w, h, skip=None):
    """Mask poligon (lubang dihormati: cincin luar searah jarum jam, lubang sebaliknya).
    skip(record) -> True untuk melewati satu fitur (mis. Indonesia, yang diambil dari peta wilayah)."""
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    r = shapefile.Reader(shp_path)
    for sr in r.iterShapeRecords():
        shape = sr.shape
        if skip is not None and skip(sr.record):
            continue
        if not in_bbox(shape.bbox):
            continue
        parts = list(shape.parts) + [len(shape.points)]
        for a, b in zip(parts[:-1], parts[1:]):
            ring = shape.points[a:b]
            if len(ring) < 3:
                continue
            xs = [p[0] for p in ring]
            ys = [p[1] for p in ring]
            if not in_bbox((min(xs), min(ys), max(xs), max(ys))):
                continue
            pts = [proj(x, y) for x, y in ring]
            # Di shapefile, cincin luar searah jarum jam (luas bertanda negatif dalam koordinat lon/lat).
            d.polygon(pts, fill=255 if signed_area(ring) < 0 else 0)
    return np.array(img) > 127


def depth_color(depth):
    out = np.zeros(depth.shape + (3,), dtype=np.float32)
    ds = [d for d, _ in DEPTH_COLORS]
    cs = np.array([c for _, c in DEPTH_COLORS], dtype=np.float32)
    for k in range(3):
        out[..., k] = np.interp(depth, ds, cs[:, k])
    return out


# ---------------------------------------------------------------- gaya pixel art

PIXEL = 4  # 1 piksel seni = 4x4 piksel layar (320x180 diperbesar)
# Palet laut terbatas: dangkal -> dalam.
PIX_SEA = [(170, 222, 232), (140, 204, 226), (114, 184, 216), (94, 164, 204), (78, 145, 191), (64, 126, 177),
           (52, 108, 162), (42, 92, 146)]
PIX_BAND_DEPTHS = [0, 200, 1000, 2000, 3000, 4000, 5500, 7000]
PIX_FOAM = (214, 240, 244)
PIX_LAND = (204, 196, 170)
PIX_LAND_EDGE = (146, 136, 110)
PIX_LABEL = (34, 74, 120)
# Palet MALAM (bawaan game): laut biru tua bertingkat, gelap dan sejuk supaya daratan Indonesia dan
# warna energi yang hangat/terang menonjol (kontras komplementer biru vs kuning-oranye).
# Daratan negara tetangga dibuat redup supaya perhatian tetap di Indonesia.
NIGHT = {
    "sea": [(62, 132, 176), (52, 116, 162), (44, 102, 148), (38, 90, 136), (33, 79, 124), (29, 70, 113), (26, 62, 103), (23, 55, 94)],
    "foam": (118, 178, 214),
    "land": (48, 58, 88),
    "land_edge": (74, 88, 126),
    "label": (150, 196, 230),
}
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def make_pixel(a):
    global PIX_SEA, PIX_FOAM, PIX_LAND, PIX_LAND_EDGE, PIX_LABEL
    if a.night:
        PIX_SEA, PIX_FOAM, PIX_LAND, PIX_LAND_EDGE, PIX_LABEL = (NIGHT["sea"], NIGHT["foam"], NIGHT["land"],
                                                                  NIGHT["land_edge"], NIGHT["label"])
    base = geo_projection(a.geojson, 1.0)

    def proj(x, y):  # kanvas diperluas EXT_X/EXT_Y di tiap sisi
        px, py = base(x, y)
        return px + EXT_X, py + EXT_Y
    W, H = OUT_W, OUT_H
    depth = np.zeros((H, W), dtype=np.float32)
    bdir = os.path.join(a.ne, "10m_physical", "ne_10m_bathymetry_all")
    for letter, meters in LEVELS:
        mask = rasterize(os.path.join(bdir, "ne_10m_bathymetry_%s_%d.shp" % (letter, meters)), proj, W, H)
        depth[mask] = meters
    land = rasterize(os.path.join(a.ne, "10m_cultural", "ne_10m_admin_0_countries.shp"), proj, W, H)
    # Turunkan ke resolusi seni (320x180).
    w, h = W // PIXEL, H // PIXEL
    d_lr = depth.reshape(h, PIXEL, w, PIXEL).mean(axis=(1, 3))
    land_lr = land.reshape(h, PIXEL, w, PIXEL).mean(axis=(1, 3)) > 0.5
    d_lr = ndimage.gaussian_filter(d_lr, sigma=0.9)
    # Indeks pita (pecahan) lalu dithering Bayer di perbatasan pita.
    f = np.interp(d_lr, PIX_BAND_DEPTHS, np.arange(len(PIX_BAND_DEPTHS), dtype=np.float32))
    th = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    idx = np.clip(np.floor(f + th - 0.5 + 0.5), 0, len(PIX_SEA) - 1).astype(int)
    pal = np.array(PIX_SEA, dtype=np.uint8)
    img = pal[idx]
    # Kilau ombak: garis pendek 2-3 piksel di laut dalam, jarang.
    rng = np.random.default_rng(11)
    for _ in range(int(w * h * 0.006)):
        y, x = rng.integers(0, h), rng.integers(0, w - 3)
        if idx[y, x] >= 3 and not land_lr[y, x:x + 3].any():
            c = pal[max(0, idx[y, x] - 2)]
            img[y, x:x + rng.integers(2, 4)] = c
    # Buih pantai: laut yang bersebelahan dengan daratan.
    near_land = ndimage.binary_dilation(land_lr, iterations=1) & ~land_lr
    img[near_land] = PIX_FOAM
    # Daratan negara (termasuk Indonesia, yang nanti ditutup gambar wilayah) + garis pantai.
    edge = land_lr & ~ndimage.binary_erosion(land_lr, iterations=1)
    img[land_lr] = PIX_LAND
    img[edge] = PIX_LAND_EDGE
    out = Image.fromarray(img, "RGB").resize((W, H), Image.NEAREST)
    # Nama laut: huruf bitmap kecil di kanvas 640x360, diperbesar 2x supaya ikut berpiksel.
    if not a.no_labels:
        layer = Image.new("RGBA", (W // 2, H // 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        font = ImageFont.load_default_imagefont()
        for name, lon, lat in SEA_NAMES:
            x, y = proj(lon, lat)
            tw = d.textlength(name, font=font)
            d.text((round(x / 2 - tw / 2), round(y / 2)), name, font=font, fill=PIX_LABEL + (200,))
        layer = layer.resize((W, H), Image.NEAREST)
        out = out.convert("RGBA")
        out.alpha_composite(layer)
        out = out.convert("RGB")
    out.save(a.out)
    print("ok (pixel art):", a.out)


# Gaya RAPI (dipakai game): pita kedalaman lebar dan halus, peralihan antarpita hanya selebar satu
# piksel papan catur, tanpa bintik acak. Kilau ombak bergerak ditambahkan shader (shaders/sea.gdshader).
REFINED = {
    "sea": [(58, 124, 168), (46, 106, 150), (38, 92, 136), (32, 80, 123), (28, 70, 112), (24, 61, 101)],
    "depths": [0, 150, 900, 2200, 4000, 6500],
    "shelf": (62, 130, 174),
    "foam": (92, 156, 196),
    "land": (44, 54, 84),
    "land_edge": (64, 78, 114),
    "label": (132, 182, 220),
}


def make_refined(a):
    base = geo_projection(a.geojson, 1.0)

    def proj(x, y):
        px, py = base(x, y)
        return px + EXT_X, py + EXT_Y
    W, H = OUT_W, OUT_H
    depth = np.zeros((H, W), dtype=np.float32)
    bdir = os.path.join(a.ne, "10m_physical", "ne_10m_bathymetry_all")
    for letter, meters in LEVELS:
        mask = rasterize(os.path.join(bdir, "ne_10m_bathymetry_%s_%d.shp" % (letter, meters)), proj, W, H)
        depth[mask] = meters
    # Negara tetangga dari Natural Earth; daratan Indonesia diambil dari peta sel kloter
    # (assets/map/cells.png), supaya garis pantai di latar sama persis dengan wilayah di game.
    land = rasterize(os.path.join(a.ne, "10m_cultural", "ne_10m_admin_0_countries.shp"), proj, W, H,
                     skip=lambda rec: rec["ADMIN"] == "Indonesia")
    w, h = W // PIXEL, H // PIXEL
    d_lr = depth.reshape(h, PIXEL, w, PIXEL).mean(axis=(1, 3))
    land_lr = land.reshape(h, PIXEL, w, PIXEL).mean(axis=(1, 3)) > 0.5
    cells = np.array(Image.open(os.path.join(ROOT, "assets", "map", "cells.png")).convert("RGBA")).astype(int)
    indo = (cells[:, :, 0] + cells[:, :, 1] * 256) > 0
    ox, oy = EXT_X // PIXEL, EXT_Y // PIXEL
    indo_full = np.zeros_like(land_lr)
    indo_full[oy:oy + indo.shape[0], ox:ox + indo.shape[1]] = indo
    # NE tetangga di dalam bingkai peta tidak boleh menimpa laut Indonesia (beda sumber data).
    land_lr = (land_lr & ~ndimage.binary_dilation(indo_full, iterations=1)) | indo_full
    d_lr = ndimage.gaussian_filter(d_lr, sigma=2.2)
    pal = np.array(REFINED["sea"], dtype=np.uint8)
    f = np.interp(d_lr, REFINED["depths"], np.arange(len(REFINED["depths"]), dtype=np.float32))
    idx = np.floor(f).astype(int)
    frac = f - idx
    # Peralihan: sepertiga terakhir tiap pita diberi pola papan catur dengan pita berikutnya.
    yy, xx = np.mgrid[0:h, 0:w]
    checker = ((xx + yy) % 2) == 0
    idx = np.where((frac > 0.72) & checker, idx + 1, idx)
    idx = np.clip(idx, 0, len(pal) - 1)
    img = pal[idx]
    # Paparan dangkal 2 piksel di sekitar daratan, lalu buih 1 piksel menempel pantai.
    dist = ndimage.distance_transform_cdt(~land_lr, metric="chessboard")
    img[dist == 2] = REFINED["shelf"]
    # Ombak: garis pendek 3 piksel tersebar teratur (kisi bergeser acak), hanya di laut lepas.
    rng = np.random.default_rng(5)
    for gy in range(0, h, 14):
        for gx in range(0, w, 22):
            y = gy + int(rng.integers(0, 10))
            x = gx + (7 if (gy // 14) % 2 else 0) + int(rng.integers(0, 12))
            if y >= h or x + 3 >= w or idx[y, x] < 2 or (dist[y, x:x + 3] < 6).any():
                continue
            img[y, x:x + 3] = pal[idx[y, x] - 1]
    img[dist == 1] = REFINED["foam"]
    edge = land_lr & ~ndimage.binary_erosion(land_lr, iterations=1)
    img[land_lr] = REFINED["land"]
    img[edge] = REFINED["land_edge"]
    out = Image.fromarray(img, "RGB").resize((W, H), Image.NEAREST)
    if not a.no_labels:
        # Nama laut: huruf bitmap 2x dengan jarak antarhuruf, warna lembut.
        layer = Image.new("RGBA", (W // 2, H // 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        font = ImageFont.load_default_imagefont()
        for name, lon, lat in SEA_NAMES:
            x, y = proj(lon, lat)
            # Jarak antarhuruf +1 piksel.
            widths = [d.textlength(ch, font=font) + 1 for ch in name]
            cx = round(x / 2 - sum(widths) / 2)
            for ch, cw in zip(name, widths):
                d.text((cx, round(y / 2)), ch, font=font, fill=REFINED["label"] + (170,))
                cx += cw
        layer = layer.resize((W, H), Image.NEAREST)
        out = out.convert("RGBA")
        out.alpha_composite(layer)
        out = out.convert("RGB")
    out.save(a.out)
    print("ok (rapi):", a.out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ne", required=True, help="folder natural-earth-vector")
    ap.add_argument("--geojson", default=os.path.join(ROOT, "tools", "geo", "indonesia-38-provinces.geojson"))
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "map", "map_background.png"))
    ap.add_argument("--no-labels", action="store_true")
    ap.add_argument("--pixel", action="store_true", help="gaya pixel art (bawaan: relief halus)")
    ap.add_argument("--night", action="store_true", help="pixel art dengan palet malam (versi lama)")
    ap.add_argument("--refined", action="store_true", help="pixel art malam yang rapi (dipakai game)")
    a = ap.parse_args()
    if a.refined:
        make_refined(a)
        return
    if a.night:
        a.pixel = True
    if a.pixel:
        make_pixel(a)
        return
    w, h = W * SS, H * SS
    proj = geo_projection(a.geojson, SS)

    # 1) Kedalaman: lapisan dari dangkal ke dalam saling menimpa.
    depth = np.zeros((h, w), dtype=np.float32)
    bdir = os.path.join(a.ne, "10m_physical", "ne_10m_bathymetry_all")
    for letter, meters in LEVELS:
        path = os.path.join(bdir, "ne_10m_bathymetry_%s_%d.shp" % (letter, meters))
        mask = rasterize(path, proj, w, h)
        depth[mask] = max(meters, 60)
    # Haluskan batas kontur supaya gradasinya lembut seperti peta relief.
    depth = ndimage.gaussian_filter(depth, sigma=3.0 * SS)
    color = depth_color(depth)
    # Bayangan relief dasar laut (cahaya dari barat laut).
    gy, gx = np.gradient(ndimage.gaussian_filter(depth, sigma=2.0 * SS))
    shade = np.clip(1.0 + (gx * 0.6 + gy * 0.6) / 700.0, 0.94, 1.06)
    color *= shade[..., None]
    # Tekstur halus supaya tidak terlalu datar.
    rng = np.random.default_rng(3)
    noise = ndimage.gaussian_filter(rng.standard_normal((h, w)).astype(np.float32), sigma=1.5 * SS)
    color += noise[..., None] * 6.0

    # 2) Daratan semua negara (termasuk Indonesia, yang nanti ditutup gambar wilayah).
    land = rasterize(os.path.join(a.ne, "10m_cultural", "ne_10m_admin_0_countries.shp"), proj, w, h)
    edge = land & ~ndimage.binary_erosion(land, iterations=SS)
    color[land] = LAND
    color[edge] = LAND_EDGE
    img = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8), "RGB")

    # 3) Nama laut.
    if not a.no_labels:
        d = ImageDraw.Draw(img, "RGBA")
        try:
            font = ImageFont.load_default(size=11 * SS)
        except TypeError:
            font = ImageFont.load_default()
        for name, lon, lat in SEA_NAMES:
            x, y = proj(lon, lat)
            text = " ".join(name)  # huruf direnggangkan
            tw = d.textlength(text, font=font)
            d.text((x - tw / 2, y), text, font=font, fill=(30, 70, 120, 150))

    img = img.resize((W, H), Image.LANCZOS)
    img.save(a.out)
    print("ok:", a.out)


if __name__ == "__main__":
    main()
