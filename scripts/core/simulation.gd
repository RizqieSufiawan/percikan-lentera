class_name Simulation
extends RefCounted
## Seluruh logika permainan, terpisah dari tampilan dan timer.
## Satu tik = satu minggu cerita selama KKN, lalu weeks_per_tick_after_kkn minggu (2) setelahnya.
## Panggil tick() dari timer (real-time)
## atau dari tombol "Berikutnya" (fallback berbasis giliran).
##
## Peta & sebaran bekerja per WILAYAH (14 node, berisi 38 provinsi asli). Setiap wilayah berisi
## KLOTER desa (VillageState): +-500 desa nyata dari satu provinsi asal, dengan nama wakil, ciri alam,
## status, dan energinya sendiri. Logika permainan menghitung kloter; rasio menang dan angka di
## layar menghitung jumlah desa nyata (Podes 2024: 84.276 desa).

signal changed
## Berita: key trigger + konteks {province, island, village, ...}.
signal news(trigger: StringName, context: Dictionary)
signal event_triggered(event: EventData, province_id: StringName)
signal offer_triggered(offer: GovOfferData)
signal stage_changed(stage: int)
signal kkn_ended(lost_villages: int)
signal game_ended(result: StringName)
## Ibu kota provinsi merayakan: sebagian besar desa di provinsinya sudah memakai energi bersih.
signal city_celebrated(city: String, province: String, share: float)
## Tonggak waktu tercapai (popup evaluasi, permainan berlanjut).
signal milestone_reached(milestone: MilestoneData, report: Dictionary)

## Status desa.
const V_DARK := 0      ## Belum ada listrik.
const V_FOSSIL := 1    ## Berlistrik energi fosil (PLTU, PLTD, genset).
const V_LIT := 2       ## Energi bersih, belum dirawat warga ("rapuh").
const V_INDEP := 3     ## Energi bersih dirawat warga ("mandiri").


class VillageState:
	var data: VillageData
	var index: int = 0
	var status: int = 0
	## Energi bersih yang dipakai (kosong jika gelap/fosil).
	var energy: StringName = &""
	## Masa pembangunan: sisa minggu sampai pembangkit menyala (0 = tidak sedang dibangun).
	var build_left: int = 0
	var build_total: int = 0
	var build_energy: StringName = &""
	## Kloter tetangga di peta (data/kloter_links.json) dan apakah kloter ini cukup dekat
	## (<= spread_max_hops) dengan kloter yang listrik bersihnya sudah terbukti.
	var links: Array = []
	var near: bool = true
	## Berapa tik kloter ini sudah berenergi bersih (untuk tampilan: warna memenuhi sel perlahan).
	var lit_age: int = 0

	func is_building() -> bool:
		return build_left > 0

	func is_clean() -> bool:
		return status == V_LIT or status == V_INDEP

	func name() -> String:
		return data.display_name if data else "Desa %d" % (index + 1)

	## Jumlah desa nyata dalam kloter ini.
	func size() -> int:
		return data.size if data else 1

	func origin() -> String:
		return data.origin if data else ""

	## "Desa X dan 502 desa sekitarnya" untuk berita.
	func kloter_text() -> String:
		var n := size() - 1
		return name() if n <= 0 else "%s dan %s desa sekitarnya" % [name(), Simulation.ribu(n)]


class ProvinceState:
	var data: ProvinceData
	var villages: Array[VillageState] = []
	## Jumlah per status (dihitung ulang lewat recount()).
	var dark: int = 0
	var fossil: int = 0
	var lit: int = 0
	var independent: int = 0
	## Jumlah DESA NYATA per status (bobot ukuran kloter).
	var dark_desa: int = 0
	var fossil_desa: int = 0
	var lit_desa: int = 0
	var independent_desa: int = 0
	var community: float = 0.0
	var internet: bool = false
	var seed: bool = false
	var built_once: bool = false
	var spread_progress: float = 0.0
	var independence_progress: float = 0.0

	func recount() -> void:
		dark = 0
		fossil = 0
		lit = 0
		independent = 0
		dark_desa = 0
		fossil_desa = 0
		lit_desa = 0
		independent_desa = 0
		for v in villages:
			var n := v.size()
			match v.status:
				V_DARK:
					dark += 1
					dark_desa += n
				V_FOSSIL:
					fossil += 1
					fossil_desa += n
				V_LIT:
					lit += 1
					lit_desa += n
				V_INDEP:
					independent += 1
					independent_desa += n

	func total_desa() -> int:
		return dark_desa + fossil_desa + lit_desa + independent_desa

	func on_desa() -> int:
		return lit_desa + independent_desa

	func total() -> int:
		return villages.size()

	## Desa yang belum memakai energi bersih (gelap + fosil).
	func unclean() -> int:
		return dark + fossil

	func on() -> int:
		return lit + independent

	## Kloter gelap/fosil yang sedang dibangun.
	func building() -> int:
		var n := 0
		for v in villages:
			if v.build_left > 0:
				n += 1
		return n

	func status() -> StringName:
		if total_desa() > 0 and float(independent_desa) / total_desa() >= 0.5:
			return &"independent"
		if on() > 0:
			return &"lit"
		if seed:
			return &"seed"
		return &"dark"


var db: GameDatabase
var cfg: GameConfig
var rng := RandomNumberGenerator.new()

var community_name: String = ""
## Bangun otomatis (lihat GameConfig, grup "Bangun otomatis"). Diatur Game/UI; bot tes memakai false.
var auto_build: bool = false
## Wilayah yang didahulukan saat bangun otomatis (wilayah yang sedang dipilih pemain).
var auto_build_focus: StringName = &"" 
var start_province: StringName
var start_energy: StringName

var tick_count: int = 0
var stage: int = 1
var kkn_active: bool = true
var points: float = 0.0
var money: float = 0.0
var welfare: float = 0.0
var blue: float = 0.0
var red: float = 0.0

var provinces: Dictionary = {}  # StringName -> ProvinceState
var owned_upgrades: Dictionary = {}  # StringName -> true
var energies: Array[StringName] = []
var flags: Dictionary = {}  # StringName -> true
var mods: Dictionary = {}  # StringName -> float
var air_islands: Array[StringName] = []
## Kecocokan yang sudah terungkap: "provinsi:desa:energi" -> true (setelah pemain membangun di sana).
var known_compat: Dictionary = {}
## Desa sasaran tiap event yang sedang menunggu jawaban: event id -> [province_id, village index].
var event_targets: Dictionary = {}

var counters: Dictionary = {}  # untuk misi & layar akhir
var completed_missions: Dictionary = {}
var event_cooldowns: Dictionary = {}

var offers_made: int = 0
var offer_cooldown: int = 0
var score_penalty: float = 0.0
var offer_target: Dictionary = {}  # {on_needed, deadline, offer}

## Hasil evaluasi tiap tonggak waktu: id -> report (lihat milestone_report()).
var milestone_reports: Dictionary = {}
## Kota yang sudah dirayakan: nama provinsi pendek -> tahun.
var celebrated_cities: Dictionary = {}

var money_zero_ticks: int = 0
var dark_ticks: int = 0
var game_over: bool = false
var result: StringName = &""


func _init(database: GameDatabase, seed_value: int = -1) -> void:
	db = database
	cfg = database.config
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# ---------------------------------------------------------------- mulai

## village_index: kloter awal yang langsung mulai dibangun (-1 = paling cocok, -2 = tidak ada).
func start(province_id: StringName, energy_id: StringName, name: String = "", village_index: int = -2) -> void:
	start_province = province_id
	start_energy = energy_id
	community_name = name if name.strip_edges() != "" else "Tim KKN Tematik"
	for p in db.provinces:
		var s := ProvinceState.new()
		s.data = p
		if not p.village_list.is_empty():
			for i in p.village_list.size():
				var v := VillageState.new()
				v.data = p.village_list[i]
				v.index = i
				v.status = V_FOSSIL if v.data.start_fossil else V_DARK
				s.villages.append(v)
		else:
			# Cadangan jika provinsi belum punya daftar desa: desa tanpa ciri.
			for i in p.villages:
				var v := VillageState.new()
				v.index = i
				v.status = V_FOSSIL if i < p.fossil_villages else V_DARK
				s.villages.append(v)
		s.recount()
		provinces[p.id] = s
	_load_links()
	energies = [energy_id]
	for u in db.upgrades:
		if u.unlock_energy == energy_id:
			owned_upgrades[u.id] = true
	var start_state: ProvinceState = provinces[province_id]
	start_state.community = cfg.start_community
	points = cfg.start_points
	money = cfg.start_money
	welfare = cfg.start_welfare
	blue = cfg.start_blue + start_state.data.island.base_resistance + start_state.data.start_resistance_mod
	if best_compat(start_state) < 0.5:
		points += cfg.mismatch_bonus_points
		blue += 5.0
	_recompute_mods()
	if village_index != -2:
		# Pembangkit pertama langsung mulai dibangun. Biayanya sama dengan klik Bangun.
		# "Otomatis" = kloter yang paling cocok dengan energi pilihan (walau tidak ada yang cocok).
		var build := _build_action()
		if build:
			var idx := village_index
			if idx < 0:
				var best_c := -1.0
				for v in start_state.villages:
					var c := village_compat(start_state, v, energy_id) + (0.01 if v.status == V_DARK else 0.0)
					if c > best_c:
						best_c = c
						idx = v.index
			do_action(build, province_id, idx, energy_id)
	changed.emit()


