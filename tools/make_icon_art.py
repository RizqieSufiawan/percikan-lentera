"""Ikon & latar judul SEMENTARA bergaya pixel art (pengganti kotak huruf placeholder).

Ikon digambar di kisi kecil (16 px untuk ikon 32, 12 px untuk ikon 24) lalu diperbesar 2x tanpa
penghalusan. Nama file sama dengan placeholder, jadi artis cukup menimpa file PNG-nya nanti.

    python3 tools/make_icon_art.py [--sheet x.png]
"""
import argparse
import glob
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import make_card_art as mca  # noqa: E402

ENERGY_COL = {"plts": (255, 204, 56), "mikrohidro": (40, 220, 205), "biomassa": (168, 214, 74),
              "angin": (204, 240, 250), "panas_bumi": (255, 128, 72)}
CAT_COL = [(255, 204, 56), (98, 196, 110), (240, 186, 64), (90, 150, 230), (170, 120, 220)]
INK = (24, 22, 40)
LIGHT = (246, 240, 222)


def dark(c, f=0.55):
    return tuple(int(v * f) for v in c)


class Icon:
    def __init__(self, g=16):
        self.g = g
        self.im = Image.new("RGBA", (g, g), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def u(self, v):  # koordinat kisi 16 -> kisi sebenarnya
        return round(v * self.g / 16)

    def R(self, x0, y0, x1, y1, c):
        self.d.rectangle([self.u(x0), self.u(y0), self.u(x1), self.u(y1)], fill=c)

    def E(self, x0, y0, x1, y1, c, outline=None):
        self.d.ellipse([self.u(x0), self.u(y0), self.u(x1), self.u(y1)], fill=c, outline=outline)

    def P(self, pts, c):
        self.d.polygon([(self.u(x), self.u(y)) for x, y in pts], fill=c)

    def L(self, pts, c, w=1):
        self.d.line([(self.u(x), self.u(y)) for x, y in pts], fill=c, width=max(1, self.u(w)))

    def badge(self, col, round_=False):
        if round_:
            self.E(0, 0, 15, 15, dark(col), None)
            self.E(1, 1, 14, 14, col)
        else:
            self.R(0, 0, 15, 15, dark(col))
            self.R(1, 1, 14, 14, col)
            self.R(1, 1, 14, 2, tuple(min(255, v + 30) for v in col))

    def out(self, size):
        return self.im.resize((size, size), Image.NEAREST)


# ---------------------------------------------------------------- simbol (koordinat kisi 16)

def sym_sun(i, c=INK):
    i.E(4, 4, 11, 11, c)
    for a, b, x, y in ((7, 1, 8, 2), (7, 13, 8, 14), (1, 7, 2, 8), (13, 7, 14, 8)):
        i.R(a, b, x, y, c)


def sym_panel(i, c=INK):
    i.P([(2, 13), (11, 13), (14, 7), (5, 7)], c)
    i.L([(6, 13), (9, 7)], LIGHT)
    i.L([(3, 10), (12, 10)], LIGHT)


def sym_drop(i, c=INK):
    i.P([(8, 2), (12, 9), (4, 9)], c)
    i.E(4, 6, 12, 14, c)
    i.R(6, 9, 7, 11, LIGHT)


def sym_leaf(i, c=INK):
    i.P([(3, 13), (4, 6), (9, 3), (13, 3), (12, 8), (8, 12)], c)
    i.L([(4, 12), (11, 5)], LIGHT)


def sym_flame(i, c=INK):
    i.P([(8, 2), (12, 8), (11, 13), (5, 13), (4, 8)], c)
    i.P([(8, 7), (10, 11), (6, 11)], LIGHT)


def sym_turbine(i, c=INK):
    i.L([(8, 6), (8, 14)], c, 1)
    i.L([(8, 6), (8, 1)], c)
    i.L([(8, 6), (13, 9)], c)
    i.L([(8, 6), (3, 9)], c)
    i.R(7, 5, 9, 7, c)


def sym_volcano(i, c=INK):
    i.P([(1, 14), (6, 6), (10, 6), (15, 14)], c)
    i.R(6, 2, 7, 4, c)
    i.R(9, 1, 10, 3, c)


def sym_bolt(i, c=INK):
    i.P([(9, 1), (4, 9), (8, 9), (6, 15), (12, 6), (8, 6)], c)


def sym_brick(i, c=INK):
    for y, off in ((3, 0), (7, 3), (11, 0)):
        for x in range(1 + off, 14, 6):
            i.R(x, y, min(x + 4, 14), y + 2, c)


def sym_wrench(i, c=INK):
    i.L([(4, 12), (10, 6)], c, 2)
    i.E(9, 2, 14, 7, c)
    i.R(11, 3, 12, 5, LIGHT)


def sym_school(i, c=INK):
    i.P([(2, 7), (8, 2), (14, 7)], c)
    i.R(3, 7, 13, 13, c)
    i.R(7, 9, 9, 13, LIGHT)


def sym_book(i, c=INK):
    i.R(2, 3, 7, 13, c)
    i.R(9, 3, 14, 13, c)
    i.L([(3, 6), (6, 6)], LIGHT)
    i.L([(10, 6), (13, 6)], LIGHT)


def sym_people(i, c=INK):
    i.E(2, 3, 6, 7, c)
    i.E(10, 3, 14, 7, c)
    i.R(1, 8, 7, 13, c)
    i.R(9, 8, 15, 13, c)


def sym_person(i, c=INK):
    i.E(5, 2, 10, 7, c)
    i.R(4, 8, 11, 14, c)


def sym_speech(i, c=INK):
    i.R(1, 2, 10, 8, c)
    i.P([(3, 8), (5, 8), (3, 11)], c)
    i.R(6, 7, 15, 12, dark(c, 0.0) if c == INK else c)
    i.R(7, 8, 14, 11, LIGHT)
    i.P([(12, 12), (14, 12), (14, 14)], LIGHT)


def sym_megaphone(i, c=INK):
    i.P([(2, 6), (6, 6), (13, 2), (13, 14), (6, 10), (2, 10)], c)
    i.R(4, 10, 6, 14, c)


def sym_coin(i, c=INK):
    i.E(2, 2, 14, 14, c)
    i.R(7, 4, 8, 12, LIGHT)
    i.R(5, 5, 10, 6, LIGHT)
    i.R(5, 10, 10, 11, LIGHT)


def sym_shop(i, c=INK):
    i.R(2, 4, 14, 7, c)
    for x in (2, 6, 10):
        i.R(x, 5, x + 1, 6, LIGHT)
    i.R(3, 7, 13, 13, c)
    i.R(5, 9, 8, 13, LIGHT)


def sym_helmet(i, c=INK):
    i.E(3, 4, 13, 14, c)
    i.R(1, 10, 15, 11, c)
    i.R(7, 4, 9, 9, LIGHT)


def sym_wifi(i, c=INK):
    i.d.arc([i.u(1), i.u(3), i.u(15), i.u(17)], 210, 330, fill=c, width=max(1, i.u(1.5)))
    i.d.arc([i.u(4), i.u(6), i.u(12), i.u(14)], 210, 330, fill=c, width=max(1, i.u(1.5)))
    i.R(7, 11, 9, 13, c)


def sym_cross(i, c=INK):
    i.R(6, 2, 10, 14, c)
    i.R(2, 6, 14, 10, c)


def sym_radar(i, c=INK):
    i.E(2, 2, 14, 14, None, c)
    i.E(5, 5, 11, 11, None, c)
    i.L([(8, 8), (13, 4)], c)
    i.R(7, 7, 8, 8, c)


def sym_pin(i, c=INK):
    i.E(4, 2, 12, 10, c)
    i.P([(5, 8), (11, 8), (8, 14)], c)
    i.R(7, 5, 8, 6, LIGHT)


def sym_shield(i, c=INK):
    i.P([(3, 2), (13, 2), (13, 8), (8, 14), (3, 8)], c)
    i.R(7, 4, 8, 10, LIGHT)


def sym_box(i, c=INK):
    i.R(2, 5, 14, 14, c)
    i.R(2, 3, 14, 5, dark(c, 0.0) if c == INK else c)
    i.R(7, 5, 8, 9, LIGHT)


def sym_boat(i, c=INK):
    i.P([(1, 10), (15, 10), (12, 14), (4, 14)], c)
    i.R(7, 2, 8, 10, c)
    i.P([(8, 3), (13, 9), (8, 9)], c)


def sym_plane(i, c=INK):
    i.P([(1, 9), (14, 6), (15, 7), (3, 11)], c)
    i.P([(6, 8), (9, 2), (11, 2), (9, 8)], c)
    i.P([(5, 10), (8, 14), (9, 14), (8, 10)], c)


def sym_road(i, c=INK):
    i.P([(6, 1), (10, 1), (15, 15), (1, 15)], c)
    for y in (3, 7, 11):
        i.R(7, y, 8, y + 2, LIGHT)


def sym_islands(i, c=INK):
    i.E(1, 9, 8, 14, c)
    i.E(9, 4, 15, 9, c)
    i.L([(6, 9), (11, 7)], c)


def sym_sprout(i, c=INK):
    i.R(7, 7, 8, 14, c)
    i.E(2, 3, 8, 8, c)
    i.E(8, 2, 14, 7, c)
    i.R(3, 13, 12, 14, c)


def sym_star(i, c=INK):
    i.P([(8, 1), (10, 6), (15, 6), (11, 9), (13, 15), (8, 11), (3, 15), (5, 9), (1, 6), (6, 6)], c)


def sym_heart(i, c=INK):
    i.E(1, 3, 8, 10, c)
    i.E(8, 3, 15, 10, c)
    i.P([(2, 8), (14, 8), (8, 15)], c)


def sym_split(i, c=INK):
    i.d.pieslice([i.u(1), i.u(1), i.u(15), i.u(15)], 90, 270, fill=(70, 120, 230))
    i.d.pieslice([i.u(1), i.u(1), i.u(15), i.u(15)], 270, 90, fill=(210, 62, 52))
    i.R(7, 4, 8, 11, LIGHT)


def sym_banknote(i, c=INK):
    i.R(1, 4, 15, 12, c)
    i.E(5, 5, 11, 11, LIGHT)
    i.R(7, 6, 8, 10, c)


def sym_tri(i, c=INK):
    i.P([(8, 1), (15, 14), (1, 14)], c)
    i.R(7, 5, 8, 10, LIGHT)
    i.R(7, 11, 8, 12, LIGHT)


def sym_building(i, c=INK):
    i.P([(1, 6), (8, 1), (15, 6)], c)
    for x in (2, 6, 10):
        i.R(x, 7, x + 2, 13, c)
    i.R(1, 13, 15, 14, c)


def sym_factory(i, c=INK):
    i.R(1, 7, 15, 14, c)
    i.R(11, 2, 13, 7, c)
    i.P([(1, 7), (5, 4), (5, 7)], c)
    i.P([(5, 7), (9, 4), (9, 7)], c)


def sym_arrow_up(i, c=INK):
    i.P([(8, 1), (14, 8), (10, 8), (10, 14), (6, 14), (6, 8), (2, 8)], c)


def sym_burst(i, c=INK):
    sym_star(i, c)


def sym_lantern(i, c=INK):
    i.R(6, 1, 9, 2, c)
    i.R(4, 3, 11, 4, c)
    i.R(4, 12, 11, 13, c)
    i.R(5, 5, 10, 11, (255, 220, 110))
    i.R(7, 7, 8, 9, (255, 250, 210))


# ciri desa
def sym_fog_trees(i, c=INK):
    for x in (2, 7, 11):
        i.P([(x, 11), (x + 2, 3), (x + 4, 11)], c)
    i.R(1, 8, 15, 9, LIGHT)
    i.R(1, 12, 15, 13, LIGHT)


def sym_valley(i, c=INK):
    i.P([(0, 14), (0, 3), (7, 12), (9, 12), (15, 3), (15, 14)], c)


def sym_husk(i, c=INK):
    i.R(7, 6, 8, 14, c)
    for a, b in ((2, 6), (13, 6), (4, 2), (11, 2)):
        i.L([(8, 6), (a, b)], c)
    i.E(3, 11, 7, 14, c)
    i.E(9, 11, 13, 14, c)


def sym_wave_wind(i, c=INK):
    i.L([(1, 4), (10, 4), (12, 2)], c)
    i.L([(1, 7), (13, 7), (15, 5)], c)
    i.P([(0, 15), (0, 11), (4, 9), (8, 11), (12, 9), (15, 11), (15, 15)], c)


def sym_cow(i, c=INK):
    i.E(3, 4, 13, 14, c)
    i.R(1, 3, 4, 5, c)
    i.R(12, 3, 15, 5, c)
    i.R(5, 8, 6, 9, LIGHT)
    i.R(10, 8, 11, 9, LIGHT)
    i.E(5, 10, 11, 13, LIGHT)


def sym_river(i, c=INK):
    for y in (3, 7, 11):
        i.L([(1, y + 2), (4, y), (8, y + 2), (12, y), (15, y + 2)], c, 1)


def sym_cracked(i, c=INK):
    i.E(9, 1, 14, 6, c)
    i.R(1, 9, 15, 14, c)
    i.L([(3, 9), (5, 12), (4, 14)], LIGHT)
    i.L([(10, 9), (9, 11), (12, 14)], LIGHT)


# ---------------------------------------------------------------- pemetaan

UPGRADE_SYM = {
    "output": sym_bolt, "material": sym_brick, "teknisi": sym_wrench, "pusat": sym_school,
    "asuransi_pembangkit": sym_shield, "bahasa_daerah": sym_speech, "dana_bergulir": sym_coin,
    "desa_belajar": sym_book, "duta_pelajar": sym_person, "ekspor_desa": sym_boat, "forum_musyawarah": sym_speech,
    "forum_nasional": sym_building, "gudang_cadang": sym_box, "hub_bandara": sym_plane, "internet_desa": sym_wifi,
    "investasi_hijau": sym_coin, "iuran_digital": sym_banknote, "jalur_antar_desa": sym_road,
    "jaringan_pulau": sym_islands, "kader_desa": sym_people, "kapal_perintis": sym_boat, "kelas_daring": sym_book,
    "klarifikasi": sym_megaphone, "koperasi_energi": sym_people, "latih_teknisi": sym_helmet,
    "pantau_jarak_jauh": sym_radar, "pasar_daring": sym_shop, "pekerjaan_hijau": sym_helmet,
    "pemuda_penggerak": sym_person, "perempuan_energi": sym_person, "peta_risiko": sym_pin, "posko_24jam": sym_cross,
    "rute_udara": sym_plane, "sekolah_daring": sym_wifi, "sekolah_lapang": sym_sprout, "sensor": sym_radar,
    "tarif_desa": sym_banknote, "telemedicine": sym_heart, "tokoh_adat": sym_speech, "umkm": sym_shop,
}
ENERGY_SYM = {"plts": sym_panel, "mikrohidro": sym_drop, "biomassa": sym_leaf, "angin": sym_turbine,
              "panas_bumi": sym_volcano}


def upgrade_icon(uid):
    i = Icon(16)
    m = re.match(r"(plts|mikrohidro|biomassa|angin|panas_bumi)_(output|material|teknisi|pusat)(\d?)", uid)
    if m:
        col = ENERGY_COL[m.group(1)]
        i.badge(col)
        UPGRADE_SYM[m.group(2)](i)
        tier = int(m.group(3) or 0)
        for k in range(tier):
            i.R(12 - k * 3, 12, 13 - k * 3, 13, LIGHT)
        return i
    cat = 0
    path = os.path.join(ROOT, "data", "upgrades", uid + ".tres")
    if os.path.exists(path):
        mm = re.search(r"^category = (\d)", open(path, encoding="utf-8").read(), re.M)
        cat = int(mm.group(1)) if mm else 0
    i.badge(CAT_COL[cat])
    UPGRADE_SYM.get(uid, sym_star)(i)
    return i


def simple(sym, col, g=16, round_=True):
    i = Icon(g)
    i.badge(col, round_)
    sym(i)
    return i


def title_background():
    mca.W, mca.H = 320, 180
    c = mca.Card(seed=7)
    c.sky("night0", "night2", 120)
    c.stars(90, 100)
    c.disc(262, 34, 9, "moon")
    c.mountains(118, 40, "mount0", step=22, seed=4)
    c.mountains(126, 22, "mount1", step=18, seed=9)
    c.ground(124)
    c.rect(0, 150, 320, 180, "sea0")
    c.sea(152)
    for k, x in enumerate((8, 30, 54, 236, 260, 286)):
        c.house(x, 138 + (k % 2), lit=True)
    c.panel(80, 146)
    c.panel(214, 146)
    c.turbine(300, 132, h=34, t=0.4)
    c.turbine(16, 128, h=30, t=1.2)
    c.crowd(110, 146, 6, arm_up=True)
    c.crowd(180, 146, 6, arm_up=True)
    # Lentera melayang (percikan cahaya) di langit.
    rr = c.r
    for _ in range(26):
        x, y = rr.randrange(20, 300), rr.randrange(30, 110)
        c.rect(x, y, x + 1, y + 2, "lamp")
        c.px(x, y - 1, "lamp2")
    mca.W, mca.H = 160, 90
    return c.im.resize((640, 360), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet")
    a = ap.parse_args()
    made = []

    def save(rel, im):
        im.save(os.path.join(ROOT, rel))
        made.append(im)

    for f in sorted(glob.glob(os.path.join(ROOT, "assets", "icons", "upgrades", "*.png"))):
        uid = os.path.basename(f)[:-4]
        save(os.path.relpath(f, ROOT), upgrade_icon(uid).out(32))
    for e, sym in ENERGY_SYM.items():
        save("assets/icons/energy/%s.png" % e, simple(sym, ENERGY_COL[e], round_=False).out(32))
    stats = {"points": (sym_star, (255, 204, 56)), "money": (sym_banknote, (220, 196, 120)),
             "welfare": (sym_heart, (98, 196, 110)), "community": (sym_people, (90, 150, 230)),
             "resistance": (sym_split, (60, 60, 80))}
    for k, (sym, col) in stats.items():
        save("assets/icons/stats/%s.png" % k, simple(sym, col).out(32))
    traits = {"gunung_api": sym_volcano, "hutan_berkabut": sym_fog_trees, "lahan_terik": sym_cracked,
              "lembah_tertutup": sym_valley, "limbah_perkebunan": sym_husk, "pesisir_berangin": sym_wave_wind,
              "peternakan": sym_cow, "sungai_deras": sym_river}
    for k, sym in traits.items():
        save("assets/icons/traits/%s.png" % k, simple(sym, (150, 190, 230), g=12).out(24))
    news = {"government": (sym_building, (170, 120, 220)), "impact": (sym_burst, (98, 196, 110)),
            "opposition": (sym_factory, (210, 62, 52)), "progress": (sym_arrow_up, (255, 204, 56)),
            "warning": (sym_tri, (240, 150, 50))}
    for k, (sym, col) in news.items():
        save("assets/icons/news/%s.png" % k, simple(sym, col, g=12).out(24))
    actions = {"build": sym_wrench, "dialog": sym_speech, "internet": sym_wifi, "train": sym_book}
    for k, sym in actions.items():
        save("assets/icons/actions/%s.png" % k, simple(sym, (240, 186, 64)).out(32))
    # Gelembung poin di peta: lentera (biasa), ide warga (Komunitas), bintang emas (langka).
    for name, sym, col in (("lentera", sym_lantern, (255, 214, 92)), ("ide", sym_people, (120, 220, 200)),
                           ("emas", sym_star, (255, 236, 120))):
        b = Icon(16)
        b.E(0, 0, 15, 15, dark(col, 0.45))
        b.E(1, 1, 14, 14, col)
        b.E(3, 2, 6, 4, (255, 255, 240))
        sym(b, INK if name != "lentera" else (60, 40, 30))
        save("assets/map/bubble_%s.png" % name, b.out(32))
    app = Icon(16)
    app.badge((40, 46, 96))
    sym_lantern(app)
    save("assets/ui/app_icon.png", app.out(64))
    # Latar layar judul sekarang dibuat oleh tools/make_title_bg.py (berlapis untuk paralaks).
    if a.sheet:
        cols = 16
        rows = (len(made) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 72, rows * 72 + 370), (30, 32, 52, 255))
        for k, im in enumerate(made):
            big = im.resize((64, 64), Image.NEAREST)
            sheet.paste(big, ((k % cols) * 72 + 4, (k // cols) * 72 + 4), big)
        sheet.paste(tb, (0, rows * 72 + 8))
        sheet.save(a.sheet)
    print("ok: %d ikon + latar judul" % len(made))


if __name__ == "__main__":
    main()
