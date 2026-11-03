class_name MapView
extends Control
## Peta wilayah. Tiap wilayah = satu PNG 1280x720 transparan (ProvinceData.region_mask) untuk batas,
## klik, dan hover. Di dalamnya, tiap KLOTER desa punya sel sendiri (assets/map/cells.png dan
## data/map_cells.json, dibuat tools/make_cells.py). Sel diwarnai sesuai energi yang dipakai kloter itu
## (EnergyData.color); rapuh bergaris, mandiri penuh, fosil coklat, gelap abu. Warna menyebar dari titik
## kloter ke tepi selnya (shaders/region_cells.gdshader).
## Latar laut dari data/ui_assets.tres -> map_background.
## Label tiap wilayah (scenes/ui/province_node.tscn) diletakkan di map_position.

signal province_clicked(id: StringName)
## Klik tepat di sel kloter: wilayah dan indeks kloternya.
signal village_clicked(id: StringName, index: int)
## Klik di laut / di luar wilayah.
signal empty_clicked

const REF := Vector2(1280, 720)
const NODE_SCENE := preload("res://scenes/ui/province_node.tscn")
const CELL_SHADER := preload("res://shaders/region_cells.gdshader")
const CELL_MAP_PATH := "res://assets/map/cells.png"
const CELL_JSON_PATH := "res://data/map_cells.json"

## Ukuran piksel pixel art (piksel referensi).
const SAMPLE_STEP := 4
## Kecepatan pertumbuhan warna di dalam sel (piksel referensi per detik).
const GROW_SPEED := 70.0
## Jari-jari titik kecil saat kloter sedang dibangun.
const BUILD_SPOT := 7.0

## Daratan yang masih ada warga tanpa listrik: biru keunguan gelap (malam), lebih terang dari laut.
const COLOR_DARK := Color(0.33, 0.37, 0.60)
const COLOR_BORDER := Color(0.07, 0.10, 0.20)
const SEA_SHADER := preload("res://shaders/sea.gdshader")

var nodes: Dictionary = {}
var selected: StringName = &""
## Mode pratinjau (layar persiapan): tanpa simulasi. Sel diwarnai dari data awal
## (gelap atau fosil), label tanpa persen, tooltip singkat.
var preview: bool = false
var hovered: StringName = &""

var _bitmaps: Dictionary = {}  # id -> BitMap (klik)
var _regions: Dictionary = {}  # id -> TextureRect dengan ShaderMaterial
var _noise: NoiseTexture2D

# Sel kloter: indeks global = _cell_base[id wilayah] + indeks kloter.
var _cell_base: Dictionary = {}
var _cell_owner: Array = []  # indeks global -> [id wilayah, indeks kloter]
var _cell_count: int = 0
var _cell_ids: Image  # 320x180, id + 1 per piksel
var _color_img: Image
var _geom_img: Image
var _color_tex: ImageTexture
var _geom_tex: ImageTexture
var _seed_pos: PackedVector2Array
var _max_r: PackedFloat32Array
var _r_now: PackedFloat32Array
var _r_target: PackedFloat32Array
var _animating: bool = false
var _selected_cell: int = -1

@onready var node_layer: Control = $Nodes
var _region_layer: Control
var _overlay: Control
var _sea: ColorRect


func build() -> void:
	_noise = NoiseTexture2D.new()
	_noise.width = 256
	_noise.height = 256
	_noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	_noise.noise = fn
	# Laut: memenuhi seluruh kotak peta (tepi gambar diperpanjang oleh shader).
	_sea = ColorRect.new()
	_sea.name = "Sea"
	_sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = SEA_SHADER
	sea_mat.set_shader_parameter("sea_tex", Game.db.ui.map_background)
	_sea.material = sea_mat
	add_child(_sea)
	_region_layer = _make_layer("Regions")
	_overlay = _make_layer("Overlay")
	_overlay.draw.connect(_draw_overlay)
	move_child(_sea, 0)
	move_child(_region_layer, 1)
	move_child(_overlay, 2)
	_load_cells()
	for p in Game.db.provinces:
		var n: ProvinceNode = NODE_SCENE.instantiate()
		node_layer.add_child(n)
		n.setup(p)
		n.pressed.connect(func(id): province_clicked.emit(id))
		nodes[p.id] = n
		if p.region_mask:
			_prepare_region(p)
	tooltip_text = "peta"  # isi sebenarnya dari _get_tooltip()
	resized.connect(_layout)
	_layout.call_deferred()


