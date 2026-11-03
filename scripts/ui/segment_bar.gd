class_name SegmentBar
extends Control
## Bar utama: mandiri (hijau) | rapuh (kuning) | fosil (coklat) | gelap (abu) + garis ambang menang.

var independent: int = 0
var lit: int = 0
var fossil: int = 0
var dark: int = 1
var marker: float = 0.85


func set_values(p_independent: int, p_lit: int, p_fossil: int, p_dark: int, p_marker: float) -> void:
	independent = p_independent
	lit = p_lit
	fossil = p_fossil
	dark = p_dark
	marker = p_marker
	queue_redraw()


func _draw() -> void:
	var total: float = max(1, independent + lit + fossil + dark)
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Palette.DARK)
	var x := 0.0
	for seg in [[independent, Palette.INDEPENDENT], [lit, Palette.LIT], [fossil, Palette.FOSSIL]]:
		var sw: float = w * seg[0] / total
		draw_rect(Rect2(x, 0, sw, h), seg[1])
		x += sw
	var mx := w * marker
	draw_line(Vector2(mx, -3), Vector2(mx, h + 3), Palette.CREAM, 2.0)
	draw_rect(Rect2(0, 0, w, h), Palette.CREAM * Color(1, 1, 1, 0.5), false, 1.0)
