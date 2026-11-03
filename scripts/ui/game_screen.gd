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
	# Klik laut = bersihkan layar: tutup panel kanan dan hapus sorotan.
	map.empty_clicked.connect(func(): province_panel.hide())
	province_panel.visibility_changed.connect(func():
		if not province_panel.visible:
			map.set_selected(&""))
	_build_speed_buttons()
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
	_welfare_row()
	_refresh()
	if Game.just_loaded:
		Game.just_loaded = false
		toast.call_deferred("Permainan dimuat: %s." % sim.date_text())
	else:
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
		"Tim %s tiba di %s membawa %s.\n\nKamu punya %d minggu (6 bulan) sebelum tim pulang. Pembangkit pertama sedang dibangun bersama warga. Setelah terbukti menyala, warga sekitar akan ikut membangun sendiri. Selesaikan misi KKN di kiri layar, dan perkuat warga lewat Pohon Upgrade (U) agar desa tetap menyala setelah kalian pergi.\n\nPetunjuk di bagian atas layar akan menuntunmu di menit-menit pertama." % [sim.community_name, p.display_name, e.display_name, Game.db.config.kkn_ticks],
		"Spasi = jeda, 1/2/3 = kecepatan, U = pohon upgrade, Tab = lipat/buka panel, Esc = menu & panduan.", ["Mulai"])


func _process(delta: float) -> void:
	_update_hints(delta)
	_combo_time = maxf(0.0, _combo_time - delta)
	_fit_panels()
	_sync_map_village()
	if not Game.is_running():
		return
	_bubble_timer += delta * Game.speed
	if _bubble_timer >= Game.db.config.bubble_interval:
		_bubble_timer = 0.0
		_spawn_bubble()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Esc juga menutup: menu jeda = Lanjut, panduan = tutup.
	if event.keycode == KEY_ESCAPE and modal.is_busy():
		var t: String = modal.current_title()
		if t == "Jeda":
			modal._on_button(0)
		elif t.begins_with("Panduan"):
			modal.dismiss()
		get_viewport().set_input_as_handled()
		return
	if modal.is_busy():
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
	%PointsLabel.text = "Poin Dukungan: %d" % int(sim.points)  # angka per bulan ditambah di _refresh_tooltips()
	%MoneyBar.value = sim.money
	%WelfareBar.value = sim.welfare
	%CommunityBar.value = sim.community_average()
	_refresh_tooltips()
	map.refresh()
	_refresh_legend()
	_update_reveal()
	province_panel.refresh()
	upgrade_panel.refresh()
	_refresh_missions()


## Tooltip HUD: dari mana didapat, dipakai untuk apa, apa yang terjadi kalau habis.
## Angka pemasukan dihitung per bulan dari keadaan sekarang.
func _refresh_tooltips() -> void:
	var sim := Game.sim
	var cfg := Game.db.config
	var per_month := 4.33 / maxf(1.0, float(sim.weeks_of(1)))
	var b := sim.income_breakdown()
	var p_total: float = (b["p_kkn"] + b["p_desa"] + b["p_komunitas"]) * per_month
	for row: Control in [$StatsPanel/VBox/PointsRow, $StatsPanel/VBox/MoneyRow, _welfare_row(),
			$TopPanel/VBox/ResRow, access_bar]:
		row.mouse_filter = Control.MOUSE_FILTER_PASS
	var m_total: float = (b["m_dasar"] + b["m_mandiri"]) * per_month
	# Pemasukan per bulan langsung terlihat di HUD; kursor "?" menandakan ada penjelasan.
	%PointsLabel.text = "Poin Dukungan: %d  (+%s/bln)" % [int(sim.points), ("%.1f" % p_total).replace(".", ",")]
	$StatsPanel/VBox/MoneyRow/Label.text = "Ekonomi +%s/bln" % ("%.1f" % m_total).replace(".", ",")
	for row: Control in [$StatsPanel/VBox/PointsRow, $StatsPanel/VBox/MoneyRow, _welfare_row()]:
		row.mouse_default_cursor_shape = Control.CURSOR_HELP
	$StatsPanel/VBox/PointsRow.tooltip_text = "Poin +%.1f/bln dari %s.\nUntuk upgrade & warga membangun." % [p_total, "tim KKN" if sim.kkn_active else "desa bersih & Komunitas"]
	$StatsPanel/VBox/MoneyRow.tooltip_text = "Ekonomi +%.1f/bln. Untuk upgrade mahal.\nNol terlalu lama = kalah." % m_total
	_welfare_row().tooltip_text = "Kesejahteraan warga. Naik saat desa dapat listrik.\nHabis = kalah."
	$TopPanel/VBox/ResRow.tooltip_text = "Biru: Ragu Warga %d.  Merah: Kepentingan Lama %d.\n100%% = kalah." % [int(sim.blue), int(sim.red)]
	resistance_bar.tooltip_text = $TopPanel/VBox/ResRow.tooltip_text
	access_bar.tooltip_text = "Hijau Mandiri, kuning Rapuh, coklat Fosil, nila Gelap.\nMenang: semua desa bersih sebelum %d." % cfg.deadline_year


