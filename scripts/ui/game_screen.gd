extends Control
## Layar utama permainan: menghubungkan simulasi dengan peta, HUD, panel, dan kartu.

var _news_by_trigger: Dictionary = {}
var _bubble_timer: float = 0.0
var _mission_labels: Dictionary = {}
var _guide_index: int = 0

@onready var map: MapView = %MapView
@onready var province_panel: PanelContainer = %ProvincePanel
@onready var upgrade_panel: PanelContainer = %UpgradePanel
@onready var modal: Control = %Modal
@onready var ticker: PanelContainer = %Ticker
@onready var access_bar: SegmentBar = %AccessBar
@onready var resistance_bar: ResistanceBar = %ResistanceBar
@onready var bubble_layer: Control = %Bubbles
@onready var feed: PanelContainer = %FeedPanel


func _ready() -> void:
	Game.ensure_game()
	var sim := Game.sim
	for n in Game.db.news:
		_news_by_trigger[n.trigger] = n
	sim.changed.connect(_refresh)
	sim.news.connect(_on_news)
	sim.event_triggered.connect(_on_event)
	sim.offer_triggered.connect(_on_offer)
	sim.kkn_ended.connect(_on_kkn_ended)
	sim.milestone_reached.connect(_on_milestone)
	sim.city_celebrated.connect(_on_city_celebrated)
	_build_toasts()
	for panel_name in ["StatsPanel", "MissionPanel", "FeedPanel"]:
		_make_collapsible(get_node(panel_name))
	sim.game_ended.connect(_on_game_ended)
	map.build()
	map.province_clicked.connect(_select_province)
	map.village_clicked.connect(_select_village_on_map)
	_build_speed_buttons()
	_build_auto_button()
	_build_legend()
	_build_missions()
	%UpgradeBtn.pressed.connect(func(): Audio.sfx(&"click"); upgrade_panel.open())
	%MenuBtn.pressed.connect(_open_menu)
	%NextBtn.pressed.connect(func(): Game.step_turn())
	%NextBtn.visible = Game.db.config.turn_based_mode
	%CommunityName.text = sim.community_name
	Audio.music(&"game")
	# Panel kanan tidak dibuka otomatis: pemain mengklik wilayahnya sendiri (petunjuk langkah 1).
	map.set_selected(sim.start_province)
	sim.auto_build_focus = sim.start_province
	_build_reveal()
	_refresh()
	_show_start_card.call_deferred()
	# Tombol debug hanya aktif saat dijalankan dari editor / build debug.
	if OS.is_debug_build():
		add_child(preload("res://scripts/ui/debug_tools.gd").new())


func _show_start_card() -> void:
	var sim := Game.sim
	var p := Game.db.get_province(sim.start_province)
	var e := Game.db.get_energy(sim.start_energy)
	feed.push(Game.db.ui.feed_start, "Tim KKN tiba di %s" % p.display_name, "%s  |  %s" % [p.display_name, sim.date_text()],
		"Tim %s membawa %s." % [sim.community_name, e.display_name])
	modal.show_card("KKN Tematik Dimulai", null,
		"Tim %s tiba di %s membawa %s.\n\nKamu punya %d minggu (6 bulan) sebelum tim pulang. Bangun pembangkit pertama bersama warga, selesaikan misi KKN di kiri layar, dan perkuat warga lewat Pohon Upgrade (U) agar desa tetap menyala setelah kalian pergi.\n\nPetunjuk di bagian atas layar akan menuntunmu di menit-menit pertama." % [sim.community_name, p.display_name, e.display_name, Game.db.config.kkn_ticks],
		"Spasi = jeda, 1/2/3 = kecepatan, B = bangun otomatis, U = pohon upgrade, Tab = lipat/buka panel, Esc = menu & panduan.", ["Mulai"])