func _build_action() -> ActionData:
	for a in db.actions:
		if a.effect == ActionData.Effect.BUILD:
			return a
	return null


## Warga membangun satu kloter berikutnya sendiri (maksimal satu per tik).
func _auto_build() -> void:
	if not auto_build:
		return
	var build := _build_action()
	if build == null:
		return
	# Warga baru mau ikut setelah hasilnya terbukti: selama pembangkit pertama masih dibangun,
	# tidak ada pembangunan otomatis.
	if total_on() == 0 and total_building() > 0:
		return
	# Awal permainan warga ragu: sedikit pembangunan berjalan bersamaan, makin banyak saat
	# makin banyak kloter terbukti menyala.
	if total_building() >= 1 + total_on() / maxi(1, cfg.auto_build_parallel_per):
		return
	if _auto_cd > 0:
		_auto_cd -= 1
		return
	var order: Array = []
	if provinces.has(auto_build_focus):
		order.append(provinces[auto_build_focus])
	var rest: Array = provinces.values()
	rest.sort_custom(func(a, b): return a.community > b.community)
	for s in rest:
		if s.data.id != auto_build_focus:
			order.append(s)
	for s: ProvinceState in order:
		if s.on() > 0 and s.community < cfg.auto_build_min_community:
			continue
		# Semua padam setelah KKN: warga bergotong royong membangun ulang satu kloter tanpa Poin,
		# supaya pemain yang kehabisan Poin tidak langsung kalah (tidak ada tombol Bangun manual).
		if not kkn_active and total_on() == 0 and total_building() == 0 and is_reachable(s):
			var rv := _pick_auto_village(s)
			if rv and _start_construction(s, rv.index, &"") != null:
				s.built_once = true
				_bump(&"built")
				_bump(&"auto_built")
				return
			continue
		if points < action_cost_points(build, s) + cfg.auto_build_reserve:
			return
		var v := _pick_auto_village(s, total_on() > 0)
		if v and can_do_action(build, s.data.id, v.index) == "":
			do_action(build, s.data.id, v.index)
			_bump(&"auto_built")
			_auto_cd = int(round(cfg.auto_build_cooldown_early * (1.0 - momentum_progress())))
			return


# ---------------------------------------------------------------- tik

func tick() -> void:
	if game_over:
		return
	tick_count += 1
	if offer_cooldown > 0:
		offer_cooldown -= 1
	_income()
	_community_and_independence()
	_maintenance()
	_construction()
	_check_missions()
	_update_near()
	_auto_build()
	_spread()
	_internet_seeds()
	_resistance()
	_check_kkn()
	_check_offer_target()
	_check_stage()
	_check_offer()
	_check_event()
	_check_cities()
	_check_end()
	_check_milestones()
	changed.emit()


func _income() -> void:
	var pm: float = 1.0 + mod("points_mult")
	if kkn_active:
		points += cfg.kkn_points_per_tick * pm
	else:
		var gain := 0.0
		for s: ProvinceState in provinces.values():
			for v in s.villages:
				if v.status == V_LIT:
					gain += cfg.points_per_lit * energy_output(v.energy)
				elif v.status == V_INDEP:
					gain += cfg.points_per_independent * energy_output(v.energy)
			if s.on() > 0:
				gain += s.community / 100.0 * cfg.points_per_community
		points += gain * pm
	var indep_money := 0.0
	for s: ProvinceState in provinces.values():
		if s.independent == 0:
			continue
		for v in s.villages:
			if v.status == V_INDEP:
				indep_money += cfg.money_per_independent * energy_output(v.energy)
	money += cfg.money_base_per_tick + indep_money + mod("money_per_tick")
	money = clampf(money, 0.0, 100.0)
	money_zero_ticks = money_zero_ticks + 1 if money <= 0.5 else 0
	# Kesejahteraan mendekati target yang ditentukan akses listrik.
	var target := 20.0 + 30.0 * electrified_ratio() + 35.0 * access_ratio()
	welfare += (target - welfare) * 0.01 + mod("welfare_per_tick")
	welfare = clampf(welfare, 0.0, 100.0)


func _community_and_independence() -> void:
	var decay := cfg.community_decay * mult("community_decay_mult", 0.2)
	var growth := cfg.community_growth * (1.0 + mod("community_gain"))
	for s: ProvinceState in provinces.values():
		# Mahasiswa KKN melatih warga wilayah awal (pengganti aksi Latih Warga).
		if kkn_active and s.data.id == start_province:
			s.community = minf(100.0, s.community + cfg.kkn_community_per_tick * (1.0 + mod("community_gain")))
		if s.on() == 0 and s.community <= 0.0:
			continue
		# Warga yang sudah memakai energi bersih mengajari tetangganya.
		if s.on() > 0:
			s.community = minf(100.0, s.community + growth * clampf(0.5 + float(s.on()) / s.total(), 0.5, 1.5))
		s.community = maxf(0.0, s.community - decay)
		# Desa mandiri memantik komunitas di provinsinya dan tetangganya.
		if s.independent > 0:
			s.community = minf(100.0, s.community + s.independent * cfg.independent_community_boost)
			for n in s.data.neighbors:
				var ns: ProvinceState = provinces.get(n)
				if ns and ns.on() > 0:
					ns.community = minf(100.0, ns.community + s.independent * cfg.independent_community_boost * 0.5)
		if s.lit > 0 and s.community >= cfg.independence_threshold:
			# Energi yang cocok lebih mudah dirawat warga: desa lebih cepat mandiri.
			var fit := _lit_fit(s)
			s.independence_progress += cfg.independence_rate * (s.community / 100.0) * (1.0 + mod("independence_rate") + _lit_care(s)) \
				* (1.0 - cfg.fit_independence_weight + cfg.fit_independence_weight * fit)
			while s.independence_progress >= 1.0 and s.lit > 0:
				s.independence_progress -= 1.0
				# Desa dengan energi paling cocok paling mudah dirawat warga.
				var best: VillageState = null
				for v in s.villages:
					if v.status == V_LIT and (best == null or village_compat(s, v, v.energy) > village_compat(s, best, best.energy)):
						best = v
				best.status = V_INDEP
				s.recount()
				_bump(&"independent_total")
				_news(&"village_independent", s, best)
				if s.status() == &"independent":
					_news_once(&"province_independent", s)


## Sebaran meniru contoh: desa hanya mengadopsi energi yang SUDAH DIPAKAI di desa asal sebaran
## (atau di provinsinya sendiri). Jadi energi yang kamu bangun lebih dulu menentukan apa yang menyebar.
## Rata-rata kecocokan energi di desa-desa rapuh provinsi ini.
func _lit_fit(s: ProvinceState) -> float:
	var sum := 0.0
	var n := 0
	for v in s.villages:
		if v.status == V_LIT:
			sum += village_compat(s, v, v.energy)
			n += 1
	return sum / n if n > 0 else 1.0


## Rata-rata bonus "indep:<energi>" desa rapuh di wilayah ini (warga terlatih merawat energi itu).
func _lit_care(s: ProvinceState) -> float:
	var sum := 0.0
	var n := 0
	for v in s.villages:
		if v.status == V_LIT:
			sum += mod(StringName("indep:%s" % v.energy))
			n += 1
	return sum / n if n > 0 else 0.0


## Teknologi yang kurang cocok lebih sering rusak: desa rapuh bisa gagal sendiri.
## Komunitas yang kuat mengurangi peluang ini (ada yang memperbaiki).
func _maintenance() -> void:
	if kkn_active:
		return
	for s: ProvinceState in provinces.values():
		if s.lit == 0:
			continue
		var care := clampf(1.0 - s.community / 100.0, 0.2, 1.0)
		for v in s.villages:
			if v.status != V_LIT:
				continue
			var misfit := 1.0 - village_compat(s, v, v.energy)
			if rng.randf() < cfg.misfit_failure_rate * misfit * care * energy_fragility(v.energy):
				_revert_village(s, v)
				_bump(&"misfit_failures")
				_news(&"village_down", s, v)


func _spread() -> void:
	var gains: Dictionary = {}
	var pools: Dictionary = {}  # id provinsi tujuan -> energi yang bisa ditiru
	var by_air: Dictionary = {}  # id provinsi tujuan yang dijangkau rute pesawat
	var spread_mult := (1.0 + mod("spread_mult")) * momentum()
	for src: ProvinceState in provinces.values():
		if src.on() == 0:
			continue
		var src_share := float(src.on()) / src.total()
		var src_pool := used_energies(src)
		# Sebar di dalam provinsi sendiri.
		_add_spread(gains, pools, src_pool, src_share, src, spread_mult, cfg.local_spread_rate / cfg.spread_rate)
		# Sebar darat ke tetangga.
		for n in src.data.neighbors:
			_add_spread(gains, pools, src_pool, src_share, provinces.get(n), spread_mult, 1.0)
		# Sebar lewat rute pesawat (antar pulau yang dibuka).
		if air_islands.has(src.data.island.id):
			for dst: ProvinceState in provinces.values():
				if dst.data.island.id != src.data.island.id and air_islands.has(dst.data.island.id):
					_add_spread(gains, pools, src_pool, src_share, dst, spread_mult, cfg.air_factor / 4.0)
					by_air[dst.data.id] = true
	for id in gains:
		var s: ProvinceState = provinces[id]
		s.spread_progress += gains[id]
		while s.spread_progress >= 1.0 and s.unclean() > 0:
			s.spread_progress -= 1.0
			# Desa hanya meniru tetangga dekat yang sudah terbukti; rute pesawat boleh membuka
			# kloter pertama di pulau yang belum punya energi bersih.
			var need_near := not (by_air.has(id) and s.on() == 0)
			if _light_village(s, true, -1, &"", pools[id], need_near) == null:
				s.spread_progress = 0.0  # tidak ada desa yang cocok dengan energi yang ditiru
				break
		if s.unclean() == 0:
			s.spread_progress = 0.0


