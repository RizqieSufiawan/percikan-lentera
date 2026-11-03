extends Node
## Tes waktu real-time: timer jalan, kartu menjeda game, game lanjut setelah dijawab,
## mode giliran (fallback) tidak memajukan waktu sendiri.
##   godot --headless res://tests/realtime_test.tscn

var _fails: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		_fails.append(msg)


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
	Game.chosen_province = &"papua"
	Game.chosen_energy = &"mikrohidro"
	Game.new_game()
	Game.goto("game")
	await _wait(0.5)
	var modal = get_tree().current_scene.get_node("%Modal")
	var sim := Game.sim
	var map: MapView = get_tree().current_scene.get_node("%MapView")
	var wrong: Array[String] = []
	for p in Game.db.provinces:
		var hit := map.province_at(map.node_center(p.id))
		if hit != p.id:
			wrong.append("%s->%s" % [p.id, hit])
	_check(wrong.is_empty(), "klik di tengah tiap wilayah mengenai provinsinya %s" % str(wrong))
	_check(map.province_at(Vector2(5, 5)) == &"", "klik di laut tidak memilih provinsi")
	_check(modal.is_busy(), "kartu pembuka tampil dan menjeda")
	var t0 := sim.tick_count
	await _wait(1.0)
	_check(sim.tick_count == t0, "waktu berhenti selama kartu tampil")
	modal._on_button(0)
	Game.set_speed(3)
	await _wait(3.2)
	_check(sim.tick_count >= 2, "waktu berjalan di 3x selama KKN (tik=%d)" % sim.tick_count)
	Game.set_speed(0)
	var t1 := sim.tick_count
	await _wait(1.0)
	_check(sim.tick_count == t1, "tombol jeda menghentikan waktu")
	Game.set_speed(3)
	sim.trigger_event(Game.db.events[1], &"papua")
	var t2 := sim.tick_count
	await _wait(1.0)
	_check(sim.tick_count == t2, "kartu event menjeda waktu")
	modal._on_button(0)
	await _wait(0.1)
	_check(modal.is_busy(), "kartu hasil event tampil")
	modal._on_button(0)
	await _wait(2.0)
	_check(sim.tick_count > t2, "waktu lanjut setelah kartu ditutup")
	var upg = get_tree().current_scene.get_node("%UpgradePanel")
	upg.open()
	var t3 := sim.tick_count
	await _wait(1.5)
	_check(sim.tick_count == t3, "pohon upgrade menjeda waktu")
	upg.close()
	# Jalankan sampai KKN selesai dan pastikan kartu KKN muncul.
	while sim.kkn_active:
		await _wait(0.2)
		while modal.is_busy():
			modal._on_button(0)
	await _wait(0.3)
	_check(not sim.kkn_active, "KKN selesai lewat timer")
	# Fallback mode giliran.
	while modal.is_busy():
		modal._on_button(0)
	Game.db.config.turn_based_mode = true
	var t4 := sim.tick_count
	await _wait(1.0)
	_check(sim.tick_count == t4, "mode giliran: waktu tidak jalan sendiri")
	Game.step_turn()
	# Maju 1 bulan, atau berhenti lebih awal jika ada kartu/berita penting yang menahan waktu.
	_check(sim.tick_count == t4 + Game.db.config.turn_ticks or sim.game_over or (sim.tick_count > t4 and modal.is_busy()),
		"mode giliran: tombol Berikutnya maju 1 bulan")
	Game.db.config.turn_based_mode = false
	print("REALTIME_TEST " + ("PASS" if _fails.is_empty() else "FAIL: " + ", ".join(_fails)))
	get_tree().quit()