func _process(delta: float) -> void:
	_update_hints(delta)
	_sync_map_village()
	if not Game.is_running():
		return
	_bubble_timer += delta * Game.speed
	if _bubble_timer >= Game.db.config.bubble_interval:
		_bubble_timer = 0.0
		_spawn_bubble()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or modal.is_busy():
		return
	match event.keycode:
		KEY_SPACE:
			Game.set_speed(0 if Game.speed > 0 else 1)
		KEY_1:
			Game.set_speed(1)
		KEY_2:
			Game.set_speed(2)
		KEY_3:
			Game.set_speed(3)
		KEY_TAB:
			toggle_all_panels()
		KEY_B:
			toggle_auto_build()
		KEY_U:
			if upgrade_panel.visible:
				upgrade_panel.close()
			else:
				upgrade_panel.open()
		KEY_ESCAPE:
			if upgrade_panel.visible:
				upgrade_panel.close()
			else:
				_open_menu()


# ---------------------------------------------------------------- HUD

func _refresh() -> void:
	var sim := Game.sim
	var cfg := Game.db.config
	# Angka desa nyata (Podes 2024), bukan jumlah kloter.
	%LitLabel.text = "Rapuh %s" % Simulation.ribu(sim.desa_lit())
	%IndepLabel.text = "Mandiri %s" % Simulation.ribu(sim.desa_independent())
	%FossilLabel.text = "Fosil %s" % Simulation.ribu(sim.desa_fossil())
	%DarkLabel.text = "Gelap %s" % Simulation.ribu(sim.desa_dark())
	access_bar.set_values(sim.desa_independent(), sim.desa_lit(), sim.desa_fossil(), sim.desa_dark(), cfg.win_access)
	resistance_bar.set_values(sim.blue, sim.red)
	%ResistanceLabel.text = "%d%%" % int(sim.total_resistance())
	%DateLabel.text = sim.date_text()
	%StageLabel.text = "Tahap %d: %s" % [sim.stage, _stage_name(sim.stage)]
	%PointsLabel.text = "Poin Dukungan: %d" % int(sim.points)
	%MoneyBar.value = sim.money
	%WelfareBar.value = sim.welfare
	%CommunityBar.value = sim.community_average()
	map.refresh()
	_refresh_legend()
	_update_reveal()
	province_panel.refresh()
	upgrade_panel.refresh()
	_refresh_missions()


func _stage_name(stage: int) -> String:
	return ["", "KKN", "Pasca-KKN", "Menyebar", "Perhatian Pemerintah", "Jaringan Antar-Desa", "Gerakan Nasional"][stage]


func _build_speed_buttons() -> void:
	var group := ButtonGroup.new()
	var buttons := [%PauseBtn, %Speed1Btn, %Speed2Btn, %Speed3Btn]
	for i in buttons.size():
		var b: Button = buttons[i]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func(): Game.set_speed(i))
		b.visible = not Game.db.config.turn_based_mode
	Game.speed_changed.connect(func(s): buttons[s].button_pressed = true)
	buttons[Game.speed].button_pressed = true


# ---------------------------------------------------------------- legenda warna peta

const LEGEND_SHORT := {&"plts": "PLTS", &"mikrohidro": "Mikrohidro", &"biomassa": "Biomassa", &"angin": "Angin", &"panas_bumi": "Panas bumi"}
var _legend_items: Dictionary = {}  # id energi -> HBoxContainer


## Baris warna energi di panel atas. Hanya energi yang sudah dibuka yang tampil.
func _build_legend() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = "Warna peta = energi yang dipakai kloter itu.\nBergaris = rapuh (belum dirawat warga), penuh = mandiri.\nCoklat = listrik fosil, nila = masih ada warga tanpa listrik.\nEnergi baru muncul di sini saat dibuka lewat Pohon Upgrade."
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for e in Game.db.energies:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw := ColorRect.new()
		sw.color = e.color
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(sw)
		var l := Label.new()
		l.text = LEGEND_SHORT.get(e.id, e.display_name)
		l.add_theme_font_size_override("font_size", 11)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(l)
		row.add_child(item)
		_legend_items[e.id] = item
	var note := Label.new()
	note.text = "garis = rapuh, penuh = mandiri"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Palette.MUTED)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(note)
	$TopPanel/VBox.add_child(row)
	for id in Game.sim.energies:
		_known_energies[id] = true
	_refresh_legend()


