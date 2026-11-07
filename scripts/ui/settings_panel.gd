class_name SettingsPanel
extends Control
## Panel Pengaturan (dipakai di layar judul dan menu jeda). Dibuat lewat kode, tersimpan otomatis.

signal closed


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
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Pengaturan"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_slider("Musik", Audio.music_volume_db, func(v): Audio.set_music_volume(v)))
	box.add_child(_slider("Efek suara", Audio.sfx_volume_db, func(v): Audio.set_sfx_volume(v); Audio.sfx(&"click")))
	var news := CheckButton.new()
	news.text = "Berita penting tampil sebagai popup"
	news.button_pressed = Game.news_popups_enabled
	news.toggled.connect(func(on): Game.news_popups_enabled = on)
	box.add_child(news)
	if OS.get_name() != "Web":
		var fs := CheckButton.new()
		fs.text = "Layar penuh"
		fs.button_pressed = Game.fullscreen
		fs.toggled.connect(func(on): Game.set_fullscreen(on))
		box.add_child(fs)
	var close := Button.new()
	close.text = "Tutup"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close)
	box.add_child(close)
	close.grab_focus()


func _slider(label: String, db_value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = 0.0 if db_value <= -60.0 else roundf(db_to_linear(db_value) * 100.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(48, 0)
	pct.text = "%d%%" % int(s.value)
	s.value_changed.connect(func(v):
		pct.text = "%d%%" % int(v)
		on_change.call(-80.0 if v <= 0.0 else linear_to_db(v / 100.0)))
	row.add_child(s)
	row.add_child(pct)
	return row


func _close() -> void:
	Audio.sfx(&"click")
	Game.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
