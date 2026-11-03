"""Tetangga antar-kloter untuk aturan sebaran "paling jauh 2 kloter dari pembangkit".

Dua kloter bertetangga jika selnya di peta (assets/map/cells.png) bersentuhan atau hanya dipisah
selat sempit (<= GAP piksel kisi). Supaya pulau kecil tidak terisolasi:
- kloter yang tetangganya kurang dari 2 disambung ke kloter terdekat (jarak titik pusat);
- setiap pasangan wilayah yang bertetangga di data (ProvinceData.neighbors) dijamin punya
  minimal satu sambungan: dua kloter terdekat dari kedua wilayah.

Hasil: data/kloter_links.json = {wilayah: [[ "wilayah:indeks", ... ] per kloter]}
Jalankan setelah tools/make_cells.py:
    python3 tools/make_kloter_links.py
"""
import json
import os
import re

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAP = 3  # piksel kisi 320x180 (1 piksel = 4 piksel layar)


def main():
    cells = json.load(open(os.path.join(ROOT, "data", "map_cells.json")))
    order = []  # gid -> (wilayah, indeks), urutan sama dengan make_cells.py
    for wid, rows in cells.items():
        for i in range(len(rows)):
            order.append((wid, i))
    img = np.array(Image.open(os.path.join(ROOT, "assets", "map", "cells.png")).convert("RGBA")).astype(np.int64)
    ids = img[..., 0] + img[..., 1] * 256 - 1  # -1 = laut
    n = len(order)
    links = [set() for _ in range(n)]
    struct = ndimage.generate_binary_structure(2, 1)
    for g in range(n):
        mask = ids == g
        if not mask.any():
            continue
        grown = ndimage.binary_dilation(mask, struct, iterations=GAP)
        for o in np.unique(ids[grown]):
            if o >= 0 and o != g:
                links[g].add(int(o))
                links[int(o)].add(g)
    pos = np.array([cells[w][i][:2] if cells[w][i] else [0, 0] for w, i in order], dtype=float)

    def nearest(a, candidates):
        d = ((pos[candidates] - pos[a]) ** 2).sum(1)
        return [candidates[j] for j in np.argsort(d)]

    for g in range(n):
        if len(links[g]) < 2:
            for o in nearest(g, [k for k in range(n) if k != g and k not in links[g]])[: 2 - len(links[g])]:
                links[g].add(o)
                links[o].add(g)
    # Wilayah bertetangga di data harus tersambung minimal satu pasang kloter.
    gid_of = {}
    for g, (w, i) in enumerate(order):
        gid_of.setdefault(w, []).append(g)
    for wid in cells:
        s = open(os.path.join(ROOT, "data", "provinces", wid + ".tres"), encoding="utf-8").read()
        m = re.search(r"neighbors = Array\[StringName\]\(\[(.*?)\]\)", s)
        for nb in re.findall(r'&"(\w+)"', m.group(1) if m else ""):
            if nb not in gid_of:
                continue
            if any(o in gid_of[nb] for g in gid_of[wid] for o in links[g]):
                continue
            best = min(((a, b) for a in gid_of[wid] for b in gid_of[nb]),
                       key=lambda p: ((pos[p[0]] - pos[p[1]]) ** 2).sum())
            links[best[0]].add(best[1])
            links[best[1]].add(best[0])
    out = {}
    for g, (w, i) in enumerate(order):
        out.setdefault(w, []).append(sorted("%s:%d" % order[o] for o in links[g]))
    json.dump(out, open(os.path.join(ROOT, "data", "kloter_links.json"), "w"), separators=(",", ":"))
    deg = [len(x) for x in links]
    print("ok: %d kloter, tetangga min %d, rata-rata %.1f, maks %d" % (n, min(deg), sum(deg) / n, max(deg)))


if __name__ == "__main__":
    main()