func _make_layer(layer_name: String) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


## Membaca sel kloter dan menyiapkan dua tekstur data (satu kolom per kloter).
func _load_cells() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(CELL_JSON_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(CELL_JSON_PATH))
	for p in Game.db.provinces:
		_cell_base[p.id] = _cell_count
		var rows: Array = data.get(String(p.id), [])
		for i in p.village_list.size():
			var r: Array = rows[i] if i < rows.size() and rows[i] != null else [p.map_position.x, p.map_position.y, 0.0]
			_seed_pos.append(Vector2(r[0], r[1]))
			_max_r.append(float(r[2]) + 6.0)
			_r_now.append(-1.0)
			_r_target.append(-1.0)
			_cell_owner.append([p.id, i])
			_cell_count += 1
	var n := maxi(1, _cell_count)
	_color_img = Image.create(n, 1, false, Image.FORMAT_RGBA8)
	_geom_img = Image.create(n, 1, false, Image.FORMAT_RGBAF)
	for k in _cell_count:
		_color_img.set_pixel(k, 0, Color(0, 0, 0, 0))
		_geom_img.set_pixel(k, 0, Color(_seed_pos[k].x, _seed_pos[k].y, -1.0, 0.0))
	_color_tex = ImageTexture.create_from_image(_color_img)
	_geom_tex = ImageTexture.create_from_image(_geom_img)
	var cell_tex: Texture2D = load(CELL_MAP_PATH) if ResourceLoader.exists(CELL_MAP_PATH) else null
	if cell_tex:
		_cell_ids = cell_tex.get_image()
		if _cell_ids.is_compressed():
			_cell_ids.decompress()


func _prepare_region(p: ProvinceData) -> void:
	var img := p.region_mask.get_image()
	if img.is_compressed():
		img.decompress()
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	_bitmaps[p.id] = bm
	var r := TextureRect.new()
	r.texture = p.region_mask
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = CELL_SHADER
	mat.set_shader_parameter("noise_tex", _noise)
	mat.set_shader_parameter("color_dark", COLOR_DARK)
	mat.set_shader_parameter("color_fossil", Palette.FOSSIL)
	mat.set_shader_parameter("border_color", COLOR_BORDER)
	mat.set_shader_parameter("pixel", float(SAMPLE_STEP))
	if _cell_ids:
		mat.set_shader_parameter("cell_map", load(CELL_MAP_PATH))
		mat.set_shader_parameter("cell_map_size", Vector2(_cell_ids.get_size()))
	mat.set_shader_parameter("cell_color", _color_tex)
	mat.set_shader_parameter("cell_geom", _geom_tex)
	mat.set_shader_parameter("cell_count", float(maxi(1, _cell_count)))
	r.material = mat
	_region_layer.add_child(r)
	_regions[p.id] = r


## Bagian peta (koordinat referensi 1280x720) yang dipaskan ke kotak MapView.
## Bawaan seluruh kanvas; layar persiapan memakai bagian daratan saja supaya peta lebih besar.
var view_rect := Rect2(Vector2.ZERO, REF)


func map_scale() -> float:
	return minf(size.x / view_rect.size.x, size.y / view_rect.size.y)


func map_offset() -> Vector2:
	return (size - view_rect.size * map_scale()) / 2.0 - view_rect.position * map_scale()


func to_screen(ref_pos: Vector2) -> Vector2:
	return map_offset() + ref_pos * map_scale()


