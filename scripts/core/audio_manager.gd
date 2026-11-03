extends Node
## Autoload "Audio". Semua suara diambil dari data/ui_assets.tres.
## Tiap jenis SFX punya pemutar sendiri dengan stream tetap (lebih stabil daripada
## mengganti stream pada pemutar yang sama).

const SFX_POLYPHONY := 3

var music_volume_db: float = -8.0
var sfx_volume_db: float = 0.0

var _music: AudioStreamPlayer
var _sfx_players: Dictionary = {}  # StringName -> AudioStreamPlayer
var _current_music: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	_music.finished.connect(_on_music_finished)
	add_child(_music)


func _ui() -> UiAssets:
	return Game.db.ui if Game.db else null


func sfx(key: StringName) -> void:
	var p: AudioStreamPlayer = _sfx_players.get(key)
	if p == null:
		var ui := _ui()
		if ui == null or not ui.sfx.has(key) or ui.sfx[key] == null:
			return
		p = AudioStreamPlayer.new()
		p.stream = ui.sfx[key]
		p.max_polyphony = SFX_POLYPHONY
		add_child(p)
		_sfx_players[key] = p
	p.volume_db = sfx_volume_db
	p.play()


func music(which: StringName) -> void:
	var ui := _ui()
	if ui == null:
		return
	var stream: AudioStream = ui.music_menu if which == &"menu" else ui.music_game
	if stream == _current_music and _music.playing:
		return
	_current_music = stream
	_music.stop()
	_music.stream = stream
	_music.volume_db = music_volume_db
	if stream:
		_music.play()


func set_music_volume(db_value: float) -> void:
	music_volume_db = db_value
	_music.volume_db = db_value


func set_sfx_volume(db_value: float) -> void:
	sfx_volume_db = db_value


func _on_music_finished() -> void:
	if _current_music:
		_music.play.call_deferred()


func _exit_tree() -> void:
	_current_music = null
	_music.stop()
	_music.stream = null
	for p in _sfx_players.values():
		p.stop()
