"""Template aset peta per pulau, semua berukuran SAMA supaya mudah digambar artis.

Setiap pulau: kanvas 100x100 piksel (pixel art; di game diperbesar 4x menjadi 400x400).
Pulau diletakkan di tengah kanvas. Posisi kanvas di peta disimpan di pulau_layout.json,
dipakai tools/compose_islands.py untuk menyusun kembali gambar artis menjadi peta 1280x720.

Pakai: python3 tools/island_templates.py
Hasil: tools/geo/per_pulau/<pulau>_100x100.png, <pulau>_400x400.png, pulau_layout.json, _panduan.png
"""
import json
import os
import re

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "geo", "per_pulau")
SIZE = 100       # kanvas pixel art per pulau
SCALE = 4        # 1 piksel seni = 4 piksel layar
ORDER = ["sumatra", "jawa", "kalimantan", "sulawesi", "nusa_tenggara", "maluku", "papua"]


def island_masks():
    masks = {}
    pdir = os.path.join(ROOT, "data", "provinces")
    for f in sorted(os.listdir(pdir)):
        if not f.endswith(".tres"):
            continue
        s = open(os.path.join(pdir, f), encoding="utf-8").read()
        isl = re.search(r"islands/(\w+)\.tres", s)
        mask = re.search(r"res://(assets/map/regions/\w+\.png)", s)
        if not (isl and mask):
            continue
        a = np.array(Image.open(os.path.join(ROOT, mask.group(1))).convert("RGBA"))[:, :, 3] > 127
        k = isl.group(1)
        masks[k] = a if k not in masks else (masks[k] | a)
    return masks


def main():
    os.makedirs(OUT, exist_ok=True)
    template = Image.open(os.path.join(ROOT, "tools", "geo", "template_peta_38_provinsi.png")).convert("RGBA")
    masks = island_masks()
    layout = {}
    guide = template.copy()
    d = ImageDraw.Draw(guide)
    for k in ORDER:
        m = masks[k]
        ys, xs = np.where(m)
        cx = (xs.min() + xs.max() + 1) / 2.0 / SCALE
        cy = (ys.min() + ys.max() + 1) / 2.0 / SCALE
        ox, oy = int(round(cx - SIZE / 2)), int(round(cy - SIZE / 2))  # pojok kiri atas, koordinat 320x180
        w, h = (xs.max() - xs.min() + 1) / SCALE, (ys.max() - ys.min() + 1) / SCALE
        assert w <= SIZE and h <= SIZE, (k, w, h)
        layout[k] = {"x": ox, "y": oy, "size": SIZE}
        # Template: hanya pulau ini, warna provinsi dari template peta.
        only = np.array(template)
        only[~m] = (0, 0, 0, 0)
        big = Image.fromarray(only).crop((ox * SCALE, oy * SCALE, (ox + SIZE) * SCALE, (oy + SIZE) * SCALE))
        big.save(os.path.join(OUT, "%s_400x400.png" % k))
        big.resize((SIZE, SIZE), Image.NEAREST).save(os.path.join(OUT, "%s_100x100.png" % k))
        d.rectangle([ox * SCALE, oy * SCALE, (ox + SIZE) * SCALE - 1, (oy + SIZE) * SCALE - 1], outline=(255, 60, 60, 255), width=2)
        d.text((ox * SCALE + 4, oy * SCALE + 2), k, fill=(255, 60, 60, 255))
        print("%-14s kanvas 100x100 di (%d, %d), pulau %dx%d" % (k, ox, oy, round(w), round(h)))
    guide.save(os.path.join(OUT, "_panduan.png"))
    json.dump(layout, open(os.path.join(OUT, "pulau_layout.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
