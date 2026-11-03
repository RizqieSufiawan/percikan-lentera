"""Membangun 24 wilayah x kloter desa dari data resmi, lalu menulis data/provinces/<id>.tres
dan daftar wilayah di data/database.tres.

Sumber:
- BPS, Statistik Potensi Desa Indonesia 2024 -> tools/podes_2024.json (tools/extract_podes.py)
- Perpres 22/2017 RUEN Lampiran I -> tools/ruen_2017.py
- Pembagian wilayah, tetangga, dan pengubah gameplay -> tools/wilayah.py
- Posisi label peta -> tools/map_layout.json (tools/make_map.py)

Aturan:
- 24 node peta = wilayah. Setiap wilayah berisi satu atau beberapa provinsi asli (total 38 provinsi, 84.276 desa).
- Desa tiap provinsi dibagi menjadi kloter berukuran +-KLOTER desa. Desa "gelap" (masih ada keluarga
  bukan pengguna listrik, Podes Tabel 3.1) dan desa "fosil" (sisanya) dikelompokkan terpisah, sehingga
  jumlah desa gelap dan fosil di game sama persis dengan data.
- Ciri kloter: peluang dari persen desa provinsi asalnya (Podes), dikali tingkat potensi RUEN.
- Kecocokan energi kloter = tingkat potensi RUEN provinsi asalnya (cocok 1.0, sedang 0.5, kurang 0.15).
- Wilayah: compat_override = rata-rata berbobot desa (untuk petunjuk), disaster_rates = persen desa
  terdampak bencana 2023-Apr 2024 (Podes Tabel 15.2) gabungan provinsi anggotanya.

Jalankan dari folder proyek:  python3 tools/build_kloter.py
"""
import json
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ruen_2017 as R  # noqa: E402
from wilayah import WILAYAH, GAMEPLAY, LABEL_OFFSET, neighbors_of  # noqa: E402

