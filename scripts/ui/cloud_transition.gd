extends CanvasLayer
## Transisi awan: gumpalan awan datang dari kiri dan kanan sampai menutup layar, scene diganti
## di balik awan, lalu awan menyibak dari tengah ke pinggir. Dipasang di root, jadi tetap hidup
## saat scene berganti, lalu menghapus dirinya sendiri.
##
## Tiap gumpal awan digambar SEKALI di SubViewport kecilnya sendiri (1 piksel = 1 piksel seni),
## jadi bentuknya berpiksel seperti seni lain di permainan. Saat bergerak, gambar gumpal itu
## digeser per piksel layar (bukan per piksel seni / 4 piksel), sehingga gerakannya halus.
##
## Pakai:  CloudTransition.play(get_tree(), func(): Game.goto("setup"))
##
## Dengan stay = true awan tidak membuka setelah scene diganti, tetapi turun ke belakang layar
## (jadi latar slide intro) dan bergoyang pelan. resume() lalu mengganti scene di balik awan
## dan baru membuka awan.

const PX := 4.0  # 1 piksel seni = 4 piksel layar
const COLS := 8
const ROWS := 5
const CLOSE_TIME := 1.5  # lama satu gumpal bergerak masuk (detik)
const CLOSE_SPREAD := 0.45  # selisih waktu berangkat antar-gumpal
const HOLD_TIME := 0.2  # awan diam menutup layar setelah scene diganti
const OPEN_TIME := 1.8
const OPEN_SPREAD := 0.45
# Warna awan malam yang disinari bulan (selaras dengan awan di menu utama).
const SHADOW := Color8(50, 48, 100)
const BASE := Color8(76, 72, 130)
const LIGHT := Color8(108, 102, 164)

var on_closed: Callable
var _view: Control
var _art := Vector2(320, 180)
var _puffs: Array = []  # {target, start, exit, balls: [[offset, r]], d_in, d_out}
var _t := 0.0
var _phase := 0  # 0 menutup, 1 menunggu scene baru, 2 menahan, 3 membuka, 4 jadi latar (diam)
var _rng := RandomNumberGenerator.new()
var _stay := false
var _clock := 0.0
var _amp := 0.0  # besar goyangan awan saat jadi latar (0..1)

## Transisi yang sedang jadi latar (fase 4), atau null.
static var resting: CanvasLayer = null


static func play(tree: SceneTree, closed: Callable, stay := false) -> void:
	var tr = load("res://scripts/ui/cloud_transition.gd").new()
	tr.on_closed = closed
	tr._stay = stay
	tree.root.add_child(tr)


## Awan yang sedang jadi latar naik lagi menutupi layar, scene diganti di baliknya, lalu awan
## membuka. Tanpa awan latar, scene langsung diganti.
static func resume(closed: Callable) -> void:
	if resting == null or not is_instance_valid(resting):
		resting = null
		closed.call()
		return
	var tr = resting
	resting = null
	tr.layer = 120
	tr.on_closed = closed
	tr._stay = false
	tr._phase = 1
	tr._t = 0.0
	tr.on_closed.call()


func is_resting() -> bool:
	return _phase == 4


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var vs := get_viewport().get_visible_rect().size
	_art = (vs / PX).ceil()
	_view = Control.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.position = Vector2.ZERO
	_view.size = vs
	_view.mouse_filter = Control.MOUSE_FILTER_STOP  # tahan klik selama transisi
	_view.draw.connect(_draw_clouds)
	add_child(_view)
	_build_puffs()
	for p in _puffs:
		_bake_puff(p)


