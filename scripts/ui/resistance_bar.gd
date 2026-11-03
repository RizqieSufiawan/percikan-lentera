class_name ResistanceBar
extends Control
## Satu bar, dua warna: biru (keraguan warga) + merah (Kepentingan Lama). Penuh = kalah.

var blue: float = 0.0
var red: float = 0.0


func set_values(p_blue: float, p_red: float) -> void:
	blue = p_blue
	red = p_red
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.15, 0.22))
	var bw := w * clampf(blue, 0, 100) / 100.0
	draw_rect(Rect2(0, 0, bw, h), Palette.BLUE)
	var rw := w * clampf(red, 0, 100 - blue) / 100.0
	draw_rect(Rect2(bw, 0, rw, h), Palette.RED)
	draw_rect(Rect2(0, 0, w, h), Palette.CREAM * Color(1, 1, 1, 0.4), false, 1.0)