## Kotak (koordinat global) yang memuat semua sel kloter satu wilayah. Dipakai sorotan tutorial.
func province_rect(id: StringName) -> Rect2:
	if not _cell_base.has(id):
		return Rect2()
	var p := Game.db.get_province(id)
	var base: int = _cell_base[id]
	var r := Rect2()
	for k in range(base, base + p.village_list.size()):
		var c := Rect2(_seed_pos[k], Vector2.ZERO).grow(maxf(4.0, _max_r[k] - 6.0))
		r = c if r.size == Vector2.ZERO else r.merge(c)
	var a := to_screen(r.position)
	return Rect2(global_position + a, r.size * map_scale())


func to_ref(screen_pos: Vector2) -> Vector2:
	return (screen_pos - map_offset()) / map_scale()


func _layout() -> void:
	for p in Game.db.provinces:
		var n: ProvinceNode = nodes[p.id]
		n.position = to_screen(p.map_position + p.label_offset) - Vector2(n.size.x / 2.0, 16)
		var r: TextureRect = _regions.get(p.id)
		if r:
			r.position = map_offset()
			r.size = REF * map_scale()
	if _sea:
		var sm: ShaderMaterial = _sea.material
		sm.set_shader_parameter("map_pos", map_offset())
		sm.set_shader_parameter("map_size", REF * map_scale())
		sm.set_shader_parameter("rect_size", size)
	queue_redraw()
	_overlay.queue_redraw()


## Dipanggil layar persiapan setelah build().
func set_preview() -> void:
	preview = true
	for id in nodes:
		var n: ProvinceNode = nodes[id]
		n.count_label.visible = false
		n.internet_mark.visible = false
	for p in Game.db.provinces:
		for i in p.village_list.size():
			_set_cell(_cell_base[p.id] + i, Color(0, 0, 0, 0), 1.0 if p.village_list[i].start_fossil else 0.0, -1.0)
	_push_cells()
	_update_region_styles()


func set_selected(id: StringName) -> void:
	selected = id
	for k in nodes:
		nodes[k].set_selected(k == id)
	_update_region_styles()


## Sorot satu kloter di peta (index -1 = tidak ada).
func set_selected_village(id: StringName, index: int) -> void:
	_selected_cell = _cell_base[id] + index if index >= 0 and _cell_base.has(id) else -1
	for r in _regions.values():
		r.material.set_shader_parameter("selected_cell", float(_selected_cell))


func refresh() -> void:
	var sim := Game.sim
	for id in nodes:
		var s: Simulation.ProvinceState = sim.provinces[id]
		nodes[id].refresh(s, Game.db.ui, sim.is_reachable(s))
		_update_cells(s)
	_push_cells()
	_update_region_styles()
	_overlay.queue_redraw()


## Posisi titik kloter di layar (koordinat lokal peta).
func village_center(id: StringName, index: int) -> Vector2:
	if not _cell_base.has(id):
		return node_center(id)
	return to_screen(_seed_pos[_cell_base[id] + index])


func node_center(id: StringName) -> Vector2:
	return to_screen(Game.db.get_province(id).map_position)


# ---------------------------------------------------------------- sel kloter

func _energy_color(energy: StringName) -> Color:
	var e := Game.db.get_energy(energy)
	return e.color if e else Palette.LIT


func _update_cells(s: Simulation.ProvinceState) -> void:
	var base: int = _cell_base[s.data.id]
	for v in s.villages:
		var k := base + v.index
		var fossil_base := 1.0 if (v.status == Simulation.V_FOSSIL or (v.data and v.data.start_fossil)) else 0.0
		# Warna memenuhi sel perlahan (desa demi desa), lambat di awal permainan.
		var r := lerpf(BUILD_SPOT, _max_r[k], Game.sim.fill_fraction(v)) if v.is_clean() else 0.0
		if v.status == Simulation.V_INDEP:
			_set_cell(k, _energy_color(v.energy), fossil_base, r, 1.0)
		elif v.status == Simulation.V_LIT:
			_set_cell(k, _energy_color(v.energy), fossil_base, r, 0.66)
		elif v.is_building():
			_set_cell(k, _energy_color(v.build_energy), fossil_base, BUILD_SPOT, 0.33)
		else:
			_set_cell(k, Color(0, 0, 0, 0), fossil_base, -1.0)


