extends Control
## Kehidupan kecil di atas peta supaya tidak terasa diam. Semua digambar di kisi pixel art
## (1 piksel seni = 4 piksel referensi), sama dengan daratan dan laut:
## - awan tipis berarak pelan dengan bayangannya di permukaan,
## - perahu kecil berlayar di laut dengan jejak ombak,
## - sesekali sekawanan burung melintas,
## - asap dari desa yang masih memakai energi fosil, dan percikan cahaya dari desa yang sudah bersih.
## Jadi peta di awal permainan berasap, dan makin berkilau saat energi bersih menyebar.
## Tidak ikut kecepatan permainan (tetap hidup saat dijeda) dan tidak menangkap klik.

const ART := 4.0  # piksel referensi per piksel seni
const GRID := Vector2(320, 180)

const BOAT_COUNT := 10
const CLOUD_COUNT := 5
const SMOKE_EVERY := 0.04  # detik antar kepulan asap (dibagi rata ke desa fosil)
const GLINT_EVERY := 0.03

const HULL := Color(0.36, 0.22, 0.16)
const SAIL := Color(0.96, 0.92, 0.80)
const WAKE := Color(0.80, 0.92, 1.0)
const CLOUD := Color(0.86, 0.90, 1.0)
const CLOUD_SHADOW := Color(0.02, 0.04, 0.12)
const SMOKE := Color(0.82, 0.80, 0.80)
const BIRD := Color(0.10, 0.12, 0.20)
const DOWN_COL := Color(1.0, 0.42, 0.32)

var map: MapView
var _sea_img: Image
var _sea_ext := Vector2(320, 180)
var _rng := RandomNumberGenerator.new()
var _boats: Array = []    # {pos, dir, speed, life, age, trail:Array}
var _clouds: Array = []   # {pos, cells:PackedVector2Array, speed}
var _birds: Array = []    # {pos, vel, n, age}
var _puffs: Array = []    # {pos, age, life, col, kind}
var _rings: Array = []    # gelombang cahaya: {pos, age, life, radius, col}
var _sparks: Array = []   # kembang api: {pos, vel, age, life, col, rocket, burst_col}
var _fades: Array = []    # kloter padam: {cell, col, age, life}
var _shows: Array = []    # perayaan kota yang sedang berjalan: {pos, left, cd, cols}
var _bird_cd := 8.0
var _smoke_cd := 0.0
var _glint_cd := 0.0
var _refresh_cd := 0.0
var _cell_pixels: Dictionary = {}  # id sel global -> PackedVector2Array piksel seni
var _fossil_cells: Array[int] = []
var _clean_cells: Array = []  # [id sel, warna]
var _t := 0.0


func setup(map_view: MapView, cell_ids: Image) -> void:
	map = map_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 2026
	var bg: Texture2D = Game.db.ui.map_background
	if bg:
		_sea_img = bg.get_image()
		if _sea_img.is_compressed():
			_sea_img.decompress()
		_sea_ext = (Vector2(_sea_img.get_size()) - MapView.REF) / 2.0
	if cell_ids:
		for y in cell_ids.get_height():
			for x in cell_ids.get_width():
				var c := cell_ids.get_pixel(x, y)
				var g := roundi(c.r8 + c.g8 * 256) - 1
				if g < 0:
					continue
				if not _cell_pixels.has(g):
					_cell_pixels[g] = PackedVector2Array()
				_cell_pixels[g].append(Vector2(x, y))
	for i in CLOUD_COUNT:
		_clouds.append(_make_cloud(Vector2(_rng.randf_range(-40, GRID.x), _rng.randf_range(10, GRID.y - 30))))
	for i in BOAT_COUNT:
		var b := _spawn_boat()
		if not b.is_empty():
			b.age = _rng.randf_range(2.0, 20.0)  # jangan semua muncul bersamaan
			_boats.append(b)


# ---------------------------------------------------------------- perayaan

## Satu kloter baru menjadi mandiri: satu gelombang cahaya dari pusat kloter.
func cell_independent(cell: int, col: Color) -> void:
	var pos: Vector2 = map._seed_pos[cell] / ART
	_rings.append({"pos": pos, "age": 0.0, "life": 1.4, "radius": 7.0, "col": col.lightened(0.45)})
	for i in 4:
		var g := _random_pixel(cell)
		if g.x >= 0:
			_puffs.append({"pos": g, "age": -i * 0.12, "life": 1.2, "kind": 1, "col": col.lightened(0.6), "drift": 0.0})


