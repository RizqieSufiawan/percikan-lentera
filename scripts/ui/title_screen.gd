extends Control
## Layar judul: Lanjutkan, Permainan Baru, Muat Permainan, Pengaturan, Panduan, Keluar.
## Latar desa malam berlapis (tools/make_title_bg.py) dengan paralaks mengikuti mouse,
## bintang berkelip, bintang jatuh, baling-baling turbin berputar, lentera naik dari balik bukit,
## dan kunang-kunang. Yang ikut bergerak (tidak dicetak di gambar lapisan): bintang terang berkelip,
## riak danau, pantulan bulan & lampu rumah yang bergoyang, air terjun mengalir, pohon kelapa
## berayun (lembar sprite title_palms.png). Judul di kiri di atas bayangan gelap; tombol masuk bergantian.

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
const STAR_COUNT := 80
const MOON := Vector2(252, 38)  # piksel seni (make_title_bg.py)
const LAKE_Y := 148  # baris tepi danau (piksel seni)
const ART_H := 180
const HOUSES := [238, 252, 280, 296, 309]  # rumah di lereng kanan (pantulan lampunya di danau)
const FALL_Y := Vector2i(124, 148)
const WATER_F := Color8(150, 190, 226)
const WATER_F2 := Color8(96, 140, 196)
const LAKE1 := Color8(40, 62, 116)
const LAKE2 := Color8(72, 96, 156)
const PALMS := preload("res://assets/ui/title_palms.png")
const PALM_FRAMES := 16
const PALM_BOX := Rect2(0, 52, 108, 128)  # piksel seni, sama dengan make_title_bg.py
const PALM_FPS := 7.0
const CRATER := Vector2(196, 62)  # kawah gunung api (piksel seni)
const SMOKE_COL := Color8(96, 88, 142)
const LAMP := Color8(255, 206, 104)
const LAMP2 := Color8(255, 240, 176)
const WALL := Color8(104, 78, 70)
const ROOF := Color8(70, 40, 44)
## Rumah berlampu (x kiri, piksel seni). 46 sengaja gelap di gambar (desa belum berlistrik).
const LIT_HOUSES := [20, 92, 238, 252, 280, 296, 309]
const CHIMNEY_HOUSES := [252, 296]  # rumah yang sedang memasak (asap dapur tipis)
const FIREFLY_COUNT := 12

var _buttons: Array[Button] = []
var _layers: Array[TextureRect] = []
var _rays: ColorRect  # pancaran cahaya bulan (shaders/moon_rays.gdshader), anak lapisan langit
var _fx: Array[Control] = []  # satu kanvas efek per lapisan, ikut bergeser bersama lapisannya
var _lanterns: Array = []
var _stars: Array = []
var _flies: Array = []
var _ripples: Array = []  # garis riak danau: {y, x, len, sp, ph, bright}
var _smoke: Array = []  # kepulan asap gunung: {p, age, life, r0, r1}
var _embers: Array = []  # bara kecil dari kawah: {p, v, age}
var _smoke_cd := 0.0
## Jendela rumah: {pos (piksel seni, kiri atas 2x2), house, ph, off_t, off_cd, pass_t, pass_cd, dir}
var _windows: Array = []
var _house_light: Dictionary = {}  # x rumah -> terang rata-rata jendelanya (untuk pantulan di danau)
var _chimney: Array = []  # asap dapur: {p, age}
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
	while _stars.size() < STAR_COUNT:
		# Posisi di kisi piksel seni, tidak menempel bulan.
		var g := Vector2(_rng.randi_range(0, 319), _rng.randi_range(0, 108))
		if g.distance_to(MOON) < 17.0:
			continue
		var roll := _rng.randf()
		_stars.append({"p": g * 4.0, "ph": _rng.randf() * TAU, "sp": _rng.randf_range(0.6, 2.2),
			"lvl": 0.55 if roll < 0.55 else (0.85 if roll < 0.9 else 1.0), "big": roll >= 0.9,
			"col": Color(1, 0.98, 0.9) if _rng.randf() < 0.7 else Color(0.8, 0.86, 1.0)})
	# Asap gunung sudah mengepul sejak awal (tidak mulai dari kosong).
	for i in 20:
		_spawn_smoke(i * 0.75)
	for hx in LIT_HOUSES:
		var top := _house_y(hx) - 9
		for wx in [2, 6]:
			_windows.append({"pos": Vector2(hx + wx, top + 4), "house": hx, "ph": _rng.randf() * TAU,
				"off_t": 0.0, "off_cd": _rng.randf_range(8.0, 70.0), "pass_t": -1.0,
				"pass_cd": _rng.randf_range(2.0, 12.0), "dir": 1.0})
	for y in range(LAKE_Y + 1, ART_H, 2):
		var dir := 1.0 if (y / 2) % 2 == 0 else -1.0
		var depth := float(y - LAKE_Y) / (ART_H - LAKE_Y)
		var x := _rng.randf_range(0, 6)
		while x < 320:
			var ln := _rng.randi_range(2, 6)
			_ripples.append({"y": y, "x": x, "len": ln, "sp": dir * _rng.randf_range(1.0, 2.5) * (0.6 + depth),
				"ph": _rng.randf() * TAU, "bright": _rng.randf() < 0.25})
			x += ln + _rng.randf_range(6, 16)
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
		if i == 0:
			_rays = ColorRect.new()
			_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rm := ShaderMaterial.new()
			rm.shader = preload("res://shaders/moon_rays.gdshader")
			_rays.material = rm
			tr.add_child(_rays)
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
	if _rays:
		# Tepat menutup gambar langit di dalam lapisannya (gambar diperbesar & dipotong "cover").
		var tr0 := _layers[0]
		var k := maxf(tr0.size.x / IMG.x, tr0.size.y / IMG.y)
		_rays.position = (tr0.size - IMG * k) / 2.0
		_rays.size = IMG * k


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
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Palette.CREAM)
	var tag: Label = %Tagline
	tag.add_theme_font_size_override("font_size", 16)
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
	st.set_corner_radius_all(4)
	st.corner_detail = 1  # sudut terpotong ala kit pixel
	st.anti_aliasing = false
	return st