func _set_cell(k: int, energy_col: Color, fossil_base: float, target_r: float, mode: float = 0.0) -> void:
	_color_img.set_pixel(k, 0, Color(energy_col.r, energy_col.g, energy_col.b, mode))
	_r_target[k] = target_r
	if target_r < 0.0:
		_r_now[k] = -1.0  # padam: langsung hilang
	elif _r_now[k] > target_r:
		_r_now[k] = target_r
	_geom_img.set_pixel(k, 0, Color(_seed_pos[k].x, _seed_pos[k].y, _r_now[k], fossil_base))
	if not is_equal_approx(_r_now[k], target_r):
		_animating = true


func _push_cells() -> void:
	_color_tex.update(_color_img)
	_geom_tex.update(_geom_img)


func _process(delta: float) -> void:
	if not _animating:
		return
	_animating = false
	var step := GROW_SPEED * delta * maxf(1.0, Game.speed)
	for k in _cell_count:
		var t := _r_target[k]
		var now := _r_now[k]
		if is_equal_approx(now, t):
			continue
		now = maxf(now, 0.0)
		now = t if absf(t - now) <= step else now + signf(t - now) * step
		_r_now[k] = now
		var g := _geom_img.get_pixel(k, 0)
		_geom_img.set_pixel(k, 0, Color(g.r, g.g, now, g.a))
		if not is_equal_approx(now, t):
			_animating = true
	_geom_tex.update(_geom_img)


## Selesaikan semua animasi sebaran seketika (dipakai tes/screenshot).
func finish_spread_animation() -> void:
	for k in _cell_count:
		_r_now[k] = _r_target[k]
		var g := _geom_img.get_pixel(k, 0)
		_geom_img.set_pixel(k, 0, Color(g.r, g.g, _r_now[k], g.a))
	_animating = false
	_geom_tex.update(_geom_img)


func _update_region_styles() -> void:
	var sim := Game.sim
	if sim == null and not preview:
		return
	for id in _regions:
		var tint := Color(0, 0, 0, 0)
		if not preview:
			var s: Simulation.ProvinceState = sim.provinces[id]
			if s.on() == 0:
				if s.seed:
					tint = Color(Palette.BLUE.r, Palette.BLUE.g, Palette.BLUE.b, 0.35)
				elif not sim.is_reachable(s):
					tint = Color(0.05, 0.06, 0.12, 0.3)
		var mat: ShaderMaterial = _regions[id].material
		mat.set_shader_parameter("region_tint", tint)
		var is_sel: bool = id == selected
		mat.set_shader_parameter("border_color", Palette.CREAM if is_sel else COLOR_BORDER)
		mat.set_shader_parameter("border_px", (4.0 if is_sel else 2.0))
		mat.set_shader_parameter("highlight", 0.15 if id == hovered else 0.0)
	# Wilayah terpilih digambar paling atas supaya garisnya utuh.
	if _regions.has(selected):
		_region_layer.move_child(_regions[selected], -1)


# ---------------------------------------------------------------- input

## Provinsi di bawah titik layar, atau &"" jika laut.
func province_at(screen_pos: Vector2) -> StringName:
	var ref := to_ref(screen_pos)
	var provinces := Game.db.provinces
	for i in range(provinces.size() - 1, -1, -1):
		var bm: BitMap = _bitmaps.get(provinces[i].id)
		if bm == null:
			continue
		var bs := bm.get_size()
		var px := Vector2i(int(ref.x * bs.x / REF.x), int(ref.y * bs.y / REF.y))
		if px.x >= 0 and px.y >= 0 and px.x < bs.x and px.y < bs.y and bm.get_bitv(px):
			return provinces[i].id
	return &""