## Kloter turun. full = padam (energi bersih hilang, kembali gelap/fosil): sel berkedip seperti lampu
## mau mati lalu memudar, gelombang merah menyusut ke pusat, dan kepulan asap. Tidak full = mandiri
## turun ke rapuh: hanya gelombang merah kecil yang menyusut.
func cell_down(cell: int, col: Color, full: bool) -> void:
	var pos: Vector2 = map._seed_pos[cell] / ART
	_rings.append({"pos": pos, "age": 0.0, "life": 1.1 if full else 0.9, "radius": 7.0 if full else 5.0,
		"col": DOWN_COL, "inward": true})
	if not full:
		return
	_fades.append({"cell": cell, "col": col, "age": 0.0, "life": 1.4})
	for i in 5:
		var g := _random_pixel(cell)
		if g.x >= 0:
			_puffs.append({"pos": g, "age": -0.3 - i * 0.15, "life": 2.4, "kind": 0, "col": Color(0.55, 0.52, 0.55),
				"drift": _rng.randf_range(0.2, 0.6)})


## Kota merayakan: beberapa letusan kembang api piksel di atas kota dan satu gelombang besar.
## at = titik referensi (1280x720), cols = warna energi yang dipakai di provinsinya.
func celebrate(at: Vector2, cols: Array) -> void:
	var pos := at / ART
	if cols.is_empty():
		cols = [Palette.LIT]
	_rings.append({"pos": pos, "age": 0.0, "life": 2.2, "radius": 18.0, "col": Color(1.0, 0.95, 0.75)})
	_shows.append({"pos": pos, "left": 7, "cd": 0.0, "cols": cols})


func _launch(show: Dictionary) -> void:
	var start: Vector2 = show.pos + Vector2(_rng.randf_range(-6, 6), 2)
	var col: Color = show.cols[_rng.randi() % show.cols.size()]
	_sparks.append({"pos": start, "vel": Vector2(_rng.randf_range(-3, 3), -_rng.randf_range(24, 32)), "age": 0.0,
		"life": _rng.randf_range(0.6, 0.85), "col": Color(1, 0.95, 0.8), "rocket": true, "burst_col": col})


func _explode(at: Vector2, col: Color) -> void:
	var n := _rng.randi_range(14, 18)
	for i in n:
		var a := TAU * i / n + _rng.randf_range(-0.15, 0.15)
		var sp := _rng.randf_range(13, 19)
		_sparks.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * sp, "age": 0.0, "life": _rng.randf_range(1.1, 1.6),
			"col": col.lightened(0.35), "rocket": false, "burst_col": col})
	_rings.append({"pos": at, "age": 0.0, "life": 0.5, "radius": 5.0, "col": Color(1, 1, 0.9)})


## Titik piksel seni di lingkaran berjari-jari r (tanpa duplikat).
func _ring_points(center: Vector2, r: float) -> Array:
	var out := {}
	var steps := maxi(8, int(r * 7.0))
	for i in steps:
		var a := TAU * i / steps
		out[(center + Vector2(cos(a), sin(a)) * r).floor()] = true
	return out.keys()


# ---------------------------------------------------------------- bantu

## Piksel seni g berupa air di gambar laut (tanpa daratan, termasuk negara tetangga).
func _is_water(g: Vector2) -> bool:
	if _sea_img == null:
		return false
	var p := (g + Vector2(0.5, 0.5)) * ART + _sea_ext
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= _sea_img.get_width() or y >= _sea_img.get_height():
		return false
	var c := _sea_img.get_pixel(x, y)
	return c.b > c.r + 0.08 and c.b > 0.15


## Kotak satu piksel seni (koordinat kisi) di layar.
func _px(g: Vector2, col: Color, w: float = 1.0, h: float = 1.0) -> void:
	var s := map.map_scale() * ART
	draw_rect(Rect2(map.to_screen(g.floor() * ART), Vector2(w, h) * s), col)