func _add_spread(gains: Dictionary, pools: Dictionary, src_pool: Array[StringName], src_share: float, dst: ProvinceState, spread_mult: float, factor: float) -> void:
	if dst == null or dst.unclean() == 0:
		return
	var pool: Array[StringName] = []
	pool.assign(pools.get(dst.data.id, []))
	for e in src_pool + used_energies(dst):
		if not pool.has(e):
			pool.append(e)
	pools[dst.data.id] = pool
	var c := spread_compat(dst, src_pool + used_energies(dst))
	var amount := src_share * c * readiness(dst) * cfg.spread_rate * spread_mult * factor
	amount *= dst.data.spread_mod * dst.data.island.base_spread
	gains[dst.data.id] = gains.get(dst.data.id, 0.0) + amount


## Energi yang sedang dipakai desa berenergi bersih di provinsi ini.
func used_energies(s: ProvinceState) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in s.villages:
		if v.is_clean() and v.energy != &"" and not out.has(v.energy):
			out.append(v.energy)
	return out


func _internet_seeds() -> void:
	if not flags.has(&"internet"):
		return
	# Upgrade Internet Desa: setiap wilayah yang sudah berenergi bersih otomatis tersambung.
	for s: ProvinceState in provinces.values():
		if not s.internet and s.on() > 0:
			s.internet = true
			_news(&"internet_installed", s)
	for src: ProvinceState in provinces.values():
		if not src.internet or src.on() == 0:
			continue
		if rng.randf() < cfg.seed_chance:
			var candidates: Array = []
			for dst: ProvinceState in provinces.values():
				if dst.on() == 0 and not dst.seed and dst.data.island.id != src.data.island.id:
					candidates.append(dst)
			if not candidates.is_empty():
				var target: ProvinceState = candidates[rng.randi_range(0, candidates.size() - 1)]
				target.seed = true
				_news(&"seed_planted", target)
	for s: ProvinceState in provinces.values():
		if s.seed and s.on() == 0 and s.unclean() > 0 and rng.randf() < cfg.seed_self_ignite:
			var v := _light_village(s, true)
			if v:
				_news(&"seed_ignited", s, v)


func _resistance() -> void:
	var fragile := 0.0
	for s: ProvinceState in provinces.values():
		fragile += maxf(0.0, s.lit - s.community / 10.0)
	var blue_growth := (cfg.blue_base + cfg.blue_per_fragile * fragile) * mult("blue_growth_mult")
	blue += blue_growth - cfg.blue_decay_per_independent * total_independent() + mod("blue_per_tick")
	blue = clampf(blue, 0.0, 100.0)
	if cfg.enable_red_resistance and (stage >= 3 or access_ratio() > 0.05):
		var years := maxf(0.0, float(tick_count - cfg.kkn_ticks) / 52.0)
		var red_growth := (cfg.red_base + cfg.red_per_clean * access_ratio() + cfg.red_per_year * years) * mult("red_growth_mult")
		red = clampf(red + red_growth, 0.0, cfg.red_max)
		if red > 30.0:
			_news_once(&"red_high", null)


func _check_kkn() -> void:
	if not kkn_active or tick_count < cfg.kkn_ticks:
		return
	kkn_active = false
	# Fase ujian: proyek di provinsi berkomunitas lemah bisa ditinggal dan padam.
	var lost := 0
	for s: ProvinceState in provinces.values():
		if s.community >= cfg.kkn_test_threshold:
			continue
		for v in s.villages:
			# Pembangkit terakhir yang tersisa tetap dijaga warga (game tidak langsung kalah saat tim pulang).
			if total_on() <= 1:
				break
			if v.status == V_LIT and rng.randf() < cfg.kkn_test_fail_chance:
				lost += v.size()
				_revert_village(s, v)
	counters[&"kkn_lost"] = lost
	counters[&"kkn_end_community"] = int(provinces[start_province].community)
	flags[&"post_kkn"] = true
	_set_stage(2)
	_news(&"kkn_end", provinces[start_province])
	kkn_ended.emit(lost)


func _check_stage() -> void:
	if stage == 2 and lit_provinces() >= cfg.stage3_provinces:
		_set_stage(3)
	elif stage == 4 and (independent_provinces() >= cfg.stage5_independent_provinces):
		_set_stage(5)
	elif stage == 5 and access_ratio() >= cfg.stage6_access:
		_set_stage(6)


func _set_stage(value: int) -> void:
	if value <= stage:
		return
	stage = value
	_news(StringName("stage_%d" % stage), null)
	stage_changed.emit(stage)


# ---------------------------------------------------------------- pemerintah

func eligibility_score() -> float:
	var active := 0
	var community_sum := 0.0
	for s: ProvinceState in provinces.values():
		if s.on() > 0:
			active += 1
			community_sum += s.community
	var community_avg := community_sum / active if active > 0 else 0.0
	var score := 100.0 * (0.35 * minf(1.0, total_on() / 20.0) + 0.35 * community_avg / 100.0 \
		+ 0.2 * welfare / 100.0 + 0.1 * (1.0 - total_resistance() / 100.0))
	return clampf(score - score_penalty, 0.0, 100.0)


func _check_offer() -> void:
	if stage < 3 or offers_made >= cfg.max_offers or offer_cooldown > 0 or not offer_target.is_empty():
		return
	var score := eligibility_score()
	if score < cfg.offer_min_score:
		return
	var tier: StringName = &"rapuh"
	if score >= cfg.offer_tier_lancar:
		tier = &"lancar"
	elif score >= cfg.offer_tier_biasa:
		tier = &"biasa"
	for o in db.offers:
		if o.tier == tier:
			offers_made += 1
			offer_cooldown = 9999  # ditunggu sampai dijawab
			offer_triggered.emit(o)
			return


func answer_offer(offer: GovOfferData, accept: bool) -> String:
	var text := ""
	if accept:
		money = clampf(money + offer.money, 0.0, 100.0)
		points += offer.points
		_apply_effects(offer.accept_effects, null, null)
		_open_air_routes(offer.airplane_islands)
		flags[&"gov_partner"] = true
		if offer.target_villages > 0:
			offer_target = {"on_needed": total_on() + offer.target_villages, "deadline": tick_count + offer.target_ticks, "offer": offer}
		offer_cooldown = cfg.offer_cooldown_accept
		_bump(&"offers_accepted")
		text = "Tawaran diterima."
		if offer.target_villages > 0:
			text += " Target: %d kloter desa baru memakai energi bersih dalam %d minggu." % [offer.target_villages, weeks_of(offer.target_ticks)]
	else:
		_apply_effects(offer.refuse_effects, null, null)
		offer_cooldown = cfg.offer_cooldown_refuse
		_bump(&"offers_refused")
		text = "Tawaran ditolak. Pemerintah akan menilai ulang kondisimu nanti."
	if stage < 4:
		_set_stage(4)
	changed.emit()
	return text


func _open_air_routes(count: int) -> void:
	if count <= 0:
		return
	flags[&"airplane"] = true
	if not air_islands.has(provinces[start_province].data.island.id):
		air_islands.append(provinces[start_province].data.island.id)
	var candidates: Array[StringName] = []
	for i in db.islands:
		if not air_islands.has(i.id):
			candidates.append(i.id)
	# Buka pulau yang paling banyak desa belum berenergi bersih lebih dulu.
	candidates.sort_custom(func(a, b): return _island_unclean(a) > _island_unclean(b))
	for i in min(count, candidates.size()):
		air_islands.append(candidates[i])
	_news(&"airplane_opened", null)


func _island_unclean(island_id: StringName) -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		if s.data.island.id == island_id:
			n += s.unclean()
	return n


func _check_offer_target() -> void:
	if offer_target.is_empty():
		return
	if total_on() >= offer_target["on_needed"]:
		_news(&"offer_target_met", null)
		offer_target = {}
	elif tick_count >= offer_target["deadline"]:
		var o: GovOfferData = offer_target["offer"]
		red = clampf(red + o.fail_red, 0.0, cfg.red_max)
		score_penalty += o.fail_score_penalty
		_bump(&"offer_targets_failed")
		_news(&"offer_target_failed", null)
		offer_target = {}


# ---------------------------------------------------------------- event & bencana

func _check_event() -> void:
	if kkn_active or rng.randf() >= cfg.event_chance:
		return
	var choices: Array = []
	var total_weight := 0.0
	for e in db.events:
		if e.min_stage > stage or event_cooldowns.get(e.id, 0) > tick_count:
			continue
		if e.opposition and not cfg.enable_red_resistance:
			continue
		var targets := _event_targets_for(e)
		if targets.is_empty() and e.requires_lit:
			continue
		var w := e.weight
		if e.opposition:
			w *= 1.0 + red / 20.0
		var target_w: Array[float] = []
		for pid in targets:
			target_w.append(_disaster_rate(e, pid) if e.is_disaster else 1.0)
		if e.is_disaster and not targets.is_empty():
			var mean := 0.0
			for x in target_w:
				mean += x
			w *= (mean / target_w.size()) / cfg.disaster_rate_ref
		choices.append([e, targets, w, target_w])
		total_weight += w
	if choices.is_empty():
		return
	var roll := rng.randf() * total_weight
	for c in choices:
		roll -= c[2]
		if roll <= 0.0:
			var e: EventData = c[0]
			var targets: Array = c[1]
			var pid: StringName = &""
			if not targets.is_empty():
				pid = targets[_weighted_index(c[3])]
			event_cooldowns[e.id] = tick_count + e.cooldown_ticks
			trigger_event(e, pid)
			return


