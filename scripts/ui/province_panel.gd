extends PanelContainer
## Panel kanan: info wilayah, aksi tingkat wilayah, daftar kloter desa, dan detail kloter terpilih
## (ciri desa + tombol bangun per energi). Satu kloter = +-500 desa nyata dari satu provinsi asal.

const STATUS_NAMES := ["Gelap", "Fosil", "Rapuh", "Mandiri"]
const STATUS_HELP := [
	"Belum berlistrik.",
	"PLTU/PLTD/genset.",
	"Bisa padam.",
	"Dirawat warga.",
]

## Nama pendek aksi tingkat provinsi (tombol sempit). Nama lengkap ada di tooltip.
const SHORT_ACTION_NAMES := {
	ActionData.Effect.TRAIN: "Latih Warga",
	ActionData.Effect.INTERNET: "Internet",
	ActionData.Effect.DIALOG: "Musyawarah",
}

var province_id: StringName = &""
var village_index: int = -1
var _action_buttons: Dictionary = {}  # ActionData -> Button (aksi tingkat provinsi)
var _village_buttons: Array[Button] = []
var _status_icons: Array[Texture2D] = []

@onready var name_label: Label = %PName
@onready var island_label: Label = %PIsland
@onready var villages_label: Label = %PVillages
@onready var community_bar: ProgressBar = %PCommunity
@onready var flags_label: Label = %PFlags
@onready var action_list: HBoxContainer = %ActionList
@onready var village_list: VBoxContainer = %VillageList
@onready var detail: VBoxContainer = %VillageDetail
@onready var v_name: Label = %VName
@onready var v_status: Label = %VStatus
@onready var v_traits: Label = %VTraits
@onready var v_build_list: VBoxContainer = %VBuildList
@onready var hint_label: Label = %PHint


func _ready() -> void:
	%PClose.pressed.connect(func(): hide())
	for c in [Palette.DARK, Palette.FOSSIL, Palette.LIT, Palette.INDEPENDENT]:
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(c)
		_status_icons.append(ImageTexture.create_from_image(img))
	# Aksi tingkat provinsi (semua kecuali BUILD; BUILD ada di detail desa).
	for a in Game.db.actions:
		if a.effect == ActionData.Effect.BUILD:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_action.bind(a))
		b.mouse_entered.connect(_show_hint.bind(a))
		b.mouse_exited.connect(func(): hint_label.hide())
		action_list.add_child(b)
		_action_buttons[a] = b
	# Latih Warga, Internet, dan Musyawarah sekarang lewat Pohon Upgrade (berlaku semua wilayah).
	action_list.visible = not _action_buttons.is_empty()


func show_province(id: StringName) -> void:
	if id != province_id:
		village_index = -1
	province_id = id
	_build_village_rows()
	show()
	refresh()


func _build_village_rows() -> void:
	for c in village_list.get_children():
		c.queue_free()
	_village_buttons.clear()
	var s: Simulation.ProvinceState = Game.sim.provinces[province_id]
	for v in s.villages:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 26)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_select_village.bind(v.index))
		village_list.add_child(b)
		_village_buttons.append(b)


func _select_village(index: int) -> void:
	Audio.sfx(&"click")
	village_index = index
	refresh()


## Pilih desa dari luar (mis. saat event menyebut desa tertentu).
func select_village(index: int) -> void:
	village_index = index
	refresh()


func refresh() -> void:
	if province_id == &"" or not visible:
		return
	var sim := Game.sim
	var s: Simulation.ProvinceState = sim.provinces[province_id]
	var d := s.data
	name_label.text = d.display_name
	var parts: Array[String] = []
	if d.members_text() != "":
		parts.append("Provinsi: " + d.members_text() + ".")
	if d.note != "":
		parts.append(d.note)
	island_label.text = " ".join(parts) if not parts.is_empty() else d.island.display_name
	villages_label.text = "%s desa: %s mandiri, %s rapuh, %s fosil, %s gelap" % [Simulation.ribu(s.total_desa()),
		Simulation.ribu(s.independent_desa), Simulation.ribu(s.lit_desa), Simulation.ribu(s.fossil_desa), Simulation.ribu(s.dark_desa)]
	if s.building() > 0:
		villages_label.text += "\n%d kloter sedang dibangun." % s.building()
	if s.lit > 0 and s.community < Game.db.config.independence_threshold:
		villages_label.text += "\nMandiri di Komunitas %d." % int(Game.db.config.independence_threshold)
	community_bar.value = s.community
	var f: Array[String] = []
	f.append("Terjangkau" if sim.is_reachable(s) else "Belum terjangkau")
	if s.internet:
		f.append("Internet")
	if s.seed:
		f.append("Benih")
	if sim.air_islands.has(d.island.id):
		f.append("Rute pesawat")
	flags_label.text = " | ".join(f)
	for a: ActionData in _action_buttons:
		var b: Button = _action_buttons[a]
		b.text = "%s\n%s" % [SHORT_ACTION_NAMES.get(a.effect, a.display_name), _cost_text(a, s)]
		var reason := sim.can_do_action(a, province_id)
		b.disabled = reason != ""
		b.tooltip_text = a.display_name + "\n" + a.description + ("\n\n" + reason if reason != "" else "")
	_refresh_village_rows(s)
	_refresh_detail(s)