KLOTER = 500
PODES = json.load(open(os.path.join(ROOT, "tools", "podes_2024.json"), encoding="utf-8"))
NAT_DESA = sum(v["total"] for v in PODES.values())
E = ["plts", "mikrohidro", "biomassa", "angin", "panas_bumi"]
LAYOUT_PATH = os.path.join(ROOT, "tools", "map_layout.json")
LAYOUT = json.load(open(LAYOUT_PATH)) if os.path.exists(LAYOUT_PATH) else {}
SHORT = {
 "Aceh": "Aceh", "Sumatera Utara": "Sumut", "Sumatera Barat": "Sumbar", "Riau": "Riau", "Jambi": "Jambi",
 "Sumatera Selatan": "Sumsel", "Bengkulu": "Bengkulu", "Lampung": "Lampung", "Kepulauan Bangka Belitung": "Babel",
 "Kepulauan Riau": "Kepri", "DKI Jakarta": "DKI Jakarta", "Jawa Barat": "Jabar", "Jawa Tengah": "Jateng",
 "DI Yogyakarta": "DIY", "Jawa Timur": "Jatim", "Banten": "Banten", "Bali": "Bali", "Nusa Tenggara Barat": "NTB",
 "Nusa Tenggara Timur": "NTT", "Kalimantan Barat": "Kalbar", "Kalimantan Tengah": "Kalteng",
 "Kalimantan Selatan": "Kalsel", "Kalimantan Timur": "Kaltim", "Kalimantan Utara": "Kaltara",
 "Sulawesi Utara": "Sulut", "Sulawesi Tengah": "Sulteng", "Sulawesi Selatan": "Sulsel", "Sulawesi Tenggara": "Sultra",
 "Gorontalo": "Gorontalo", "Sulawesi Barat": "Sulbar", "Maluku": "Maluku", "Maluku Utara": "Malut",
 "Papua Barat": "Papua Barat", "Papua Barat Daya": "Papua Barat Daya", "Papua": "Papua",
 "Papua Selatan": "Papua Selatan", "Papua Tengah": "Papua Tengah", "Papua Pegunungan": "Papua Pegunungan",
}
# Nama kloter = nama desa wakil (fiktif), gaya per daerah: (sebutan, suku kata 1, suku kata 2, digabung?)
NAME_STYLE = {
 "Aceh": ("Gampong", ["Lam", "Blang", "Meunasah", "Cot", "Krueng", "Lhok"], ["Ara", "Baro", "Raya", "Teungoh", "Tuha", "Mee", "Bate", "Pulo"], False),
 "Sumatera Barat": ("Nagari", ["Koto", "Sungai", "Batu", "Padang", "Lubuk", "Tanjung"], ["Gadang", "Tinggi", "Baru", "Panjang", "Ampek", "Rajo"], False),
 "_sumatra": ("Desa", ["Lubuk", "Koto", "Teluk", "Muara", "Tanjung", "Batu", "Bukit", "Padang", "Simpang", "Air"], ["Raya", "Hijau", "Tinggi", "Permai", "Gadang", "Indah", "Lestari", "Baru", "Jaya", "Mulia"], False),
 "Jawa Barat": ("Desa", ["Suka", "Ci", "Mekar", "Sinar", "Jaya", "Karya"], ["mulya", "jaya", "sari", "asih", "wangi", "makmur", "galih", "rahayu"], True),
 "Banten": ("Desa", ["Suka", "Ci", "Mekar", "Sindang"], ["mulya", "jaya", "sari", "asih", "laya"], True),
 "DKI Jakarta": ("Kelurahan", ["Kebon", "Pulo", "Rawa", "Tanjung"], ["Baru", "Jati", "Bunga", "Kelapa"], False),
 "_jawa": ("Desa", ["Sumber", "Karang", "Tegal", "Wono", "Rejo", "Kali", "Banyu", "Sido", "Mojo", "Ngadi"], ["mulyo", "sari", "rejo", "jati", "asri", "harjo", "luhur", "makmur", "agung", "kerto"], True),
 "Bali": ("Desa", ["Tegal", "Banjar", "Batu", "Pura", "Yeh"], ["Sari", "Kaja", "Kelod", "Asri", "Anyar"], False),
 "_nt": ("Desa", ["Watu", "Lamba", "Oe", "Rana", "Kote", "Lewo", "Nua", "Wai"], ["Mesa", "Bara", "Lia", "Leka", "Kaka", "Mbaru", "Lolo", "Nggela", "Tana"], False),
 "_kal": ("Desa", ["Nanga", "Long", "Muara", "Tumbang", "Rantau", "Sungai", "Tanjung"], ["Bahau", "Kayan", "Apari", "Hulu", "Lebak", "Ensa", "Seluang", "Ruai", "Danum"], False),
 "_sul": ("Desa", ["Salu", "Mata", "Bonto", "Bulu", "Lembang", "Tompo", "Tana", "Wana"], ["Rappo", "Sapiri", "Lotong", "Tinggi", "Bangun", "Lalong", "Rante", "Lipu"], False),
 "_maluku": ("Negeri", ["Hatu", "Ama", "Tala", "Lau", "Waai", "Soa", "Toma"], ["Manis", "Lima", "Besi", "Putih", "Mera", "Raya", "Lusi"], False),
 "_papua": ("Kampung", ["Ki", "Me", "Mo", "Wa", "Ari", "Te", "Ya", "Sua", "Ye"], ["peri", "taro", "bawi", "nage", "bor", "kuri", "doki", "wani", "mbo"], True),
}
LEVEL_VALUE = {"cocok": 1.0, "sedang": 0.5, "kurang": 0.15}
LEVEL_FACTOR = {"cocok": 1.0, "sedang": 0.6, "kurang": 0.3}
CONFLICTS = {frozenset(x) for x in [("hutan_berkabut", "lahan_terik"), ("lembah_tertutup", "pesisir_berangin"),
                                    ("hutan_berkabut", "pesisir_berangin")]}
