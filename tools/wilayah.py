"""Pembagian 38 provinsi ke wilayah (node peta; eksperimen: 38 wilayah = 38 provinsi), plus pengaturan gameplay tiap wilayah.

Dipakai oleh tools/build_kloter.py (data .tres) dan tools/make_map.py (gambar wilayah).
Ubah di sini, lalu jalankan:  python3 tools/make_map.py  lalu  python3 tools/build_kloter.py
"""

# id: (nama lengkap, label peta, pulau, [provinsi anggota sesuai nama di Podes])
# EKSPERIMEN: satu node peta = satu provinsi (38). Id wilayah lama dipertahankan untuk provinsi yang
# dulu berdiri sendiri, supaya data lain (event, tes) tetap cocok.
WILAYAH = {
 "aceh":     ("Aceh", "Aceh", "sumatra", ["Aceh"]),
 "sumut":    ("Sumatera Utara", "Sumut", "sumatra", ["Sumatera Utara"]),
 "sumbar":   ("Sumatera Barat", "Sumbar", "sumatra", ["Sumatera Barat"]),
 "riau":     ("Riau", "Riau", "sumatra", ["Riau"]),
 "kepri":    ("Kepulauan Riau", "Kepri", "sumatra", ["Kepulauan Riau"]),
 "jambi":    ("Jambi", "Jambi", "sumatra", ["Jambi"]),
 "sumsel":   ("Sumatera Selatan", "Sumsel", "sumatra", ["Sumatera Selatan"]),
 "babel":    ("Kepulauan Bangka Belitung", "Babel", "sumatra", ["Kepulauan Bangka Belitung"]),
 "bengkulu": ("Bengkulu", "Bengkulu", "sumatra", ["Bengkulu"]),
 "lampung":  ("Lampung", "Lampung", "sumatra", ["Lampung"]),
 "banten":   ("Banten", "Banten", "jawa", ["Banten"]),
 "dki":      ("DKI Jakarta", "DKI", "jawa", ["DKI Jakarta"]),
 "jabar":    ("Jawa Barat", "Jabar", "jawa", ["Jawa Barat"]),
 "jateng":   ("Jawa Tengah", "Jateng", "jawa", ["Jawa Tengah"]),
 "diy":      ("DI Yogyakarta", "DIY", "jawa", ["DI Yogyakarta"]),
 "jatim":    ("Jawa Timur", "Jatim", "jawa", ["Jawa Timur"]),
 "bali":     ("Bali", "Bali", "nusa_tenggara", ["Bali"]),
 "ntb":      ("Nusa Tenggara Barat", "NTB", "nusa_tenggara", ["Nusa Tenggara Barat"]),
 "ntt":      ("Nusa Tenggara Timur", "NTT", "nusa_tenggara", ["Nusa Tenggara Timur"]),
 "kalbar":   ("Kalimantan Barat", "Kalbar", "kalimantan", ["Kalimantan Barat"]),
 "kalteng":  ("Kalimantan Tengah", "Kalteng", "kalimantan", ["Kalimantan Tengah"]),
 "kalsel":   ("Kalimantan Selatan", "Kalsel", "kalimantan", ["Kalimantan Selatan"]),
 "kaltim":   ("Kalimantan Timur", "Kaltim", "kalimantan", ["Kalimantan Timur"]),
 "kaltara":  ("Kalimantan Utara", "Kaltara", "kalimantan", ["Kalimantan Utara"]),
 "sulut":    ("Sulawesi Utara", "Sulut", "sulawesi", ["Sulawesi Utara"]),
 "gorontalo": ("Gorontalo", "Gorontalo", "sulawesi", ["Gorontalo"]),
 "sulteng":  ("Sulawesi Tengah", "Sulteng", "sulawesi", ["Sulawesi Tengah"]),
 "sulbar":   ("Sulawesi Barat", "Sulbar", "sulawesi", ["Sulawesi Barat"]),
 "sulsel":   ("Sulawesi Selatan", "Sulsel", "sulawesi", ["Sulawesi Selatan"]),
 "sultra":   ("Sulawesi Tenggara", "Sultra", "sulawesi", ["Sulawesi Tenggara"]),
 "maluku":   ("Maluku", "Maluku", "maluku", ["Maluku"]),
 "malut":    ("Maluku Utara", "Malut", "maluku", ["Maluku Utara"]),
 "pbd":      ("Papua Barat Daya", "PBD", "papua", ["Papua Barat Daya"]),
 "pabar":    ("Papua Barat", "Papua Barat", "papua", ["Papua Barat"]),
 "papteng":  ("Papua Tengah", "Papua Tengah", "papua", ["Papua Tengah"]),
 "papua":    ("Papua", "Papua", "papua", ["Papua"]),
 "papeg":    ("Papua Pegunungan", "Papua Peg.", "papua", ["Papua Pegunungan"]),
 "papsel":   ("Papua Selatan", "Papua Sel.", "papua", ["Papua Selatan"]),
}

