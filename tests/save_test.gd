extends SceneTree
## Tes simpan & muat: keadaan setelah muat sama persis, dan permainan berlanjut identik.
##   godot --headless -s res://tests/save_test.gd
func _init() -> void:
	await process_frame
	var game = root.get_node("/root/Game")
	game.chosen_province = &"ntt"
	game.chosen_energy = &"plts"
	game.chosen_village = -1
	game.new_game()
	var sim: Simulation = game.sim
	for i in 160:
		sim.tick()
		if i % 10 == 0:
			for u in game.db.upgrades:
				if sim.upgrade_state(u) == "":
					sim.buy_upgrade(u)
					break
	var ok := true
	ok = game.save_game("1") and ok
	var before := var_to_str(sim.to_save())
	ok = game.load_game("1") and ok
	var sim2: Simulation = game.sim
	var after := var_to_str(sim2.to_save())
	print("sama setelah muat: ", before == after)
	if before != after:
		var a: Dictionary = sim.to_save()
		var b: Dictionary = sim2.to_save()
		for k in a:
			if var_to_str(a[k]) != var_to_str(b.get(k)):
				var sa := var_to_str(a[k])
				var sb := var_to_str(b.get(k))
				var j := 0
				while j < mini(sa.length(), sb.length()) and sa[j] == sb[j]:
					j += 1
				print("  beda: ", k, " @", j, "  ", sa.substr(maxi(0, j - 60), 120).replace("\n", " "), "  ||  ", sb.substr(maxi(0, j - 60), 120).replace("\n", " "))
	ok = ok and before == after
	for i in 120:
		sim.tick()
		sim2.tick()
	var same_future := var_to_str(sim.to_save()) == var_to_str(sim2.to_save())
	print("berlanjut identik: ", same_future, "  akses ", int(sim2.access_ratio() * 100), "%  tik ", sim2.tick_count)
	ok = ok and same_future
	var m: Dictionary = game.save_info("1")
	print("info slot: ", m.get("name"), " ", m.get("date"))
	print("latest: ", game.latest_slot())
	game.delete_save("1")
	print("SAVE_TEST ", "PASS" if ok else "FAIL")
	quit()