REMOTE = {"hutan_berkabut", "lembah_tertutup", "sungai_deras"}
MAX_TRAITS = 2
# id event -> kolom Podes Tabel 15.2
DISASTER_COLS = {"banjir_bandang": ["banjir", "banjir_bandang"],
                 "badai_pesisir": ["gelombang_pasang", "puting_beliung", "abrasi"],
                 "kemarau_panjang": ["kekeringan"], "erupsi": ["gunung_meletus"], "titik_api": ["karhutla"]}


def unit_of(p):
    return R.RUEN_UNIT.get(p, p)


def unit_desa(unit, shared_bio=False):
    members = [p for p in PODES if unit_of(p) == unit]
    if shared_bio:
        members = ["Kalimantan Timur", "Kalimantan Utara"]
    return sum(PODES[p]["total"] for p in members)


def ruen_levels(p):
    unit = unit_of(p)
    pot = R.potential(unit)
    lq = {}
    for e in E + ["biogas"]:
        desa = unit_desa(unit, pot["_bio_shared"] and e in ("biomassa", "biogas"))
        lq[e] = (pot[e] / R.NASIONAL[e]) / (desa / NAT_DESA)
    m = max(lq[e] for e in E)
    lv = {}
    for e in E:
        r = lq[e] / m if m > 0 else 0
        lv[e] = "cocok" if (r >= 0.6 or lq[e] >= 1.5) else ("sedang" if (r >= 0.25 or lq[e] >= 0.6) else "kurang")
    return lv, lq


def trait_probs(p):
    d = PODES[p]
    t = d["total"]
    pct = lambda *keys: sum(d[k] for k in keys) / t
    lv, lq = ruen_levels(p)
    f = {e: LEVEL_FACTOR[lv[e]] for e in E}
    return {
        "limbah_perkebunan": pct("perkebunan") * f["biomassa"],
        "sungai_deras": pct("sungai") * pct("lereng", "puncak") * f["mikrohidro"],
        "pesisir_berangin": pct("pesisir") * f["angin"],
        "lahan_terik": pct("dataran") * (1 - pct("dalam_hutan", "tepi_hutan")) * f["plts"],
        "gunung_api": min(0.35, lq["panas_bumi"] * 0.15) * f["panas_bumi"],
        "peternakan": min(0.3, lq["biogas"] * 0.1),
        "hutan_berkabut": pct("dalam_hutan", "tepi_hutan") * 0.6,
        "lembah_tertutup": pct("lereng", "puncak", "lembah") * 0.25,
    }


def split(total, n):
    base, extra = divmod(total, n)
    return [base + (1 if i < extra else 0) for i in range(n)]


def kloters_for(p, rng):
    d = PODES[p]
    dark = d["bukan_pengguna"]
    fossil = d["total"] - dark
    out = []
    for status, count in (("dark", dark), ("fossil", fossil)):
        if count <= 0:
            continue
        n = max(1, round(count / KLOTER))
        for size in split(count, n):
            out.append({"origin": p, "size": size, "dark": status == "dark", "traits": []})
    probs = trait_probs(p)
    order = sorted(probs, key=lambda k: -probs[k])
    n = len(out)
    for t in order:
        k = round(n * probs[t])
        idx = list(range(n))
        rng.shuffle(idx)
        # Ciri pedalaman lebih dulu ke kloter gelap; ciri lain ke kloter yang cirinya masih sedikit.
        idx.sort(key=lambda i: (len(out[i]["traits"]), 0 if (t in REMOTE) == out[i]["dark"] else 1))
        for i in idx:
            if k <= 0:
                break
            tr = out[i]["traits"]
            if len(tr) >= MAX_TRAITS or any(frozenset((t, x)) in CONFLICTS for x in tr):
                continue
            tr.append(t)
            k -= 1
    for kl in out:
        if not kl["traits"]:
            for t in order:
                if not any(frozenset((t, x)) in CONFLICTS for x in kl["traits"]):
                    kl["traits"].append(t)
                    break
    lv, _ = ruen_levels(p)
    for kl in out:
        kl["compat"] = {e: LEVEL_VALUE[lv[e]] for e in E}
    return out


