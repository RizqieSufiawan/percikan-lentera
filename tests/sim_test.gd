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
	var ok := true
	var quick := OS.get_cmdline_user_args().has("quick")
	for strategy in ["seimbang", "asal_pilih", "ngebut", "pasif"]:
		var wins := 0
		var line := ""
		for seed_value in range(6):
			# "asal_pilih" = pemain yang membawa energi tanpa membaca ciri alam (mikrohidro di NTT yang kering).
			var r := _play(db, strategy, seed_value, "ntt", "mikrohidro" if strategy == "asal_pilih" else "plts")
			if r["result"] == &"win":
				wins += 1
			line += "  seed %d: %-16s tik %4d (%4.1f mnt, %d)  akses %3d%%  mandiri %3d%%  resist %3d  tahap %d\n" % [
				seed_value, r["result"], r["tick"], r["minutes"], r["year"], r["access"], r["indep"], r["resist"], r["stage"]]
		print("== strategi %s: menang %d/6" % [strategy, wins])
		print(line)
	# Uji semua provinsi awal + energi tidak cocok tidak error.
	for p in (db.provinces if not quick else []):
		var r := _play(db, "seimbang", 1, p.id, "mikrohidro")
		print("awal %-8s mikrohidro -> %s tik %d" % [p.id, r["result"], r["tick"]])
	# Setiap provinsi awal harus bisa dimenangkan dengan energi KKN yang paling cocok (data RUEN).
	for p in (db.provinces if not quick else []):
		var best: StringName = &""
		var best_c := -1.0
		for e in db.energies:
			if e.kkn_available and db.province_compat(p, e.id) > best_c:
				best_c = db.province_compat(p, e.id)
				best = e.id
		var wins := 0
		var ticks: Array[int] = []
		for seed_value in range(3):
			var r := _play(db, "seimbang", seed_value, p.id, best)
			if r["result"] == &"win":
				wins += 1
			ticks.append(r["tick"])
		print("terbaik %-8s %-10s -> menang %d/3 tik %s" % [p.id, best, wins, ticks])
		if wins == 0:
			ok = false
	print("SIM_TEST_DONE" if ok else "SIM_TEST_FAIL")
	quit()


func _play(db: GameDatabase, strategy: String, seed_value: int, province: StringName, energy: StringName) -> Dictionary:
	var sim := Simulation.new(db, seed_value)
	_pending_event = []
	_pending_offer = null
	sim.event_triggered.connect(func(e, pid): _pending_event = [e, pid])
	sim.offer_triggered.connect(func(o): _pending_offer = o)
	sim.start(province, energy, "Tes")
	var seconds := 0.0
	while not sim.game_over and sim.tick_count < TEST_CAP:
		seconds += db.config.kkn_tick_seconds if sim.kkn_active else db.config.tick_seconds
		sim.tick()
		# Pemain manusia sesekali mengklik gelembung.
		if strategy != "pasif" and sim.tick_count % 12 == 0:
			sim.collect_bubble()
		if not _pending_event.is_empty():
			var e: EventData = _pending_event[0]
			var choice := 0 if strategy in ["seimbang", "asal_pilih"] else 1
			sim.answer_event(e, _pending_event[1], choice)
			_pending_event = []
		if _pending_offer:
			var accept := strategy == "ngebut" or _pending_offer.tier != &"rapuh"
			sim.answer_offer(_pending_offer, accept)
			_pending_offer = null
		if strategy != "pasif" or sim.tick_count % 8 == 0:
			_bot_turn(sim, db, strategy)
	return {
		"result": sim.result if sim.game_over else &"cap", "tick": sim.tick_count, "year": sim.current_year(), "minutes": seconds / 60.0,
		"access": int(sim.access_ratio() * 100), "indep": int(sim.independent_ratio() * 100),
		"resist": int(sim.total_resistance()), "stage": sim.stage,
	}


func _bot_turn(sim: Simulation, db: GameDatabase, strategy: String) -> void:
	var build: ActionData = db.actions[0]
	# Upgrade termurah yang bisa dibeli.
	var best: UpgradeData = null
	for u in db.upgrades:
		if sim.upgrade_state(u) == "" and (best == null or u.cost_points < best.cost_points):
			if u.unlock_energy != &"" and strategy in ["seimbang", "asal_pilih"] and sim.energies.size() >= 3:
				# Pemain yang membaca ciri desa tetap membuka energi baru jika lebih cocok
				# untuk desa-desa yang belum bersih daripada energi terlemah yang dimiliki.
				if strategy == "asal_pilih" or _energy_score(sim, u.unlock_energy) <= _weakest_owned(sim):
					continue
			best = u
	if best and (strategy == "ngebut" or sim.points > sim.upgrade_cost(best) + 4):
		sim.buy_upgrade(best)
	for s: Simulation.ProvinceState in sim.provinces.values():
		var id := s.data.id
		if strategy == "asal_pilih":
			# Sama seperti seimbang, tapi selalu membangun dengan energi pertama yang dimiliki,
			# tanpa membaca ciri desa.
			for v: Simulation.VillageState in s.villages:
				if not v.is_clean() and sim.can_do_action(build, id, v.index, sim.energies[0]) == "" and (s.community >= 20 or s.on() == 0):
					sim.do_action(build, id, v.index, sim.energies[0])
					break
		elif sim.can_do_action(build, id) == "" and (strategy == "ngebut" or s.community >= 20 or s.on() == 0):
			sim.do_action(build, id)


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
