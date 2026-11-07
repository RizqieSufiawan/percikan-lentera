"""Kit UI pixel "Percikan Lentera": panel, tombol, tab, bar, scrollbar, kolom isian, toggle, slider.

Digambar di grid seni lalu diperbesar 2x (1 piksel seni = 2 piksel layar), dari palet game
(scripts/ui/palette.gd): malam navy, bingkai indigo, aksen emas lentera, teks krem.
Hasil: assets/ui/kit/*.png, dipakai sebagai StyleBoxTexture di assets/ui/main_theme.tres
(texture_margin = ukuran sudut dalam piksel layar).

Pakai:  python3 tools/make_ui_kit.py           (tulis PNG)
        python3 tools/make_ui_kit.py --sheet   (juga lembar pratinjau di scratch)
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "kit")
S = 2  # piksel layar per piksel seni

# Palet (sesuai Palette.gd + turunan gelap/terang).
T = (0, 0, 0, 0)
OUTL = (8, 10, 26, 255)          # garis luar
BG = (20, 24, 56, 236)           # isi panel (sedikit tembus)
BG_HI = (34, 40, 84, 236)        # sorot dalam kiri-atas
BG_LO = (14, 17, 40, 236)        # bayangan dalam kanan-bawah
FRAME = (78, 86, 150, 255)       # bingkai indigo
FRAME_HI = (112, 120, 190, 255)
FRAME_LO = (52, 58, 108, 255)
GOLD = (255, 196, 64, 255)       # Palette.LIT
GOLD_HI = (255, 230, 150, 255)
GOLD_LO = (196, 132, 40, 255)
GOLD_DK = (128, 80, 28, 255)
CREAM = (245, 235, 209, 255)
BTN = (42, 48, 100, 255)
BTN_HI = (66, 74, 140, 255)
BTN_LO = (28, 32, 70, 255)
BTN_H = (58, 66, 132, 255)
BTN_H_HI = (88, 98, 170, 255)
BTN_H_LO = (38, 44, 92, 255)
DIS = (32, 34, 52, 255)
DIS_HI = (44, 46, 66, 255)
DIS_LO = (24, 25, 40, 255)
DIS_OUT = (18, 19, 30, 255)
SLOT = (12, 14, 32, 255)
SLOT_HI = (30, 34, 66, 255)


def canvas(w, h):
    return Image.new("RGBA", (w, h), T)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def chamfer_box(im, x0, y0, x1, y1, out, fill, hi=None, lo=None, cut=1):
    """Kotak bersudut terpotong `cut` piksel: garis luar, isi, sorot atas-kiri, bayangan bawah-kanan."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = min(x - x0, x1 - x)
            dy = min(y - y0, y1 - y)
            if dx + dy < cut:
                continue  # sudut terpotong
            edge = dx == 0 or dy == 0 or dx + dy == cut
            px(im, x, y, out if edge else fill)
    if hi:
        for x in range(x0 + cut + 1, x1 - cut):
            px(im, x, y0 + 1, hi)
        for y in range(y0 + cut + 1, y1 - cut):
            px(im, x0 + 1, y, hi)
    if lo:
        for x in range(x0 + cut + 1, x1 - cut):
            px(im, x, y1 - 1, lo)
        for y in range(y0 + cut + 1, y1 - cut):
            px(im, x1 - 1, y, lo)


def save(im, name):
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    big.save(os.path.join(OUT, name + ".png"))
    return big


# ---------------------------------------------------------------- panel

def spark(im, cx, cy):
    """Ornamen sudut: percikan lentera (belah ketupat emas 5 px dengan inti terang)."""
    for dx, dy, c in [(0, -2, GOLD_LO), (-2, 0, GOLD_LO), (2, 0, GOLD_LO), (0, 2, GOLD_LO),
                      (0, -1, GOLD), (-1, 0, GOLD), (1, 0, GOLD), (0, 1, GOLD), (0, 0, GOLD_HI)]:
        px(im, cx + dx, cy + dy, c)


