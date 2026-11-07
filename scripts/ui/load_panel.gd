class_name LoadPanel
extends Control
## Daftar slot simpanan: Muat / Hapus. Mode simpan (save_mode) dipakai dari menu jeda.

signal closed
signal loaded

var save_mode := false
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Simpan Permainan" if save_mode else "Muat Permainan"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	var close := Button.new()
	close.text = "Tutup"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close)
	box.add_child(close)
	_fill()


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for slot in Game.SLOTS:
		if save_mode and slot == Game.AUTO_SLOT:
			continue
		var m := Game.save_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%s\n%s" % [Game.slot_name(slot), _describe(m)]
		l.add_theme_font_size_override("font_size", 16)
		row.add_child(l)
		var act := Button.new()
		act.custom_minimum_size = Vector2(110, 40)
		if save_mode:
			act.text = "Timpa" if not m.is_empty() else "Simpan"
			act.pressed.connect(func():
				Audio.sfx(&"buy")
				Game.save_game(slot)
				_fill())
		else:
			act.text = "Muat"
			act.disabled = m.is_empty() or m.get("game_over", false)
			act.pressed.connect(func():
				Audio.sfx(&"click")
				if Game.load_game(slot):
					loaded.emit()
					Game.goto("game"))
		row.add_child(act)
		var del := Button.new()
		del.text = "Hapus"
		del.custom_minimum_size = Vector2(90, 40)
		del.disabled = m.is_empty()
		del.pressed.connect(func():
			Audio.sfx(&"click")
			Game.delete_save(slot)
			_fill())
		row.add_child(del)
		_rows.add_child(row)


func _describe(m: Dictionary) -> String:
	if m.is_empty():
		return "Kosong"
	var p := Game.db.get_province(StringName(m.get("province", "")))
	var e := Game.db.get_energy(StringName(m.get("energy", "")))
	var t := "%s · %s · %s %s · %d%% desa bersih" % [m.get("name", ""), m.get("date", ""),
		p.display_name if p else "", ("(" + e.display_name + ")") if e else "", int(float(m.get("access", 0.0)) * 100.0)]
	if m.get("game_over", false):
		t += " · selesai"
	return t


func _close() -> void:
	Audio.sfx(&"click")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
