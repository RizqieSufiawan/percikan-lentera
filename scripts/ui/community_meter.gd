class_name CommunityMeter
extends Control
## Bar Komunitas mini di bawah label wilayah. Merah di bawah 20 (warga belum membangun sendiri),
## kuning 20-45, hijau 45+ (desa bisa Mandiri). Dua garis putih = ambang 20 dan 45.

var value := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	if not is_equal_approx(v, value):
		value = v
		queue_redraw()


func _draw() -> void:
	var cfg := Game.db.config
	var w := size.x
	var h := size.y
	draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(0.04, 0.05, 0.1, 0.9))
	var col := Color(0.86, 0.33, 0.28)
	if value >= cfg.independence_threshold:
		col = Palette.INDEPENDENT
	elif value >= cfg.auto_build_min_community:
		col = Palette.LIT
	draw_rect(Rect2(0, 0, w * clampf(value / 100.0, 0.0, 1.0), h), col)
	for t in [cfg.auto_build_min_community, cfg.independence_threshold]:
		var x := roundf(w * t / 100.0)
		draw_line(Vector2(x, -1), Vector2(x, h + 1), Color(1, 1, 1, 0.85), 1.0)