## Persen desa yang mengalami bencana ini di provinsi pid (data Podes), minimal disaster_rate_floor.
func _disaster_rate(e: EventData, pid: StringName) -> float:
	var s: ProvinceState = provinces.get(pid)
	if s == null:
		return cfg.disaster_rate_ref
	return maxf(s.data.disaster_rates.get(e.id, cfg.disaster_rate_ref), cfg.disaster_rate_floor)


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


## Memunculkan event untuk provinsi tertentu (juga dipakai tombol debug).
func trigger_event(e: EventData, pid: StringName) -> void:
	var s: ProvinceState = provinces.get(pid)
	var vi := -1
	if s:
		var v := _pick_event_village(e, s)
		if v:
			vi = v.index
	event_targets[e.id] = [pid, vi]
	event_triggered.emit(e, pid)


## Provinsi yang memenuhi syarat event (pulau, ada desa berenergi bersih, ada desa dengan ciri sasaran).
func _event_targets_for(e: EventData) -> Array:
	var out: Array = []
	for s: ProvinceState in provinces.values():
		if e.requires_lit and s.on() == 0:
			continue
		if not e.island_tags.is_empty() and not e.island_tags.has(s.data.island.id):
			continue
		if not e.target_traits.is_empty() and _pick_event_village(e, s) == null:
			continue
		out.append(s.data.id)
	return out


func _pick_event_village(e: EventData, s: ProvinceState) -> VillageState:
	var pool: Array[VillageState] = []
	for v in s.villages:
		if e.requires_lit and not v.is_clean():
			continue
		if not e.target_traits.is_empty() and not _has_any_trait(v, e.target_traits):
			continue
		pool.append(v)
	if pool.is_empty() and e.target_traits.is_empty():
		pool = s.villages.duplicate()
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _has_any_trait(v: VillageState, wanted: Array[StringName]) -> bool:
	if v.data == null:
		return false
	for t in v.data.traits:
		if wanted.has(t):
			return true
	return false


## Nama desa sasaran event (untuk teks kartu).
func event_village_name(e: EventData) -> String:
	var t: Array = event_targets.get(e.id, [])
	if t.size() < 2 or t[1] < 0:
		return "sebuah desa"
	var s: ProvinceState = provinces.get(t[0])
	return s.villages[t[1]].name() if s else "sebuah desa"


## Provinsi asal desa sasaran event (kosong jika tidak ada).
func event_origin_name(e: EventData) -> String:
	var t: Array = event_targets.get(e.id, [])
	if t.size() < 2 or t[1] < 0:
		return ""
	var s: ProvinceState = provinces.get(t[0])
	return s.villages[t[1]].origin() if s else ""


## Kesiapan menghadapi event otomatis (0..1): Komunitas wilayah sasaran + upgrade yang relevan.
## Bencana: upgrade pengurang krisis (Peta Risiko, Sensor, dll.) dan Teknisi Warga energi yang rentan.
## Tekanan Kepentingan Lama: upgrade penahan resistensi merah. Lainnya: penahan resistensi biru.
func event_readiness(e: EventData, province_id: StringName) -> float:
	var s: ProvinceState = provinces.get(province_id)
	var comm := (s.community if s else community_average()) / 100.0
	var r := 0.15 + 0.3 * comm
	if e.is_disaster:
		r += -mod("crisis_mult") * 0.6
	elif e.opposition:
		r += -mod("red_growth_mult") * 0.9 - mod("blue_growth_mult") * 0.2
	else:
		r += -mod("blue_growth_mult") * 0.6 - mod("crisis_mult") * 0.2
	for en in e.vulnerable_energies:
		if owned_upgrades.has(StringName("%s_teknisi" % en)):
			r += 0.15
	return clampf(r, 0.05, 0.95)


## Nama upgrade yang belum dimiliki dan akan menaikkan Kesiapan untuk event ini (untuk kartu hasil).
func event_helpers(e: EventData, limit: int = 2) -> Array[String]:
	var key: StringName = &"crisis_mult" if e.is_disaster else (&"red_growth_mult" if e.opposition else &"blue_growth_mult")
	var out: Array[String] = []
	for en in e.vulnerable_energies:
		var t := db.get_upgrade(StringName("%s_teknisi" % en))
		if t and energies.has(en) and not owned_upgrades.has(t.id) and out.size() < limit:
			out.append("%s (%s)" % [t.display_name, db.get_energy(en).display_name])
	for u in db.upgrades:
		if out.size() >= limit:
			break
		if not owned_upgrades.has(u.id) and u.modifiers.get(key, 0.0) < 0.0:
			out.append(u.display_name)
	return out


## Event otomatis: Kesiapan menentukan hasilnya. Mengembalikan {ready, success, text}.
func resolve_event(e: EventData, province_id: StringName) -> Dictionary:
	var ready := event_readiness(e, province_id)
	var success := rng.randf() < ready
	var text := answer_event(e, province_id, 0 if success else 1, true)
	return {"ready": ready, "success": success, "text": text}


## Dipanggil UI saat pemain memilih. Mengembalikan teks hasil.
func answer_event(event: EventData, province_id: StringName, option_index: int, brief: bool = false) -> String:
	var opt: EventOption = event.option_a if option_index == 0 else event.option_b
	var s: ProvinceState = provinces.get(province_id)
	var v: VillageState = null
	var t: Array = event_targets.get(event.id, [])
	if s and t.size() >= 2 and t[1] >= 0 and t[1] < s.villages.size():
		v = s.villages[t[1]]
	event_targets.erase(event.id)
	_apply_effects(opt.effects, s, v)
	var text := opt.result_text
	if opt.crisis_severity > 0.0 and s != null:
		var lost := _apply_crisis(s, opt.crisis_severity, event)
		if lost[0] + lost[1] > 0:
			text += ("\n%s desa padam, %s desa mandiri turun jadi rapuh." if brief else "\n\nAkibat krisis: %s desa gagal (kembali ke fosil/gelap), %s desa mandiri turun menjadi rapuh.") % [ribu(lost[0]), ribu(lost[1])]
		elif not brief:
			text += "\n\nKomunitas cukup kuat: tidak ada desa yang gagal."
		if lost[2] > 0:
			text += "\nPembangunan di %d kloter tertunda hingga %d minggu." % [lost[2], lost[3]]
		if not event.vulnerable_energies.is_empty() and not brief:
			var names: Array[String] = []
			for eid in event.vulnerable_energies:
				var en := db.get_energy(eid)
				names.append(en.display_name if en else String(eid))
			text += "\nEnergi yang paling rentan pada bencana ini: %s." % ", ".join(names)
	_check_end()
	changed.emit()
	return text


## Kerentanan desa terhadap krisis event: energi rentan dan ciri sasaran memperparah.
func _vulnerability(v: VillageState, e: EventData) -> float:
	return _vulnerability_energy(v, v.energy, e)


func _vulnerability_energy(v: VillageState, energy: StringName, e: EventData) -> float:
	if e == null:
		return 1.0
	var m := energy_fragility(energy)
	if e.vulnerable_energies.has(energy):
		m *= 2.0
	if not e.target_traits.is_empty():
		m *= 1.5 if _has_any_trait(v, e.target_traits) else 0.5
	return m


## Mengembalikan [desa gagal, desa mandiri turun, kloter yang pembangunannya tertunda, minggu tunda]
## (jumlah desa = desa nyata, bukan kloter).
func _apply_crisis(s: ProvinceState, severity: float, event: EventData = null) -> Array:
	var sev := severity * mult("crisis_mult", 0.3)
	var failed := 0
	var downgraded := 0
	var delayed := 0
	var delay_weeks := 0
	for v in s.villages:
		if v.status == V_LIT:
			var fragility := 2.0 - village_compat(s, v, v.energy)
			if rng.randf() < sev * cfg.crisis_lit_loss * fragility * _vulnerability(v, event):
				_revert_village(s, v)
				failed += v.size()
		elif v.status == V_INDEP and cfg.enable_village_downgrade and s.community < cfg.crisis_independent_threshold:
			if rng.randf() < sev * cfg.crisis_independent_loss * _vulnerability(v, event):
				v.status = V_LIT
				downgraded += v.size()
		elif v.is_building():
			# Bencana menunda pembangunan yang sedang berjalan (paling parah untuk energi yang rentan).
			var b_vuln := _vulnerability_energy(v, v.build_energy, event)
			if rng.randf() < minf(1.0, sev * cfg.crisis_build_delay_chance * b_vuln):
				var w := int(round(cfg.crisis_build_delay_weeks * clampf(b_vuln, 0.5, 2.0)))
				var wt := ticks_of_weeks(w)
				v.build_left += wt
				v.build_total += wt
				delayed += 1
				delay_weeks = maxi(delay_weeks, w)
	s.recount()
	if failed + downgraded > 0:
		_news(&"village_down", s)
		_bump(&"villages_lost", failed + downgraded)
	if delayed > 0:
		_news(&"build_delayed", s)
		_bump(&"builds_delayed", delayed)
	return [failed, downgraded, delayed, delay_weeks]