func _refresh_legend() -> void:
	for id in _legend_items:
		var owned: bool = Game.sim.energies.has(id)
		_legend_items[id].visible = owned
		if owned and not _known_energies.has(id):
			_known_energies[id] = true
			var e := Game.db.get_energy(id)
			if e:
				toast("Energi baru terbuka: %s. Warnanya sekarang muncul di peta dan legenda." % e.display_name, e.color)


# ---------------------------------------------------------------- bangun otomatis

var _auto_btn: Button


func _build_auto_button() -> void:
	_auto_btn = Button.new()
	_auto_btn.toggle_mode = true
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.custom_minimum_size = Vector2(0, 40)
	_auto_btn.tooltip_text = ("Bangun otomatis (B): warga membangun kloter berikutnya sendiri saat Poin cukup.\n" +
		"Hanya di wilayah yang Komunitasnya minimal %d, energi dipilih yang paling cocok dengan ciri desa.\n" +
		"Wilayah yang sedang kamu pilih didahulukan. Matikan jika ingin menabung Poin untuk upgrade.") % int(Game.db.config.auto_build_min_community)
	_auto_btn.toggled.connect(_set_auto_build)
	var hbox: HBoxContainer = %UpgradeBtn.get_parent()
	hbox.add_child(_auto_btn)
	hbox.move_child(_auto_btn, %UpgradeBtn.get_index())
	_auto_btn.set_pressed_no_signal(Game.sim.auto_build)
	_update_auto_text()


func _set_auto_build(on: bool) -> void:
	Audio.sfx(&"click")
	Game.auto_build = on
	Game.sim.auto_build = on
	_update_auto_text()


func toggle_auto_build() -> void:
	if not _auto_btn.visible:
		return
	_auto_btn.button_pressed = not _auto_btn.button_pressed


func _update_auto_text() -> void:
	_auto_btn.text = "Otomatis: Nyala" if Game.sim.auto_build else "Otomatis: Mati"


func _build_missions() -> void:
	var list: VBoxContainer = %MissionList
	for m in Game.db.missions:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)
		_mission_labels[m.id] = [l, m]


func _refresh_missions() -> void:
	var sim := Game.sim
	%MissionPanel.visible = sim.kkn_active
	if not sim.kkn_active:
		return
	%KknTimeLabel.text = "Sisa masa KKN: %d minggu" % sim.kkn_weeks_left()
	for id in _mission_labels:
		var l: Label = _mission_labels[id][0]
		var m: MissionData = _mission_labels[id][1]
		var done := sim.completed_missions.has(id)
		l.text = ("[x] " if done else "[ ] ") + m.text + ("" if done else "  (+%d P)" % int(m.reward_points))
		l.modulate = Palette.INDEPENDENT if done else Palette.CREAM


## Klik sel kloter di peta: buka wilayahnya dan pilih kloter itu di panel kanan.
func _select_village_on_map(id: StringName, index: int) -> void:
	province_panel.select_village(index)


var _shown_village := [&"", -2]


## Sorot di peta kloter yang sedang dipilih di panel kanan.
func _sync_map_village() -> void:
	var pid: StringName = province_panel.province_id if province_panel.visible else &""
	var idx: int = province_panel.village_index if province_panel.visible else -1
	if pid != _shown_village[0] or idx != _shown_village[1]:
		_shown_village = [pid, idx]
		map.set_selected_village(pid, idx)


func _select_province(id: StringName) -> void:
	Game.sim.auto_build_focus = id
	map.set_selected(id)
	province_panel.show_province(id)


# ---------------------------------------------------------------- berita, event, tawaran

func _on_news(trigger: StringName, ctx: Dictionary) -> void:
	match trigger:
		&"village_lit", &"province_first_lit", &"seed_ignited":
			Audio.sfx(&"lit")
		&"village_independent", &"province_independent":
			Audio.sfx(&"independent")
		&"village_down":
			Audio.sfx(&"dark")
		&"red_high", &"offer_target_failed":
			Audio.sfx(&"warning")
		&"mission_done":
			Audio.sfx(&"buy")
		_:
			if String(trigger).begins_with("stage_"):
				Audio.sfx(&"stage")
	if trigger == &"kkn_end":
		return  # punya kartu sendiri (_on_kkn_ended)
	var n: NewsData = _news_by_trigger.get(trigger)
	if n == null:
		return
	var text := n.headline.format(ctx)
	if n.image:
		var where: String = ctx["province"] if ctx["province"] != "" else "Nusantara"
		feed.push(n.image, text, "%s  |  %s" % [where, Game.sim.date_text()], text)
	if n.important and Game.news_popups_enabled:
		Audio.sfx(&"news")
		var where: String = ctx["province"] if ctx["province"] != "" else "Nusantara"
		modal.show_card("Berita Penting", n.image if n.image else n.icon, text, "%s  |  %s" % [where, Game.sim.date_text()], ["Lanjut"])
	else:
		ticker.push(text, n.icon)