# Tetangga darat / jalur pendek di dalam satu gugus pulau (sebaran langsung). Antarpulau lewat
# internet atau rute pesawat. Ditulis sekali per pasangan.
NEIGHBORS = [
 ("aceh", "sumut"), ("sumut", "sumbar"), ("sumut", "riau"), ("sumbar", "riau"), ("sumbar", "jambi"),
 ("sumbar", "bengkulu"), ("riau", "jambi"), ("riau", "kepri"), ("jambi", "sumsel"), ("jambi", "bengkulu"),
 ("sumsel", "bengkulu"), ("sumsel", "lampung"), ("bengkulu", "lampung"), ("sumsel", "babel"),
 ("banten", "dki"), ("banten", "jabar"), ("dki", "jabar"), ("jabar", "jateng"), ("jateng", "diy"), ("jateng", "jatim"),
 ("jatim", "bali"), ("bali", "ntb"), ("ntb", "ntt"),
 ("kalbar", "kalteng"), ("kalbar", "kaltim"), ("kalteng", "kalsel"), ("kalteng", "kaltim"), ("kalsel", "kaltim"),
 ("kaltim", "kaltara"),
 ("sulut", "gorontalo"), ("gorontalo", "sulteng"), ("sulteng", "sulbar"), ("sulteng", "sulsel"),
 ("sulteng", "sultra"), ("sulbar", "sulsel"), ("sulsel", "sultra"),
 ("maluku", "malut"),
 ("pbd", "pabar"), ("pabar", "papteng"), ("papteng", "papua"), ("papteng", "papeg"), ("papua", "papeg"),
 ("papeg", "papsel"), ("papteng", "papsel"),
]

# Geser label nama wilayah dari titik tengahnya (piksel), untuk wilayah kecil yang berdempetan.
LABEL_OFFSET = {
 "bali": (0, -18), "ntb": (0, 18),
}

# Pengubah gameplay: (spread_mod, start_resistance_mod, catatan)
_JAWA_BARAT = (1.1, 2.0, "Padat, menyebar cepat, tapi tekanan energi lama lebih besar.")
_PAPUA = (0.8, 2.0, "Pegunungan terpencil. Libatkan tokoh adat.")
GAMEPLAY = {
 "sumut": (1.0, -2.0, "Komunitas kuat: resistensi awal sedikit lebih rendah."),
 "sumsel": (0.9, 0.0, ""), "jambi": (0.9, 0.0, ""), "babel": (0.9, 0.0, ""),
 "jabar": _JAWA_BARAT, "dki": _JAWA_BARAT, "banten": _JAWA_BARAT,
 "kalteng": (0.9, 0.0, ""),
 "kalsel": (1.0, 3.0, "Daerah tambang batu bara: tekanan energi lama lebih kuat."),
 "kaltim": (1.0, 3.0, "Daerah tambang: tekanan energi lama lebih kuat."),
 "kaltara": (1.0, 3.0, "Daerah tambang: tekanan energi lama lebih kuat."),
 "kalbar": (0.9, 0.0, "Banyak desa di perbatasan."),
 "sulsel": (1.1, -1.0, ""), "sulbar": (1.1, -1.0, ""),
 "ntt": (0.9, 0.0, ""),
 "maluku": (0.9, 0.0, "Kepulauan: dari luar Maluku hanya terjangkau lewat internet atau pesawat."),
 "malut": (0.9, 0.0, "Kepulauan: dari luar Maluku hanya terjangkau lewat internet atau pesawat."),
 "pabar": (0.9, 0.0, ""), "pbd": (0.9, 0.0, ""),
 "papua": (0.8, 2.0, "Libatkan tokoh adat."),
 "papteng": _PAPUA, "papeg": _PAPUA, "papsel": (0.8, 2.0, "Pesisir selatan yang terpencil. Libatkan tokoh adat."),
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
