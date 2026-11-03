"""Membuat gambar wilayah peta (assets/map/regions/<id>.png) dan posisi label (tools/map_layout.json).

Tiga sumber yang bisa dipakai:
  1) GeoJSON 38 provinsi (bawaan, untuk placeholder):
       python3 tools/make_map.py --geojson <indonesia-38-provinces.geojson>
  2) Satu PNG peta Indonesia dengan warna polos berbeda untuk tiap provinsi + legenda warna:
       python3 tools/make_map.py --color-map peta.png --legend legenda.json
     legenda.json: {"#e6194b": "Aceh", "#3cb44b": "Sumatera Utara", ...}  (nama sesuai tools/wilayah.py)
  3) Satu folder berisi PNG transparan per provinsi (ekspor layer dari Krita/Aseprite/Photoshop):
       python3 tools/make_map.py --layers-dir folder_layer/
     nama file = nama provinsi, misalnya "Jawa Barat.png". Semua PNG berukuran sama.

Gambar dari sumber 2 dan 3 sebaiknya 1280x720 dan sejajar dengan assets/map/map_background.png.

Gambar peta buatanmu sendiri (paling mudah):
  1) Buka tools/geo/template_peta_38_provinsi.png (1280x720) di Krita/Photoshop/Aseprite sebagai layer
     paling bawah. Gambar petamu di atasnya dengan posisi yang sama.
  2) Ekspor gambar daratanmu (tanpa laut, latar transparan) sebagai satu PNG 1280x720, lalu:
       python3 tools/make_map.py --geojson tools/geo/indonesia-38-provinces.geojson --art daratan.png
     Batas wilayah diambil dari template, sedangkan gradasi gambarmu dipakai sebagai tekstur di dalam
     wilayah. Warna status (gelap/fosil/rapuh/mandiri) dikalikan dengan tekstur itu.
  3) Gambar lautnya simpan sebagai assets/map/map_background.png.
Opsi --template-out <folder> menulis ulang template berwarna + legendanya.
Setelah selesai, jalankan:  python3 tools/build_kloter.py  (memakai posisi label baru),
lalu  python3 tools/make_cells.py  (membagi wilayah menjadi sel kloter).
Opsi --preview <file.png> menyimpan pratinjau berwarna untuk dicek.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from wilayah import WILAYAH, NEIGHBORS, province_to_wilayah  # noqa: E402

W, H = 1280, 720
# Area peta di layar: selebar layar (panel kiri/kanan bisa dilipat), proporsi asli (tanpa peregangan).
MAP_X0, MAP_X1 = 20, 1260
Y_CENTER = 368
Y_STRETCH = 1.0
SEA_GROW = 3          # piksel laut di sekitar daratan ikut jadi milik wilayah (pulau kecil mudah diklik)
INNER_BORDER = 0.72   # kecerahan garis batas provinsi di dalam satu wilayah
ALIASES = {"Daerah Istimewa Yogyakarta": "DI Yogyakarta", "DIY": "DI Yogyakarta",
           "Bangka Belitung": "Kepulauan Bangka Belitung", "Jakarta": "DKI Jakarta"}

PROVINCES = sorted(province_to_wilayah())


def norm(name):
    name = name.strip()
    return ALIASES.get(name, name)


def read_geojson(path):
    """Cincin poligon per provinsi dari GeoJSON 38 provinsi."""
    data = json.load(open(path, encoding="utf-8"))
    polys = {}
    for f in data["features"]:
        name = norm(f["properties"].get("PROVINSI") or f["properties"].get("name"))
        g = f["geometry"]
        rings = [p[0] for p in g["coordinates"]] if g["type"] == "MultiPolygon" else [g["coordinates"][0]]
        polys[name] = rings
    return polys


def geo_projection(path, scale=1.0):
    """Fungsi (lon, lat) -> (x, y) piksel layar 1280x720 (dikali scale). Dipakai juga oleh make_sea.py
    supaya latar laut sejajar persis dengan wilayah."""
    polys = read_geojson(path)
    lons = [x for rings in polys.values() for r in rings for x, _ in r]
    lats = [y for rings in polys.values() for r in rings for _, y in r]
    lon0, lon1 = min(lons), max(lons)
    lat0, lat1 = min(lats), max(lats)
    sx = (MAP_X1 - MAP_X0) / (lon1 - lon0)
    sy = sx * Y_STRETCH
    y_mid = (lat0 + lat1) / 2

    def proj(x, y):
        return ((MAP_X0 + (x - lon0) * sx) * scale, (Y_CENTER - (y - y_mid) * sy) * scale)
    return proj


def labels_from_geojson(path):
    polys = read_geojson(path)
    proj = geo_projection(path)

    img = Image.new("I", (W, H), 0)
    d = ImageDraw.Draw(img)
    missing = [p for p in PROVINCES if p not in polys]
    if missing:
        sys.exit("Provinsi tidak ada di GeoJSON: %s" % missing)
    for i, p in enumerate(PROVINCES, start=1):
        for r in polys[p]:
            pts = [proj(x, y) for x, y in r]
            if len(pts) >= 3:
                d.polygon(pts, fill=i, outline=i)
            elif pts:
                d.point(pts, fill=i)
    return np.array(img, dtype=np.int32)


def labels_from_color_map(path, legend_path):
    legend = json.load(open(legend_path, encoding="utf-8"))
    img = Image.open(path).convert("RGBA")
    if img.size != (W, H):
        img = img.resize((W, H), Image.NEAREST)
    a = np.array(img)
    lab = np.zeros((H, W), dtype=np.int32)
    for hexcol, name in legend.items():
        name = norm(name)
        if name not in PROVINCES:
            sys.exit("Nama provinsi di legenda tidak dikenal: %s" % name)
        h = hexcol.lstrip("#")
        rgb = np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)])
        hit = (np.abs(a[:, :, :3].astype(int) - rgb).sum(axis=2) <= 6) & (a[:, :, 3] >= 128)
        lab[hit] = PROVINCES.index(name) + 1
    return lab


def labels_from_layers(folder):
    lab = np.zeros((H, W), dtype=np.int32)
    for fn in os.listdir(folder):
        if not fn.lower().endswith(".png"):
            continue
        name = norm(os.path.splitext(fn)[0])
        if name not in PROVINCES:
            print("lewati (nama tidak dikenal):", fn)
            continue
        img = Image.open(os.path.join(folder, fn)).convert("RGBA")
        if img.size != (W, H):
            img = img.resize((W, H), Image.NEAREST)
        lab[np.array(img)[:, :, 3] >= 128] = PROVINCES.index(name) + 1
    return lab


def grow_into_sea(lab, r):
    dist, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
    out = lab.copy()
    sea = (lab == 0) & (dist <= r)
    out[sea] = lab[iy[sea], ix[sea]]
    return out


def write_template(lab0, folder):
    """Template berwarna: satu warna polos per provinsi + legenda JSON (untuk --color-map)."""
    os.makedirs(folder, exist_ok=True)
    rng = np.random.default_rng(7)
    rgb = np.zeros((H, W, 4), dtype=np.uint8)
    legend = {}
    for i, p in enumerate(PROVINCES, start=1):
        while True:
            c = rng.integers(40, 250, 3)
            hexcol = "#%02x%02x%02x" % tuple(int(x) for x in c)
            if hexcol not in legend:
                break
        legend[hexcol] = p
        m = lab0 == i
        rgb[m, :3] = c
        rgb[m, 3] = 255
    Image.fromarray(rgb, "RGBA").save(os.path.join(folder, "template_peta_38_provinsi.png"))
    json.dump(legend, open(os.path.join(folder, "legenda_warna.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("template ditulis ke", folder)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geojson")
    ap.add_argument("--color-map")
    ap.add_argument("--legend")
    ap.add_argument("--layers-dir")
    ap.add_argument("--preview")
    ap.add_argument("--art", help="PNG daratan buatanmu (1280x720); kecerahannya jadi tekstur wilayah")
    ap.add_argument("--template-out", help="folder untuk template warna per provinsi + legenda")
    a = ap.parse_args()
    if a.geojson:
        lab0 = labels_from_geojson(a.geojson)
    elif a.color_map:
        lab0 = labels_from_color_map(a.color_map, a.legend)
    elif a.layers_dir:
        lab0 = labels_from_layers(a.layers_dir)
    else:
        sys.exit(__doc__)
    found = set(np.unique(lab0)) - {0}
    missing = [p for i, p in enumerate(PROVINCES, start=1) if i not in found]
    if missing:
        print("PERINGATAN: provinsi tidak tergambar:", missing)
    if a.template_out:
        write_template(lab0, a.template_out)
    lab = grow_into_sea(lab0, SEA_GROW)
    art = None
    if a.art:
        im = Image.open(a.art).convert("LA")
        if im.size != (W, H):
            im = im.resize((W, H), Image.BILINEAR)
        arr = np.array(im).astype(np.float32) / 255.0
        lum, alpha = arr[:, :, 0], arr[:, :, 1]
        # Normalisasi ke 0.55-1.0 supaya warna status tetap terbaca; area tanpa gambar = 1.0.
        lo, hi = np.percentile(lum[alpha > 0.5], [2, 98]) if (alpha > 0.5).any() else (0.0, 1.0)
        norm_l = np.clip((lum - lo) / max(1e-3, hi - lo), 0, 1)
        art = np.where(alpha > 0.5, 0.55 + 0.45 * norm_l, 1.0).astype(np.float32)
    p2w = province_to_wilayah()
    wid_of_label = {i: p2w[p] for i, p in enumerate(PROVINCES, start=1)}
    wlab = np.zeros_like(lab, dtype=object)
    os.makedirs(os.path.join(ROOT, "assets", "map", "regions"), exist_ok=True)
    layout = {}
    preview = np.zeros((H, W, 3), dtype=np.uint8) + np.array([20, 28, 60], dtype=np.uint8)
    rng = np.random.default_rng(3)
    for wid, (_, _, _, members) in WILAYAH.items():
        ids = [PROVINCES.index(p) + 1 for p in members]
        mask = np.isin(lab, ids)
        # Garis batas provinsi di dalam wilayah (abu terang), supaya 38 provinsi tetap terlihat.
        shade = np.ones((H, W), dtype=np.float32)
        inner = np.zeros((H, W), dtype=bool)
        inner[:, :-1] |= (lab[:, :-1] != lab[:, 1:]) & mask[:, :-1] & mask[:, 1:]
        inner[:-1, :] |= (lab[:-1, :] != lab[1:, :]) & mask[:-1, :] & mask[1:, :]
        if art is not None:
            shade *= art
        shade[inner] = INNER_BORDER
        rgba = np.zeros((H, W, 4), dtype=np.uint8)
        v = (shade * 255).astype(np.uint8)
        rgba[:, :, 0] = v
        rgba[:, :, 1] = v
        rgba[:, :, 2] = v
        rgba[:, :, 3] = np.where(mask, 255, 0)
        Image.fromarray(rgba, "RGBA").save(os.path.join(ROOT, "assets", "map", "regions", wid + ".png"))
        # Posisi label: titik terdalam di potongan terbesar wilayah.
        comp, n = ndimage.label(mask)
        if n == 0:
            print("PERINGATAN: wilayah kosong", wid)
            continue
        sizes = ndimage.sum(mask, comp, range(1, n + 1))
        big = comp == (int(np.argmax(sizes)) + 1)
        edt = ndimage.distance_transform_edt(big)
        y, x = np.unravel_index(int(np.argmax(edt)), edt.shape)
        layout[wid] = [int(x), int(y)]
        col = rng.integers(90, 230, 3)
        preview[mask] = (col * shade[mask][:, None]).astype(np.uint8)
    json.dump(layout, open(os.path.join(ROOT, "tools", "map_layout.json"), "w"), indent=1)
    # Cek tetangga darat dari gambar (sebelum laut ditambahkan) dibanding daftar NEIGHBORS.
    touch = set()
    for dy, dx in ((0, 1), (1, 0)):
        a1 = lab0[: H - dy, : W - dx]
        b1 = lab0[dy:, dx:]
        m = (a1 > 0) & (b1 > 0) & (a1 != b1)
        for x1, y1 in set(zip(a1[m].tolist(), b1[m].tolist())):
            w1, w2 = wid_of_label[x1], wid_of_label[y1]
            if w1 != w2:
                touch.add(tuple(sorted((w1, w2))))
    listed = {tuple(sorted(p)) for p in NEIGHBORS}
    print("Bersentuhan di gambar tapi tidak ada di NEIGHBORS:", sorted(touch - listed))
    print("Ada di NEIGHBORS tapi tidak bersentuhan (jalur laut pendek):", sorted(listed - touch))
    if a.preview:
        img = Image.fromarray(preview)
        d = ImageDraw.Draw(img)
        for wid, (x, y) in layout.items():
            d.text((x - 12, y - 5), WILAYAH[wid][1], fill=(255, 255, 255))
        img.save(a.preview)
    print("ok:", len(layout), "wilayah")


if __name__ == "__main__":
    main()
