extends SceneTree
## Tes simulasi tanpa tampilan. Jalankan dari folder proyek:
##   godot --headless -s res://tests/sim_test.gd
## Bot sederhana memainkan beberapa ronde dengan strategi berbeda,
## lalu mencetak hasil, supaya angka di game_config.tres bisa disetel.

## Batas tik khusus tes (permainan sungguhan tidak punya batas waktu).
const TEST_CAP := 2400
var _pending_event: Array = []
var _pending_offer: GovOfferData


func _init() -> void:
	var db: GameDatabase = load("res://data/database.tres")
	var args := OS.get_cmdline_user_args()
	var seeds := 4
	var strategies := ["seimbang", "asal_pilih", "ngebut", "pasif"]
	for a in args:
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("only="):
			strategies = a.substr(5).split(",")
		elif "=" in a:
			var kv := a.split("=")
			db.config.set(kv[0], float(kv[1]))
			print("set ", kv[0], " = ", db.config.get(kv[0]))
	for strategy in strategies:
		var wins := 0
		var line := ""
		for seed_value in range(seeds):
			var r := _play(db, strategy, seed_value, "ntt", "mikrohidro" if strategy == "asal_pilih" else "plts")
			if r["result"] == &"win":
				wins += 1
			line += "  s%d %-15s %d (%4.1f mnt) 25%%:%s 50%%:%s 75%%:%s akses %3d%% mandiri %3d%% resMax %3d poinMax %4d sisa %4d upg %2d\n" % [
				seed_value, r["result"], r["year"], r["minutes"], r["y25"], r["y50"], r["y75"], r["access"], r["indep"], r["rmax"], r["pmax"], r["pend"], r["upg"]]
		print("== %s: menang %d/%d" % [strategy, wins, seeds])
		print(line)
	print("PROBE_DONE")
	quit()


func _play(db: GameDatabase, strategy: String, seed_value: int, province: StringName, energy: StringName) -> Dictionary:
	var sim := Simulation.new(db, seed_value)
	_pending_event = []
	_pending_offer = null
	sim.event_triggered.connect(func(e, pid): _pending_event = [e, pid])
	sim.offer_triggered.connect(func(o): _pending_offer = o)
	sim.auto_build = true
	sim.start(province, energy, "Tes", -1)
	var seconds := 0.0
	var ys := {"y25": "-", "y50": "-", "y75": "-"}
	var rmax := 0.0
	var pmax := 0.0
	while not sim.game_over and sim.tick_count < TEST_CAP:
		seconds += db.config.seconds_per_tick(sim.kkn_active, sim.tick_count)
		sim.tick()
		var acc := sim.access_ratio()
		for k in [["y25", 0.25], ["y50", 0.5], ["y75", 0.75]]:
			if ys[k[0]] == "-" and acc >= k[1]:
				ys[k[0]] = str(sim.current_year())
		rmax = maxf(rmax, sim.total_resistance())
		pmax = maxf(pmax, sim.points)
		# Pemain manusia sesekali mengklik gelembung.
		if strategy != "pasif" and sim.tick_count % 12 == 0:
			sim.collect_bubble()
		if not _pending_event.is_empty():
			var e: EventData = _pending_event[0]
			if e.auto_resolve:
				sim.resolve_event(e, _pending_event[1])
			else:
				var choice := 0 if strategy in ["seimbang", "asal_pilih"] else 1
				sim.answer_event(e, _pending_event[1], choice)
			_pending_event = []
		if _pending_offer:
			var accept := strategy == "ngebut" or _pending_offer.tier != &"rapuh"
			sim.answer_offer(_pending_offer, accept)
			_pending_offer = null
		if strategy != "pasif" or sim.tick_count % 26 == 0:
			_bot_turn(sim, db, strategy)
	return {
		"result": sim.result if sim.game_over else &"cap", "tick": sim.tick_count, "year": sim.current_year(), "minutes": seconds / 60.0,
		"access": int(sim.access_ratio() * 100), "indep": int(sim.independent_ratio() * 100),
		"resist": int(sim.total_resistance()), "stage": sim.stage,
		"y25": ys["y25"], "y50": ys["y50"], "y75": ys["y75"], "rmax": int(rmax), "pmax": int(pmax),
		"pend": int(sim.points), "upg": sim.owned_upgrades.size(),
	}


func _bot_turn(sim: Simulation, db: GameDatabase, strategy: String) -> void:
	# Upgrade termurah yang bisa dibeli. "ngebut" mendahulukan upgrade penyebar/pembangun
	# (sebaran, waktu bangun, output) dan baru membeli yang lain bila tidak ada.
	var best: UpgradeData = null
	var rush_only := strategy == "ngebut" and _has_rush(sim, db)
	for u in db.upgrades:
		if rush_only and not _is_rush(u):
			continue
		if sim.upgrade_state(u) == "" and (best == null or u.cost_points < best.cost_points):
			if u.unlock_energy != &"" and strategy in ["seimbang", "asal_pilih"] and sim.energies.size() >= 3:
				# Pemain yang membaca ciri desa tetap membuka energi baru jika lebih cocok
				# untuk desa-desa yang belum bersih daripada energi terlemah yang dimiliki.
				if strategy == "asal_pilih" or _energy_score(sim, u.unlock_energy) <= _weakest_owned(sim):
					continue
			best = u
	if best and (strategy == "ngebut" or sim.points > sim.upgrade_cost(best) + 4):
		sim.buy_upgrade(best)
	# Pembangunan sepenuhnya otomatis (tidak ada tombol Bangun): bot hanya memilih upgrade
	# dan wilayah yang didahulukan (wilayah dengan komunitas tertinggi yang masih bisa dibangun).
	var focus: Simulation.ProvinceState = null
	for s: Simulation.ProvinceState in sim.provinces.values():
		if s.unclean() > 0 and sim.is_reachable(s) and (focus == null or s.community > focus.community):
			focus = s
	if focus:
		sim.auto_build_focus = focus.data.id


func _is_rush(u: UpgradeData) -> bool:
	if u.unlock_energy != &"":
		return true
	for k in u.modifiers:
		var key := String(k)
		if key in ["spread_mult", "build_time_mult"] or key.begins_with("output:") or key.begins_with("build:"):
			return true
	return false


func _has_rush(sim: Simulation, db: GameDatabase) -> bool:
	for u in db.upgrades:
		# Hanya upgrade penyebar yang bisa dibeli dengan menabung Poin; yang terhalang Ekonomi
		# tidak ditunggu (dulu bot macet menabung Poin selamanya).
		if _is_rush(u) and sim.upgrade_state(u) in ["", "Poin Dukungan kurang"]:
			return true
	return false


## Seberapa cocok energi ini untuk semua desa yang belum bersih di provinsi yang sudah terjangkau.
func _energy_score(sim: Simulation, energy: StringName) -> float:
	var total := 0.0
	for s: Simulation.ProvinceState in sim.provinces.values():
		if not sim.is_reachable(s):
			continue
		for v: Simulation.VillageState in s.villages:
			if not v.is_clean():
				total += sim.village_compat(s, v, energy)
	return total


func _weakest_owned(sim: Simulation) -> float:
	var low := INF
	for e in sim.energies:
		low = minf(low, _energy_score(sim, e))
	return low
