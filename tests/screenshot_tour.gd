extends Node
## Tur otomatis: membuka setiap layar, memainkan sebentar, dan menyimpan screenshot.
## Jalankan dengan tampilan (bukan headless):
##   godot res://tests/screenshot_tour.tscn -- <folder_output>

var out_dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _modal() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("%Modal") if scene else null


func _press_modal(index: int = 0) -> void:
	var m := _modal()
	if m and m.is_busy():
		m._on_button(index)
	await _wait(0.1)


func _run() -> void:
	# Lepaskan diri dari current_scene supaya tidak ikut terhapus saat pindah layar.
	var root := get_tree().root
	reparent(root)
	var dummy := Node.new()
	root.add_child(dummy)
	get_tree().current_scene = dummy

	Game.slides_mode = "intro"
	Game.slides_next = "setup"
	Game.goto("slides")
	await _wait(0.8)
	await _shot("01_intro")

	Game.goto("setup")
	await _wait(0.5)
	await _shot("02_setup")

	Game.chosen_province = &"ntt"
	Game.chosen_energy = &"plts"
	Game.chosen_name = "KKN Tematik Nyala"
	Game.new_game()
	Game.goto("game")
	await _wait(0.6)
	await _shot("03_game_start_card")
	await _press_modal(0)
	await _wait(0.3)
	await _shot("03b_game_fresh")

	var sim := Game.sim
	var db := Game.db
	sim.buy_upgrade(db.get_upgrade(&"sekolah_lapang"))
	sim.do_action(db.actions[0], &"ntt")
	for i in 3:
		sim.tick()
	var pp0 = get_tree().current_scene.get_node("%ProvincePanel")
	for v in sim.provinces[&"ntt"].villages:
		if v.is_building():
			pp0.select_village(v.index)
			break
	await _wait(0.3)
	await _shot("04a_building")
	for i in 12:
		sim.tick()
	await _wait(0.4)
	get_tree().current_scene.get_node("%MapView").finish_spread_animation()
	await _shot("04_game_kkn")
	sim.points += 30
	var pp = get_tree().current_scene.get_node("%ProvincePanel")
	pp.select_village(1)
	await _wait(0.3)
	await _shot("04c_village_detail")
	pp.select_village(-1)
	for c in get_tree().current_scene.get_children():
		if c.has_method("handle_key"):
			c.handle_key(KEY_F1)
			await _wait(0.2)
			await _shot("04b_debug_help")
			c.handle_key(KEY_F1)

	get_tree().current_scene.toggle_all_panels()
	await _wait(0.3)
	await _shot("04d_panels_collapsed")
	get_tree().current_scene.toggle_all_panels()

	var upg := get_tree().current_scene.get_node("%UpgradePanel")
	upg.open()
	await _wait(0.3)
	await _shot("05_upgrades")
	upg.close()

	# Main cepat sampai pertengahan permainan, jawab semua kartu dengan pilihan pertama.
	for i in 380:
		sim.tick()
		if i % 6 == 0:
			for s: Simulation.ProvinceState in sim.provinces.values():
				sim.do_action(db.actions[0], s.data.id)
			for u in db.upgrades:
				if sim.upgrade_state(u) == "":
					sim.buy_upgrade(u)
					break
		var guard := 0
		while _modal().is_busy() and guard < 6:
			guard += 1
			if i > 300 and _modal().title_label.text.begins_with("Tawaran"):
				break
			await _press_modal(0)
		if sim.game_over:
			break
	await _wait(0.3)
	get_tree().current_scene.get_node("%MapView").finish_spread_animation()
	await _shot("06_game_midgame")

	var disaster: EventData = db.events[0]
	for e in db.events:
		if e.id == &"badai_pesisir":
			disaster = e
	sim.trigger_event(disaster, sim.start_province)
	await _wait(0.3)
	await _shot("07_event_card")
	await _press_modal(1)
	await _shot("08_event_result")
	await _press_modal(0)
	while _modal().is_busy():
		await _press_modal(0)

	sim.offer_triggered.emit(db.offers[1])
	await _wait(0.3)
	await _shot("09_offer_card")
	await _press_modal(0)
	while _modal().is_busy():
		await _press_modal(0)

	sim.trigger_milestone(db.milestones[2])
	await _wait(0.3)
	await _shot("09c_milestone")
	while _modal().is_busy():
		await _press_modal(0)
	# Tonggak kecil + perayaan kota = notifikasi kecil, tidak menjeda.
	sim.trigger_milestone(db.milestones[1])
	sim.city_celebrated.emit("Kupang", "NTT", 0.52)
	await _wait(0.4)
	await _shot("09d_toasts")

	sim.news.emit(&"province_independent", {"province": "Nusa Tenggara Timur", "island": "Nusa Tenggara"})
	await _wait(0.3)
	await _shot("09b_news_popup")
	while _modal().is_busy():
		await _press_modal(0)

	get_tree().current_scene._open_menu()
	await _wait(0.2)
	await _shot("10_pause_menu")
	await _press_modal(0)

	sim._end(&"win")
	await _wait(2.0)
	await _shot("11_end")
	print("TOUR_DONE")
	get_tree().quit()
