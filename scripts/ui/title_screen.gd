extends Control
## Layar judul: Lanjutkan, Permainan Baru, Muat Permainan, Pengaturan, Panduan, Keluar.
## Latar desa malam berlapis (tools/make_title_bg.py) dengan paralaks mengikuti mouse,
## bintang berkelip, bintang jatuh, baling-baling turbin berputar, lentera naik dari balik bukit,
## dan kunang-kunang. Judul di kiri di atas bayangan gelap; tombol masuk bergantian.

const IMG := Vector2(1280, 720)  # ukuran gambar lapisan
const MARGIN := 32.0  # lapisan dibuat lebih besar dari layar agar bisa digeser
const LAYERS := [  # [file, kedalaman paralaks]
	["res://assets/ui/title_sky.png", 0.15],
	["res://assets/ui/title_far.png", 0.35],
	["res://assets/ui/title_mid.png", 0.65],
	["res://assets/ui/title_near.png", 1.0],
]
const TURBINE_HUB := Vector2(1074, 334)  # dari make_title_bg.py (koordinat gambar)
const LANTERN_COUNT := 14
const STAR_COUNT := 28
const FIREFLY_COUNT := 12

var _buttons: Array[Button] = []
var _layers: Array[TextureRect] = []
var _fx: Array[Control] = []  # satu kanvas efek per lapisan, ikut bergeser bersama lapisannya
var _lanterns: Array = []
var _stars: Array = []
var _flies: Array = []
var _shooting := {}
var _next_shooting := 4.0
var _par := Vector2.ZERO
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_scenery()
	%Shade.texture = _make_shade()
	_style_texts()
	_build_buttons()
	for i in LANTERN_COUNT:
		_lanterns.append(_new_lantern(true))
	for i in STAR_COUNT:
		_stars.append({"p": Vector2(_rng.randf() * IMG.x, _rng.randf() * 400.0), "ph": _rng.randf() * TAU,
			"sp": _rng.randf_range(0.8, 2.4), "big": _rng.randf() < 0.25})
	for i in FIREFLY_COUNT:
		_flies.append({"p": Vector2(_rng.randf() * IMG.x, _rng.randf_range(600, 700)), "ph": _rng.randf() * TAU})
	Audio.music(&"menu")
	_play_intro()


func _build_scenery() -> void:
	var draws := [_draw_sky_fx, _draw_lanterns, _draw_mid_fx, _draw_near_fx]
	for i in LAYERS.size():
		var tr := TextureRect.new()
		tr.texture = load(LAYERS[i][0])
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Scenery.add_child(tr)
		var fx := Control.new()
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx.draw.connect(draws[i])
		tr.add_child(fx)
		_layers.append(tr)
		_fx.append(fx)
	_layout_layers()


func _layout_layers() -> void:
	var vs := size if size.x > 0 else get_viewport_rect().size
	for i in _layers.size():
		var tr := _layers[i]
		var d: float = LAYERS[i][1]
		tr.size = vs + Vector2.ONE * MARGIN * 2.0
		tr.position = (Vector2(-MARGIN, -MARGIN) - _par * MARGIN * d).round()


## Titik di gambar lapisan (1280x720) -> titik lokal di lapisan yang sudah diperbesar/dipotong.
func _map(c: Control, p: Vector2) -> Vector2:
	var k := maxf(c.size.x / IMG.x, c.size.y / IMG.y)
	return (c.size - IMG * k) / 2.0 + p * k


func _pix(c: Control) -> float:
	return 4.0 * maxf(c.size.x / IMG.x, c.size.y / IMG.y)


# ---------------------------------------------------------------- tampilan

