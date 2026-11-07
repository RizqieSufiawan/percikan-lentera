extends Node
##   godot --path . res://tests/outro_test.tscn  (butuh tampilan, mis. xvfb-run)
## Selesaikan permainan, lalu tekan tombol keyboard saat penutup: harus pindah ke layar akhir tanpa error.
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
	Game.chosen_province = &"ntt"
	Game.chosen_energy = &"plts"
	Game.new_game()
	Game.sim.counters[&"tutorial_step"] = 99
	Game.sim.counters[&"lessons_off"] = 1
	Game.goto("game")
	await _wait(1.0)
	var sim := Game.sim
	for s: Simulation.ProvinceState in sim.provinces.values():
		for v in s.villages:
			if not v.is_clean():
				v.energy = sim.best_energy_for(s, v)
				v.status = Simulation.V_INDEP
		s.recount()
	sim._check_end()
	await _wait(2.5)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(1.5)
	print("OUTRO_TEST ", "PASS" if get_tree().current_scene.name == "End" else "FAIL " + get_tree().current_scene.name)
	get_tree().quit()
