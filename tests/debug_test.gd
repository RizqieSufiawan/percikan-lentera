extends Node
## Menekan semua tombol debug sekali dan memastikan tidak ada error.
##   godot --headless res://tests/debug_test.tscn

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := get_tree().root
	reparent(root)
	var dummy := Node.new()
	root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.chosen_province = &"sumut"
	Game.chosen_energy = &"biomassa"
	Game.new_game()
	# Tutorial menjeda permainan di langkah penjelasan; tes ini menguji hal lain.
	Game.sim.counters[&"tutorial_step"] = 99
	Game.sim.counters[&"lessons_off"] = 1
	# Seed tetap supaya tes tidak bergantung keberuntungan (F5 = ujian KKN sungguhan bisa memadamkan semua desa).
	Game.sim.rng.seed = 7
	Game.goto("game")
	await _wait(0.5)
	var screen := get_tree().current_scene
	var modal = screen.get_node("%Modal")
	var dbg: Node = null
	for c in screen.get_children():
		if c.has_method("handle_key"):
			dbg = c
	if dbg == null:
		print("DEBUG_TEST FAIL: debug tools tidak dimuat")
		get_tree().quit()
		return
	var keys := [
		[KEY_F1, false, false], [KEY_F2, false, false], [KEY_F5, true, false],
		[KEY_F6, true, false], [KEY_F7, false, false], [KEY_F8, false, false],
		[KEY_F9, false, false], [KEY_F9, true, false], [KEY_F9, false, true],
		[KEY_F10, true, false], [KEY_F10, false, false], [KEY_F11, false, false], [KEY_F11, true, false],
		[KEY_DELETE, false, true], [KEY_DELETE, false, false], [KEY_DELETE, true, false], [KEY_HOME, false, false], [KEY_END, false, false],
	]
	for i in Game.db.events.size():
		keys.append([KEY_F3, false, false])
	keys.append([KEY_F3, true, false])
	for i in 3:
		keys.append([KEY_F4, false, false])
	for i in Game.db.news.size():
		keys.append([KEY_PAGEUP, false, false])
	for i in Game.db.milestones.size():
		keys.append([KEY_PAGEDOWN, false, false])
	keys.append([KEY_INSERT, false, false])
	for k in keys:
		if not is_instance_valid(dbg) or Game.sim.game_over:
			print("DEBUG_TEST FAIL: permainan berakhir sebelum semua tombol dites (%s, on=%d)" % [Game.sim.result, Game.sim.total_on()])
			get_tree().quit()
			return
		dbg.handle_key(k[0], k[1], k[2])
		await _wait(0.02)
		var guard := 0
		while modal.is_busy() and guard < 10:
			modal._on_button(guard % 2)
			guard += 1
			await _wait(0.02)
	dbg.handle_key(KEY_F12)
	await _wait(1.6)
	# Penutup peta (beberapa detik) dilewati.
	if get_tree().current_scene and get_tree().current_scene.has_method("skip_outro"):
		get_tree().current_scene.skip_outro()
		await _wait(1.0)
	var ended: bool = get_tree().current_scene != null and get_tree().current_scene.name == "End"
	print("DEBUG_TEST " + ("PASS" if ended else "FAIL: layar akhir tidak muncul"))
	get_tree().quit()
