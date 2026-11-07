## Dipakai lewat: const UiKit := preload("res://scripts/ui/ui_kit.gd")
## Kotak berwarna untuk elemen yang warnanya berubah-ubah (tombol kloter, node upgrade, toast, petunjuk).
## Gaya sama dengan kit pixel di assets/ui/kit: sudut terpotong 45 derajat, tanpa antialias, garis tegas.


static func box(bg: Color, border: Color, border_w: int = 2, cut: int = 4, margin: float = 6.0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(cut)
	st.corner_detail = 1  # radius + detail 1 = potongan lurus (chamfer)
	st.anti_aliasing = false
	st.set_content_margin_all(margin)
	return st