func _make_cloud(at: Vector2) -> Dictionary:
	# Gabungan beberapa elips kecil, dibaca sebagai blok piksel seni.
	var cells := PackedVector2Array()
	var w := _rng.randi_range(16, 30)
	var blobs := _rng.randi_range(4, 7)
	var seen := {}
	for i in blobs:
		var cx := _rng.randf_range(2, w - 2)
		var cy := _rng.randf_range(-0.5, 0.5)
		var rx := _rng.randf_range(3.5, 7.0)
		var ry := rx * 0.55
		for y in range(-8, 9):
			for x in range(-8, int(w) + 8):
				var d := pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2)
				if d <= 1.0 and not seen.has(Vector2(x, y)):
					seen[Vector2(x, y)] = true
					cells.append(Vector2(x, y))
	return {"pos": at, "cells": cells, "speed": _rng.randf_range(0.6, 1.1)}


func _spawn_boat() -> Dictionary:
	for attempt in 40:
		var g := Vector2(_rng.randi_range(-20, int(GRID.x) + 20), _rng.randi_range(-10, int(GRID.y) + 10))
		if not (_is_water(g) and _is_water(g + Vector2(3, 0)) and _is_water(g - Vector2(3, 0)) and _is_water(g + Vector2(0, 2))):
			continue
		var dir := Vector2.RIGHT if _rng.randf() < 0.5 else Vector2.LEFT
		if _rng.randf() < 0.3:
			dir = (dir + Vector2(0, _rng.randf_range(-0.6, 0.6))).normalized()
		return {"pos": g, "dir": dir, "speed": _rng.randf_range(1.2, 2.2), "life": _rng.randf_range(35.0, 70.0),
			"age": 0.0, "trail": []}
	return {}


func _refresh_cells() -> void:
	_fossil_cells.clear()
	_clean_cells.clear()
	var sim := Game.sim
	for p in Game.db.provinces:
		if not map._cell_base.has(p.id):
			continue
		var base: int = map._cell_base[p.id]
		if map.preview or sim == null:
			for i in p.village_list.size():
				if p.village_list[i].start_fossil:
					_fossil_cells.append(base + i)
			continue
		var s: Simulation.ProvinceState = sim.provinces[p.id]
		for v in s.villages:
			if v.status == Simulation.V_FOSSIL:
				_fossil_cells.append(base + v.index)
			elif v.is_clean():
				var e := Game.db.get_energy(v.energy)
				var col: Color = e.color if e else Palette.LIT
				_clean_cells.append([base + v.index, col, v.status == Simulation.V_INDEP])


func _random_pixel(cell: int) -> Vector2:
	var arr: PackedVector2Array = _cell_pixels.get(cell, PackedVector2Array())
	if arr.is_empty():
		return Vector2(-1, -1)
	return arr[_rng.randi() % arr.size()]


# ---------------------------------------------------------------- gerak