func _on_event(e: EventData, province_id: StringName) -> void:
	Audio.sfx(&"event")
	var ctx := {"province": "Nusantara", "island": "", "village": Game.sim.event_village_name(e)}
	var p := Game.db.get_province(province_id)
	if p:
		var origin := Game.sim.event_origin_name(e)
		ctx["province"] = origin if origin != "" else p.display_name
		ctx["island"] = p.island.display_name
		_select_province(province_id)
		var t: Array = Game.sim.event_targets.get(e.id, [])
		if t.size() >= 2 and t[1] >= 0:
			province_panel.select_village(t[1])
	var title := ("BENCANA: " if e.is_disaster else "") + e.title
	feed.push(e.image, title, "%s, %s  |  %s" % [ctx["village"], ctx["province"], Game.sim.date_text()], e.body.format(ctx))
	modal.show_card(title, e.image, e.body.format(ctx), e.fact, [e.option_a.label, e.option_b.label],
		func(i: int):
			var result := Game.sim.answer_event(e, province_id, i)
			modal.show_card("Hasil", null, result, "", ["Lanjut"]))


func _on_offer(o: GovOfferData) -> void:
	Audio.sfx(&"offer")
	var lines: Array[String] = [o.body, ""]
	lines.append("Jika diterima:")
	lines.append("- Ekonomi +%d, Poin +%d" % [int(o.money), int(o.points)])
	if o.airplane_islands >= 99:
		lines.append("- Rute pesawat ke semua pulau")
	elif o.airplane_islands > 0:
		lines.append("- Rute pesawat ke %d pulau" % o.airplane_islands)
	if o.target_villages > 0:
		lines.append("- Target: %d kloter desa baru berenergi bersih dalam %d minggu (gagal = Resistensi merah naik)" % [o.target_villages, Game.sim.weeks_of(o.target_ticks)])
	lines.append("")
	lines.append("Jika ditolak: tawaran bisa datang lagi nanti, isinya mengikuti kondisimu saat itu.")
	feed.push(o.image, "Tawaran Pemerintah: " + o.title, "Pemerintah  |  " + Game.sim.date_text(), o.body)
	var tier_names := {&"rapuh": "Kondisi rapuh", &"biasa": "Kondisi biasa", &"lancar": "Kondisi lancar"}
	modal.show_card("Tawaran Pemerintah: " + o.title, o.image, "\n".join(lines),
		"Skor Kelayakan: %d (%s)" % [int(Game.sim.eligibility_score()), tier_names.get(o.tier, "")], ["Terima", "Tolak"],
		func(i: int):
			var result := Game.sim.answer_offer(o, i == 0)
			modal.show_card("Pemerintah", null, result, "", ["Lanjut"]))


## Tonggak waktu: tonggak besar (2030, 2045, 2060) = popup yang menjeda; tonggak kecil = notifikasi.
## Permainan selalu berlanjut.
func _on_milestone(m: MilestoneData, report: Dictionary) -> void:
	Audio.sfx(&"news")
	var text := Game.sim.milestone_text(m, report)
	var img: Texture2D = m.image if m.image else Game.db.ui.end_win
	feed.push(img, "Tonggak: " + m.title, "Nusantara  |  " + Game.sim.date_text(), text)
	if m.major:
		modal.show_card("Tonggak: " + m.title, img, text, m.source, ["Lanjut"])
	else:
		var r_ok: bool = report.get("on_track", false)
		toast(Game.sim.milestone_short(m, report), Palette.INDEPENDENT if r_ok else Palette.LIT)


