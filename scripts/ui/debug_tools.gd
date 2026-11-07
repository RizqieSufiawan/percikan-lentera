extends CanvasLayer
## Tombol debug untuk menguji semua fitur dengan cepat.
## Hanya aktif di build debug (dijalankan dari editor). Build Release tidak memuatnya.
## Tekan F1 di layar permainan untuk melihat daftar tombol.

const HELP := """DEBUG  (F1 untuk tutup)
F1   tampilkan / sembunyikan daftar ini
F2   +50 Poin, +30 Ekonomi
F3   event/bencana berikutnya  (Shift: sebelumnya)
F4   tawaran pemerintah: rapuh > biasa > lancar
F5   akhiri KKN, fase ujian asli (Shift: aman, desa tidak padam)
F6   nyalakan 1 desa di provinsi terpilih  (Shift: 5 desa)
F7   jadikan provinsi terpilih mandiri
F8   krisis di provinsi terpilih
F9   resistensi biru +15  (Shift: merah +15, Ctrl: reset ke 0)
F10  buka semua upgrade gratis
F11  benih di provinsi terpilih  (Shift: buka rute pesawat semua pulau)
F12  menang  (Shift: kalah resistensi, Ctrl: kalah padam)
Delete    isi PETA SETENGAH: separuh desa bersih, semua energi & upgrade terbuka, tahap 4
          (Shift: PENUH, semua desa bersih campur semua energi, 1 desa sengaja disisakan
          supaya belum menang; tekan F12 untuk layar menang)
Insert    lompat 1 tahun (berhenti jika ada kartu)
Home      naik tahap
End       munculkan gelembung aksi sekarang
PageUp    berita berikutnya (tes popup & ticker)
PageDown  tonggak waktu berikutnya (2030, 2040, 2045, 2050, 2060)"""

const TIERS: Array[StringName] = [&"rapuh", &"biasa", &"lancar"]

var _event_index: int = -1
var _offer_index: int = -1
var _milestone_index := -1
var _news_index: int = -1

var _help: PanelContainer
var _status: Label


func _ready() -> void:
	layer = 20
	_help = PanelContainer.new()
	_help.position = Vector2(250, 110)
	_help.visible = false
	var help_label := Label.new()
	help_label.text = HELP
	help_label.add_theme_font_size_override("font_size", 16)
	_help.add_child(help_label)
	add_child(_help)
	_status = Label.new()
	_status.text = "DEBUG aktif: tekan F1"
	_status.modulate = Color(1, 0.6, 0.6)
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_constant_override("outline_size", 4)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.anchor_left = 1.0
	_status.anchor_right = 1.0
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = -420
	_status.offset_right = -12
	_status.offset_top = -68
	_status.offset_bottom = -50
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if handle_key(event.keycode, event.shift_pressed, event.ctrl_pressed):
			get_viewport().set_input_as_handled()