## Kesejahteraan dipindah ke panel atas, di bawah Resistensi: dua-duanya syarat kalah.
func _welfare_row() -> HBoxContainer:
	var row: HBoxContainer = get_node_or_null("TopPanel/VBox/WelfareRow")
	if row == null:
		row = $StatsPanel/VBox/WelfareRow
		row.reparent($TopPanel/VBox, false)
		$TopPanel/VBox.move_child(row, $TopPanel/VBox/ResRow.get_index() + 1)
		var label: Label = row.get_node("Label")
		label.text = "Kesejahteraan"
		label.custom_minimum_size.x = 0
		row.get_node("Icon").custom_minimum_size = Vector2(16, 16)
		var bar: ProgressBar = row.get_node("WelfareBar")
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


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
	# Metode (bukan lambda) supaya sambungan otomatis putus saat layar game ditutup.
	Game.speed_changed.connect(_on_speed_changed)
	buttons[Game.speed].button_pressed = true


func _on_speed_changed(s: int) -> void:
	var buttons := [%PauseBtn, %Speed1Btn, %Speed2Btn, %Speed3Btn]
	buttons[s].button_pressed = true


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
		"Warga hanya meniru tetangga dekat (paling jauh 2 kloter dari pembangkit yang sudah menyala).\n" +
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
	%MissionPanel.visible = sim.kkn_active and _hint_panel == null
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
	if e.auto_resolve:
		# Tanpa pilihan: Kesiapan (upgrade + Komunitas) menentukan hasilnya.
		var r: Dictionary = Game.sim.resolve_event(e, province_id)
		var body: String = e.body.format(ctx) + "\n\n"
		body += ("SIAP" if r["success"] else "TIDAK SIAP") + " (kesiapan %d%%). " % int(r["ready"] * 100.0) + r["text"]
		if not r["success"]:
			var helps: Array[String] = Game.sim.event_helpers(e)
			if not helps.is_empty():
				body += "\nBantu lain kali: %s." % ", ".join(helps)
		modal.show_card(title, e.image, body, e.fact, ["Lanjut"])
		return
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
	if not collapsed:
		_apply_reveal()
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
#   Desa pertama menyala : statistik desa, bar akses, Komunitas, kabar terbaru.
#   KKN selesai          : Kesejahteraan dan Resistensi (Ragu Warga + Kepentingan Lama).

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
		toast("Desa pertama menyala! Warga sekitar mulai ikut membangun sendiri.")  # bar desa sudah tampil sejak awal
	if _reveal_ready and post and not _reveal_post_kkn:
		toast("Panel baru di atas: Resistensi (100% = kalah) dan Kesejahteraan (habis = kalah).", Palette.INDEPENDENT)
	_reveal_ready = true
	_reveal_lit = lit
	_reveal_post_kkn = post
	var total := sim.desa_independent() + sim.desa_lit() + sim.desa_fossil() + sim.desa_dark()
	_simple_label.text = "0 dari %s desa memakai energi bersih" % Simulation.ribu(total)
	_update_upgrade_pulse()
	if changed:
		_apply_reveal()