## Perayaan kecil saat ibu kota provinsi "beralih": sebagian besar desa di provinsinya sudah bersih.
func _on_city_celebrated(city: String, province: String, share: float) -> void:
	Audio.sfx(&"independent")
	var text := "%s merayakan! %d%% desa di %s kini memakai energi bersih." % [city, roundi(share * 100), province]
	toast(text, Palette.INDEPENDENT)
	ticker.push(text, null)


# ---------------------------------------------------------------- panel yang bisa dilipat

var _collapsibles: Array[PanelContainer] = []


## Menambah tombol -/+ di baris pertama panel. Saat dilipat, hanya baris pertama yang tampil,
## supaya peta di belakangnya terlihat. Tab = lipat/buka semua panel.
func _make_collapsible(panel: PanelContainer) -> void:
	var vbox: VBoxContainer = panel.get_child(0)
	var first: Control = vbox.get_child(0)
	var row: HBoxContainer
	if first is HBoxContainer:
		row = first
	else:
		row = HBoxContainer.new()
		vbox.add_child(row)
		vbox.move_child(row, 0)
		first.reparent(row)
		first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn := Button.new()
	btn.text = "-"
	btn.tooltip_text = "Lipat / buka panel (Tab = semua)"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(26, 22)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): _set_collapsed(panel, not panel.get_meta("collapsed", false)))
	row.add_child(btn)
	panel.set_meta("toggle", btn)
	panel.set_meta("full_offsets", Vector4(panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_collapsibles.append(panel)


func _set_collapsed(panel: PanelContainer, collapsed: bool) -> void:
	Audio.sfx(&"click")
	panel.set_meta("collapsed", collapsed)
	var vbox: VBoxContainer = panel.get_child(0)
	for i in range(1, vbox.get_child_count()):
		vbox.get_child(i).visible = not collapsed
	var btn: Button = panel.get_meta("toggle")
	btn.text = "+" if collapsed else "-"
	var full: Vector4 = panel.get_meta("full_offsets")
	if not collapsed:
		panel.offset_top = full.y
		panel.offset_bottom = full.w
		_relayout_left.call_deferred()
		return
	# Lipat ke tinggi minimum; panel yang menempel di bawah layar menyusut ke bawah.
	var h := panel.get_combined_minimum_size().y
	if panel.anchor_top >= 1.0:
		panel.offset_top = full.w - h
	else:
		panel.offset_bottom = full.y + h
	_relayout_left.call_deferred()


## Panel Misi selalu menempel tepat di bawah panel statistik (dilipat atau tidak).
func _relayout_left() -> void:
	var stats: PanelContainer = $StatsPanel
	var mission: PanelContainer = $MissionPanel
	var h := mission.offset_bottom - mission.offset_top
	if mission.get_meta("collapsed", false):
		h = mission.get_combined_minimum_size().y
	else:
		var full: Vector4 = mission.get_meta("full_offsets")
		h = full.w - full.y
	mission.offset_top = stats.offset_bottom + 8.0
	mission.offset_bottom = mission.offset_top + h


func toggle_all_panels() -> void:
	var any_open := false
	for p in _collapsibles:
		if not p.get_meta("collapsed", false):
			any_open = true
	for p in _collapsibles:
		_set_collapsed(p, any_open)
	if any_open:
		province_panel.hide()


# ---------------------------------------------------------------- tampilan bertahap
# Supaya awal permainan tidak penuh angka: panel dan angka muncul saat mulai relevan.
#   Awal      : tanggal, Poin, Ekonomi, misi KKN, dan satu kalimat ringkas di panel atas.
#   Desa pertama menyala : statistik desa, bar akses, Komunitas, kabar terbaru, tombol Otomatis.
#   KKN selesai          : Kesejahteraan dan Ketahanan (biru vs merah).

var _reveal_ready := false
var _reveal_lit := false
var _reveal_post_kkn := false
var _simple_label: Label
var _known_energies: Dictionary = {}
var _pulse_tween: Tween


func _build_reveal() -> void:
	_simple_label = Label.new()
	_simple_label.add_theme_font_size_override("font_size", 13)
	_simple_label.add_theme_color_override("font_color", Palette.MUTED)
	_simple_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%LitLabel.get_parent().add_child(_simple_label)


func _update_reveal() -> void:
	var sim := Game.sim
	var lit := _reveal_lit or sim.total_on() > 0 or int(sim.counters.get(&"lit_ever", 0)) > 0
	var post := _reveal_post_kkn or not sim.kkn_active
	var changed := not _reveal_ready or lit != _reveal_lit or post != _reveal_post_kkn
	if _reveal_ready and lit and not _reveal_lit:
		Audio.sfx(&"point")
		toast("Desa pertama menyala! Angka desa, Komunitas, kabar terbaru, dan tombol Otomatis (B) sekarang terbuka.")
	if _reveal_ready and post and not _reveal_post_kkn:
		toast("Panel baru: Kesejahteraan (kiri) dan Ketahanan biru lawan merah (atas). Jaga biru tetap unggul.", Palette.INDEPENDENT)
	_reveal_ready = true
	_reveal_lit = lit
	_reveal_post_kkn = post
	var total := sim.desa_independent() + sim.desa_lit() + sim.desa_fossil() + sim.desa_dark()
	_simple_label.text = "0 dari %s desa memakai energi bersih" % Simulation.ribu(total)
	_update_upgrade_pulse()
	if not changed:
		return
	for n: Control in [%IndepLabel, %LitLabel, %FossilLabel, %DarkLabel, access_bar]:
		n.visible = lit
	_simple_label.visible = not lit
	$StatsPanel/VBox/CommunityRow.visible = lit
	feed.visible = lit
	if _auto_btn:
		_auto_btn.visible = lit
	$StatsPanel/VBox/WelfareRow.visible = post
	$TopPanel/VBox/ResRow.visible = post
	_fit_panels.call_deferred()


## Panel statistik dan panel atas menyusut/membesar mengikuti baris yang tampil.
func _fit_panels() -> void:
	var stats: PanelContainer = $StatsPanel
	if not stats.get_meta("collapsed", false):
		stats.offset_bottom = stats.offset_top + stats.get_combined_minimum_size().y
		if stats.has_meta("full_offsets"):
			var full: Vector4 = stats.get_meta("full_offsets")
			stats.set_meta("full_offsets", Vector4(full.x, full.y, full.z, stats.offset_bottom))
	var top: PanelContainer = $TopPanel
	top.offset_bottom = top.offset_top + top.get_combined_minimum_size().y
	_relayout_left()


## Tombol Pohon Upgrade berkedip selama pemain belum pernah membeli upgrade padahal sudah mampu.
func _update_upgrade_pulse() -> void:
	var sim := Game.sim
	var want := false
	if int(sim.counters.get(&"upgrades_bought", 0)) == 0 and not upgrade_panel.visible:
		for u in Game.db.upgrades:
			if sim.upgrade_state(u) == "":
				want = true
				break
	var btn: Button = %UpgradeBtn
	if want and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(btn, "modulate", Color(1.7, 1.45, 0.6), 0.55).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(btn, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)
	elif not want and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		btn.modulate = Color.WHITE


# ---------------------------------------------------------------- notifikasi kecil (toast)

var _toast_box: VBoxContainer
const TOAST_SECONDS := 4.5
const TOAST_MAX := 3


func _build_toasts() -> void:
	# Tengah atas, tepat di bawah panel Nusantara: petunjuk awal (jika ada), lalu notifikasi kecil.
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	add_child(stack)
	# Di bawah panel upgrade dan kartu popup supaya tidak menutupi keduanya.
	var below: Node = get_node_or_null("UpgradeDim")
	if below == null:
		below = modal
	move_child(stack, below.get_index())
	stack.anchor_left = 0.5
	stack.anchor_right = 0.5
	stack.offset_left = -260.0
	stack.offset_right = 260.0
	stack.offset_top = 132.0
	stack.offset_bottom = 132.0
	_build_hints(stack)
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 6)
	stack.add_child(_toast_box)


# ---------------------------------------------------------------- petunjuk menit pertama

var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_step: int = 0
var _hint_timer: float = 0.0
var _hint_check: float = 0.0


## Langkah petunjuk: [teks, Callable yang mengembalikan true jika langkah selesai].
func _hint_steps() -> Array:
	var sim := Game.sim
	return [
		["Langkah 1/6: Pembangkit pertama sedang dibangun (2–4 bulan). Klik wilayahmu di peta (yang bergaris terang) untuk melihat isinya.",
			func(): return province_panel.visible],
		["Langkah 2/6: Panel kanan berisi kloter desa di wilayah ini. Klik satu kloter untuk melihat ciri alam dan energi yang cocok.",
			func(): return province_panel.village_index >= 0 or _hint_timer > 12.0],
		["Langkah 3/6: Buka Pohon Upgrade (U, tombol yang berkedip di bawah). Tab Edukasi & Warga mempercepat Kekuatan Komunitas.",
			func(): return int(sim.counters.get(&"upgrades_bought", 0)) >= 1],
		["Langkah 4/6: Di tab Sumber Energi, tiap energi punya cabang sendiri: Output Listrik, Material Bangunan, lalu Teknisi Warga. Perkuat energi yang kamu pakai.",
			func(): return _owns_energy_branch() or int(sim.counters.get(&"upgrades_bought", 0)) >= 3],
		["Langkah 5/6: Setelah desa pertama menyala, tombol Otomatis (B) muncul di bawah. Saat nyala, warga membangun kloter berikutnya sendiri jika Komunitas wilayah minimal %d." % int(Game.db.config.auto_build_min_community),
			func(): return _reveal_lit and _hint_timer > 10.0],
		["Langkah 6/6: Klik gelembung yang muncul di peta untuk Poin tambahan. Arahkan mouse ke wilayah lain untuk melihat ciri desanya.",
			func(): return _hint_timer > 14.0],
	]


func owned_upgrade_count() -> int:
	return Game.sim.owned_upgrades.size()


func _owns_energy_branch() -> bool:
	for id in Game.sim.owned_upgrades:
		var u := Game.db.get_upgrade(id)
		if u and u.category == UpgradeData.Category.ENERGY and u.unlock_energy == &"":
			return true
	return false


func _build_hints(parent: Control) -> void:
	if Game.sim == null or Game.sim.tick_count > Game.db.config.kkn_ticks:
		return
	_hint_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.03, 0.94)
	style.border_color = Palette.LIT
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	_hint_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	_hint_panel.add_child(row)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(470, 0)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_hint_label)
	var close := Button.new()
	close.text = "x"
	close.tooltip_text = "Tutup petunjuk"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _hint_panel.queue_free(); _hint_panel = null)
	row.add_child(close)
	parent.add_child(_hint_panel)
	_hint_step = 0
	_show_hint()