func _refresh_village_rows(s: Simulation.ProvinceState) -> void:
	if _village_buttons.size() != s.villages.size():
		_build_village_rows()
	for v in s.villages:
		var b := _village_buttons[v.index]
		b.icon = _status_icons[v.status]
		var traits: Array[String] = []
		if v.data:
			for t in v.data.traits:
				var td := Game.db.get_trait(t)
				traits.append(td.display_name.to_lower() if td else String(t))
		b.text = "%s · %s · %s" % [v.name(), v.origin(), ", ".join(traits)]
		if v.is_building():
			b.text = "[dibangun %d mgg] %s" % [Game.sim.weeks_of(v.build_left), b.text]
		b.tooltip_text = "%s dan %s desa sekitarnya (%s)\nStatus: %s" % [v.name(), Simulation.ribu(v.size() - 1), v.origin(), STATUS_NAMES[v.status]]
		b.set_pressed_no_signal(v.index == village_index)


func _refresh_detail(s: Simulation.ProvinceState) -> void:
	if village_index < 0 or village_index >= s.villages.size():
		v_name.text = "Pilih desa di atas"
		v_status.text = "Baca ciri desanya, lalu pilih energi yang paling cocok."
		v_traits.text = ""
		for c in v_build_list.get_children():
			c.queue_free()
		return
	var sim := Game.sim
	var v: Simulation.VillageState = s.villages[village_index]
	v_name.text = "%s · %s" % [v.name(), v.origin()] if v.origin() != "" else v.name()
	var status := "Kloter %s desa. Status: %s. %s" % [Simulation.ribu(v.size()), STATUS_NAMES[v.status], STATUS_HELP[v.status]]
	if v.is_clean():
		var en := Game.db.get_energy(v.energy)
		var ename: String = en.display_name if en else String(v.energy)
		if sim.is_compat_known(province_id, village_index, v.energy):
			status += "\nEnergi: %s (terbukti %s)" % [ename, Palette.compat_word(sim.village_compat(s, v, v.energy)).to_lower()]
		else:
			status += "\nEnergi: %s (meniru desa lain, belum terbukti)" % ename
	if v.is_building():
		var ben := Game.db.get_energy(v.build_energy)
		status += "\nSedang dibangun: %s, menyala ±%d minggu lagi (%d%%)." % [ben.display_name if ben else String(v.build_energy),
			sim.weeks_of(v.build_left), roundi(100.0 * (v.build_total - v.build_left) / maxf(1.0, v.build_total))]
	v_status.text = status
	var trait_lines: Array[String] = []
	if v.data:
		for t in v.data.traits:
			var td := Game.db.get_trait(t)
			if td:
				trait_lines.append("%s: %s" % [td.display_name, td.description])
	v_traits.text = "\n".join(trait_lines)
	_refresh_build_buttons(s, v)


func _refresh_build_buttons(s: Simulation.ProvinceState, v: Simulation.VillageState) -> void:
	for c in v_build_list.get_children():
		c.queue_free()
	# Pembangunan sepenuhnya otomatis: panel kanan hanya menampilkan informasi kloter.
	v_build_list.visible = false
	if v.is_clean() or v.is_building() or not v_build_list.visible:
		return
	var build: ActionData = null
	for a in Game.db.actions:
		if a.effect == ActionData.Effect.BUILD:
			build = a
	if build == null:
		return
	var sim := Game.sim
	for eid in sim.energies:
		var en := Game.db.get_energy(eid)
		var b := Button.new()
		b.icon = en.icon if en else null
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 26)
		b.add_theme_font_size_override("font_size", 12)
		var label: String = en.display_name if en else String(eid)
		if sim.is_compat_known(province_id, v.index, eid):
			label += " [%s]" % Palette.compat_word(sim.village_compat(s, v, eid)).to_lower()
		b.text = "Bangun: %s  (%s)" % [label, _cost_text(build, s)]
		var reason := sim.can_do_action(build, province_id, v.index, eid)
		b.disabled = reason != ""
		b.tooltip_text = build.description + ("\n\n" + reason if reason != "" else "")
		b.pressed.connect(_on_build.bind(build, v.index, eid))
		v_build_list.add_child(b)


func _cost_text(a: ActionData, s: Simulation.ProvinceState) -> String:
	var cost := "%dP" % int(Game.sim.action_cost_points(a, s))
	if a.cost_money > 0:
		cost += "+%dE" % a.cost_money
	return cost


func _show_hint(a: ActionData) -> void:
	var reason := Game.sim.can_do_action(a, province_id)
	hint_label.text = a.description + ("\n> " + reason if reason != "" else "")
	hint_label.show()


func _on_action(a: ActionData) -> void:
	if Game.sim.do_action(a, province_id):
		Audio.sfx(&"click")


func _on_build(a: ActionData, index: int, energy: StringName) -> void:
	if Game.sim.do_action(a, province_id, index, energy):
		Audio.sfx(&"buy")