func _process(delta: float) -> void:
	if map == null or not is_visible_in_tree():
		return
	_t += delta
	_refresh_cd -= delta
	if _refresh_cd <= 0.0:
		_refresh_cd = 1.0
		_refresh_cells()

	for c in _clouds:
		c.pos.x += c.speed * delta
		if c.pos.x > GRID.x + 8:
			var n := _make_cloud(Vector2(-30, _rng.randf_range(10, GRID.y - 30)))
			c.pos = n.pos
			c.cells = n.cells
			c.speed = n.speed

	for i in range(_boats.size() - 1, -1, -1):
		var b: Dictionary = _boats[i]
		b.age += delta
		var nxt: Vector2 = b.pos + b.dir * b.speed * delta
		var ahead: Vector2 = nxt + b.dir * 3.0
		if not _is_water(ahead) or not _is_water(ahead + Vector2(0, 1)):
			# Belok menghindari daratan; jika buntu, putar balik.
			var turned := false
			for ang in [0.6, -0.6, 1.2, -1.2]:
				var d: Vector2 = b.dir.rotated(ang)
				if _is_water(b.pos + d * 4.0) and _is_water(b.pos + d * 4.0 + Vector2(0, 1)):
					b.dir = d
					turned = true
					break
			if not turned:
				b.dir = -b.dir
			nxt = b.pos
		var cell_before: Vector2 = b.pos.floor()
		b.pos = nxt
		if b.pos.floor() != cell_before:
			b.trail.push_front(cell_before)
			if b.trail.size() > 6:
				b.trail.pop_back()
		var off: bool = b.pos.x < -30 or b.pos.x > GRID.x + 30 or b.pos.y < -20 or b.pos.y > GRID.y + 20
		if b.age > b.life or off:
			var nb := _spawn_boat()
			if nb.is_empty():
				_boats.remove_at(i)
			else:
				_boats[i] = nb

	_bird_cd -= delta
	if _bird_cd <= 0.0:
		_bird_cd = _rng.randf_range(18.0, 34.0)
		var left := _rng.randf() < 0.5
		var y := _rng.randf_range(20, GRID.y - 40)
		var vel := Vector2(6.0 if left else -6.0, _rng.randf_range(-1.0, 1.0))
		_birds.append({"pos": Vector2(-10 if left else GRID.x + 10, y), "vel": vel, "n": _rng.randi_range(3, 5), "age": 0.0})
	for i in range(_birds.size() - 1, -1, -1):
		var f: Dictionary = _birds[i]
		f.age += delta
		f.pos += f.vel * delta
		if f.pos.x < -20 or f.pos.x > GRID.x + 20:
			_birds.remove_at(i)

	# Asap dan percikan: jumlahnya dibagi ke banyak desa, jadi peta penuh fosil berasap tipis
	# di mana-mana, dan peta penuh energi bersih berkilau di mana-mana.
	_smoke_cd -= delta
	while _smoke_cd <= 0.0:
		_smoke_cd += SMOKE_EVERY * (1.0 + 4.0 * (1.0 - minf(1.0, _fossil_cells.size() / 60.0)))
		if _fossil_cells.is_empty():
			break
		var g := _random_pixel(_fossil_cells[_rng.randi() % _fossil_cells.size()])
		if g.x >= 0:
			_puffs.append({"pos": g, "age": 0.0, "life": _rng.randf_range(2.6, 4.0), "kind": 0, "col": SMOKE,
				"drift": _rng.randf_range(0.2, 0.6)})
	_glint_cd -= delta
	while _glint_cd <= 0.0:
		_glint_cd += GLINT_EVERY * (1.0 + 4.0 * (1.0 - minf(1.0, _clean_cells.size() / 60.0)))
		if _clean_cells.is_empty():
			break
		var pick: Array = _clean_cells[_rng.randi() % _clean_cells.size()]
		var g := _random_pixel(pick[0])
		if g.x >= 0:
			var col: Color = pick[1].lightened(0.55)
			_puffs.append({"pos": g, "age": 0.0, "life": _rng.randf_range(0.9, 1.5) * (1.3 if pick[2] else 1.0), "kind": 1,
				"col": col, "drift": 0.0})
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p.age += delta
		if p.age >= p.life:
			_puffs.remove_at(i)

	for i in range(_fades.size() - 1, -1, -1):
		_fades[i].age += delta
		if _fades[i].age >= _fades[i].life:
			_fades.remove_at(i)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].age += delta
		if _rings[i].age >= _rings[i].life:
			_rings.remove_at(i)
	for i in range(_shows.size() - 1, -1, -1):
		var sh: Dictionary = _shows[i]
		sh.cd -= delta
		if sh.cd <= 0.0:
			sh.cd = _rng.randf_range(0.35, 0.6)
			sh.left -= 1
			_launch(sh)
			if sh.left <= 0:
				_shows.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp.age += delta
		sp.pos += sp.vel * delta
		if sp.rocket:
			if sp.age >= sp.life:
				_explode(sp.pos, sp.burst_col)
				_sparks.remove_at(i)
			continue
		sp.vel = sp.vel * (1.0 - 1.3 * delta) + Vector2(0, 7.0) * delta  # melambat lalu jatuh pelan
		if sp.age >= sp.life:
			_sparks.remove_at(i)
	queue_redraw()


# ---------------------------------------------------------------- gambar

