"""Hitung posisi label tiap wilayah di peta (nama + persen) supaya berada di bagian daratan yang paling
lega, lalu tulis ke data/provinces/<id>.tres sebagai label_offset.

Cara: dari gambar wilayah (assets/map/regions/<id>.png, 1280x720) dibuat peta jarak ke tepi wilayah.
Jarak mendatar dihitung lebih "mahal" karena kotak label lebih lebar daripada tinggi, jadi titik
terpilih adalah tempat kotak label paling muat. Sedikit dipilih yang dekat map_position supaya label
tidak melompat ke pulau kecil yang jauh. Label lain yang sudah ditempatkan dihindari.

Kotak teks label (scenes/ui/province_node.tscn): pusat teks ada 30 px di bawah titik label
(nama di y 31..47, persen di 45..61, node digeser -16), jadi titik label = pusat teks - (0, 30).

Pakai:  python3 tools/place_labels.py           (tulis)
        python3 tools/place_labels.py --dry     (hanya cetak)
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROV = os.path.join(ROOT, "data", "provinces")
TEXT_DY = 30  # pusat teks relatif titik label
BOX = (64, 32)  # perkiraan kotak teks (lebar, tinggi) untuk menghindari tabrakan antar-label


def read(path):
    s = open(path, encoding="utf-8").read()
    mp = re.search(r"map_position = Vector2\(([-\d.]+), ([-\d.]+)\)", s)
    reg = re.search(r'path="res://(assets/map/regions/[^"]+\.png)"', s)
    name = re.search(r'short_name = "([^"]*)"', s)
    return s, (float(mp.group(1)), float(mp.group(2))), reg.group(1) if reg else None, name.group(1) if name else ""


def main():
    dry = "--dry" in sys.argv
    items = []
    for fn in sorted(os.listdir(PROV)):
        if fn.endswith(".tres"):
            s, mp, reg, name = read(os.path.join(PROV, fn))
            if reg:
                a = np.array(Image.open(os.path.join(ROOT, reg)).convert("RGBA"))[:, :, 3] > 127
                items.append([fn, s, mp, a, name])
    # Wilayah paling kecil ditempatkan dulu (pilihannya paling sedikit).
    items.sort(key=lambda it: it[3].sum())
    taken = np.zeros_like(items[0][3])
    for it in items:
        fn, s, mp, mask, name = it
        # Jarak ke tepi; arah mendatar dibobot 0.5 (kotak label ~2x lebih lebar dari tinggi).
        dt = ndimage.distance_transform_edt(np.pad(mask, 1), sampling=[1.0, 0.5])[1:-1, 1:-1]
        yy, xx = np.mgrid[0:mask.shape[0], 0:mask.shape[1]]
        near = np.hypot(xx - mp[0], (yy - mp[1]) * 1.2)
        score = np.minimum(dt, 18.0) - near * 0.04
        score[~mask] = -1e9
        # Hindari kotak label lain.
        score[taken] -= 1000
        y, x = np.unravel_index(np.argmax(score), score.shape)
        label = (round(x - mp[0]), round(y - TEXT_DY - mp[1]))
        bw, bh = BOX
        taken[max(0, y - bh):y + bh, max(0, x - bw):x + bw] = True
        print("%-14s %-14s teks di (%4d,%4d)  ruang %.1f  label_offset %s" % (fn, name, x, y, dt[y, x], label))
        line = "label_offset = Vector2(%d, %d)" % label
        if re.search(r"^label_offset = .*$", s, re.M):
            s = re.sub(r"^label_offset = .*$", line, s, flags=re.M)
        else:
            s = re.sub(r"^(map_position = .*)$", r"\1\n" + line, s, count=1, flags=re.M)
        if not dry:
            open(os.path.join(PROV, fn), "w", encoding="utf-8").write(s)


if __name__ == "__main__":
    main()