## [id wilayah, indeks kloter] di bawah titik layar, atau [] jika tidak ada sel.
func cell_at(screen_pos: Vector2) -> Array:
	if _cell_ids == null:
		return []
	var ref := to_ref(screen_pos)
	var cs := _cell_ids.get_size()
	var px := Vector2i(int(ref.x * cs.x / REF.x), int(ref.y * cs.y / REF.y))
	if px.x < 0 or px.y < 0 or px.x >= cs.x or px.y >= cs.y:
		return []
	var c := _cell_ids.get_pixel(px.x, px.y)
	var gid := int(round(c.r * 255.0) + round(c.g * 255.0) * 256.0) - 1
	if gid < 0 or gid >= _cell_owner.size():
		return []
	return _cell_owner[gid]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := province_at(event.position)
		if id != hovered:
			if nodes.has(hovered):
				nodes[hovered].set_hovered(false)
			hovered = id
			if nodes.has(id):
				nodes[id].set_hovered(true)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != &"" else Control.CURSOR_ARROW
			_update_region_styles()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := province_at(event.position)
		if id != &"":
			province_clicked.emit(id)
			var cell := cell_at(event.position)
			if not cell.is_empty() and cell[0] == id:
				village_clicked.emit(cell[0], cell[1])
			accept_event()
		else:
			empty_clicked.emit()


func _get_tooltip(at_position: Vector2) -> String:
	var id := province_at(at_position)
	if id == &"":
		return ""
	if preview:
		var p := Game.db.get_province(id)
		var m := p.members_text()
		return "%s%s\nKlik untuk memilih" % [p.display_name, ("\nProvinsi: " + m) if m != "" else ""]
	if Game.sim == null:
		return ""
	var s: Simulation.ProvinceState = Game.sim.provinces[id]
	var members := s.data.members_text()
	var cfg := Game.db.config
	var stage := "macet, warga belum membangun sendiri" if s.community < cfg.auto_build_min_community \
		else ("warga membangun sendiri" if s.community < cfg.independence_threshold else "desa bisa Mandiri")
	var text := "%s%s\n%s desa: %s mandiri, %s rapuh, %s fosil, %s gelap\n\nBar di bawah nama = Komunitas %d%% (%s).\nGaris putih: %d = warga membangun sendiri, %d = desa jadi Mandiri." % [s.data.display_name,
		("\nProvinsi: " + members) if members != "" else "", Simulation.ribu(s.total_desa()), Simulation.ribu(s.independent_desa),
		Simulation.ribu(s.lit_desa), Simulation.ribu(s.fossil_desa), Simulation.ribu(s.dark_desa), int(s.community), stage,
		int(cfg.auto_build_min_community), int(cfg.independence_threshold)]
	var cell := cell_at(at_position)
	if not cell.is_empty() and cell[0] == id:
		var v: Simulation.VillageState = s.villages[cell[1]]
		var st: String = ["gelap", "fosil", "rapuh", "mandiri"][v.status]
		var en := Game.db.get_energy(v.energy)
		text += "\n\nKloter: %s (%s desa, %s%s)" % [v.name(), Simulation.ribu(v.data.size if v.data else 1), st,
			(", " + en.display_name) if en and v.is_clean() else ""]
	var hints := Game.db.trait_summary(s.data)
	if hints != "":
		text += "\n\nCIRI DESA\n" + hints
	return text


# ---------------------------------------------------------------- gambar

func _draw() -> void:
	# Di luar gambar laut: warna laut terdalam supaya menyambung.
	draw_rect(Rect2(Vector2.ZERO, size), Color8(23, 55, 94))


## Digambar di atas wilayah: rute pesawat dan tanda internet.
func _draw_overlay() -> void:
	var sim := Game.sim
	if sim == null or preview:
		return
	if sim.air_islands.size() > 1:
		var hubs: Array[Vector2] = []
		for island_id in sim.air_islands:
			for p in Game.db.provinces:
				if p.island.id == island_id:
					hubs.append(node_center(p.id))
					break
		for i in range(1, hubs.size()):
			_overlay.draw_dashed_line(hubs[0], hubs[i], Palette.CREAM * Color(1, 1, 1, 0.6), 2.0, 10.0)
	for id in sim.provinces:
		if sim.provinces[id].internet:
			_overlay.draw_arc(node_center(id), 22.0 * map_scale() + 6, 0, TAU, 32, Palette.BLUE, 2.0)
