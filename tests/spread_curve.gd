extends SceneTree
## Kurva akses per tahun (bot sederhana: beli upgrade termurah bila Poin cukup + cadangan).
## godot --headless -s res://tests/spread_curve.gd -- <early_mult> <late_mult>
func _init() -> void:
	var db: GameDatabase = load("res://data/database.tres")
	var a := OS.get_cmdline_user_args()
	if a.size() >= 2:
		db.config.spread_early_mult = float(a[0])
		db.config.spread_late_mult = float(a[1])
	for seed_value in 3:
		var sim := Simulation.new(db, seed_value)
		sim.auto_build = true
		sim.start(&"ntt", &"plts", "x", -1)
		var line := "seed %d:" % seed_value
		while not sim.game_over and sim.tick_count < 2000:
			sim.tick()
			for u in db.upgrades:
				if sim.upgrade_state(u) == "" and sim.points > sim.upgrade_cost(u) + 6:
					sim.buy_upgrade(u)
					break
			if sim.tick_count % 104 == 0:
				line += " %d:%d%%" % [db.config.start_year + sim.tick_count / 52, int(sim.access_ratio() * 100)]
		print(line, "  -> ", sim.result if "result" in sim else "", " tik ", sim.tick_count)
	quit()
