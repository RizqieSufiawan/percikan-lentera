"""Potensi EBT per provinsi, Perpres 22/2017 (RUEN) Lampiran I. Satuan MW.

Tabel 35 panas bumi (sumber daya total + cadangan total), Tabel 40 mini/mikrohidro,
Tabel 42 bioenergi (biomassa/biofuel + biogas), Tabel 44 surya, Tabel 46 bayu (>= 4 m/s).
Provinsi yang tidak tercantum di sebuah tabel = 0.
Data 2015, sebelum pemekaran: "Papua" = Papua + Papua Selatan + Tengah + Pegunungan,
"Papua Barat" = Papua Barat + Papua Barat Daya. Bioenergi Kaltim digabung dengan Kaltara.
"""

PANAS_BUMI = {
 "Jawa Barat": 2159 + 3765, "Sumatera Utara": 434 + 2316, "Lampung": 1243 + 1339, "Sumatera Selatan": 918 + 964,
 "Jawa Tengah": 517 + 1344, "Sumatera Barat": 801 + 1035, "Nusa Tenggara Timur": 629 + 763, "Jawa Timur": 362 + 1012,
 "Bengkulu": 580 + 780, "Aceh": 980 + 332, "Jambi": 422 + 621, "Sulawesi Utara": 128 + 768, "Maluku Utara": 197 + 580,
 "Sulawesi Tengah": 385 + 368, "Maluku": 454 + 220, "Banten": 261 + 365, "Sulawesi Barat": 369 + 162,
 "Sulawesi Selatan": 292 + 163, "Bali": 92 + 262, "Sulawesi Tenggara": 225 + 98, "Gorontalo": 140 + 110,
 "Nusa Tenggara Barat": 6 + 169, "Kepulauan Bangka Belitung": 106, "Papua Barat": 75, "Kalimantan Barat": 65,
 "Kalimantan Selatan": 50, "Kalimantan Utara": 50, "Riau": 41, "Kalimantan Timur": 18, "DI Yogyakarta": 10,
}
MIKROHIDRO = {
 "Kalimantan Timur": 3562, "Kalimantan Tengah": 3313, "Aceh": 1538, "Sumatera Barat": 1353, "Sumatera Utara": 1204,
 "Jawa Timur": 1142, "Jawa Tengah": 1044, "Kalimantan Utara": 943, "Sulawesi Selatan": 762, "Jawa Barat": 647,
 "Papua": 615, "Sumatera Selatan": 448, "Jambi": 447, "Sulawesi Tengah": 370, "Lampung": 352,
 "Sulawesi Tenggara": 301, "Riau": 284, "Maluku": 190, "Kalimantan Selatan": 158, "Kalimantan Barat": 124,
 "Gorontalo": 117, "Sulawesi Utara": 111, "Bengkulu": 108, "Nusa Tenggara Timur": 95, "Banten": 72,
 "Nusa Tenggara Barat": 31, "Maluku Utara": 24, "Bali": 15, "Sulawesi Barat": 7, "DI Yogyakarta": 5, "Papua Barat": 3,
}
# (biomassa/biofuel, biogas)
BIOENERGI = {
 "Riau": (4157.4, 37.7), "Jawa Timur": (2851.3, 569.6), "Sumatera Utara": (2796.1, 115.5),
 "Jawa Barat": (1979.8, 574.3), "Jawa Tengah": (1884.1, 348.4), "Sumatera Selatan": (2061.4, 71.2),
 "Jambi": (1821.0, 18.9), "Kalimantan Tengah": (1486.7, 12.2), "Lampung": (1407.6, 84.5),
 "Kalimantan Barat": (1279.3, 28.9), "Kalimantan Selatan": (1266.3, 23.6), "Aceh": (1136.6, 37.7),
 "Kalimantan Timur+Utara": (946.6, 17.7), "Sulawesi Selatan": (890.3, 69.1), "Sumatera Barat": (923.1, 34.7),
 "Bengkulu": (633.0, 11.8), "Banten": (346.5, 118.6), "Nusa Tenggara Barat": (341.3, 52.8),
 "Sulawesi Tengah": (307.4, 19.5), "Nusa Tenggara Timur": (192.5, 48.0), "DI Yogyakarta": (183.1, 41.1),
 "Kepulauan Bangka Belitung": (217.7, 5.4), "Sulawesi Barat": (197.8, 8.1), "Bali": (146.9, 44.7),
 "Sulawesi Utara": (150.2, 13.8), "Sulawesi Tenggara": (132.8, 17.7), "Gorontalo": (119.1, 11.5),
 "DKI Jakarta": (0.5, 126.1), "Papua": (81.4, 15.1), "Papua Barat": (50.8, 4.1), "Maluku Utara": (27.5, 7.0),
 "Maluku": (23.6, 9.0), "Kepulauan Riau": (11.6, 4.3),
}
SURYA = {
 "Kalimantan Barat": 20113, "Sumatera Selatan": 17233, "Kalimantan Timur": 13479, "Sumatera Utara": 11851,
 "Jawa Timur": 10335, "Nusa Tenggara Barat": 9931, "Jawa Barat": 9099, "Jambi": 8847, "Jawa Tengah": 8753,
 "Kalimantan Tengah": 8459, "Aceh": 7881, "Kepulauan Riau": 7763, "Sulawesi Selatan": 7588,
 "Nusa Tenggara Timur": 7272, "Papua Barat": 6307, "Sulawesi Tengah": 6187, "Kalimantan Selatan": 6031,
 "Sumatera Barat": 5898, "Kalimantan Utara": 4643, "Sulawesi Tenggara": 3917, "Bengkulu": 3475,
 "Maluku Utara": 3036, "Kepulauan Bangka Belitung": 2810, "Banten": 2461, "Lampung": 2238, "Sulawesi Utara": 2113,
 "Papua": 2035, "Maluku": 2020, "Sulawesi Barat": 1677, "Bali": 1254, "Gorontalo": 1218, "DI Yogyakarta": 996,
 "Riau": 753, "DKI Jakarta": 225,
}
ANGIN = {
 "Nusa Tenggara Timur": 10188, "Jawa Timur": 7907, "Jawa Barat": 7036, "Jawa Tengah": 5213, "Sulawesi Selatan": 4193,
 "Maluku": 3188, "Nusa Tenggara Barat": 2605, "Kepulauan Bangka Belitung": 1787, "Banten": 1753, "Bengkulu": 1513,
 "Sulawesi Tenggara": 1414, "Papua": 1411, "Sulawesi Utara": 1214, "Lampung": 1137, "DI Yogyakarta": 1079,
 "Bali": 1019, "Kalimantan Selatan": 1006, "Kepulauan Riau": 922, "Sulawesi Tengah": 908, "Aceh": 894,
 "Kalimantan Tengah": 681, "Kalimantan Barat": 554, "Sulawesi Barat": 514, "Maluku Utara": 504, "Papua Barat": 437,
 "Sumatera Barat": 428, "Sumatera Utara": 356, "Sumatera Selatan": 301, "Kalimantan Timur": 212, "Gorontalo": 137,
 "Kalimantan Utara": 73, "Jambi": 37, "Riau": 22, "DKI Jakarta": 4,
}
NASIONAL = {"plts": 207898, "angin": 60647, "mikrohidro": 19385, "biomassa": 32653.8, "panas_bumi": 29544,
            "biogas": 2602.6}

# Provinsi Podes 2024 -> provinsi RUEN 2015
RUEN_UNIT = {"Papua Barat Daya": "Papua Barat", "Papua Selatan": "Papua", "Papua Tengah": "Papua",
             "Papua Pegunungan": "Papua"}


def potential(unit: str) -> dict:
    bio_key = "Kalimantan Timur+Utara" if unit in ("Kalimantan Timur", "Kalimantan Utara") else unit
    bio = BIOENERGI.get(bio_key, (0.0, 0.0))
    return {"plts": SURYA.get(unit, 0), "angin": ANGIN.get(unit, 0), "mikrohidro": MIKROHIDRO.get(unit, 0),
            "biomassa": bio[0] + bio[1], "panas_bumi": PANAS_BUMI.get(unit, 0), "biogas": bio[1],
            "_bio_shared": bio_key != unit}
