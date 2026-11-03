extends SceneTree
## Ukur kecepatan & jangkauan sebaran awal (tanpa upgrade). godot --headless -s res://tests/spread_probe.gd -- <hops>
func _init() -> void:
	var db: GameDatabase = load("res://data/database.tres")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		db.config.spread_max_hops = int(args[0])
	for seed_value in 2:
		var sim := Simulation.new(db, seed_value)
		sim.auto_build = true
		sim.start(&"ntt", &"plts", "x", -1)
		var first_lit := -1
		var line := "seed %d hops %d:" % [seed_value, db.config.spread_max_hops]
		for t in range(1, 157):
			sim.tick()
			if first_lit < 0 and sim.total_on() > 0:
				first_lit = t
			if t % 13 == 0:
				var provs := 0
				for s in sim.provinces.values():
					if s.on() > 0:
						provs += 1
				line += "  [m%d kloter %d bangun %d wil %d]" % [t / 4.33, sim.total_on(), sim.total_building(), provs]
		print(line, "  pertama menyala tik ", first_lit, "  built ", sim.counters.get(&"built", 0))
	quit()