func _apply_effects(effects: Dictionary, s: ProvinceState, v: VillageState) -> void:
	for key: StringName in effects:
		var amount: float = effects[key]
		match key:
			&"points":
				points = maxf(0.0, points + amount)
			&"money":
				money = clampf(money + amount, 0.0, 100.0)
			&"welfare":
				welfare = clampf(welfare + amount, 0.0, 100.0)
			&"blue":
				blue = clampf(blue + amount, 0.0, 100.0)
			&"red":
				if cfg.enable_red_resistance:
					red = clampf(red + amount, 0.0, cfg.red_max)
			&"community":
				if s:
					s.community = clampf(s.community + amount, 0.0, 100.0)
			&"lit":
				if s:
					if amount > 0:
						for i in int(amount):
							if s.unclean() > 0:
								_light_village(s)
					else:
						for i in mini(int(-amount), s.lit):
							_revert_village(s)
			&"fossil":
				# Desa gelap mendapat listrik dari energi fosil (mis. genset). Desa sasaran didahulukan.
				if s:
					for i in int(amount):
						var target := v if v and v.status == V_DARK else _first_with_status(s, V_DARK)
						if target:
							target.status = V_FOSSIL
							target.energy = &""
					s.recount()
			&"to_fossil":
				# Desa rapuh kembali memakai energi fosil. Desa sasaran didahulukan.
				if s:
					for i in int(amount):
						var target := v if v and v.status == V_LIT else _first_with_status(s, V_LIT)
						if target:
							target.status = V_FOSSIL
							target.energy = &""
					s.recount()
			_:
				if String(key).begins_with("count_"):
					_bump(StringName(String(key).substr(6)), int(amount))


func _first_with_status(s: ProvinceState, status: int) -> VillageState:
	for v in s.villages:
		if v.status == status:
			return v
	return null


# ---------------------------------------------------------------- aksi pemain

## village_index & energy hanya dipakai aksi BUILD (bangun di desa tertentu dengan energi pilihan).
## Jika -1 / kosong, game memilih desa dan energi terbaik secara otomatis.
func can_do_action(action: ActionData, province_id: StringName, village_index: int = -1, energy: StringName = &"") -> String:
	if game_over:
		return "Permainan selesai."
	var s: ProvinceState = provinces.get(province_id)
	if s == null:
		return "Pilih provinsi dulu."
	if action.requires_upgrade != &"" and not owned_upgrades.has(action.requires_upgrade):
		var u := db.get_upgrade(action.requires_upgrade)
		return "Butuh upgrade: %s" % (u.display_name if u else String(action.requires_upgrade))
	if not is_reachable(s):
		return "Belum terjangkau. Butuh tetangga yang berenergi bersih atau rute pesawat."
	match action.effect:
		ActionData.Effect.BUILD:
			if s.unclean() == 0:
				return "Semua desa di sini sudah memakai energi bersih."
			if s.unclean() - s.building() <= 0:
				return "Desa yang tersisa sedang dibangun."
			if village_index < 0 and _pick_auto_village(s) == null:
				return "Belum ada desa yang cocok dengan energi yang sudah dibuka. Buka energi lain di Pohon Upgrade, atau pilih kloter dan bangun sendiri."
			if village_index >= 0:
				if village_index >= s.villages.size():
					return "Desa tidak ada."
				if s.villages[village_index].is_clean():
					return "Desa ini sudah memakai energi bersih."
				if s.villages[village_index].is_building():
					return "Pembangkit di sini sedang dibangun."
			if energy != &"" and not energies.has(energy):
				return "Energi ini belum dibuka."
		ActionData.Effect.INTERNET:
			if s.internet:
				return "Internet desa sudah terpasang."
			if s.on() == 0:
				return "Butuh desa berenergi bersih dulu."
		ActionData.Effect.TRAIN:
			if s.community >= 100.0:
				return "Komunitas sudah penuh."
	if points < action_cost_points(action, s):
		return "Poin Dukungan kurang."
	if action.cost_money > 0 and money - action.cost_money < cfg.money_reserve:
		return "Ekonomi kurang."
	return ""


func action_cost_points(action: ActionData, s: ProvinceState) -> float:
	var cost := float(action.cost_points)
	if action.effect == ActionData.Effect.BUILD and s.seed and not s.built_once:
		cost *= 1.0 - cfg.seed_build_discount
	return cost


func do_action(action: ActionData, province_id: StringName, village_index: int = -1, energy: StringName = &"") -> bool:
	if can_do_action(action, province_id, village_index, energy) != "":
		return false
	var s: ProvinceState = provinces[province_id]
	points -= action_cost_points(action, s)
	money -= action.cost_money
	match action.effect:
		ActionData.Effect.BUILD:
			s.built_once = true
			if cfg.enable_build_time:
				_start_construction(s, village_index, energy)
			else:
				var v := _light_village(s, false, village_index, energy)
				if v:
					_reveal_compat(s, v)
			blue = clampf(blue + cfg.build_blue_outsider * clampf(1.0 - s.community / 50.0, 0.0, 1.0), 0.0, 100.0)
			_bump(&"built")
		ActionData.Effect.TRAIN:
			s.community = minf(100.0, s.community + action.amount * (1.0 + mod("community_gain")))
			_bump(&"trained")
			if kkn_active:
				_bump(&"trained_in_kkn")
		ActionData.Effect.INTERNET:
			s.internet = true
			_news(&"internet_installed", s)
		ActionData.Effect.DIALOG:
			blue = maxf(0.0, blue - action.amount)
			s.community = minf(100.0, s.community + 3.0)
			_bump(&"dialog")
	_check_missions()
	changed.emit()
	return true


func is_reachable(s: ProvinceState) -> bool:
	# Benih internet: warga di sana sudah kenal gerakan ini dan mengundang tim untuk membangun.
	if s.data.id == start_province or s.on() > 0 or s.seed:
		return true
	for n in s.data.neighbors:
		var ns: ProvinceState = provinces.get(n)
		if ns and ns.on() > 0:
			return true
	return air_islands.has(s.data.island.id)


func collect_bubble() -> void:
	points += cfg.bubble_points
	changed.emit()


# ---------------------------------------------------------------- upgrade

func upgrade_state(u: UpgradeData) -> String:
	## "" = bisa dibeli, "owned" = sudah, selain itu alasan terkunci.
	if owned_upgrades.has(u.id):
		return "owned"
	for r in u.requires:
		if not owned_upgrades.has(r):
			var ru := db.get_upgrade(r)
			return "Butuh: %s" % (ru.display_name if ru else String(r))
	if u.requires_flag != &"" and not flags.has(u.requires_flag):
		match u.requires_flag:
			&"post_kkn": return "Terbuka setelah KKN selesai"
			&"gov_partner": return "Butuh kerja sama pemerintah (terima satu tawaran)"
			&"airplane": return "Terbuka setelah rute pesawat dibuka pemerintah"
		return "Belum terbuka"
	if points < upgrade_cost(u):
		return "Poin Dukungan kurang"
	if u.cost_money > 0 and money - u.cost_money < cfg.money_reserve:
		return "Ekonomi kurang"
	return ""


## Biaya Poin saat ini: naik setiap kali upgrade lain dibeli (gaya Plague Inc).
func upgrade_cost(u: UpgradeData) -> int:
	var bought := int(counters.get(&"upgrades_bought", 0))
	return int(round(u.cost_points * (1.0 + cfg.upgrade_cost_growth * bought)))


func buy_upgrade(u: UpgradeData) -> bool:
	if upgrade_state(u) != "":
		return false
	points -= upgrade_cost(u)
	money -= u.cost_money
	owned_upgrades[u.id] = true
	_bump(&"upgrades_bought")
	if u.unlock_energy != &"" and not energies.has(u.unlock_energy):
		energies.append(u.unlock_energy)
	for f in u.flags:
		flags[f] = true
	if u.id == &"rute_udara":
		_open_air_routes(99)
	_recompute_mods()
	_check_missions()
	changed.emit()
	return true


func _recompute_mods() -> void:
	mods.clear()
	for id in owned_upgrades:
		var u := db.get_upgrade(id)
		if u == null:
			continue
		for k in u.modifiers:
			mods[k] = mods.get(k, 0.0) + u.modifiers[k]


func mod(key: StringName) -> float:
	return mods.get(key, 0.0)


## Pengali Poin/Ekonomi dari desa yang memakai energi ini (upgrade "output:<energi>").
func energy_output(energy: StringName) -> float:
	if energy == &"":
		return 1.0
	return 1.0 + mod(StringName("output:%s" % energy))


## Pengali peluang rusak dan dampak bencana untuk energi ini (upgrade "quality:<energi>").
func energy_fragility(energy: StringName) -> float:
	if energy == &"":
		return 1.0
	return maxf(0.25, 1.0 - mod(StringName("quality:%s" % energy)))


## Pengali dengan batas bawah, supaya tumpukan upgrade tidak menghapus suatu ancaman sepenuhnya.
func mult(key: StringName, floor_value: float = 0.4) -> float:
	return maxf(floor_value, 1.0 + mod(key))


# ---------------------------------------------------------------- misi

func _check_missions() -> void:
	if not kkn_active:
		return
	for m in db.missions:
		if completed_missions.has(m.id):
			continue
		var value: int = counters.get(m.counter, 0)
		match m.counter:
			&"lit_total":
				value = total_on()
			&"start_community":
				value = int(provinces[start_province].community)
		if value >= m.target:
			completed_missions[m.id] = true
			points += m.reward_points
			blue = maxf(0.0, blue - m.reward_blue)
			news.emit(&"mission_done", {"province": m.text, "island": "", "village": ""})