def style_for(p, wid):
    if p in NAME_STYLE:
        return NAME_STYLE[p]
    island = WILAYAH[wid][2]
    return NAME_STYLE.get({"sumatra": "_sumatra", "jawa": "_jawa", "nusa_tenggara": "_nt", "kalimantan": "_kal",
                           "sulawesi": "_sul", "maluku": "_maluku"}.get(island, "_papua"))


def make_name(p, wid, used, rng):
    prefix, a, b, joined = style_for(p, wid)
    for _ in range(200):
        x, y = rng.choice(a), rng.choice(b)
        core = (x + y) if joined else (x + " " + y)
        if core not in used:
            used.add(core)
            return "%s %s" % (prefix, core)
    core = "%s %s %d" % (rng.choice(a), rng.choice(b), len(used))
    used.add(core)
    return "%s %s" % (prefix, core)


def fmt_dict(d):
    return "Dictionary[StringName, float]({" + ", ".join('&"%s": %s' % (k, repr(round(float(v), 3))) for k, v in d.items()) + "})"


def ribu(n):
    return "{:,}".format(n).replace(",", ".")


def build(wid):
    path = os.path.join(ROOT, "data", "provinces", wid + ".tres")
    name, label, island, members = WILAYAH[wid]
    rng = random.Random("kloter-" + wid)
    kl = []
    for p in members:
        kl += kloters_for(p, rng)
    used = set()
    for k in kl:
        k["name"] = make_name(k["origin"], wid, used, rng)
    total = sum(PODES[p]["total"] for p in members)
    dark = sum(PODES[p]["bukan_pengguna"] for p in members)
    # Kecocokan wilayah (untuk petunjuk alam): rata-rata berbobot desa, dibulatkan ke 3 tingkat.
    comp = {}
    for e in E:
        avg = sum(k["compat"][e] * k["size"] for k in kl) / total
        comp[e] = 1.0 if avg >= 0.75 else (0.5 if avg >= 0.35 else 0.15)
    rates = {}
    for ev, cols in DISASTER_COLS.items():
        rates[ev] = round(100.0 * sum(PODES[p][c] for p in members for c in cols) / total, 1)
    spread_mod, resist_mod, note = GAMEPLAY.get(wid, (1.0, 0.0, ""))
    pos = LAYOUT.get(wid, [640, 360])
    off = LABEL_OFFSET.get(wid, (0, 0))
    region = "res://assets/map/regions/%s.png" % wid
    has_region = os.path.exists(os.path.join(ROOT, "assets", "map", "regions", wid + ".png"))

    lines = ['[gd_resource type="Resource" script_class="ProvinceData" format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://scripts/data/province_data.gd" id="p_script"]')
    lines.append('[ext_resource type="Resource" path="res://data/islands/%s.tres" id="p_island"]' % island)
    if has_region:
        lines.append('[ext_resource type="Texture2D" path="%s" id="p_region"]' % region)
    lines.append('[ext_resource type="Script" path="res://scripts/data/village_data.gd" id="v_script"]')
    lines.append("")
    for i, k in enumerate(kl):
        lines.append('[sub_resource type="Resource" id="k_%d"]' % i)
        lines.append('script = ExtResource("v_script")')
        lines.append("display_name = %s" % json.dumps(k["name"], ensure_ascii=False))
        lines.append("traits = Array[StringName]([%s])" % ", ".join('&"%s"' % t for t in k["traits"]))
        if not k["dark"]:
            lines.append("start_fossil = true")
        lines.append("size = %d" % k["size"])
        lines.append("origin = %s" % json.dumps(SHORT[k["origin"]], ensure_ascii=False))
        lines.append("compat = %s" % fmt_dict(k["compat"]))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("p_script")')
    lines.append('id = &"%s"' % wid)
    lines.append("display_name = %s" % json.dumps(name, ensure_ascii=False))
    lines.append("short_name = %s" % json.dumps(label, ensure_ascii=False))
    lines.append('island = ExtResource("p_island")')
    if has_region:
        lines.append('region_mask = ExtResource("p_region")')
    lines.append("map_position = Vector2(%d, %d)" % tuple(pos))
    if off != (0, 0):
        lines.append("label_offset = Vector2(%d, %d)" % tuple(off))
    lines.append("neighbors = Array[StringName]([%s])" % ", ".join('&"%s"' % n for n in neighbors_of(wid)))
    lines.append("villages = %d" % len(kl))
    lines.append("fossil_villages = %d" % sum(1 for k in kl if not k["dark"]))
    lines.append("village_list = Array[ExtResource(\"v_script\")]([%s])" % ", ".join('SubResource("k_%d")' % i for i in range(len(kl))))
    if resist_mod:
        lines.append("start_resistance_mod = %s" % repr(float(resist_mod)))
    if spread_mod != 1.0:
        lines.append("spread_mod = %s" % repr(float(spread_mod)))
    lines.append("compat_override = " + fmt_dict(comp))
    lines.append("disaster_rates = " + fmt_dict(rates))
    lines.append("member_provinces = PackedStringArray(%s)" % ", ".join(json.dumps(m, ensure_ascii=False) for m in members))
    lines.append("note = %s" % json.dumps(note, ensure_ascii=False))
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return name, kl, total, dark, comp, rates


