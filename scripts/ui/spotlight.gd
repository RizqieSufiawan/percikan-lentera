class_name Spotlight
extends Control
## Lapisan tutorial: seluruh layar diredupkan kecuali satu kotak (hal yang harus diklik pemain),
## dengan bingkai berkedip di sekelilingnya. Tidak menangkap klik, jadi permainan tetap bisa dimainkan.

const DIM := Color(0.0, 0.0, 0.02, 0.5)
const PAD := 6.0

var hole := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_hole(rect: Rect2) -> void:
	visible = rect.size != Vector2.ZERO
	if not visible:
		return
	# Koordinat global -> lokal lapisan ini.
	var local := Rect2(rect.position - global_position, rect.size).grow(PAD)
	if not local.is_equal_approx(hole):
		hole = local
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	var h := hole.intersection(full)
	draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)
	var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 220.0)
	draw_rect(h, Color(Palette.LIT, a), false, 3.0)