# ---------------------------------------------------------------- akhir

func _check_end() -> void:
	if game_over:
		return
	if total_resistance() >= 100.0:
		_end(&"lose_resistance")
	elif welfare <= 0.0:
		_end(&"lose_welfare")
	elif money_zero_ticks >= cfg.economy_grace_ticks:
		_end(&"lose_economy")
	elif _all_dark_too_long():
		_end(&"lose_dark")
	elif desa_dark() + desa_fossil() == 0:
		# Semua desa di Indonesia sudah memakai energi bersih.
		_end(&"win")
	elif (cfg.max_ticks > 0 and tick_count >= cfg.max_ticks) or (cfg.deadline_year > 0 and current_year() >= cfg.deadline_year):
		_end(&"timeout")


func _all_dark_too_long() -> bool:
	if kkn_active or total_on() > 0 or total_building() > 0:
		dark_ticks = 0
		return false
	dark_ticks += 1
	if dark_ticks == 1:
		_news_once(&"all_dark_warning", null)
	return dark_ticks >= cfg.dark_grace_ticks


func _end(r: StringName) -> void:
	game_over = true
	result = r
	game_ended.emit(r)


func ending_title() -> String:
	if result == &"win":
		if independent_ratio() < cfg.win_independent:
			return "Bersih tapi Rapuh"
		if current_year() < cfg.fast_win_year:
			return "Cepat dan Tahan"
		return "Tepat Waktu" if current_year() <= _final_milestone_year() else "Pelan tapi Tahan"
	if result == &"timeout":
		return "Belum Tuntas"
	if total_on() > 0 and float(total_independent()) / total_on() < 0.3:
		return "Cepat tapi Rapuh"
	if result == &"lose_resistance":
		return "Ditolak Warga"
	return "Padam"


func ending_reason() -> String:
	match result:
		&"win":
			var text := "Seluruh %s desa di Indonesia kini memakai energi bersih, dan %d%% di antaranya dirawat warganya sendiri." % [ribu(desa_total()), roundi(independent_ratio() * 100)]
			var year := current_year()
			for m in db.milestones:
				if m.target_no_dark or m.on_track_access >= 0.0:
					continue
				if year < m.year:
					text += " Target tercapai pada %d, %d tahun lebih cepat dari %s." % [year, m.year - year, m.title]
				elif year == m.year:
					text += " Target tercapai pada %d, tepat di tahun %s." % [year, m.title]
				else:
					text += " Target tercapai pada %d, %d tahun setelah %s." % [year, year - m.year, m.title]
				break
			return text
		&"lose_resistance": return "Resistensi penuh. Warga dan pihak yang diuntungkan energi lama menolak program."
		&"lose_welfare": return "Kesejahteraan warga runtuh."
		&"lose_economy": return "Ekonomi habis terlalu lama. Program tidak bisa dibiayai."
		&"lose_dark": return "Semua pembangkit energi bersih padam setelah tim KKN pulang. Tidak ada yang merawat."
		&"timeout": return "Tahun %d tiba, tapi belum semua desa memakai energi bersih. Kepentingan lama sempat mengakar terlalu dalam." % cfg.deadline_year
	return ""


func _final_milestone_year() -> int:
	for m in db.milestones:
		if not m.target_no_dark and m.on_track_access < 0.0:
			return m.year
	return 2060


# ---------------------------------------------------------------- perayaan kota

func _check_cities() -> void:
	if db.cities.is_empty() or celebrated_cities.size() >= db.cities.size():
		return
	var clean := {}
	var total := {}
	for s: ProvinceState in provinces.values():
		for v in s.villages:
			var o := v.origin()
			total[o] = total.get(o, 0) + v.size()
			if v.is_clean():
				clean[o] = clean.get(o, 0) + v.size()
	for o in total:
		if celebrated_cities.has(o) or not db.cities.has(o):
			continue
		var share := float(clean.get(o, 0)) / maxf(1.0, total[o])
		if share >= cfg.city_celebrate_share:
			celebrated_cities[o] = current_year()
			city_celebrated.emit(db.cities[o], o, share)


# ---------------------------------------------------------------- tonggak waktu

func milestone_tick(m: MilestoneData) -> int:
	return tick_of_year(m.year)


func _check_milestones() -> void:
	if game_over:
		return
	for m in db.milestones:
		if not milestone_reports.has(m.id) and tick_count >= milestone_tick(m):
			trigger_milestone(m)


## Evaluasi tonggak sekarang juga (juga dipakai tombol debug).
func trigger_milestone(m: MilestoneData) -> void:
	var r := milestone_report(m)
	milestone_reports[m.id] = r
	milestone_reached.emit(m, r)


func milestone_report(m: MilestoneData) -> Dictionary:
	var ta := m.target_access if m.target_access >= 0.0 else cfg.win_access
	var ti := m.target_independent if m.target_independent >= 0.0 else cfg.win_independent
	return {
		"year": current_year(),
		"access": access_ratio(), "independent": independent_ratio(),
		"target_access": ta, "target_independent": ti,
		"clean_desa": desa_on(), "total_desa": desa_total(), "dark_desa": desa_dark(),
		"fossil_desa": desa_fossil(), "start_dark": _start_dark_desa(),
		"met": (desa_dark() == 0) if m.target_no_dark else (access_ratio() >= ta and independent_ratio() >= ti),
		"has_track": m.on_track_access >= 0.0,
		"track_access": m.on_track_access, "track_independent": maxf(0.0, m.on_track_independent),
		"on_track": m.on_track_access >= 0.0 and access_ratio() >= m.on_track_access \
			and independent_ratio() >= maxf(0.0, m.on_track_independent),
	}


func _start_dark_desa() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		for v in s.villages:
			if v.data and not v.data.start_fossil:
				n += v.size()
	return n


## Teks evaluasi tonggak untuk popup.
func milestone_text(m: MilestoneData, r: Dictionary) -> String:
	var lines: Array[String] = []
	if m.intro != "":
		lines.append(m.intro)
		lines.append("")
	lines.append("CAPAIAN SAMPAI %s" % date_text().to_upper())
	if m.target_no_dark:
		lines.append("Desa yang masih punya warga tanpa listrik: %s (awal: %s, target: 0)." % [ribu(r["dark_desa"]), ribu(r["start_dark"])])
		var done := int(r["start_dark"]) - int(r["dark_desa"])
		lines.append("Sudah terjangkau: %s desa (%d%%)." % [ribu(maxi(0, done)), roundi(100.0 * maxi(0, done) / maxf(1.0, r["start_dark"]))])
	var gap_access: float = r["target_access"] - r["access"]
	lines.append("Desa berenergi bersih: %d%% (target %d%%)%s." % [roundi(r["access"] * 100), roundi(r["target_access"] * 100),
		(", kurang ±%s desa" % ribu(int(ceil(gap_access * r["total_desa"])))) if gap_access > 0.0 else ", tercapai"])
	lines.append("Dirawat warga sendiri (mandiri): %d%% (target %d%%)." % [roundi(r["independent"] * 100), roundi(r["target_independent"] * 100)])
	lines.append("Masih memakai listrik fosil: %s desa." % ribu(r["fossil_desa"]))
	lines.append("")
	if r["has_track"]:
		lines.append("JALUR MENUJU TARGET 2060")
		lines.append("Batas minimum tahun ini: %d%% desa berenergi bersih dan %d%% mandiri." % [
			roundi(r["track_access"] * 100), roundi(r["track_independent"] * 100)])
		if r["on_track"]:
			lines.append("DI JALUR. Dengan laju seperti ini, target 2060 bisa tercapai, bahkan lebih cepat.")
		else:
			var need := maxf(0.0, r["track_access"] - r["access"])
			lines.append("KELUAR JALUR. Perlu ±%s desa bersih lagi untuk kembali ke jalur. Perkuat komunitas dan pilih energi yang cocok." % ribu(int(ceil(need * r["total_desa"]))) if need > 0.0
				else "KELUAR JALUR. Desa sudah banyak menyala, tapi terlalu sedikit yang dirawat warga sendiri. Perkuat Edukasi & Warga.")
	elif r["met"]:
		lines.append("Target tonggak ini tercapai. Pertahankan, dan lanjutkan sampai semua desa mandiri.")
	elif not m.target_no_dark and gap_access <= 0.15:
		lines.append("Hampir sampai. Sedikit lagi.")
	else:
		lines.append("Belum tercapai.")
	lines.append("Permainan berlanjut.")
	return "\n".join(lines)


## Satu baris singkat untuk notifikasi kecil.
func milestone_short(m: MilestoneData, r: Dictionary) -> String:
	var t := "%s: %d%% desa bersih, %d%% mandiri." % [m.title, roundi(r["access"] * 100), roundi(r["independent"] * 100)]
	if r.get("has_track", false):
		t += " DI JALUR menuju 2060." if r["on_track"] else " KELUAR JALUR dari target 2060."
	return t


## Satu baris ringkasan tonggak untuk layar akhir.
func milestone_summary(m: MilestoneData, r: Dictionary) -> String:
	if r.get("has_track", false):
		return "%d: %d%% desa berenergi bersih, %s menuju target 2060." % [m.year, roundi(r["access"] * 100),
			"di jalur" if r["on_track"] else "keluar jalur"]
	return "%s (%d): %d%% desa berenergi bersih (target %d%%), %d%% mandiri (target %d%%)." % [m.title, m.year,
		roundi(r["access"] * 100), roundi(r["target_access"] * 100), roundi(r["independent"] * 100), roundi(r["target_independent"] * 100)]


