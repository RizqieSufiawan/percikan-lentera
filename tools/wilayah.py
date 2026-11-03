"""Pembagian 38 provinsi ke 24 wilayah (node peta), plus pengaturan gameplay tiap wilayah.

Dipakai oleh tools/build_kloter.py (data .tres) dan tools/make_map.py (gambar wilayah).
Ubah di sini, lalu jalankan:  python3 tools/make_map.py  lalu  python3 tools/build_kloter.py
"""

# id: (nama lengkap, label peta, pulau, [provinsi anggota sesuai nama di Podes])
WILAYAH = {
 "aceh":    ("Aceh", "Aceh", "sumatra", ["Aceh"]),
 "sumut":   ("Sumatera Utara", "Sumut", "sumatra", ["Sumatera Utara"]),
 "riau":    ("Riau, Sumatera Barat & Kepulauan Riau", "Riau-Sumbar", "sumatra", ["Riau", "Sumatera Barat", "Kepulauan Riau"]),
 "sumsel":  ("Sumatera Selatan, Jambi & Bangka Belitung", "Sumsel-Jambi", "sumatra", ["Sumatera Selatan", "Jambi", "Kepulauan Bangka Belitung"]),
 "lampung": ("Lampung & Bengkulu", "Lampung", "sumatra", ["Lampung", "Bengkulu"]),
 "jabar":   ("Jawa Barat, DKI Jakarta & Banten", "Jabar", "jawa", ["Jawa Barat", "DKI Jakarta", "Banten"]),
 "jateng":  ("Jawa Tengah & DI Yogyakarta", "Jateng", "jawa", ["Jawa Tengah", "DI Yogyakarta"]),
 "jatim":   ("Jawa Timur", "Jatim", "jawa", ["Jawa Timur"]),
 "bali":    ("Bali", "Bali", "nusa_tenggara", ["Bali"]),
 "ntb":     ("Nusa Tenggara Barat", "NTB", "nusa_tenggara", ["Nusa Tenggara Barat"]),
 "ntt":     ("Nusa Tenggara Timur", "NTT", "nusa_tenggara", ["Nusa Tenggara Timur"]),
 "kalbar":  ("Kalimantan Barat", "Kalbar", "kalimantan", ["Kalimantan Barat"]),
 "kalteng": ("Kalimantan Tengah", "Kalteng", "kalimantan", ["Kalimantan Tengah"]),
 "kalsel":  ("Kalimantan Selatan", "Kalsel", "kalimantan", ["Kalimantan Selatan"]),
 "kaltim":  ("Kalimantan Timur & Utara", "Kaltim", "kalimantan", ["Kalimantan Timur", "Kalimantan Utara"]),
 "sulut":   ("Sulawesi Utara & Gorontalo", "Sulut", "sulawesi", ["Sulawesi Utara", "Gorontalo"]),
 "sulteng": ("Sulawesi Tengah", "Sulteng", "sulawesi", ["Sulawesi Tengah"]),
 "sulsel":  ("Sulawesi Selatan & Barat", "Sulsel", "sulawesi", ["Sulawesi Selatan", "Sulawesi Barat"]),
 "sultra":  ("Sulawesi Tenggara", "Sultra", "sulawesi", ["Sulawesi Tenggara"]),
 "maluku":  ("Maluku", "Maluku", "maluku", ["Maluku"]),
 "malut":   ("Maluku Utara", "Malut", "maluku", ["Maluku Utara"]),
 "pabar":   ("Papua Barat & Papua Barat Daya", "Papua Barat", "papua", ["Papua Barat", "Papua Barat Daya"]),
 "papua":   ("Papua", "Papua", "papua", ["Papua"]),
 "papteng": ("Papua Tengah, Pegunungan & Selatan", "Papua Tengah", "papua", ["Papua Tengah", "Papua Pegunungan", "Papua Selatan"]),
}

# Tetangga darat / jalur pendek di dalam satu gugus pulau (sebaran langsung). Antarpulau lewat
# internet atau rute pesawat. Ditulis sekali per pasangan.
NEIGHBORS = [
 ("aceh", "sumut"), ("sumut", "riau"), ("riau", "sumsel"), ("riau", "lampung"), ("sumsel", "lampung"),
 ("jabar", "jateng"), ("jateng", "jatim"), ("jatim", "bali"),
 ("bali", "ntb"), ("ntb", "ntt"),
 ("kalbar", "kalteng"), ("kalbar", "kaltim"), ("kalteng", "kalsel"), ("kalteng", "kaltim"), ("kalsel", "kaltim"),
 ("sulut", "sulteng"), ("sulteng", "sulsel"), ("sulteng", "sultra"), ("sulsel", "sultra"),
 ("maluku", "malut"),
 ("pabar", "papteng"), ("papteng", "papua"),
]

# Geser label nama wilayah dari titik tengahnya (piksel), untuk wilayah kecil yang berdempetan.
LABEL_OFFSET = {
 "bali": (0, -18), "ntb": (0, 18),
}

# Pengubah gameplay: (spread_mod, start_resistance_mod, catatan)
GAMEPLAY = {
 "sumut": (1.0, -2.0, "Komunitas kuat: resistensi awal sedikit lebih rendah."),
 "sumsel": (0.9, 0.0, ""),
 "jabar": (1.1, 2.0, "Padat, menyebar cepat, tapi tekanan energi lama lebih besar."),
 "kalteng": (0.9, 0.0, ""),
 "kalsel": (1.0, 3.0, "Daerah tambang batu bara: tekanan energi lama lebih kuat."),
 "kaltim": (1.0, 3.0, "Daerah tambang: tekanan energi lama lebih kuat."),
 "kalbar": (0.9, 0.0, "Banyak desa di perbatasan."),
 "sulsel": (1.1, -1.0, ""),
 "ntt": (0.9, 0.0, ""),
 "maluku": (0.9, 0.0, "Kepulauan: dari luar Maluku hanya terjangkau lewat internet atau pesawat."),
 "malut": (0.9, 0.0, "Kepulauan: dari luar Maluku hanya terjangkau lewat internet atau pesawat."),
 "pabar": (0.9, 0.0, ""),
 "papua": (0.8, 2.0, "Libatkan tokoh adat."),
 "papteng": (0.8, 2.0, "Pegunungan terpencil dan pesisir selatan. Libatkan tokoh adat."),
}


def province_to_wilayah() -> dict:
    out = {}
    for wid, (_, _, _, members) in WILAYAH.items():
        for p in members:
            out[p] = wid
    return out


def neighbors_of(wid: str) -> list:
    out = []
    for a, b in NEIGHBORS:
        if a == wid:
            out.append(b)
        elif b == wid:
            out.append(a)
    return out