func _make_button(text: String, _primary: bool) -> Button:
	# Semua tombol sama: hanya teks. Blok kuning mengikuti tombol yang ditunjuk (mouse atau
	# keyboard); bila tidak ada yang ditunjuk, tidak ada blok kuning.
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(400, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_ALL
	var clear := Color(0, 0, 0, 0)
	var lit := _button_style(Palette.LIT, Palette.CREAM)
	b.add_theme_stylebox_override("normal", _button_style(clear, clear))
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", _button_style(Palette.LIT.darkened(0.12), Palette.CREAM))
	b.add_theme_stylebox_override("disabled", _button_style(clear, clear))
	b.add_theme_color_override("font_color", Palette.CREAM)
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Palette.NIGHT)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.mouse_exited.connect(func(): if b.has_focus(): b.release_focus())
	%Buttons.add_child(b)
	_buttons.append(b)
	return b


## Keterangan tombol (mis. data simpanan) di sisi kanan, hanya tampil saat tombol ditunjuk.
func _add_detail(b: Button, text: String, col: Color, _below := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	l.offset_left = -300
	l.offset_right = -14
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	b.add_child(l)
	b.focus_entered.connect(func(): l.visible = true)
	b.focus_exited.connect(func(): l.visible = false)


## Panah atas/bawah saat belum ada tombol yang ditunjuk: mulai dari tombol pertama/terakhir.
func _unhandled_input(event: InputEvent) -> void:
	if _buttons.is_empty() or get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
		_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_focus_prev"):
		_buttons[-1].grab_focus()
		get_viewport().set_input_as_handled()


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
		_add_detail(cont, info, Color(Palette.NIGHT, 0.75))
		cont.pressed.connect(func():
			Audio.sfx(&"click")
			if Game.load_game(last):
				Game.goto("game"))
	var start := _make_button("Permainan Baru", not has_save)
	start.pressed.connect(_on_start)
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
	for r in _ripples:
		r["x"] = fposmod(r["x"] + r["sp"] * delta, 330.0)
	_update_volcano(delta)
	_update_houses(delta)
	for fx in _fx:
		fx.queue_redraw()


func _draw_sky_fx() -> void:
	var c: Control = _fx[0]
	var px := _pix(c)
	for st in _stars:
		# Kelip: gelombang pelan ditambah kedip cepat sesekali (seperti bintang sungguhan).
		var w := 0.5 + 0.5 * sin(_time * st["sp"] + st["ph"])
		var flick := 1.0 - 0.45 * maxf(0.0, sin(_time * st["sp"] * 5.3 + st["ph"] * 3.0)) * w
		var a: float = st["lvl"] * (0.25 + 0.75 * w) * flick
		var p := _map(c, st["p"])
		c.draw_rect(Rect2(p, Vector2(px, px)), Color(st["col"], a))
		if st["big"] and a > 0.7:
			var arm := Color(0.75, 0.75, 0.95, (a - 0.7) * 2.5)
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
	_draw_volcano(c, _pix(c))
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
	_draw_grass(c, px)
	_draw_lake(c, px)
	_draw_waterfall(c, px)
	_draw_houses(c, px)
	var hub := _map(c, TURBINE_HUB)
	for k in 3:
		var ang := _time * 1.4 + k * TAU / 3.0
		var dir := Vector2(cos(ang), sin(ang))
		for st in range(1, 12):
			var q := hub + dir * px * st
			c.draw_rect(Rect2((q / px).floor() * px, Vector2(px, px)), Color(0.88, 0.9, 0.96))
	c.draw_rect(Rect2((hub / px).floor() * px - Vector2(px, px) * 0.5, Vector2(px, px) * 2.0), Color(0.6, 0.62, 0.72))


## Kotak satu atau beberapa piksel seni (koordinat seni 320x180) di kanvas efek c.
func _art(c: Control, px: float, g: Vector2, col: Color, w: float = 1.0) -> void:
	c.draw_rect(Rect2(_map(c, g.floor() * 4.0), Vector2(w * px, px)), col)


func _draw_lake(c: Control, px: float) -> void:
	# Riak: garis pendek bergeser pelan, arah berselang per baris, panjangnya mengembang-mengempis.
	for r in _ripples:
		var ln := maxf(1.0, roundf(r["len"] * (0.55 + 0.45 * sin(_time * 1.3 + r["ph"]))))
		var x := floorf(r["x"]) - 5.0
		if x > 320.0 or x + ln < 0.0:
			continue
		_art(c, px, Vector2(x, r["y"]), LAKE2 if r["bright"] else LAKE1, ln)
	# Pantulan bulan: di dekat tepi danau berbentuk cakram bulan yang gepeng (sedikit bergoyang,
	# baris berselang agak redup seperti permukaan air), lalu pecah jadi garis-garis ke bawah.
	var disc := [5, 8, 10, 10, 9, 7, 4]
	for i in disc.size():
		var y: int = LAKE_Y + 1 + i
		var hw: int = disc[i]
		var wob := roundf(sin(_time * 1.3 + i * 0.9) * 0.8)
		var col := Color8(226, 222, 198) if i % 2 == 0 else Color8(196, 196, 186)
		_art(c, px, Vector2(MOON.x - hw + wob, y), col, hw * 2)
		if i % 2 == 1:
			# Satu celah gelap per baris berselang, bergeser pelan (riak memecah pantulan).
			var cut := int(fmod(_time * 1.2 + i * 2.3, float(hw * 2 - 2))) + 1
			_art(c, px, Vector2(MOON.x - hw + wob + cut, y), Color8(120, 130, 160))
	for y in range(LAKE_Y + 2 + disc.size(), ART_H, 2):
		var spread := 4 + (y - LAKE_Y) / 5
		var wob := roundf(sin(_time * 1.6 + y * 0.9) * 1.2 + sin(_time * 0.7 + y * 0.35))
		var ln := spread * 2 - int(absf(sin(_time * 2.1 + y * 1.7)) * 3.0)
		var x0 := MOON.x - spread + wob
		var col := Color8(196, 198, 196) if y < 164 else Color8(150, 156, 176)
		var gap := int((0.5 + 0.5 * sin(_time * 1.1 + y)) * ln)
		if gap > 0 and gap < ln - 1:
			_art(c, px, Vector2(x0, y), col, gap)
			_art(c, px, Vector2(x0 + gap + 1, y), col, ln - gap - 1)
		else:
			_art(c, px, Vector2(x0, y), col, ln)
		# Kilau kecil berpindah-pindah di pantulan.
		if fmod(_time * 3.0 + y * 0.37, 1.0) < 0.15:
			_art(c, px, Vector2(x0 + int(fmod(y * 7.3 + floorf(_time * 3.0) * 5.0, ln)), y), Color8(240, 236, 210))
	# Pantulan lampu rumah: titik hangat bergoyang.
	for hx in HOUSES:
		for k in 4:
			var y: int = LAKE_Y + 2 + k * 3
			if absf(hx + 3 - MOON.x) < 12.0 and y < LAKE_Y + 9:
				continue  # tertutup cakram pantulan bulan
			var wob := roundf(sin(_time * 2.0 + hx + k * 1.3))
			var a: float = (0.75 + 0.25 * sin(_time * 3.0 + hx * 0.7 + k)) * _house_light.get(hx, 1.0)
			_art(c, px, Vector2(hx + 3 + wob, y), Color(Color8(200, 160, 96), a))
			_art(c, px, Vector2(hx + 4 + wob, y), Color(Color8(160, 126, 90), a))


# ---------------------------------------------------------------- gunung api

func _spawn_smoke(age: float = 0.0) -> void:
	_smoke.append({"p": CRATER + Vector2(_rng.randf_range(-2.0, 2.0), -1.0), "age": age,
		"life": _rng.randf_range(13.0, 17.0), "r0": _rng.randf_range(0.8, 1.4), "r1": _rng.randf_range(5.0, 8.0),
		"ph": _rng.randf() * TAU})


func _update_volcano(delta: float) -> void:
	_smoke_cd -= delta
	if _smoke_cd <= 0.0:
		_smoke_cd = _rng.randf_range(0.6, 0.9)
		_spawn_smoke()
	for i in range(_smoke.size() - 1, -1, -1):
		var s: Dictionary = _smoke[i]
		s["age"] += delta
		if s["age"] >= s["life"]:
			_smoke.remove_at(i)
	if _rng.randf() < delta * 0.3:
		_embers.append({"p": CRATER + Vector2(_rng.randf_range(-2, 2), 0), "v": Vector2(_rng.randf_range(-2, 3), -_rng.randf_range(5, 9)), "age": 0.0})
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e["age"] += delta
		e["v"] += Vector2(0.6, 4.0) * delta
		e["p"] += e["v"] * delta
		if e["age"] > 1.6:
			_embers.remove_at(i)


## Posisi kepulan: naik, makin condong ke kanan terbawa angin, bergelombang pelan.
func _smoke_pos(s: Dictionary) -> Vector2:
	var a: float = s["age"]
	return s["p"] + Vector2(a * 0.75 + a * a * 0.07 + sin(a * 0.35 + s["ph"]) * 1.2, -a * 1.35 + a * a * 0.015)


func _draw_volcano(c: Control, px: float) -> void:
	# Pendar kawah: jingga redup berdenyut, dipantulkan ke dasar asap.
	var pulse := 0.5 + 0.5 * sin(_time * 0.9) * sin(_time * 2.3 + 1.0)
	for dx in range(-4, 5):
		var a := (0.35 + 0.35 * pulse) * (1.0 - absf(dx) / 5.0)
		_art(c, px, CRATER + Vector2(dx, 1), Color(1.0, 0.45, 0.2, a))
	for dx in range(-2, 3):
		_art(c, px, CRATER + Vector2(dx, 0), Color(1.0, 0.7, 0.35, 0.45 + 0.4 * pulse))
	# Asap: lingkaran piksel berpola papan catur (tipis, ciri pixel art), membesar dan memudar.
	for s in _smoke:
		var t: float = s["age"] / s["life"]
		var r: float = lerpf(s["r0"], s["r1"], sqrt(t))
		var cpos := _smoke_pos(s)
		var a := 0.9 * (1.0 - t * t) * minf(1.0, s["age"] * 1.5)
		var warm := clampf(1.0 - s["age"] / 4.0, 0.0, 1.0) * (0.4 + 0.6 * pulse)
		var col := SMOKE_COL.lerp(Color8(170, 96, 96), warm * 0.6)
		var ir := int(ceilf(r))
		for yy in range(-ir, ir + 1):
			for xx in range(-ir, ir + 1):
				var g := (cpos + Vector2(xx, yy)).floor()
				if Vector2(xx, yy).length() > r:
					continue
				# Tepi lebih tipis (setengah piksel diisi), tengah penuh.
				var edge := Vector2(xx, yy).length() > r - 1.2
				if edge and int(g.x + g.y) % 2 == 0:
					continue
				_art(c, px, g, Color(col, a * (0.6 if edge else 1.0)))
	for e in _embers:
		var t: float = e["age"] / 1.6
		_art(c, px, e["p"], Color(1.0, 0.65 - t * 0.3, 0.3, 1.0 - t))


# ---------------------------------------------------------------- rumah

## Sama dengan hill_y() di make_title_bg.py: tinggi punggung bukit (piksel seni).
func _hill(x: float) -> float:
	return 144.0 - 32.0 * exp(-pow((x - 266.0) / 58.0, 2.0)) - 9.0 * exp(-pow((x - 70.0) / 60.0, 2.0))


func _house_y(x: float) -> int:
	return int(_hill(x + 5.0)) + 1  # kaki rumah di lereng


## Sawah terasering: garis teras (rumus sama dengan make_title_bg.py) tetap diam, angin dari kiri
## lewat sebagai kilau yang menyapu ke kanan serempak di semua baris, seperti hamparan padi
## yang tersibak. Tepi kilau memakai dithering Bayer (gaya pixel art), bukan gradasi halus.
const BAYER4 := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _draw_grass(c: Control, px: float) -> void:
	var tiers := [Color8(44, 66, 78), Color8(56, 82, 92), Color8(72, 100, 106)]
	for x in range(180, 320):
		var hy := _hill(x)
		# Dua hembusan dengan panjang berbeda supaya tidak terasa berulang kaku.
		var t := x * 0.035 - _time * 0.75
		var g := pow(maxf(0.0, sin(t)), 3.0) + 0.5 * pow(maxf(0.0, sin(t * 0.6 + 2.0)), 4.0)
		g = clampf(g, 0.0, 1.0) * 2.0  # 0..2 = tingkat warna
		for k in range(1, 8):
			var y := int(hy + k * 3 + sin(x * 0.08 + k) * 0.8)
			if y >= LAKE_Y - 2 or (x + k) % 9 == 0:
				continue
			var lvl := int(g)
			var frac := g - lvl
			if frac * 16.0 > BAYER4[(y % 4) * 4 + (x % 4)] + 0.5:
				lvl += 1
			_art(c, px, Vector2(x, y), tiers[mini(lvl, 2)])


func _update_houses(delta: float) -> void:
	var sum := {}
	var cnt := {}
	for w in _windows:
		# Kadang lampu dimatikan beberapa detik (orang keluar kamar), lalu menyala lagi.
		w["off_cd"] -= delta
		if w["off_cd"] <= 0.0:
			w["off_cd"] = _rng.randf_range(35.0, 90.0)
			w["off_t"] = _rng.randf_range(2.0, 5.0)
		w["off_t"] = maxf(0.0, w["off_t"] - delta)
		# Kadang ada bayangan orang lewat di depan jendela.
		w["pass_cd"] -= delta
		if w["pass_cd"] <= 0.0 and w["pass_t"] < 0.0:
			w["pass_cd"] = _rng.randf_range(4.0, 14.0)
			w["pass_t"] = 0.0
			w["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
		if w["pass_t"] >= 0.0:
			w["pass_t"] += delta
			if w["pass_t"] > 1.2:
				w["pass_t"] = -1.0
		var b := _window_light(w)
		sum[w["house"]] = sum.get(w["house"], 0.0) + b
		cnt[w["house"]] = cnt.get(w["house"], 0) + 1
	for h in sum:
		_house_light[h] = sum[h] / cnt[h]
	if _rng.randf() < delta * 1.2:
		var hx: int = CHIMNEY_HOUSES[_rng.randi() % CHIMNEY_HOUSES.size()]
		_chimney.append({"p": Vector2(hx + 3, _house_y(hx) - 13), "age": 0.0})
	for i in range(_chimney.size() - 1, -1, -1):
		_chimney[i]["age"] += delta
		if _chimney[i]["age"] > 4.0:
			_chimney.remove_at(i)


## Terang jendela 0..1: pelita berpendar halus, atau padam sebentar.
func _window_light(w: Dictionary) -> float:
	if w["off_t"] > 0.0:
		return 0.0
	return 0.86 + 0.08 * sin(_time * 2.7 + w["ph"]) + 0.06 * sin(_time * 7.9 + w["ph"] * 2.0)


func _draw_houses(c: Control, px: float) -> void:
	for w in _windows:
		var b := _window_light(w)
		var g: Vector2 = w["pos"]
		var dark := Color8(30, 30, 50)
		# Jendela 2x2: kiri atas paling terang (sumber cahaya), sisanya kuning lampu.
		var cols := [LAMP2, LAMP, LAMP, LAMP]
		for k in 4:
			var o := Vector2(k % 2, k / 2)
			var col: Color = dark.lerp(cols[k], b)
			# Bayangan orang lewat: satu kolom gelap bergeser melintasi jendela.
			if w["pass_t"] >= 0.0 and b > 0.0:
				var t: float = w["pass_t"] / 1.2
				var sx: float = lerpf(-1.0, 2.0, t) if w["dir"] > 0.0 else lerpf(2.0, -1.0, t)
				if absf(o.x - sx) < 0.75:
					col = col.darkened(0.55)
			_art(c, px, g + o, col)
		# Pendar ke dinding di samping jendela ikut redup saat lampu padam.
		_art(c, px, g + Vector2(-1, 0), Color(WALL.lerp(LAMP, 0.35), b))
		_art(c, px, g + Vector2(2, 1), Color(WALL.lerp(LAMP, 0.35), b))
		if b > 0.0:
			c.draw_circle(_map(c, (g + Vector2(1, 1)) * 4.0), px * 2.2, Color(LAMP, 0.06 * b))
	for s in _chimney:
		var t: float = s["age"] / 4.0
		var g: Vector2 = s["p"] + Vector2(t * 3.0 + sin(s["age"] * 1.5) * 0.7, -t * 9.0)
		_art(c, px, g, Color(0.62, 0.6, 0.7, 0.45 * (1.0 - t)))
		if t > 0.4:
			_art(c, px, g + Vector2(1, 0), Color(0.62, 0.6, 0.7, 0.25 * (1.0 - t)))


## Kolom air terjun per baris (x0, x1), sama dengan fall_span() di make_title_bg.py.
func _fall_span(y: int) -> Vector2i:
	if y < 128:
		return Vector2i(162, 164)  # pancuran atas, keluar dari bawah celah pepohonan
	if y < 130:
		return Vector2i(161, 165)
	if y == 130:
		return Vector2i(160, 166)  # limpasan di birai
	if y < 137:
		return Vector2i(161, 165)
	if y < 143:
		return Vector2i(161, 166)
	return Vector2i(160, 167)  # melebar dekat kolam


func _draw_waterfall(c: Control, px: float) -> void:
	# Garis aliran vertikal bergulir ke bawah (tiap kolom beda kecepatan), tepi lebih gelap,
	# buih di birai dan di kolam berkedip, riak kolam menyebar ke danau, uap tipis naik.
	var hi := Color8(168, 204, 234)
	var mid := Color8(116, 156, 204)
	var edge := Color8(70, 102, 150)
	for y in range(FALL_Y.x, FALL_Y.y):
		var sp := _fall_span(y)
		for x in range(sp.x, sp.y + 1):
			var col := mid
			if x == sp.x or x == sp.y:
				col = edge
			else:
				var flow := int(_time * (5.0 + (x % 3) * 1.2))
				if posmod(y - flow + x * 5, 4) == 0:
					col = hi
			if y == 130 and posmod(x + int(_time * 2.5), 3) == 0:
				col = Color8(220, 236, 250)  # buih di birai
			_art(c, px, Vector2(x, y), col)
	var step := int(_time * 4.0)
	for x in range(156, 172):
		var h := posmod(x * 37 + step * 13, 10)
		if h < 7:
			_art(c, px, Vector2(x, LAKE_Y - 1 - (h % 2)), WATER_F)
		if h == 0:
			_art(c, px, Vector2(x, LAKE_Y - 3), Color(WATER_F, 0.5))
	# Riak kolam: garis tipis melebar keluar dari kaki air terjun lalu pudar.
	for k in 3:
		var t := fmod(_time * 0.4 + k / 3.0, 1.0)
		var half := 3.0 + t * 12.0
		var y := LAKE_Y + 1 + int(t * 3.0)
		var a := 0.5 * (1.0 - t)
		_art(c, px, Vector2(163 - half, y), Color(WATER_F, a), 3.0)
		_art(c, px, Vector2(163 + half - 2.0, y), Color(WATER_F, a), 3.0)
	for k in 4:
		var t := fmod(_time * 0.5 + k * 0.25, 1.0)
		_art(c, px, Vector2(159 + k * 3 + roundf(sin(_time + k) * 1.0), LAKE_Y - 3 - floorf(t * 7.0)),
			Color(0.85, 0.9, 1.0, 0.35 * (1.0 - t)))


func _draw_near_fx() -> void:
	# Kunang-kunang di rumput depan.
	var c: Control = _fx[3]
	var px := _pix(c)
	# Pohon kelapa berayun: lembar sprite diputar terus (satu putaran = satu ayunan penuh).
	var frame := int(_time * PALM_FPS) % PALM_FRAMES
	var src := Rect2(frame * PALM_BOX.size.x, 0, PALM_BOX.size.x, PALM_BOX.size.y)
	c.draw_texture_rect_region(PALMS, Rect2(_map(c, PALM_BOX.position * 4.0), PALM_BOX.size * px), src)
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