def update_database():
    """Tulis ulang daftar wilayah di data/database.tres sesuai urutan WILAYAH."""
    path = os.path.join(ROOT, "data", "database.tres")
    s = open(path, encoding="utf-8").read()
    s = re.sub(r'^\[ext_resource type="Resource" path="res://data/provinces/[^"]+" id="[^"]+"\]\n', "", s, flags=re.M)
    new_ext = "".join('[ext_resource type="Resource" path="res://data/provinces/%s.tres" id="prov_%s"]\n' % (w, w)
                      for w in WILAYAH)
    s = s.replace("\n[resource]\n", "\n" + new_ext + "\n[resource]\n", 1)
    m = re.search(r'^provinces = Array\[ExtResource\("([^"]+)"\)\]\(\[.*?\]\)$', s, re.M)
    arr = "provinces = Array[ExtResource(\"%s\")]([%s])" % (m.group(1), ", ".join('ExtResource("prov_%s")' % w for w in WILAYAH))
    s = s[:m.start()] + arr + s[m.end():]
    s = re.sub(r"\n{3,}", "\n\n", s)
    open(path, "w", encoding="utf-8").write(s)


if __name__ == "__main__":
    grand = [0, 0, 0]
    for wid in WILAYAH:
        name, kl, total, dark, comp, rates = build(wid)
        grand[0] += len(kl)
        grand[1] += total
        grand[2] += dark
        cocok = [e for e in E if comp[e] == 1.0]
        sizes = [k["size"] for k in kl]
        print("%-8s %-40s kloter %3d (gelap %2d) desa %6d gelap %5d (%2d%%)  cocok: %s" % (
            wid, name, len(kl), sum(1 for k in kl if k["dark"]), total, dark, round(100 * dark / total), ", ".join(cocok)))
    update_database()
    # Hapus file wilayah lama yang tidak dipakai lagi.
    for fn in os.listdir(os.path.join(ROOT, "data", "provinces")):
        wid = fn.split(".")[0]
        if fn.endswith(".tres") and wid not in WILAYAH:
            os.remove(os.path.join(ROOT, "data", "provinces", fn))
            print("hapus", fn)
    print("TOTAL kloter %d, desa %d, gelap %d" % tuple(grand))