func _make_shade() -> GradientTexture2D:
	# Gelap di kiri (tempat judul dan tombol), memudar ke kanan agar latar tetap terlihat.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.32, 0.62])
	var n := Palette.NIGHT
	g.colors = PackedColorArray([Color(n, 0.92), Color(n, 0.7), Color(n, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t


func _style_texts() -> void:
	var title: Label = %GameTitle
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_constant_override("line_spacing", -18)
	title.add_theme_color_override("font_color", Palette.CREAM)
	# Bayangan tegas warna bingkai lentera, gaya retro.
	title.add_theme_color_override("font_shadow_color", Color(0.55, 0.28, 0.16))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 5)
	var sub: Label = %Subtitle
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Palette.CREAM)
	var tag: Label = %Tagline
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Palette.MUTED)


func _button_style(bg: Color, bar: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_width_left = 4
	st.border_color = bar
	st.content_margin_left = 20
	st.content_margin_right = 16
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	st.set_corner_radius_all(2)
	return st


func _make_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 52 if primary else 42)
	b.add_theme_font_size_override("font_size", 20 if primary else 17)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		# Tombol utama: lentera menyala (kuning, teks gelap).
		b.add_theme_stylebox_override("normal", _button_style(Palette.LIT, Palette.CREAM))
		b.add_theme_stylebox_override("hover", _button_style(Palette.LIT.lightened(0.15), Palette.CREAM))
		b.add_theme_stylebox_override("pressed", _button_style(Palette.LIT.darkened(0.12), Palette.CREAM))
		b.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), Palette.CREAM))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Palette.NIGHT)
	else:
		# Tombol biasa: teks saja, garis kuning dan latar tipis saat disorot.
		var clear := Color(0, 0, 0, 0)
		b.add_theme_stylebox_override("normal", _button_style(clear, clear))
		b.add_theme_stylebox_override("hover", _button_style(Color(Palette.LIT, 0.14), Palette.LIT))
		b.add_theme_stylebox_override("pressed", _button_style(Color(Palette.LIT, 0.24), Palette.LIT))
		b.add_theme_stylebox_override("focus", _button_style(Color(Palette.LIT, 0.14), Palette.LIT))
		b.add_theme_stylebox_override("disabled", _button_style(clear, clear))
		b.add_theme_color_override("font_color", Palette.CREAM)
		b.add_theme_color_override("font_hover_color", Palette.LIT)
		b.add_theme_color_override("font_focus_color", Palette.LIT)
		b.add_theme_color_override("font_pressed_color", Palette.LIT)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	%Buttons.add_child(b)
	_buttons.append(b)
	return b


## Teks kecil di tombol: di kanan, atau di baris kedua (below) untuk teks panjang seperti data simpanan.
func _add_detail(b: Button, text: String, col: Color, below := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	if below:
		# Tombol dipertinggi dan teks utama digeser ke atas agar baris kedua muat.
		b.custom_minimum_size.y = 66
		for st in ["normal", "hover", "pressed", "focus"]:
			var box: StyleBox = b.get_theme_stylebox(st).duplicate()
			box.content_margin_bottom = 26
			b.add_theme_stylebox_override(st, box)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_left = 20
		l.offset_right = -14
		l.offset_top = -28
		l.offset_bottom = -10
	else:
		l.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		l.offset_left = -200
		l.offset_right = -14
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)