func _draw() -> void:
	if map == null:
		return
	# Bayangan awan dulu (jatuh di bawah-kanan awan), lalu isi lainnya, awan paling atas.
	for c in _clouds:
		for cell in c.cells:
			_px(c.pos + cell + Vector2(3, 6), Color(CLOUD_SHADOW, 0.13))

	for b in _boats:
		var fade := clampf(minf(b.age / 2.0, (b.life - b.age) / 2.0), 0.0, 1.0)
		for k in b.trail.size():
			_px(b.trail[k], Color(WAKE, 0.45 * fade * (1.0 - k / 6.0)))
		var g: Vector2 = b.pos.floor()
		var facing := 1.0 if b.dir.x >= 0.0 else -1.0
		# Lambung 3 piksel, layar 2 piksel di atasnya; ayun naik-turun pelan.
		var bob := 1.0 if fmod(_t + b.life, 1.6) < 0.8 else 0.0
		_px(g + Vector2(-1, 0), Color(HULL, fade), 3.0, 1.0)
		_px(g + Vector2(0, -1 - bob * 0.0), Color(SAIL, fade))
		_px(g + Vector2(-facing * 0.0, -2), Color(SAIL, fade * (0.75 + 0.25 * bob)))
		_px(g + Vector2(facing, 1), Color(WAKE, 0.35 * fade))

	for p in _puffs:
		var t: float = p.age / p.life
		if p.kind == 0:
			# Asap: naik dua-tiga piksel, membesar sedikit, memudar.
			var g: Vector2 = p.pos + Vector2(t * p.drift * 3.0, -floor(t * 4.0))
			var a := 0.75 * (1.0 - t * t)
			_px(g, Color(p.col, a))
			if t > 0.4:
				_px(g + Vector2(1, 0), Color(p.col, a * 0.7))
		else:
			# Percikan: kedip berbentuk plus kecil, lalu hilang.
			var a := sin(t * PI)
			_px(p.pos, Color(p.col, 0.9 * a))
			if a > 0.7:
				for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					_px(p.pos + d, Color(p.col, 0.45 * a))

	for f in _birds:
		var flap := int(f.age * 5.0) % 2 == 0
		for k in f.n:
			# Formasi V kecil.
			var side := 1.0 if k % 2 == 1 else -1.0
			var row := ceilf(k / 2.0)
			var g: Vector2 = (f.pos + Vector2(-signf(f.vel.x) * row * 2.0, side * row * 1.5)).floor()
			if flap:
				_px(g + Vector2(-1, -1), BIRD)
				_px(g + Vector2(1, -1), BIRD)
			else:
				_px(g + Vector2(-1, 0), BIRD)
				_px(g + Vector2(1, 0), BIRD)
			_px(g, BIRD)

	for f in _fades:
		# Lampu mau mati: berkedip makin jarang, lalu habis.
		var t: float = f.age / f.life
		var on := t < 0.12 or (int(f.age * (16.0 - 10.0 * t)) % 2 == 0)
		var a := (1.0 - t) * (0.85 if on else 0.15)
		if a > 0.02:
			for g in _cell_pixels.get(f.cell, PackedVector2Array()):
				_px(g, Color(f.col, a))

	for r in _rings:
		var t: float = r.age / r.life
		var rad: float = r.radius * (1.0 - pow(1.0 - t, 2.0))
		if r.get("inward", false):
			rad = r.radius * (1.0 - t * t)
		var a := 0.85 * (1.0 - t)
		for g in _ring_points(r.pos, maxf(0.5, rad)):
			_px(g, Color(r.col, a))
		if rad > 2.0:
			for g in _ring_points(r.pos, rad - 1.0):
				_px(g, Color(r.col, a * 0.35))

	for sp in _sparks:
		var t: float = sp.age / sp.life
		if sp.rocket:
			_px(sp.pos, sp.col)
			_px(sp.pos + Vector2(0, 1), Color(sp.col, 0.5))
		else:
			var a := 1.0 if t < 0.6 else (1.0 - t) / 0.4
			# Berkedip di akhir supaya terasa seperti percikan yang padam.
			if t > 0.7 and int(sp.age * 20.0) % 2 == 0:
				continue
			_px(sp.pos, Color(sp.col, a))
			# Ekor pendek ke arah datangnya percikan.
			_px(sp.pos - sp.vel.normalized() * 1.2, Color(sp.col, a * 0.45))

	for c in _clouds:
		for cell in c.cells:
			var under: bool = c.cells.has(cell + Vector2(0, 1))
			_px(c.pos + cell, Color(CLOUD, 0.5 if under else 0.36))
