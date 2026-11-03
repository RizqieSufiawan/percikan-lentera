# Aset peta per pulau (ukuran sama semua)

**Setiap pulau = satu PNG 100 x 100 piksel, latar transparan.** Di game diperbesar 4x (400 x 400) tanpa blur.

| File yang dikirim artis | Ukuran |
| --- | --- |
| sumatra.png, jawa.png, kalimantan.png, sulawesi.png, nusa_tenggara.png, maluku.png, papua.png | 100 x 100 |

- Acuan bentuk: `<pulau>_100x100.png` (ukuran asli) atau `<pulau>_400x400.png` (diperbesar, lebih mudah dilihat).
  Warna di template = provinsi. Gambar daratan tepat di atas bentuk itu, jangan digeser.
- Bagian yang bukan pulau itu biarkan transparan (jangan diwarnai laut).
- Boleh juga menggambar di 400 x 400; nanti dikecilkan otomatis.
- `_panduan.png` menunjukkan letak ketujuh kanvas di peta.

Menyusun kembali (dikerjakan programmer):
    python3 tools/compose_islands.py <folder gambar artis> --out daratan.png
    python3 tools/make_map.py --geojson tools/geo/indonesia-38-provinces.geojson --art daratan.png
    python3 tools/build_kloter.py
    python3 tools/make_cells.py