func _build_buttons() -> void:
	# Lanjutkan hanya muncul jika ada permainan tersimpan; saat itu ia menjadi tombol utama.
	var last := Game.latest_slot()
	var has_save := last != ""
	if has_save:
		var m := Game.save_info(last)
		var cont := _make_button("Lanjutkan", true)
		var info := "%s · %s" % [m.get("name", ""), m.get("date", "")]
		if m.has("access"):
			info += " · %d%% desa menyala" % roundi(100.0 * float(m["access"]))
		_add_detail(cont, info, Color(Palette.NIGHT, 0.75), true)
		cont.pressed.connect(func():
			Audio.sfx(&"click")
			if Game.load_game(last):
				Game.goto("game"))
	var start := _make_button("Permainan Baru", not has_save)
	start.pressed.connect(_on_start)
	if not Game.intro_seen:
		_add_detail(start, "dengan cerita pembuka", Color(Palette.NIGHT, 0.7) if not has_save else Palette.MUTED)
	var load_btn := _make_button("Muat Permainan", false)
	load_btn.pressed.connect(func():
		Audio.sfx(&"click")
		add_child(LoadPanel.new()))
	var guide := _make_button("Panduan", false)
	guide.pressed.connect(func():
		Audio.sfx(&"click")
		Game.slides_mode = "guide"
		Game.slides_next = "title"
		Game.goto("slides"))
	var settings := _make_button("Pengaturan", false)
	settings.pressed.connect(func():
		Audio.sfx(&"click")
		add_child(SettingsPanel.new()))
	if OS.get_name() != "Web":
		var quit := _make_button("Keluar", false)
		quit.pressed.connect(func(): get_tree().quit())
	_buttons[0].grab_focus()


func _play_intro() -> void:
	# Judul memudar masuk, lalu tombol muncul satu per satu.
	for n in [%GameTitle, %Subtitle, %Tagline]:
		n.modulate.a = 0.0
	for b in _buttons:
		b.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(%GameTitle, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(%Subtitle, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tw.parallel().tween_property(%Tagline, "modulate:a", 1.0, 0.6).set_delay(0.35)
	for i in _buttons.size():
		tw.parallel().tween_property(_buttons[i], "modulate:a", 1.0, 0.3).set_delay(0.45 + 0.07 * i)


# ---------------------------------------------------------------- animasi latar

func _process(delta: float) -> void:
	_time += delta
	# Paralaks: ikuti mouse dengan halus, plus ayunan pelan agar tetap hidup tanpa mouse.
	var vs := get_viewport_rect().size
	var m := (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)) * 2.0
	m = m.clamp(Vector2(-1, -1), Vector2(1, 1)) * 0.8 + Vector2(sin(_time * 0.13), cos(_time * 0.1)) * 0.2
	_par = _par.lerp(m, minf(1.0, delta * 2.5))
	_layout_layers()
	var top := 0.08 * IMG.y
	for i in _lanterns.size():
		var l: Dictionary = _lanterns[i]
		l["pos"].y -= l["speed"] * l["size"] * delta
		if l["pos"].y < top:
			_lanterns[i] = _new_lantern(false)
	for f in _flies:
		f["ph"] += delta
		f["p"] += Vector2(sin(f["ph"] * 0.7), cos(f["ph"] * 1.1)) * 9.0 * delta
	_next_shooting -= delta
	if _next_shooting <= 0.0:
		_next_shooting = _rng.randf_range(6.0, 12.0)
		_shooting = {"p": Vector2(_rng.randf_range(500, 1150), _rng.randf_range(20, 160)), "t": 0.0}
	if not _shooting.is_empty():
		_shooting["t"] += delta
		if _shooting["t"] > 0.9:
			_shooting = {}
	for fx in _fx:
		fx.queue_redraw()


func _draw_sky_fx() -> void:
	var c: Control = _fx[0]
	var px := _pix(c)
	for st in _stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * st["sp"] + st["ph"]))
		var p := _map(c, st["p"])
		c.draw_rect(Rect2(p, Vector2(px, px)), Color(1, 0.98, 0.9, a))
		if st["big"] and a > 0.8:
			var arm := Color(0.75, 0.75, 0.95, (a - 0.8) * 4.0)
			for o in [Vector2(px, 0), Vector2(-px, 0), Vector2(0, px), Vector2(0, -px)]:
				c.draw_rect(Rect2(p + o, Vector2(px, px)), arm)
	if not _shooting.is_empty():
		var t: float = _shooting["t"] / 0.9
		var head := _map(c, _shooting["p"] + Vector2(-260, 90) * t)
		var dir := Vector2(-260, 90).normalized()
		for k in 10:
			var q := head - dir * px * k * 1.5
			c.draw_rect(Rect2((q / px).floor() * px, Vector2(px, px)), Color(1, 0.95, 0.8, (1.0 - k / 10.0) * sin(t * PI)))