func _show_hint() -> void:
	var steps := _hint_steps()
	if _hint_panel == null:
		return
	if _hint_step >= steps.size():
		_hint_panel.queue_free()
		_hint_panel = null
		return
	_hint_label.text = steps[_hint_step][0]


func _update_hints(delta: float) -> void:
	if _hint_panel == null:
		return
	_hint_check += delta
	if _hint_step == 1 or _hint_step == 4 or _hint_step == 5:
		if _hint_step != 4 or _reveal_lit:
			_hint_timer += delta
	if _hint_check < 0.25:
		return
	_hint_check = 0.0
	var steps := _hint_steps()
	var advanced := false
	while _hint_step < steps.size() and steps[_hint_step][1].call():
		_hint_step += 1
		_hint_timer = 0.0
		advanced = true
	if advanced:
		Audio.sfx(&"point")
		_show_hint()


## Notifikasi kecil yang tidak menjeda permainan, hilang sendiri setelah beberapa detik.
func toast(text: String, accent: Color = Palette.LIT) -> void:
	if _toast_box == null:
		return
	while _toast_box.get_child_count() >= TOAST_MAX:
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.2, 0.92)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(500, 0)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	_toast_box.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func _on_kkn_ended(lost: int) -> void:
	var text := "Enam bulan berlalu. Tim mahasiswa pulang ke kampus.\n\n"
	if lost > 0:
		text += "%s desa padam karena tidak ada warga yang cukup terlatih untuk merawatnya.\n\n" % Simulation.ribu(lost)
	else:
		text += "Semua desa tetap menyala. Warga yang kamu latih mulai mengambil alih.\n\n"
	text += "Desa kuning sekarang berstatus RAPUH: berlistrik, tapi belum ada warga yang mampu merawatnya. Desa menjadi MANDIRI (hijau) saat Komunitas wilayahnya mencapai 45. Komunitas tumbuh sendiri di wilayah berenergi bersih, dan lebih cepat dengan upgrade Edukasi & Warga.\n\n"
	text += "Mulai sekarang Poin Dukungan hanya datang dari komunitas warga."
	var n: NewsData = _news_by_trigger.get(&"kkn_end")
	if n and n.image:
		feed.push(n.image, "KKN selesai, tim pulang" + (" (%s desa padam)" % Simulation.ribu(lost) if lost > 0 else ""), "Nusantara  |  " + Game.sim.date_text(), text)
	modal.show_card("KKN Selesai", null, text, "Waktu sekarang berjalan lebih cepat.", ["Lanjut"])


