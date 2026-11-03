"""Membagi peta menjadi SEL KLOTER: setiap kloter desa punya area sendiri di peta, supaya warna energi
(PLTS kuning, mikrohidro biru, dst.) terlihat di tempat yang masuk akal.

Penempatan (perkiraan, bukan koordinat desa sebenarnya):
- Kloter diletakkan di dalam provinsi ASALNYA (batas provinsi dari GeoJSON 38 provinsi).
- Di dalam provinsi: kloter berciri pesisir diletakkan dekat pantai; berciri gunung api, hutan berkabut,
  lembah, atau sungai deras di pedalaman; ciri lain di antaranya.
- Sel = daerah terdekat ke titik kloter (Voronoi), di kisi pixel art 320x180.

Hasil:
- assets/map/cells.png  : 320x180, id sel per piksel (R + G*256 = id global + 1; 0 = laut)
- data/map_cells.json   : per wilayah, per kloter: [x, y, jari-jari] dalam koordinat 1280x720

Jalankan SETELAH tools/build_kloter.py (urutan kloter diambil dari data/provinces/*.tres):
    python3 tools/make_cells.py
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from make_map import PROVINCES, SEA_GROW, grow_into_sea, labels_from_geojson  # noqa: E402
from build_kloter import SHORT  # noqa: E402

PIXEL = 4
GW, GH = 1280 // PIXEL, 720 // PIXEL
COAST = {"pesisir_berangin"}
INLAND = {"gunung_api", "hutan_berkabut", "lembah_tertutup", "sungai_deras"}
LONG = {v: k for k, v in SHORT.items()}


def read_db_order():
    """Urutan wilayah seperti di data/database.tres (urutan id global sel)."""
    db = open(os.path.join(ROOT, "data", "database.tres"), encoding="utf-8").read()
    ids = re.findall(r'path="res://data/provinces/(\w+)\.tres" id="([^"]+)"', db)
    path_of = {rid: name for name, rid in ids}
    m = re.search(r"^provinces = Array\[[^\]]*\]\(\[(.*?)\]\)", db, re.M)
    return [path_of[r] for r in re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))]


def read_kloters(wid):
    s = open(os.path.join(ROOT, "data", "provinces", wid + ".tres"), encoding="utf-8").read()
    subs = {}
    for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', s, re.S):
        body = m.group(2)
        origin = re.search(r'^origin = "(.*)"$', body, re.M)
        traits = re.search(r"^traits = Array\[StringName\]\(\[(.*?)\]\)", body, re.M)
        subs[m.group(1)] = {
            "origin": LONG.get(origin.group(1), origin.group(1)) if origin else None,
            "traits": re.findall(r'&"(\w+)"', traits.group(1)) if traits else [],
        }
    order = re.search(r"^village_list = .*?\(\[(.*)\]\)", s, re.M)
    return [subs[k] for k in re.findall(r'SubResource\("([^"]+)"\)', order.group(1))]


def farthest_points(pts, n, rng):
    """n titik yang saling berjauhan (sebaran merata) dari daftar piksel pts (N x 2)."""
    if len(pts) <= n:
        return pts.copy()
    chosen = [pts[rng.integers(len(pts))]]
    d = np.full(len(pts), np.inf)
    for _ in range(n - 1):
        d = np.minimum(d, ((pts - chosen[-1]) ** 2).sum(1))
        chosen.append(pts[int(d.argmax())])
    return np.array(chosen)


def lloyd(pts, seeds, iters=4):
    for _ in range(iters):
        own = ((pts[:, None, :] - seeds[None, :, :]) ** 2).sum(2).argmin(1)
        for k in range(len(seeds)):
            mine = pts[own == k]
            if len(mine):
                c = mine.mean(0)
                # Titik harus tetap di dalam provinsi: pakai piksel terdekat ke rata-rata.
                seeds[k] = mine[((mine - c) ** 2).sum(1).argmin()]
    return seeds


def main():
    geo = os.path.join(ROOT, "tools", "geo", "indonesia-38-provinces.geojson")
    lab = grow_into_sea(labels_from_geojson(geo), SEA_GROW)
    # Turunkan ke kisi pixel art (piksel tengah tiap blok 4x4).
    glab = lab[PIXEL // 2::PIXEL, PIXEL // 2::PIXEL][:GH, :GW]
    land = glab > 0
    coast_dist = ndimage.distance_transform_edt(land)
    ids = np.zeros((GH, GW), dtype=np.int32)
    out = {}
    gid = 0
    rng = np.random.default_rng(11)
    missing = 0
    for wid in read_db_order():
        kl = read_kloters(wid)
        entries = [None] * len(kl)
        by_origin = {}
        for i, k in enumerate(kl):
            by_origin.setdefault(k["origin"], []).append(i)
        for origin, idxs in by_origin.items():
            pi = PROVINCES.index(origin) + 1
            ys, xs = np.where(glab == pi)
            pts = np.stack([xs, ys], 1).astype(np.float64)
            if len(pts) == 0:
                missing += len(idxs)
                continue
            seeds = lloyd(pts, farthest_points(pts, len(idxs), rng).astype(np.float64))
            # Cocokkan titik dengan kloter: titik paling pesisir untuk kloter pesisir, dst.
            cd = coast_dist[seeds[:, 1].astype(int), seeds[:, 0].astype(int)]
            want = [0 if set(kl[i]["traits"]) & COAST else (2 if set(kl[i]["traits"]) & INLAND else 1) for i in idxs]
            seed_order = np.argsort(cd, kind="stable")
            kl_order = sorted(range(len(idxs)), key=lambda j: (want[j], j))
            assign = {}
            for s_i, k_j in zip(seed_order, kl_order):
                assign[k_j] = seeds[s_i]
            sarr = np.array([assign.get(j, seeds[0]) for j in range(len(idxs))])
            own = ((pts[:, None, :] - sarr[None, :, :]) ** 2).sum(2).argmin(1)
            for j, i in enumerate(idxs):
                cell = pts[own == j]
                g = gid + i + 1
                if len(cell):
                    ids[cell[:, 1].astype(int), cell[:, 0].astype(int)] = g
                    r = np.sqrt(((cell - sarr[j]) ** 2).sum(1)).max() + 1.5
                else:
                    missing += 1
                    r = 0.0
                entries[i] = [round((sarr[j][0] + 0.5) * PIXEL, 1), round((sarr[j][1] + 0.5) * PIXEL, 1), round(r * PIXEL, 1)]
        out[wid] = entries
        gid += len(kl)
    img = np.zeros((GH, GW, 4), dtype=np.uint8)
    img[..., 0] = ids % 256
    img[..., 1] = ids // 256
    img[..., 3] = 255
    Image.fromarray(img, "RGBA").save(os.path.join(ROOT, "assets", "map", "cells.png"))
    json.dump(out, open(os.path.join(ROOT, "data", "map_cells.json"), "w"), separators=(",", ":"))
    print("ok: %d kloter, %d tanpa area (provinsi terlalu kecil di peta)" % (gid, missing))


if __name__ == "__main__":
    main()
