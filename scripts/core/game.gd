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
	load_settings.call_deferred()


func goto(scene_key: String) -> void:
	get_tree().change_scene_to_file(SCENES[scene_key])


func new_game() -> void:
	just_loaded = false
	sim = Simulation.new(db)
	# Pembangunan sepenuhnya otomatis: warga membangun sendiri setelah hasilnya terbukti.
	sim.auto_build = true
	sim.start(chosen_province, chosen_energy, chosen_name, chosen_village)
	_holds.clear()
	_accumulator = 0.0
	speed = 1


func _process(delta: float) -> void:
	if sim == null or sim.game_over or speed == 0 or not _holds.is_empty():
		return
	if db.config.turn_based_mode:
		return
	_accumulator += delta * speed
	while _holds.is_empty() and not sim.game_over:
		var interval := db.config.seconds_per_tick(sim.kkn_active, sim.tick_count)
		if _accumulator < interval:
			break
		_accumulator -= interval
		sim.tick()
		# Simpan otomatis setiap setengah tahun cerita.
		if sim.tick_count % 13 == 0 and not sim.game_over:
			save_game(AUTO_SLOT)


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


# ---------------------------------------------------------------- simpan & muat

const SAVE_DIR := "user://saves/"
const AUTO_SLOT := "auto"
const SLOTS := ["auto", "1", "2", "3"]
## true sesaat setelah memuat: layar game tidak menampilkan kartu pembuka.
var just_loaded: bool = false


func _save_path(slot: String) -> String:
	return SAVE_DIR + "slot_%s.save" % slot


func slot_name(slot: String) -> String:
	return "Simpan otomatis" if slot == AUTO_SLOT else "Slot %s" % slot


func save_game(slot: String) -> bool:
	if sim == null:
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"meta": {"name": sim.community_name, "date": sim.date_text(), "year": sim.current_year(),
			"province": sim.start_province, "energy": sim.start_energy, "access": sim.access_ratio(),
			"saved_at": Time.get_unix_time_from_system(), "game_over": sim.game_over},
		"sim": sim.to_save(),
	}
	var f := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data)  # biner: angka pecahan tersimpan persis
	return true


func _read_save(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		return {}
	var f := FileAccess.open(_save_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var()
	if not (v is Dictionary and v.has("sim")):
		return {}
	# Simpanan dari versi peta lama (24 wilayah) tidak bisa dipakai: dianggap kosong.
	if int(v["sim"].get("version", 0)) != Simulation.SAVE_VERSION:
		return {}
	return v


## {} jika slot kosong. Selain itu meta: name, date, year, province, energy, access, saved_at.
func save_info(slot: String) -> Dictionary:
	var d := _read_save(slot)
	return d.get("meta", {}) if not d.is_empty() else {}


func load_game(slot: String) -> bool:
	var d := _read_save(slot)
	if d.is_empty():
		return false
	sim = Simulation.new(db)
	sim.load_save(d["sim"])
	chosen_province = sim.start_province
	chosen_energy = sim.start_energy
	chosen_name = sim.community_name
	_holds.clear()
	_accumulator = 0.0
	speed = 1
	just_loaded = true
	return true


func delete_save(slot: String) -> void:
	if FileAccess.file_exists(_save_path(slot)):
		DirAccess.remove_absolute(_save_path(slot))


## Slot terbaru yang permainannya belum selesai ("" jika tidak ada), untuk tombol Lanjutkan.
func latest_slot() -> String:
	var best := ""
	var best_t := -1.0
	for slot in SLOTS:
		var m := save_info(slot)
		if not m.is_empty() and not m.get("game_over", false) and float(m.get("saved_at", 0)) > best_t:
			best_t = float(m["saved_at"])
			best = slot
	return best


# ---------------------------------------------------------------- pengaturan

const SETTINGS_PATH := "user://settings.cfg"
var fullscreen: bool = false


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	Audio.set_music_volume(c.get_value("audio", "music_db", Audio.music_volume_db))
	Audio.set_sfx_volume(c.get_value("audio", "sfx_db", Audio.sfx_volume_db))
	news_popups_enabled = c.get_value("game", "news_popups", news_popups_enabled)
	set_fullscreen(c.get_value("video", "fullscreen", false))


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music_db", Audio.music_volume_db)
	c.set_value("audio", "sfx_db", Audio.sfx_volume_db)
	c.set_value("game", "news_popups", news_popups_enabled)
	c.set_value("video", "fullscreen", fullscreen)
	c.save(SETTINGS_PATH)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if OS.get_name() == "Web" or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