func _on_game_ended(_result: StringName) -> void:
	await get_tree().create_timer(1.2).timeout
	upgrade_panel.close()
	Game.goto("end")


# ---------------------------------------------------------------- gelembung aksi

func _spawn_bubble() -> void:
	var sim := Game.sim
	var candidates: Array[StringName] = []
	for id in sim.provinces:
		var s: Simulation.ProvinceState = sim.provinces[id]
		if s.on() > 0 or sim.is_reachable(s):
			candidates.append(id)
	if candidates.is_empty():
		return
	var id: StringName = candidates[randi() % candidates.size()]
	var b := TextureButton.new()
	b.texture_normal = Game.db.ui.bubble
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(28, 28)
	b.size = Vector2(28, 28)
	b.tooltip_text = "Warga ingin terlibat! Klik untuk Poin Dukungan."
	b.position = map.node_center(id) + Vector2(randf_range(-30, 30), randf_range(-46, -28))
	bubble_layer.add_child(b)
	b.pressed.connect(func():
		Game.sim.collect_bubble()
		Audio.sfx(&"point")
		_float_text("+%s P" % str(Game.db.config.bubble_points), b.position)
		b.queue_free())
	var t := b.create_tween()
	t.tween_interval(Game.db.config.bubble_lifetime)
	t.tween_property(b, "modulate:a", 0.0, 0.5)
	t.tween_callback(b.queue_free)