func _new_lantern(anywhere: bool) -> Dictionary:
	# Lentera muncul dari balik bukit (lapisan tengah menutupinya sampai naik ke langit).
	var x := IMG.x * (0.3 + 0.7 * _rng.randf()) if _rng.randf() < 0.85 else IMG.x * _rng.randf()
	return {
		"pos": Vector2(x, _rng.randf_range(0.15, 0.75) * IMG.y if anywhere else IMG.y * 0.86),
		"speed": _rng.randf_range(9.0, 20.0),
		"sway": _rng.randf_range(4.0, 12.0),
		"phase": _rng.randf() * TAU,
		"size": 1.0 if _rng.randf() < 0.65 else 1.5,
	}


func _draw_lanterns() -> void:
	var c: Control = _fx[1]
	var px := _pix(c) * 0.5
	for l in _lanterns:
		var s: float = l["size"]
		var p := _map(c, l["pos"] + Vector2(sin(_time * 0.8 + l["phase"]) * l["sway"], 0))
		p = (p / px).floor() * px
		# Memudar saat mendekati atas layar.
		var a := clampf((l["pos"].y / IMG.y - 0.08) / 0.3, 0.0, 1.0)
		var flick := 0.85 + 0.15 * sin(_time * 7.0 + l["phase"] * 3.0)
		c.draw_circle(p + Vector2(0, 5) * s, 16.0 * s, Color(Palette.LIT, 0.10 * a * flick))
		c.draw_circle(p + Vector2(0, 5) * s, 9.0 * s, Color(Palette.LIT, 0.16 * a * flick))
		var w := 8.0 * s
		var h := 10.0 * s
		var body := Rect2(p - Vector2(w / 2.0, 0), Vector2(w, h))
		c.draw_rect(body, Color(1.0, 0.62, 0.22, a))
		c.draw_rect(Rect2(body.position + Vector2(px, px * 2), Vector2(w - px * 2, h - px * 3)), Color(1.0, 0.86, 0.45, a * flick))
		c.draw_rect(Rect2(body.position - Vector2(-px, px), Vector2(w - px * 2, px)), Color(0.55, 0.28, 0.16, a))


func _draw_mid_fx() -> void:
	# Baling-baling turbin: tiga bilah dari kotak piksel, berputar pelan.
	var c: Control = _fx[2]
	var px := _pix(c)
	var hub := _map(c, TURBINE_HUB)
	for k in 3:
		var ang := _time * 1.4 + k * TAU / 3.0
		var dir := Vector2(cos(ang), sin(ang))
		for st in range(1, 12):
			var q := hub + dir * px * st
			c.draw_rect(Rect2((q / px).floor() * px, Vector2(px, px)), Color(0.88, 0.9, 0.96))
	c.draw_rect(Rect2((hub / px).floor() * px - Vector2(px, px) * 0.5, Vector2(px, px) * 2.0), Color(0.6, 0.62, 0.72))


func _draw_near_fx() -> void:
	# Kunang-kunang di rumput depan.
	var c: Control = _fx[3]
	var px := _pix(c)
	for f in _flies:
		var a := 0.5 + 0.5 * sin(f["ph"] * 2.3)
		var p := _map(c, f["p"])
		c.draw_circle(p, px * 2.5, Color(0.75, 0.95, 0.45, 0.12 * a))
		c.draw_rect(Rect2((p / px).floor() * px, Vector2(px, px)), Color(0.85, 1.0, 0.55, a))


func _on_start() -> void:
	Audio.sfx(&"click")
	if Game.intro_seen:
		Game.goto("setup")
	else:
		Game.slides_mode = "intro"
		Game.slides_next = "setup"
		Game.goto("slides")