def panel(ornament=True):
    n = 24
    im = canvas(n, n)
    # Garis luar gelap, lalu bingkai indigo 1 px, lalu isi dengan sorot dalam.
    chamfer_box(im, 0, 0, n - 1, n - 1, OUTL, FRAME, cut=2)
    chamfer_box(im, 1, 1, n - 2, n - 2, FRAME, BG, BG_HI, BG_LO, cut=2)
    # Bingkai: sisi atas-kiri sedikit lebih terang, bawah-kanan lebih gelap.
    for i in range(3, n - 3):
        px(im, i, 1, FRAME_HI)
        px(im, 1, i, FRAME_HI)
        px(im, i, n - 2, FRAME_LO)
        px(im, n - 2, i, FRAME_LO)
    if ornament:
        for cx, cy in [(2, 2), (n - 3, 2), (2, n - 3), (n - 3, n - 3)]:
            spark(im, cx, cy)
    return im


def tooltip():
    n = 12
    im = canvas(n, n)
    chamfer_box(im, 0, 0, n - 1, n - 1, OUTL, FRAME, cut=1)
    rect(im, 2, 2, n - 3, n - 3, (14, 17, 40, 248))
    for i in range(2, n - 2):
        px(im, i, 1, FRAME_HI)
    return im


# ---------------------------------------------------------------- tombol

def button(face, hi, lo, out, depth=2, pressed=False):
    """Tombol 16x16 seni: tebal 2 px di bawah (kesan timbul). Ditekan = tanpa ketebalan, turun 1 px."""
    w, h = 16, 16
    im = canvas(w, h)
    top = 1 if pressed else 0
    d = 0 if pressed else depth
    # Bagian bawah (sisi timbul) digambar dulu.
    if d:
        chamfer_box(im, 0, top, w - 1, h - 1, out, lo, cut=2)
    chamfer_box(im, 0, top, w - 1, h - 1 - d, out, face, hi, None, cut=2)
    # Kilau kecil di kiri-atas.
    px(im, 3, top + 2, hi)
    return im


# ---------------------------------------------------------------- tab

def tab(face, hi, out, top_line=None):
    w, h = 12, 12
    im = canvas(w, h)
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x)
            if y + dx < 2:
                continue
            edge = dx == 0 or y == 0 or y + dx == 2
            px(im, x, y, out if edge else face)
    for x in range(2, w - 2):
        px(im, x, 1, hi)
    if top_line:
        for x in range(2, w - 2):
            px(im, x, 1, top_line)
    return im


# ---------------------------------------------------------------- bar, slot, scrollbar

def bar_bg():
    im = canvas(6, 6)
    rect(im, 0, 0, 5, 5, OUTL)
    rect(im, 1, 1, 4, 4, SLOT)
    for x in range(1, 5):
        px(im, x, 1, (6, 8, 20, 255))  # bayangan dalam di atas (cekung)
    return im


def bar_fill(c, hi, lo):
    im = canvas(6, 6)
    rect(im, 0, 0, 5, 5, c)
    for x in range(6):
        px(im, x, 0, hi)
        px(im, x, 5, lo)
    return im


def scroll_track():
    im = canvas(4, 8)
    rect(im, 0, 0, 3, 7, (10, 12, 28, 160))
    return im


def scroll_grab(face, hi, lo):
    im = canvas(4, 8)
    chamfer_box(im, 0, 0, 3, 7, OUTL, face, cut=1)
    for y in range(2, 6):
        px(im, 1, y, hi)
        px(im, 2, y, lo)
    return im


def scroll_grab_h(face, hi, lo):
    return scroll_grab(face, hi, lo).transpose(Image.Transpose.TRANSPOSE)


def field(focus=False):
    """Kolom isian (LineEdit): cekung, bingkai emas saat aktif."""
    n = 12
    im = canvas(n, n)
    chamfer_box(im, 0, 0, n - 1, n - 1, GOLD if focus else FRAME_LO, SLOT, cut=1)
    for x in range(1, n - 1):
        px(im, x, 1, (6, 8, 20, 255))
    return im


# ---------------------------------------------------------------- ikon: toggle, slider, panah

def toggle(on):
    w, h = 16, 9
    im = canvas(w, h)
    chamfer_box(im, 0, 0, w - 1, h - 1, OUTL, (24, 70, 44, 255) if on else SLOT, cut=2)
    kx = w - 8 if on else 1
    chamfer_box(im, kx, 1, kx + 6, h - 2, OUTL, GOLD if on else FRAME, cut=1)
    px(im, kx + 2, 2, GOLD_HI if on else FRAME_HI)
    return im