## Tiga keputusan yang paling menentukan, untuk layar akhir.
func key_decisions() -> Array[String]:
	var out: Array[String] = []
	var kkn_comm := int(counters.get(&"kkn_end_community", 0))
	var lost_kkn := ribu(int(counters.get(&"kkn_lost", 0)))
	if kkn_comm < int(cfg.kkn_test_threshold):
		out.append("Saat tim KKN pulang, Komunitas wilayah awal baru %d, sehingga %s desa gagal. Upgrade Edukasi & Warga mempercepat Komunitas." % [kkn_comm, lost_kkn])
	else:
		out.append("Saat tim KKN pulang, Komunitas wilayah awal sudah %d. Desa yang gagal: %s." % [kkn_comm, lost_kkn])
	var acc := int(counters.get(&"offers_accepted", 0))
	var ref := int(counters.get(&"offers_refused", 0))
	if acc + ref == 0:
		out.append("Pemerintah tidak pernah menawarkan kerja sama. Skor kelayakanmu belum cukup tinggi.")
	else:
		out.append("Tawaran pemerintah: %d diterima, %d ditolak. Target gagal: %d." % [acc, ref, int(counters.get(&"offer_targets_failed", 0))])
	var lost := int(counters.get(&"villages_lost", 0))
	var genset := int(counters.get(&"genset", 0))
	var mismatch := int(counters.get(&"built_mismatch", 0))
	var line := "Desa yang gagal atau turun status karena krisis dan bencana: %s." % ribu(lost)
	if mismatch > 0:
		line += " %d kali kamu membangun dengan energi yang kurang cocok." % mismatch
	if genset > 0:
		line += " Kamu memilih genset %d kali, memberi makan Kepentingan Lama." % genset
	out.append(line)
	for m in db.milestones:
		if milestone_reports.has(m.id):
			out.append(milestone_summary(m, milestone_reports[m.id]))
	return out


# ---------------------------------------------------------------- desa

# ---------------------------------------------------------------- masa pembangunan

## Pemain memesan pembangunan: biaya dibayar sekarang, pembangkit menyala setelah
## build_weeks_min..build_weeks_max minggu (bisa tertunda bencana). Kecocokan terungkap saat menyala.
func _start_construction(s: ProvinceState, village_index: int, energy: StringName) -> VillageState:
	var v: VillageState = null
	if village_index >= 0 and village_index < s.villages.size():
		v = s.villages[village_index]
	else:
		v = _pick_auto_village(s)
	if v == null or v.is_clean() or v.is_building():
		return null
	v.build_energy = energy if energy != &"" else best_energy_for(s, v, energies)
	var weeks := rng.randi_range(cfg.build_weeks_min, cfg.build_weeks_max)
	var energy_speed := maxf(0.4, 1.0 - mod(StringName("build:%s" % v.build_energy)))
	weeks = maxi(1, int(round(weeks * mult("build_time_mult", 0.4) * energy_speed)))
	var ticks := ticks_of_weeks(weeks)
	v.build_left = ticks
	v.build_total = ticks
	_news(&"build_started", s, v)
	return v


## Kloter untuk bangun otomatis / Bangun tanpa memilih kloter: hanya desa yang cocok dengan
## energi yang sudah dibuka; desa gelap didahulukan, lalu yang paling cocok.
func _pick_auto_village(s: ProvinceState, require_near: bool = false) -> VillageState:
	var v: VillageState = null
	for c in s.villages:
		if c.is_clean() or c.is_building() or not is_eligible(s, c, energies):
			continue
		if require_near and not c.near:
			continue
		if v == null or (c.status == V_DARK and v.status != V_DARK) \
				or (c.status == v.status and best_village_compat(s, c) > best_village_compat(s, v)):
			v = c
	return v


func _construction() -> void:
	for s: ProvinceState in provinces.values():
		for v in s.villages:
			if v.build_left <= 0:
				continue
			v.build_left -= 1
			if v.build_left > 0:
				continue
			v.build_total = 0
			if v.is_clean():
				continue
			var lit := _light_village(s, false, v.index, v.build_energy)
			v.build_energy = &""
			if lit:
				_reveal_compat(s, lit)


## Membaca tetangga antar-kloter. Tanpa file ini semua kloter dianggap dekat (aturan lama).
func _load_links() -> void:
	const PATH := "res://data/kloter_links.json"
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return
	for id in provinces:
		var s: ProvinceState = provinces[id]
		var rows: Array = data.get(String(id), [])
		for i in mini(rows.size(), s.villages.size()):
			for key in rows[i]:
				var parts: PackedStringArray = String(key).split(":")
				var ns: ProvinceState = provinces.get(StringName(parts[0]))
				var j := int(parts[1])
				if ns and j < ns.villages.size():
					s.villages[i].links.append(ns.villages[j])
	_has_links = true


var _has_links := false


## Kloter "dekat" = paling jauh spread_max_hops langkah dari kloter yang sudah berenergi bersih.
func _update_near() -> void:
	if not _has_links:
		return
	var dist: Dictionary = {}
	var frontier: Array = []
	for s: ProvinceState in provinces.values():
		for v in s.villages:
			v.near = false
			if v.is_clean():
				v.lit_age += 1
				dist[v] = 0
				frontier.append(v)
	var hops := 0
	while not frontier.is_empty() and hops < cfg.spread_max_hops:
		hops += 1
		var next: Array = []
		for v in frontier:
			for n in v.links:
				if not dist.has(n):
					dist[n] = hops
					next.append(n)
		frontier = next
	for v in dist:
		v.near = true


var _auto_cd := 0


## 0 di awal permainan, 1 saat momentum_full_access desa sudah berenergi bersih.
func momentum_progress() -> float:
	return smoothstep(0.0, cfg.momentum_full_access, access_ratio())


## Pengali sebaran: lambat di awal, makin cepat saat makin banyak desa memakai energi bersih.
func momentum() -> float:
	return lerpf(cfg.spread_early_mult, cfg.spread_late_mult, momentum_progress())


## Tampilan: seberapa penuh warna energi di sel kloter ini (0..1).
func fill_fraction(v: VillageState) -> float:
	var ticks := lerpf(cfg.fill_ticks_early, cfg.fill_ticks_late, momentum_progress())
	return clampf(float(v.lit_age + 1) / maxf(1.0, ticks), 0.0, 1.0)


func total_building() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.building()
	return n


## Satu desa mulai memakai energi bersih (menjadi "rapuh"). Mengembalikan desanya.
## - Aksi pemain: desa & energi pilihan pemain; jika tidak diisi, desa gelap paling cocok didahulukan.
## - Sebaran: desa dipilih acak berbobot kecocokan; desa fosil lebih jarang beralih dan
##   menaikkan resistensi merah karena menyentuh kepentingan lama.
func _light_village(s: ProvinceState, from_spread: bool = false, village_index: int = -1, energy: StringName = &"", pool: Array = [], require_near: bool = false) -> VillageState:
	var epool: Array[StringName] = []
	epool.assign(pool if not pool.is_empty() else energies)
	if s.unclean() == 0:
		return null
	var v: VillageState = null
	if village_index >= 0 and village_index < s.villages.size() and not s.villages[village_index].is_clean():
		v = s.villages[village_index]
	elif from_spread:
		var total_w := 0.0
		var weights: Array[float] = []
		for c in s.villages:
			var w := 0.0
			if not c.is_clean() and not c.is_building() and is_eligible(s, c, epool) and (c.near or not require_near):
				w = (1.0 if c.status == V_DARK else cfg.fossil_convert_weight) * (0.3 + best_village_compat(s, c, epool))
			weights.append(w)
			total_w += w
		if total_w <= 0.0:
			return null
		var roll := rng.randf() * total_w
		for i in s.villages.size():
			roll -= weights[i]
			if weights[i] > 0.0 and roll <= 0.0:
				v = s.villages[i]
				break
	else:
		for c in s.villages:
			if c.is_clean() or c.is_building():
				continue
			if v == null or (c.status == V_DARK and v.status != V_DARK) \
					or (c.status == v.status and best_village_compat(s, c) > best_village_compat(s, v)):
				v = c
	if v == null:
		return null
	var was_dark := s.on() == 0
	if v.status == V_FOSSIL:
		_bump(&"fossil_converted")
		if cfg.enable_red_resistance:
			red = clampf(red + cfg.fossil_convert_red, 0.0, cfg.red_max)
	else:
		welfare = clampf(welfare + cfg.new_access_welfare, 0.0, 100.0)
	v.energy = energy if energy != &"" else best_energy_for(s, v, epool)
	v.status = V_LIT
	v.lit_age = 0
	s.recount()
	_bump(&"lit_ever")
	if not from_spread and village_compat(s, v, v.energy) < 0.45:
		_bump(&"built_mismatch")
	if was_dark:
		_news(&"province_first_lit", s, v)
	else:
		_news(&"village_lit", s, v)
	return v


## Desa rapuh yang gagal kembali ke kondisi awalnya: fosil jika dulu memakai fosil, selain itu gelap.
## Jika desa tidak disebut, desa rapuh dengan energi paling tidak cocok yang gagal lebih dulu.
func _revert_village(s: ProvinceState, v: VillageState = null) -> void:
	if v == null:
		for c in s.villages:
			if c.status == V_LIT and (v == null or village_compat(s, c, c.energy) < village_compat(s, v, v.energy)):
				v = c
	if v == null or v.status != V_LIT:
		return
	v.status = V_FOSSIL if (v.data and v.data.start_fossil) else V_DARK
	v.energy = &""
	s.recount()