## Gambar satu gumpal ke SubViewport-nya sendiri (sekali saja, lalu dipakai sebagai tekstur).
func _bake_puff(p: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for b in p["balls"]:
		var r: float = b[1]
		lo = lo.min(b[0] - Vector2(r + 1, r))
		hi = hi.max(b[0] + Vector2(r, r + 3))
	lo = (lo - Vector2(2, 2)).floor()
	hi = (hi + Vector2(2, 2)).ceil()
	var vp := SubViewport.new()
	vp.size = Vector2i(hi - lo)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cv := Node2D.new()
	cv.position = -lo
	var balls: Array = p["balls"]
	cv.draw.connect(func():
		# Tiap bola: bayangan di bawah, lalu bola terang, lalu bola dasar yang sedikit digeser ke
		# kiri bawah, sehingga hanya tepi kanan-atas (yang menghadap bulan) yang tersisa terang.
		for b in balls:
			cv.draw_circle((b[0] + Vector2(-1, 3)).round(), b[1], SHADOW)
		for b in balls:
			cv.draw_circle(b[0].round(), b[1], LIGHT)
		for b in balls:
			var r: float = b[1]
			cv.draw_circle((b[0] + Vector2(-r * 0.1, r * 0.13)).round(), r * 0.93, BASE))
	vp.add_child(cv)
	add_child(vp)
	p["tex"] = vp.get_texture()
	p["origin"] = lo  # sudut kiri atas tekstur relatif terhadap pusat gumpal (piksel seni)
	p["size"] = hi - lo


func _build_puffs() -> void:
	var cw := _art.x / COLS
	var rh := _art.y / ROWS
	var mid := _art / 2.0
	for r in ROWS + 1:
		for c in COLS + 1:
			# Kisi rapat (lebih banyak dari layar) supaya saat menutup tidak ada celah.
			var target := Vector2((c + 0.25 * (r % 2)) * cw, (r + 0.1) * rh) \
				+ Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
			var R := _rng.randf_range(0.82, 1.0) * maxf(cw, rh)
			var side := -1.0 if target.x < mid.x else 1.0
			var start := target + Vector2(side * (_art.x * 0.75 + _rng.randf_range(0, 60)), _rng.randf_range(-24, 24))
			var away := (target - mid) / mid  # -1..1
			var exit := target + Vector2(side * (_art.x * 0.7 + _rng.randf_range(20, 70)), away.y * 50.0)
			var balls := [[Vector2.ZERO, R]]
			for k in 2:
				var s := -1.0 if k == 0 else 1.0
				var rr := R * _rng.randf_range(0.6, 0.75)
				balls.append([Vector2(s * R * _rng.randf_range(0.75, 0.95), R * 0.35), rr])
			for k in _rng.randi_range(2, 3):
				var ang := deg_to_rad(_rng.randf_range(-150, -30))
				var rr := R * _rng.randf_range(0.45, 0.6)
				balls.append([Vector2(cos(ang), sin(ang)) * R * _rng.randf_range(0.55, 0.75), rr])
			var edge := absf(away.x)  # 0 di tengah, 1 di pinggir
			_puffs.append({
				"target": target, "start": start, "exit": exit, "balls": balls,
				"d_in": _rng.randf_range(0.0, CLOSE_SPREAD),
				# Menyibak dari tengah: gumpal di tengah berangkat lebih dulu.
				"d_out": edge * OPEN_SPREAD + _rng.randf_range(0.0, 0.08),
			})
	# Gumpal yang lebih rendah digambar belakangan (di depan), seperti awan menumpuk.
	_puffs.sort_custom(func(a, b): return a["target"].y < b["target"].y)


func _process(delta: float) -> void:
	_t += delta
	_clock += delta
	_amp = move_toward(_amp, 1.0 if _phase == 4 else 0.0, delta * 0.8)
	match _phase:
		0:
			if _t >= CLOSE_TIME + CLOSE_SPREAD:
				_phase = 1
				_t = 0.0
				if _stay:
					resting = self  # sudah diisi sebelum scene baru menjalankan _ready()
				if on_closed.is_valid():
					on_closed.call()
		1:
			# Beri waktu scene baru dimuat dan menggambar beberapa frame di balik awan.
			if _t >= 0.1:
				_phase = 4 if _stay else 2
				_t = 0.0
				if _stay:
					# Turun ke belakang layar: UI scene baru tampil di atas awan.
					layer = -10
		2:
			if _t >= HOLD_TIME:
				_phase = 3
				_t = 0.0
		3:
			if _t >= OPEN_TIME + OPEN_SPREAD + 0.1:
				queue_free()
				return
	_view.queue_redraw()


func _puff_pos(p: Dictionary) -> Array:  # [posisi, skala]
	match _phase:
		0:
			var k := clampf((_t - p["d_in"]) / CLOSE_TIME, 0.0, 1.0)
			k = 1.0 - pow(1.0 - k, 3.0)  # cepat lalu melambat saat sampai
			return [p["start"].lerp(p["target"], k), 1.0]
		3:
			var k := clampf((_t - p["d_out"]) / OPEN_TIME, 0.0, 1.0)
			k = 1.0 - cos(k * PI / 2.0)  # pelan lalu makin cepat menyibak
			return [(p["target"] + _wobble(p)).lerp(p["exit"], k), 1.0]
	return [p["target"] + _wobble(p), 1.0]


func _wobble(p: Dictionary) -> Vector2:
	var ph: float = p["target"].x * 0.13 + p["target"].y * 0.07
	return Vector2(sin(_clock * 0.5 + ph) * 3.0, cos(_clock * 0.37 + ph * 1.7) * 1.5) * _amp


func _draw_clouds() -> void:
	if _phase == 1 or _phase == 2 or _phase == 4:
		_view.draw_rect(Rect2(Vector2.ZERO, _view.size), BASE)  # jaminan: tidak ada celah saat scene diganti
	for p in _puffs:
		var c: Vector2 = _puff_pos(p)[0]
		if c.x < -_art.x * 0.6 or c.x > _art.x * 1.6:
			continue
		# Posisi dibulatkan ke piksel LAYAR (bukan piksel seni): bentuk tetap tajam, gerak halus.
		var tl: Vector2 = ((c + p["origin"]) * PX).round()
		_view.draw_texture_rect(p["tex"], Rect2(tl, p["size"] * PX), false)