def slider_grab(hl=False):
    im = canvas(7, 9)
    chamfer_box(im, 0, 0, 6, 8, OUTL, GOLD_HI if hl else GOLD, cut=1)
    for y in range(2, 7):
        px(im, 3, y, GOLD_LO)
    return im


def arrow_down():
    im = canvas(7, 5)
    for i, row in enumerate([(0, 6), (1, 5), (2, 4), (3, 3)]):
        for x in range(row[0], row[1] + 1):
            px(im, x, i, CREAM)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    out = {}
    out["panel"] = save(panel(), "panel")
    out["panel_plain"] = save(panel(False), "panel_plain")
    out["tooltip"] = save(tooltip(), "tooltip")
    out["btn_normal"] = save(button(BTN, BTN_HI, BTN_LO, OUTL), "btn_normal")
    out["btn_hover"] = save(button(BTN_H, BTN_H_HI, BTN_H_LO, GOLD_LO), "btn_hover")
    out["btn_pressed"] = save(button(GOLD_LO, GOLD, GOLD_DK, GOLD_DK, pressed=True), "btn_pressed")
    out["btn_active"] = save(button(GOLD_LO, GOLD, GOLD_DK, GOLD_DK), "btn_active")
    out["btn_disabled"] = save(button(DIS, DIS_HI, DIS_LO, DIS_OUT), "btn_disabled")
    out["tab_sel"] = save(tab(BG[:3] + (255,), BG_HI[:3] + (255,), FRAME, GOLD), "tab_selected")
    out["tab_unsel"] = save(tab((14, 16, 36, 255), (24, 28, 56, 255), OUTL), "tab_unselected")
    out["tab_hover"] = save(tab((30, 34, 72, 255), (46, 52, 100, 255), FRAME_LO), "tab_hovered")
    out["bar_bg"] = save(bar_bg(), "bar_bg")
    out["bar_fill"] = save(bar_fill(GOLD, GOLD_HI, GOLD_LO), "bar_fill")
    out["scroll_track"] = save(scroll_track(), "scroll_track")
    out["scroll_grab"] = save(scroll_grab(FRAME, FRAME_HI, FRAME_LO), "scroll_grab")
    out["scroll_grab_hl"] = save(scroll_grab(GOLD_LO, GOLD, GOLD_DK), "scroll_grab_hl")
    out["hscroll_grab"] = save(scroll_grab_h(FRAME, FRAME_HI, FRAME_LO), "hscroll_grab")
    out["hscroll_grab_hl"] = save(scroll_grab_h(GOLD_LO, GOLD, GOLD_DK), "hscroll_grab_hl")
    out["hscroll_track"] = save(scroll_track().transpose(Image.Transpose.TRANSPOSE), "hscroll_track")
    out["field"] = save(field(), "field")
    out["field_focus"] = save(field(True), "field_focus")
    out["toggle_on"] = save(toggle(True), "toggle_on")
    out["toggle_off"] = save(toggle(False), "toggle_off")
    out["slider_grab"] = save(slider_grab(), "slider_grab")
    out["slider_grab_hl"] = save(slider_grab(True), "slider_grab_hl")
    out["arrow_down"] = save(arrow_down(), "arrow_down")
    print("kit: %d gambar di %s" % (len(out), OUT))
    if "--sheet" in sys.argv:
        sheet(out)


def sheet(out):
    """Lembar pratinjau: semua potongan diperbesar 2x lagi di atas latar malam."""
    pad = 12
    items = list(out.items())
    W = 900
    x = y = pad
    row_h = 0
    pos = []
    for k, im in items:
        if x + im.width * 2 > W - pad:
            x = pad
            y += row_h + pad
            row_h = 0
        pos.append((k, im, x, y))
        x += im.width * 2 + pad
        row_h = max(row_h, im.height * 2)
    sh = Image.new("RGBA", (W, y + row_h + pad), (22, 26, 58, 255))
    for k, im, x, y in pos:
        sh.alpha_composite(im.resize((im.width * 2, im.height * 2), Image.NEAREST), (x, y))
    p = "/home/claude/scratch/ui_kit_sheet.png"
    sh.save(p)
    print("pratinjau:", p)


if __name__ == "__main__":
    main()