func _float_text(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Palette.LIT
	l.position = pos
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	bubble_layer.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", pos.y - 30, 0.8)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)


# ---------------------------------------------------------------- menu & panduan

func _open_menu() -> void:
	var popup_text := "Berita penting: Popup" if Game.news_popups_enabled else "Berita penting: Ticker saja"
	var music_text := "Musik: Nyala" if Audio.music_volume_db > -60 else "Musik: Mati"
	modal.show_card("Jeda", null, "Permainan dijeda.", "", ["Lanjut", "Panduan", popup_text, music_text, "Menu Utama"], _on_menu_choice)


func _on_menu_choice(i: int) -> void:
	if i == 1:
		_open_guide()
	elif i == 2:
		Game.news_popups_enabled = not Game.news_popups_enabled
		_open_menu()
	elif i == 3:
		Audio.set_music_volume(-80.0 if Audio.music_volume_db > -60 else -8.0)
		_open_menu()
	elif i == 4:
		Game.sim = null
		Game.goto("title")


func _open_guide(index: int = 0) -> void:
	var slides := Game.db.guide_slides
	if slides.is_empty():
		return
	var s: SlideData = slides[index]
	var buttons: Array = []
	if index > 0:
		buttons.append("Kembali")
	buttons.append("Lanjut" if index < slides.size() - 1 else "Tutup")
	modal.show_card("Panduan %d/%d: %s" % [index + 1, slides.size(), s.title], s.image, s.text, "", buttons, _on_guide_choice.bind(index))


func _on_guide_choice(i: int, index: int) -> void:
	var next := index + 1
	if index > 0 and i == 0:
		next = index - 1
	if next < Game.db.guide_slides.size():
		_open_guide(next)