## Dipisah dari input supaya bisa dipanggil dari tes.
func handle_key(key: Key, shift: bool = false, ctrl: bool = false) -> bool:
	var sim := Game.sim
	if sim == null or not is_inside_tree() or sim.game_over:
		return false
	var screen := get_parent()
	var pid: StringName = screen.map.selected if screen.map.selected != &"" else sim.start_province
	var s: Simulation.ProvinceState = sim.provinces[pid]
	var msg := ""
	match key:
		KEY_F1:
			_help.visible = not _help.visible
			return true
		KEY_F2:
			sim.points += 50
			sim.money = minf(100.0, sim.money + 30)
			msg = "+50 Poin, +30 Ekonomi"
		KEY_F3:
			var events := Game.db.events
			_event_index = wrapi(_event_index + (-1 if shift else 1), 0, events.size())
			var e: EventData = events[_event_index]
			var targets := sim._event_targets_for(e)
			var target := pid
			if not targets.has(pid) and not targets.is_empty():
				target = targets[0]
			msg = "event %d/%d: %s di %s" % [_event_index + 1, events.size(), e.id, target]
			sim.trigger_event(e, target)
		KEY_F4:
			_offer_index = wrapi(_offer_index + 1, 0, TIERS.size())
			for o in Game.db.offers:
				if o.tier == TIERS[_offer_index]:
					msg = "tawaran: " + String(o.tier)
					sim.offer_triggered.emit(o)
		KEY_F5:
			if sim.kkn_active:
				# Nyalakan 1 desa dulu jika belum ada, supaya tidak langsung kalah "padam".
				var start: Simulation.ProvinceState = sim.provinces[sim.start_province]
				if sim.total_on() == 0 and start.dark > 0:
					sim._light_village(start)
				if shift:
					# Mode aman: komunitas dinaikkan ke ambang supaya fase ujian tidak memadamkan desa.
					for ps: Simulation.ProvinceState in sim.provinces.values():
						if ps.lit > 0:
							ps.community = maxf(ps.community, Game.db.config.kkn_test_threshold + 5.0)
				sim.tick_count = maxi(sim.tick_count, Game.db.config.kkn_ticks - 1)
				sim.tick()
				msg = "KKN diakhiri" + (" (aman)" if shift else " (fase ujian asli)")
			else:
				msg = "KKN sudah selesai"
		KEY_F6:
			var n := 5 if shift else 1
			var done := 0
			for i in n:
				if s.unclean() > 0:
					sim._light_village(s)
					done += 1
			msg = "%d desa beralih ke energi bersih di %s" % [done, s.data.display_name]
		KEY_F7:
			var need := ceili(s.total() * 0.6)
			for v in s.villages:
				if s.independent >= need and not v.is_clean():
					continue
				if not v.is_clean():
					v.energy = sim.best_energy_for(s, v)
				v.status = Simulation.V_INDEP
				s.recount()
			s.community = 100.0
			msg = "%s jadi mandiri" % s.data.display_name
		KEY_F8:
			var lost := sim._apply_crisis(s, 1.0)
			msg = "krisis %s: %d padam, %d turun status" % [s.data.display_name, lost[0], lost[1]]
		KEY_F9:
			if ctrl:
				sim.blue = 0.0
				sim.red = 0.0
				msg = "resistensi direset"
			elif shift:
				sim.red = clampf(sim.red + 15, 0, Game.db.config.red_max)
				msg = "resistensi merah +15"
			else:
				sim.blue = clampf(sim.blue + 15, 0, 100)
				msg = "resistensi biru +15"
		KEY_F10:
			_unlock_all(sim)
			msg = "semua upgrade terbuka"
		KEY_DELETE:
			_unlock_all(sim)
			msg = _fill_map(sim, 1.0 if shift else 0.5)
		KEY_F11:
			if shift:
				sim._open_air_routes(99)
				msg = "rute pesawat semua pulau"
			else:
				s.seed = true
				sim._news(&"seed_planted", s)
				msg = "benih di " + s.data.display_name
		KEY_F12:
			if ctrl:
				sim._end(&"lose_dark")
			elif shift:
				sim._end(&"lose_resistance")
			else:
				sim._end(&"win")
			msg = "akhir permainan: " + String(sim.result)
		KEY_INSERT:
			var count := 0
			for i in 52:
				if sim.game_over or not Game._holds.is_empty():
					break
				sim.tick()
				count += 1
			msg = "lompat %d minggu" % count
		KEY_HOME:
			if sim.stage < 6:
				sim._set_stage(sim.stage + 1)
			msg = "tahap %d" % sim.stage
		KEY_END:
			screen._spawn_bubble()
			msg = "gelembung muncul"
		KEY_PAGEDOWN:
			var ms := Game.db.milestones
			if ms.is_empty():
				return true
			_milestone_index = wrapi(_milestone_index + 1, 0, ms.size())
			sim.trigger_milestone(ms[_milestone_index])
			msg = "tonggak %s" % ms[_milestone_index].title
		KEY_PAGEUP:
			var news := Game.db.news
			_news_index = wrapi(_news_index + 1, 0, news.size())
			var n: NewsData = news[_news_index]
			sim.news.emit(n.trigger, {"province": s.data.display_name, "island": s.data.island.display_name})
			msg = "berita %d/%d: %s%s" % [_news_index + 1, news.size(), n.trigger, " (popup)" if n.important else ""]
		_:
			return false
	sim._check_end()
	sim.changed.emit()
	_status.text = "DEBUG: " + msg
	print("[debug] ", msg)
	return true


func _unlock_all(sim: Simulation) -> void:
	for u in Game.db.upgrades:
		if sim.owned_upgrades.has(u.id):
			continue
		sim.owned_upgrades[u.id] = true
		if u.unlock_energy != &"" and not sim.energies.has(u.unlock_energy):
			sim.energies.append(u.unlock_energy)
		for f in u.flags:
			sim.flags[f] = true
	sim.flags[&"airplane"] = true
	sim.flags[&"post_kkn"] = true
	sim.flags[&"gov_partner"] = true
	sim._recompute_mods()


## Isi peta: share = bagian desa yang bersih di tiap provinsi (0.5 = setengah, 1.0 = penuh).
## Energi dipilih paling cocok dari SEMUA energi, jadi petanya campuran. Sebagian besar rapuh,
## sebagian mandiri. Pada 1.0 satu desa disisakan supaya permainan belum langsung menang.
func _fill_map(sim: Simulation, share: float) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var all_e: Array[StringName] = []
	for e in Game.db.energies:
		all_e.append(e.id)
	var left_over := false
	for s: Simulation.ProvinceState in sim.provinces.values():
		var order: Array = s.villages.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		var target := roundi(order.size() * share)
		var done := 0
		for v: Simulation.VillageState in order:
			if done >= target:
				break
			if share >= 1.0 and not left_over and v == order[order.size() - 1]:
				left_over = true  # satu desa disisakan
				continue
			v.energy = sim.best_energy_for(s, v, all_e)
			v.status = Simulation.V_INDEP if rng.randf() < (0.6 if share >= 1.0 else 0.3) else Simulation.V_LIT
			v.lit_age = 9999
			done += 1
		s.community = maxf(s.community, 70.0 if share >= 1.0 else 45.0)
		s.recount()
	sim._set_stage(6 if share >= 1.0 else 4)
	sim.kkn_active = false
	return "peta terisi %d%%, semua energi terbuka" % roundi(share * 100)
