"""Menyusun gambar pulau buatan artis (semua 100x100 atau 400x400) menjadi satu peta 1280x720.

Pakai: python3 tools/compose_islands.py <folder berisi sumatra.png, jawa.png, ...> [--out daratan.png]
Lalu:  python3 tools/make_map.py --geojson tools/geo/indonesia-38-provinces.geojson --art daratan.png
       python3 tools/build_kloter.py
       python3 tools/make_cells.py
Area transparan tidak menimpa pulau lain, jadi kanvas yang saling tumpang tindih aman.
"""
import argparse
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--out", default="daratan.png")
    a = ap.parse_args()
    layout = json.load(open(os.path.join(ROOT, "tools", "geo", "per_pulau", "pulau_layout.json")))
    canvas = Image.new("RGBA", (320, 180), (0, 0, 0, 0))
    for k, pos in layout.items():
        path = os.path.join(a.folder, k + ".png")
        if not os.path.exists(path):
            print("lewati (tidak ada):", path)
            continue
        im = Image.open(path).convert("RGBA")
        if im.size != (pos["size"], pos["size"]):
            im = im.resize((pos["size"], pos["size"]), Image.NEAREST)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        layer.paste(im, (pos["x"], pos["y"]))
        canvas = Image.alpha_composite(canvas, layer)
    canvas.resize((320 * SCALE, 180 * SCALE), Image.NEAREST).save(a.out)
    print("ok:", a.out)


if __name__ == "__main__":
    main()
