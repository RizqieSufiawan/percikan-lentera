extends Node
## Autoload "Game": memegang data, simulasi, dan waktu (real-time + jeda).

signal speed_changed(speed: int)

const DATABASE_PATH := "res://data/database.tres"
const SCENES := {
	"title": "res://scenes/title.tscn",
	"slides": "res://scenes/slides.tscn",
	"setup": "res://scenes/setup.tscn",
	"game": "res://scenes/game.tscn",
	"end": "res://scenes/end.tscn",
}

var db: GameDatabase
var sim: Simulation

## 0 = jeda, 1/2/3 = kecepatan.
var speed: int = 1
var _accumulator: float = 0.0
## Alasan jeda otomatis (event, berita, tawaran). Game jalan lagi saat kosong.
var _holds: Dictionary = {}

## Pilihan dari layar setup.
var chosen_province: StringName = &""
var chosen_energy: StringName = &""
var chosen_name: String = ""
## Kloter awal yang langsung dibangun: -1 = paling cocok (otomatis).
var chosen_village: int = -1
## Bangun otomatis (bisa diubah pemain saat bermain).
var auto_build: bool = true

## Slide yang ditampilkan layar slides: "intro" atau "guide". Setelah selesai pindah ke next_scene.
var slides_mode: String = "intro"
var slides_next: String = "setup"
var intro_seen: bool = false

## Opsi pemain.
var news_popups_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(DATABASE_PATH):
		db = load(DATABASE_PATH)
		auto_build = db.config.auto_build_default


func goto(scene_key: String) -> void:
	get_tree().change_scene_to_file(SCENES[scene_key])


func new_game() -> void:
	sim = Simulation.new(db)
	sim.auto_build = auto_build
	sim.start(chosen_province, chosen_energy, chosen_name, chosen_village)
	_holds.clear()
	_accumulator = 0.0
	speed = 1


func _process(delta: float) -> void:
	if sim == null or sim.game_over or speed == 0 or not _holds.is_empty():
		return
	if db.config.turn_based_mode:
		return
	var interval: float = db.config.kkn_tick_seconds if sim.kkn_active else db.config.tick_seconds
	_accumulator += delta * speed
	while _accumulator >= interval and _holds.is_empty() and not sim.game_over:
		_accumulator -= interval
		sim.tick()


func set_speed(value: int) -> void:
	speed = clampi(value, 0, 3)
	speed_changed.emit(speed)


func is_running() -> bool:
	return sim != null and not sim.game_over and speed > 0 and _holds.is_empty()


## Jeda otomatis dengan alasan tertentu. Panggil release() dengan alasan yang sama.
func hold(reason: StringName) -> void:
	_holds[reason] = true


func release(reason: StringName) -> void:
	_holds.erase(reason)


## Fallback berbasis giliran: maju satu giliran (beberapa tik) secara manual.
func step_turn() -> void:
	if sim == null:
		return
	for i in db.config.turn_ticks:
		if sim.game_over or not _holds.is_empty():
			return
		sim.tick()


## Dipakai saat scene game dijalankan langsung dari editor (F6) tanpa lewat menu.
func ensure_game() -> void:
	if sim != null and not sim.game_over:
		return
	if chosen_province == &"":
		var p: ProvinceData = db.provinces[0]
		chosen_province = p.id
		var best := -1.0
		for e in db.energies:
			if not e.kkn_available:
				continue
			var c: float = db.province_compat(p, e.id)
			if c > best:
				best = c
				chosen_energy = e.id
	new_game()