## Menyembunyikan/menampilkan baris sesuai tahap. Baris di panel yang sedang dilipat tetap tersembunyi.
func _apply_reveal() -> void:
	if not _reveal_ready:
		return
	var lit := _reveal_lit
	var post := _reveal_post_kkn
	# Bar desa & angkanya tampil sejak awal (pemain langsung melihat seberapa banyak yang fosil/gelap).
	for n: Control in [%IndepLabel, %LitLabel, %FossilLabel, %DarkLabel, access_bar]:
		n.visible = true
	_simple_label.visible = false
	# Komunitas tampil per wilayah di peta (bar kecil di bawah label), bukan di panel kiri.
	$StatsPanel/VBox/CommunityRow.visible = false
	_welfare_row().visible = post
	feed.visible = lit
	if _auto_btn:
		_auto_btn.visible = lit
	$TopPanel/VBox/ResRow.visible = post


## Panel statistik dan panel atas selalu setinggi isinya (baris bisa muncul/hilang kapan saja),
## lalu panel Misi ditempel tepat di bawah panel statistik. Dipanggil tiap frame; murah.
func _fit_panels() -> void:
	var stats: PanelContainer = $StatsPanel
	var bottom := stats.offset_top + stats.get_combined_minimum_size().y
	if not is_equal_approx(stats.offset_bottom, bottom):
		stats.offset_bottom = bottom
		if stats.has_meta("full_offsets") and not stats.get_meta("collapsed", false):
			var full: Vector4 = stats.get_meta("full_offsets")
			stats.set_meta("full_offsets", Vector4(full.x, full.y, full.z, bottom))
	var top: PanelContainer = $TopPanel
	var top_bottom := top.offset_top + top.get_combined_minimum_size().y
	if not is_equal_approx(top.offset_bottom, top_bottom):
		top.offset_bottom = top_bottom
	var mission: PanelContainer = $MissionPanel
	if not is_equal_approx(mission.offset_top, bottom + 8.0):
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
	_hint_stack = stack
	_spotlight = Spotlight.new()
	_spotlight.visible = false
	add_child(_spotlight)
	move_child(_spotlight, stack.get_index())
	_build_hints(stack)
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 6)
	stack.add_child(_toast_box)


# ---------------------------------------------------------------- petunjuk menit pertama

var _hint_panel: PanelContainer
var _hint_stack: VBoxContainer
var _spotlight: Spotlight
var _hint_label: Label
var _hint_step: int = 0
var _hint_timer: float = 0.0
var _hint_check: float = 0.0