## Setelah pemain membangun di sebuah desa, kecocokan energinya terungkap.
func _reveal_compat(s: ProvinceState, v: VillageState) -> void:
	var key := "%s:%d:%s" % [s.data.id, v.index, v.energy]
	if known_compat.has(key):
		return
	known_compat[key] = true
	var en := db.get_energy(v.energy)
	var c := village_compat(s, v, v.energy)
	var verdict := "cocok, mudah menyebar dan awet"
	if c < 0.45:
		verdict = "kurang cocok, mudah rusak dan lambat menyebar"
	elif c < 0.9:
		verdict = "lumayan cocok"
	news.emit(&"compat_revealed", {"province": s.data.display_name, "island": s.data.island.display_name,
		"village": v.name(), "energy": en.display_name if en else String(v.energy), "verdict": verdict})


func is_compat_known(province_id: StringName, village_index: int, energy_id: StringName) -> bool:
	return known_compat.has("%s:%d:%s" % [province_id, village_index, energy_id])


## Kecocokan energi tingkat pulau/provinsi (sebelum ciri desa).
func compat(s: ProvinceState, energy_id: StringName) -> float:
	if s.data.compat_override.has(energy_id):
		return s.data.compat_override[energy_id]
	return s.data.island.energy_compat.get(energy_id, 0.15)


## Kecocokan energi di satu desa (0.15 sampai 1.0). Ciri desa paling menentukan,
## kecocokan pulau hanya memberi kecenderungan:
##   village_base + village_island_weight x kecocokan pulau + jumlah bonus ciri desa.
func village_compat(s: ProvinceState, v: VillageState, energy_id: StringName) -> float:
	if energy_id == &"":
		return 0.15
	if v.data == null:
		return compat(s, energy_id)
	# Kecocokan provinsi asal kloter (RUEN); jika kosong, kecocokan wilayah.
	var base: float = v.data.compat.get(energy_id, compat(s, energy_id)) if not v.data.compat.is_empty() else compat(s, energy_id)
	var c := cfg.village_base_compat + cfg.village_island_weight * base
	for t in v.data.traits:
		var td := db.get_trait(t)
		if td:
			c += td.energy_bonus.get(energy_id, 0.0)
	c += mod(StringName("fit:%s" % energy_id))
	return clampf(c, 0.15, 1.0)


func best_energy_for(s: ProvinceState, v: VillageState, pool: Array[StringName] = []) -> StringName:
	var best: StringName = &""
	var best_c := -1.0
	for e in (pool if not pool.is_empty() else energies):
		var c := village_compat(s, v, e)
		if c > best_c:
			best_c = c
			best = e
	return best


func best_village_compat(s: ProvinceState, v: VillageState, pool: Array[StringName] = []) -> float:
	return village_compat(s, v, best_energy_for(s, v, pool))


## Rata-rata kecocokan terbaik di desa yang belum berenergi bersih (penentu kecepatan sebar).
## pool = energi yang bisa ditiru (kosong = semua energi yang sudah dibuka).
## Desa ini mau meniru / dibangun otomatis? Hanya jika ada energi (dari pool) yang minimal "sedang" cocok.
func is_eligible(s: ProvinceState, v: VillageState, pool: Array[StringName] = []) -> bool:
	return best_village_compat(s, v, pool) >= cfg.adopt_min_compat


## Kekuatan sebar ke wilayah ini: rata-rata kecocokan desa yang belum bersih, tapi desa yang
## tidak cocok dengan energi mana pun di pool dihitung 0 (mereka tidak terpengaruh).
func spread_compat(s: ProvinceState, pool: Array[StringName] = []) -> float:
	var sum := 0.0
	var n := 0
	for v in s.villages:
		if v.is_clean():
			continue
		n += 1
		var c := best_village_compat(s, v, pool)
		if c >= cfg.adopt_min_compat and not v.is_building():
			sum += c
	return sum / n if n > 0 else 0.0


func best_compat(s: ProvinceState, pool: Array[StringName] = []) -> float:
	var sum := 0.0
	var n := 0
	for v in s.villages:
		if not v.is_clean():
			sum += best_village_compat(s, v, pool)
			n += 1
	if n == 0:
		for v in s.villages:
			sum += best_village_compat(s, v, pool)
			n += 1
	return sum / n if n > 0 else 0.15


## Energi yang paling banyak dipakai desa berenergi bersih di provinsi ini (untuk panel).
func main_energy(s: ProvinceState) -> StringName:
	var counts: Dictionary = {}
	for v in s.villages:
		if v.is_clean():
			counts[v.energy] = counts.get(v.energy, 0) + 1
	var best: StringName = &""
	for e in counts:
		if best == &"" or counts[e] > counts[best]:
			best = e
	return best


func readiness(s: ProvinceState) -> float:
	var r := 0.45 + s.community / 100.0 * 0.75 - total_resistance() * 0.006
	# Desa yang sudah punya listrik fosil cenderung merasa "sudah cukup".
	r -= cfg.fossil_readiness_penalty * float(s.fossil) / maxf(1.0, s.total())
	if s.seed:
		r += 0.2
	return clampf(r, 0.1, 1.5)


# ---------------------------------------------------------------- total

func total_villages() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.total()
	return n


func total_on() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.on()
	return n


func total_lit() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.lit
	return n


func total_independent() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.independent
	return n


func total_fossil() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.fossil
	return n


func total_dark() -> int:
	return total_villages() - total_on() - total_fossil()


## Jumlah desa nyata (bukan kloter), untuk tampilan dan syarat menang.
func desa_total() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.total_desa()
	return n


func desa_lit() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.lit_desa
	return n


func desa_independent() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.independent_desa
	return n


func desa_fossil() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.fossil_desa
	return n


func desa_dark() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		n += s.dark_desa
	return n


func desa_on() -> int:
	return desa_lit() + desa_independent()


static func ribu(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "." + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if n < 0 else "") + t + out


## Bagian desa nyata yang berlistrik (fosil maupun bersih).
func electrified_ratio() -> float:
	var t := desa_total()
	return float(desa_on() + desa_fossil()) / t if t > 0 else 0.0


## Bagian desa yang memakai energi bersih.
func access_ratio() -> float:
	var t := desa_total()
	return float(desa_on()) / t if t > 0 else 0.0


func independent_ratio() -> float:
	var t := desa_total()
	return float(desa_independent()) / t if t > 0 else 0.0


func total_resistance() -> float:
	return blue + red


func community_average() -> float:
	var n := 0
	var sum := 0.0
	for s: ProvinceState in provinces.values():
		if s.on() > 0:
			n += 1
			sum += s.community
	return sum / n if n > 0 else 0.0


func lit_provinces() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		if s.on() > 0:
			n += 1
	return n


func independent_provinces() -> int:
	var n := 0
	for s: ProvinceState in provinces.values():
		if s.status() == &"independent":
			n += 1
	return n


## Minggu cerita sejak awal permainan (KKN 1 tik = 1 minggu, setelahnya lebih cepat).
func week_number(t: int = -1) -> int:
	if t < 0:
		t = tick_count
	if t <= cfg.kkn_ticks:
		return t
	return cfg.kkn_ticks + (t - cfg.kkn_ticks) * cfg.weeks_per_tick_after_kkn


func current_year() -> int:
	return cfg.start_year + week_number() / 52


## Tik pertama yang jatuh di awal tahun ini.
func tick_of_year(year: int) -> int:
	var w := (year - cfg.start_year) * 52
	if w <= cfg.kkn_ticks:
		return w
	return cfg.kkn_ticks + ceili(float(w - cfg.kkn_ticks) / cfg.weeks_per_tick_after_kkn)


## Lama sekian tik (mulai sekarang) dalam minggu cerita, untuk teks.
func weeks_of(ticks: int) -> int:
	return week_number(tick_count + ticks) - week_number()


## Lama sekian minggu cerita (mulai sekarang) dalam tik.
func ticks_of_weeks(weeks: int) -> int:
	if kkn_active:
		return weeks
	return maxi(1, roundi(float(weeks) / cfg.weeks_per_tick_after_kkn))


func date_text() -> String:
	var months := ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
	var week := week_number()
	var year := cfg.start_year + week / 52
	var month := int((week % 52) / 52.0 * 12.0)
	return "%s %d" % [months[month], year]


func kkn_weeks_left() -> int:
	return max(0, cfg.kkn_ticks - tick_count)


func _bump(key: StringName, by: int = 1) -> void:
	counters[key] = counters.get(key, 0) + by


var _news_seen: Dictionary = {}


func _news(trigger: StringName, s: ProvinceState, v: VillageState = null) -> void:
	var ctx := {"province": "", "island": "", "village": "", "kloter": ""}
	if s:
		ctx["province"] = v.origin() if v and v.origin() != "" else s.data.display_name
		ctx["island"] = s.data.island.display_name
		ctx["village"] = v.name() if v else "sebuah desa"
		ctx["kloter"] = v.kloter_text() if v else "sebuah desa"
	news.emit(trigger, ctx)


func _news_once(trigger: StringName, s: ProvinceState) -> void:
	var key := String(trigger) + (String(s.data.id) if s else "")
	if _news_seen.has(key):
		return
	_news_seen[key] = true
	_news(trigger, s)
