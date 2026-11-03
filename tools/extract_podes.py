"""Ekstrak tabel Podes 2024 (BPS) per provinsi ke tools/podes_2024.json.
Pakai: python3 tools/extract_podes.py <path PDF Statistik Potensi Desa Indonesia 2024>
Butuh pdftotext (poppler)."""
import json, os, re, subprocess, sys

PROV = ["Aceh","Sumatera Utara","Sumatera Barat","Riau","Jambi","Sumatera Selatan","Bengkulu","Lampung",
 "Kepulauan Bangka Belitung","Kepulauan Riau","DKI Jakarta","Jawa Barat","Jawa Tengah","DI Yogyakarta","Jawa Timur",
 "Banten","Bali","Nusa Tenggara Barat","Nusa Tenggara Timur","Kalimantan Barat","Kalimantan Tengah",
 "Kalimantan Selatan","Kalimantan Timur","Kalimantan Utara","Sulawesi Utara","Sulawesi Tengah","Sulawesi Selatan",
 "Sulawesi Tenggara","Gorontalo","Sulawesi Barat","Maluku","Maluku Utara","Papua Barat","Papua Barat Daya","Papua",
 "Papua Selatan","Papua Tengah","Papua Pegunungan"]
# (halaman PDF, kolom yang diambil, jumlah angka per baris)
TABLES = {
 "topografi": (39, ["puncak","lereng","dataran","lembah","total"]),
 "hutan":     (40, ["dalam_hutan","tepi_hutan","luar_hutan","total","mangrove"]),
 "laut":      (41, ["pesisir","bukan_pesisir","total"]),
 "pertanian": (55, ["pangan","hortikultura","perkebunan","peternakan","perikanan","kehutanan","jasa","total_pertanian"]),
 "listrik":   (61, ["pln","non_pln","bukan_pengguna","pju_pln","pju_non_pln","pju_non_listrik"]),
 "sungai":    (69, ["sungai","irigasi","danau","embung","mata_air"]),
 "bencana1":  (190, ["longsor","banjir","banjir_bandang","gempa","tsunami","gelombang_pasang"]),
 "bencana2":  (191, ["puting_beliung","gunung_meletus","karhutla","kekeringan","abrasi","tanpa_bencana"]),
}
NUM = re.compile(r"^g?(\d{1,3}(?:\.\d{3})*|–|-)$")


def page_text(pdf, pg):
    return subprocess.run(["pdftotext", "-f", str(pg), "-l", str(pg), "-layout", pdf, "-"],
                          capture_output=True, text=True).stdout


def parse(text, ncols):
    lines = text.splitlines()
    out = {}
    names = sorted(PROV, key=len, reverse=True)
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        hit = next((p for p in names if line == p or line.startswith(p + " ")), None)
        if hit and hit not in out:
            nums = []
            rest = line[len(hit):].split()
            j = i
            while True:
                for tok in rest:
                    m = NUM.match(tok)
                    if m:
                        nums.append(0 if m.group(1) in "–-" else int(m.group(1).replace(".", "")))
                if len(nums) >= ncols or j - i > 12:
                    break
                j += 1
                if j >= len(lines):
                    break
                nxt = lines[j].strip()
                if any(nxt == p or nxt.startswith(p + " ") for p in names):
                    break
                rest = nxt.split()
            out[hit] = nums[:ncols]
        i += 1
    return out


if __name__ == "__main__":
    pdf = sys.argv[1]
    data = {p: {} for p in PROV}
    problems = []
    for key, (pg, cols) in TABLES.items():
        rows = parse(page_text(pdf, pg), len(cols))
        for p in PROV:
            r = rows.get(p, [])
            if len(r) != len(cols):
                problems.append((key, p, r))
            for c, v in zip(cols, r):
                data[p][c] = v
    for pr in problems:
        print("PERIKSA", pr)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "podes_2024.json")
    json.dump(data, open(out, "w"), indent=1, ensure_ascii=False)
    print("ok", out)