## Langkah petunjuk: [teks, Callable yang mengembalikan true jika langkah selesai].
func _hint_steps() -> Array:
	var sim := Game.sim
	return [
		["1/5  Klik wilayahmu yang disorot di peta.",
			func(): return province_panel.visible],
		["2/5  Klik kloter lain di panel kanan untuk membandingkan energinya.",
			# Klik wilayah di peta sudah memilih satu kloter, jadi langkah ini menunggu kloter LAIN.
			func(): return (province_panel.village_index >= 0 and province_panel.village_index != _hint_v0) or _hint_timer > 15.0],
		["3/5  Buka Pohon Upgrade (U) dan beli satu upgrade.",
			func(): return int(sim.counters.get(&"upgrades_bought", 0)) >= 1],
		["4/5  Tab Sumber Energi: perkuat energi yang kamu pakai.",
			func(): return _owns_energy_branch() or int(sim.counters.get(&"upgrades_bought", 0)) >= 3],
		["5/5  Klik gelembung di peta untuk Poin tambahan.",
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


## Langkah tutorial disimpan di sim.counters (ikut tersimpan), jadi memuat permainan tidak
## mengulang tutorial: lanjut dari langkah terakhir, atau tidak muncul jika sudah selesai/ditutup.
const TUTORIAL_KEY := &"tutorial_step"
const TUTORIAL_DONE := 99


func _build_hints(parent: Control) -> void:
	if Game.sim == null or Game.sim.tick_count > Game.db.config.kkn_ticks:
		return
	var saved_step := int(Game.sim.counters.get(TUTORIAL_KEY, 0))
	if saved_step >= _hint_steps().size():
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
	close.pressed.connect(func():
		Game.sim.counters[TUTORIAL_KEY] = TUTORIAL_DONE
		_hint_panel.queue_free()
		_hint_panel = null)
	row.add_child(close)
	parent.add_child(_hint_panel)
	_hint_step = saved_step
	_show_hint()


func _show_hint() -> void:
	var steps := _hint_steps()
	if _hint_panel == null:
		return
	if _hint_step >= steps.size():
		Game.sim.counters[TUTORIAL_KEY] = TUTORIAL_DONE
		_hint_panel.queue_free()
		_hint_panel = null
		return
	_hint_label.text = steps[_hint_step][0]


func _update_hints(delta: float) -> void:
	_update_spotlight()
	if _hint_panel == null:
		return
	_hint_check += delta
	if _hint_step == 1 or _hint_step == 4:
		_hint_timer += delta
	if _hint_check < 0.25:
		return
	_hint_check = 0.0
	var steps := _hint_steps()
	var advanced := false
	while _hint_step < steps.size() and steps[_hint_step][1].call():
		_hint_step += 1
		Game.sim.counters[TUTORIAL_KEY] = _hint_step
		_hint_timer = 0.0
		_hint_v0 = province_panel.village_index
		advanced = true
	if advanced:
		Audio.sfx(&"point")
		_show_hint()


## Sorotan tutorial: redupkan layar kecuali hal yang dituju langkah petunjuk sekarang.
## Saat Pohon Upgrade terbuka, petunjuk dipindah ke atas panel itu supaya tetap terbaca.
func _update_spotlight() -> void:
	if _hint_stack == null:
		return
	var up_open := upgrade_panel.visible
	var busy: bool = modal.is_busy()
	# Selama tutorial, panel statistik & misi disembunyikan supaya tidak menutupi wilayah awal
	# (mis. Aceh di pojok kiri atas). Muncul lagi begitu petunjuk selesai atau ditutup.
	var tut := _hint_panel != null
	$StatsPanel.visible = not tut
	%MissionPanel.visible = not tut and Game.sim.kkn_active
	# Urutan lapisan: HUD < sorotan < petunjuk < (panel upgrade) < kartu popup.
	# Saat panel upgrade terbuka: panel upgrade < sorotan < petunjuk < kartu popup.
	if up_open != _hint_layer_up:
		_hint_layer_up = up_open
		if up_open:
			_place_after(_spotlight, upgrade_panel)
			_place_after(_hint_stack, _spotlight)
		else:
			var below: Node = get_node_or_null("UpgradeDim")
			_place_before(_hint_stack, below if below else modal)
			_place_before(_spotlight, _hint_stack)
	# Tepat di bawah panel atas (yang tingginya berubah saat baris baru muncul).
	_hint_stack.offset_top = 4.0 if up_open else $TopPanel.offset_bottom + 8.0
	# Notifikasi kecil disembunyikan selama Pohon Upgrade terbuka supaya tidak menutupi judulnya.
	if _toast_box:
		_toast_box.visible = not up_open
	_hint_stack.offset_bottom = _hint_stack.offset_top
	if _hint_panel == null or busy:
		_spotlight.set_hole(Rect2())
		return
	_spotlight.set_hole(_hint_target(up_open))


var _hint_layer_up := false
var _hint_v0 := -1


func _place_after(node: Node, ref: Node) -> void:
	var i := ref.get_index()
	move_child(node, i if node.get_index() < i else i + 1)


func _place_before(node: Node, ref: Node) -> void:
	var i := ref.get_index()
	move_child(node, i - 1 if node.get_index() < i else i)


func _hint_target(up_open: bool) -> Rect2:
	match _hint_step:
		0:
			return Rect2() if up_open else map.province_rect(Game.sim.start_province)
		1:
			return province_panel.get_global_rect() if province_panel.visible and not up_open else Rect2()
		2:
			return Rect2() if up_open else %UpgradeBtn.get_global_rect()
		3:
			if not up_open:
				return %UpgradeBtn.get_global_rect()
			var tabs: TabContainer = upgrade_panel.tabs
			if tabs.current_tab == 0:
				return Rect2()
			var bar := tabs.get_tab_bar()
			var r := bar.get_tab_rect(0)
			return Rect2(bar.global_position + r.position, r.size)
	return Rect2()


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
	text += "Mulai sekarang Poin Dukungan hanya datang dari komunitas warga.\n\nTarget: semua desa berenergi bersih sebelum %d. Kepentingan lama makin kuat setiap tahun." % Game.db.config.deadline_year
	var n: NewsData = _news_by_trigger.get(&"kkn_end")
	if n and n.image:
		feed.push(n.image, "KKN selesai, tim pulang" + (" (%s desa padam)" % Simulation.ribu(lost) if lost > 0 else ""), "Nusantara  |  " + Game.sim.date_text(), text)
	modal.show_card("KKN Selesai", null, text, "Waktu sekarang berjalan lebih cepat.", ["Lanjut"])


func _on_game_ended(_result: StringName) -> void:
	# Simpanan otomatis ditandai selesai supaya tombol Lanjutkan tidak membuka permainan yang sudah tamat.
	Game.save_game(Game.AUTO_SLOT)
	await get_tree().create_timer(1.2).timeout
	upgrade_panel.close()
	Game.goto("end")


# ---------------------------------------------------------------- gelembung aksi

const BUBBLE_TEX := {
	"lentera": preload("res://assets/map/bubble_lentera.png"),
	"ide": preload("res://assets/map/bubble_ide.png"),
	"emas": preload("res://assets/map/bubble_emas.png"),
}
var _combo := 0
var _combo_time := 0.0


## Gelembung muncul di atas kloter yang sudah berenergi bersih (warga desa itu ingin terlibat).
## Tiga jenis: lentera (Poin), ide warga (Komunitas wilayah naik), bintang emas (langka, Poin 3x,
## melayang lebih cepat). Klik beruntun dalam beberapa detik memberi combo.
func _spawn_bubble() -> void:
	var sim := Game.sim
	var spots: Array = []
	for id in sim.provinces:
		var s: Simulation.ProvinceState = sim.provinces[id]
		for v in s.villages:
			if v.is_clean() or v.is_building():
				spots.append([id, v])
	if spots.is_empty():
		for id in sim.provinces:
			if sim.is_reachable(sim.provinces[id]):
				spots.append([id, null])
	if spots.is_empty():
		return
	var spot: Array = spots[randi() % spots.size()]
	var id: StringName = spot[0]
	var v: Simulation.VillageState = spot[1]
	var roll := randf()
	var kind := "emas" if roll < 0.08 else ("ide" if roll < 0.3 else "lentera")
	var b := TextureButton.new()
	b.texture_normal = BUBBLE_TEX[kind]
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(30, 30)
	b.size = Vector2(30, 30)
	b.pivot_offset = Vector2(15, 15)
	var where := v.name() if v else Game.db.get_province(id).display_name
	b.tooltip_text = {"lentera": "Warga %s ingin terlibat! Klik untuk Poin.",
		"ide": "Ide warga %s! Klik: Komunitas wilayah naik.",
		"emas": "Bintang emas di %s! Poin 3x, cepat hilang."}[kind] % where
	var base := (map.village_center(id, v.index) if v else map.node_center(id)) + Vector2(-15, -34)
	b.position = base
	bubble_layer.add_child(b)
	# Muncul dengan memantul, lalu melayang naik-turun.
	b.scale = Vector2.ZERO
	var pop := b.create_tween()
	pop.tween_property(b, "scale", Vector2.ONE * 1.25, 0.18).set_trans(Tween.TRANS_BACK)
	pop.tween_property(b, "scale", Vector2.ONE, 0.12)
	var bob := b.create_tween().set_loops()
	var amp := 6.0 if kind == "emas" else 3.0
	var period := 0.45 if kind == "emas" else 0.9
	bob.tween_property(b, "position:y", base.y - amp, period).set_trans(Tween.TRANS_SINE)
	bob.tween_property(b, "position:y", base.y, period).set_trans(Tween.TRANS_SINE)
	if kind == "emas":
		var drift := b.create_tween()
		drift.tween_property(b, "position:x", base.x + randf_range(-40, 40), 3.5).set_trans(Tween.TRANS_SINE)
	b.pressed.connect(func():
		_combo = _combo + 1 if _combo_time > 0.0 else 1
		_combo_time = 4.0
		var gain: float = Game.sim.collect_bubble(kind, id, _combo)
		Audio.sfx(&"point")
		var label := "+%.1f P" % gain if kind != "ide" else "+Komunitas  +%.1f P" % gain
		if _combo > 1:
			label += "  combo x%d" % _combo
		_float_text(label, b.position)
		_sparkle(b.position + Vector2(15, 15), kind)
		b.queue_free())
	# Berkedip sebelum hilang.
	var life: float = Game.db.config.bubble_lifetime * (0.6 if kind == "emas" else 1.0)
	var t := b.create_tween()
	t.tween_interval(maxf(0.5, life - 1.5))
	for k in 4:
		t.tween_property(b, "modulate:a", 0.25, 0.18)
		t.tween_property(b, "modulate:a", 1.0, 0.18)
	t.tween_property(b, "modulate:a", 0.0, 0.2)
	t.tween_callback(b.queue_free)


## Percikan piksel kecil saat gelembung diklik.
func _sparkle(center: Vector2, kind: String) -> void:
	var col: Color = {"lentera": Palette.LIT, "ide": Color(0.47, 0.86, 0.78), "emas": Color(1, 0.93, 0.47)}[kind]
	for k in 10:
		var p := ColorRect.new()
		p.color = col
		p.size = Vector2(3, 3)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = center
		bubble_layer.add_child(p)
		var a := TAU * k / 10.0 + randf() * 0.3
		var t := p.create_tween()
		t.tween_property(p, "position", center + Vector2(cos(a), sin(a)) * randf_range(16, 30), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.35)
		t.tween_callback(p.queue_free)


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
	modal.show_card("Jeda", null, "Permainan dijeda.", "", ["Lanjut", "Simpan", "Pengaturan", "Panduan", "Menu Utama"], _on_menu_choice)


func _on_menu_choice(i: int) -> void:
	if i == 1:
		_open_overlay(_make_save_panel())
	elif i == 2:
		_open_overlay(SettingsPanel.new())
	elif i == 3:
		_open_guide()
	elif i == 4:
		# Simpan otomatis supaya bisa Lanjutkan dari layar judul.
		Game.save_game(Game.AUTO_SLOT)
		Game.sim = null
		Game.goto("title")


func _make_save_panel() -> LoadPanel:
	var p := LoadPanel.new()
	p.save_mode = true
	return p


## Panel di atas peta (Simpan / Pengaturan). Game tetap dijeda, lalu menu jeda dibuka lagi.
func _open_overlay(panel: Control) -> void:
	Game.hold(&"overlay")
	add_child(panel)
	panel.closed.connect(func():
		Game.release(&"overlay")
		_open_menu())


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
