extends Control
## Layar persiapan: pilih wilayah awal langsung di peta, energi yang dibawa tim KKN,
## dan nama komunitas. Hanya energi dengan kkn_available = true yang bisa dipilih.
## Kecocokan tidak ditampilkan: pemain menebak dari ciri alam wilayah.

var _energy_buttons: Dictionary = {}

@onready var map: MapView = %MapView


func _ready() -> void:
	# Pas ke bagian daratan saja (tanpa laut kosong di atas dan bawah) supaya peta lebih besar.
	map.view_rect = Rect2(10, 128, 1260, 484)
	map.build()
	map.set_preview()
	map.province_clicked.connect(_pick_province)
	# Klik kloter di peta juga memilihnya.
	map.village_clicked.connect(func(pid: StringName, idx: int):
		if pid == Game.chosen_province:
			Audio.sfx(&"click")
			_select_village_item(idx))
	var egroup := ButtonGroup.new()
	for e in Game.db.energies:
		if not e.kkn_available:
			continue
		var b := Button.new()
		b.icon = e.icon
		b.text = e.display_name
		b.toggle_mode = true
		b.button_group = egroup
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.tooltip_text = e.display_name
		b.pressed.connect(_pick_energy.bind(e.id))
		%EnergyList.add_child(b)
		_energy_buttons[e.id] = b
	%VillagePick.item_selected.connect(_pick_village)
	# Daftar kloter panjang: popup dibatasi ±6 baris lalu bisa di-scroll.
	%VillagePick.get_popup().max_size = Vector2i(100000, 200)
	%NameEdit.text = Game.chosen_name
	%StartBtn.pressed.connect(_on_start)
	%BackBtn.pressed.connect(func(): Game.goto("title"))
	var first: StringName = Game.chosen_province if Game.chosen_province != &"" else Game.db.provinces[0].id
	if not _energy_buttons.has(Game.chosen_energy):
		Game.chosen_energy = _energy_buttons.keys()[0]
	_energy_buttons[Game.chosen_energy].button_pressed = true
	var keep_village := Game.chosen_village
	_pick_province(first, false)
	_select_village_item(keep_village)
	_pick_energy(Game.chosen_energy, false)


func _pick_province(id: StringName, sound: bool = true) -> void:
	if sound:
		Audio.sfx(&"click")
	if Game.chosen_province != id:
		Game.chosen_village = -1
	Game.chosen_province = id
	map.set_selected(id)
	var p := Game.db.get_province(id)
	var n := 0
	var fossil := 0
	for v in p.village_list:
		n += v.size
		if v.start_fossil:
			fossil += v.size
	_fill_villages(p)
	%InfoScroll.scroll_vertical = 0
	%RegionName.text = p.display_name
	var members := p.members_text()
	%ProvinceInfo.text = "%s%s\n%s desa (%d kloter): %s memakai listrik fosil, %s masih punya warga tanpa listrik. %s\nCIRI DESA\n%s" % [
		p.island.display_name, (" | Provinsi: " + members) if members != "" else "", Simulation.ribu(n), p.village_list.size(),
		Simulation.ribu(fossil), Simulation.ribu(n - fossil), p.note, Game.db.trait_summary(p)]


## Daftar kloter wilayah ini. Tidak ada pilihan otomatis: pemain harus membaca ciri desa dan memilih.
func _fill_villages(p: ProvinceData) -> void:
	var pick: OptionButton = %VillagePick
	pick.clear()
	for i in p.village_list.size():
		var v: VillageData = p.village_list[i]
		var traits: Array[String] = []
		for t in v.traits:
			var td := Game.db.get_trait(t)
			traits.append(td.display_name if td else String(t))
		var text := "%s · %s · %s desa%s" % [v.display_name, ", ".join(traits), Simulation.ribu(v.size),
			"" if v.start_fossil else " (gelap)"]
		pick.add_item(text, i)
		pick.set_item_metadata(pick.item_count - 1, i)
	pick.select(-1)
	pick.text = "Pilih kloter (daftar atau klik di peta)"
	Game.chosen_village = -1
	map.set_selected_village(p.id, -1)
	_update_start()


func _select_village_item(index: int) -> void:
	var pick: OptionButton = %VillagePick
	for i in pick.item_count:
		if pick.get_item_metadata(i) == index:
			pick.select(i)
			Game.chosen_village = index
			map.set_selected_village(Game.chosen_province, index)
			pick.tooltip_text = pick.get_item_text(i)
			_update_start()
			return


func _pick_village(item: int) -> void:
	Audio.sfx(&"click")
	Game.chosen_village = %VillagePick.get_item_metadata(item)
	map.set_selected_village(Game.chosen_province, Game.chosen_village)
	%VillagePick.tooltip_text = %VillagePick.get_item_text(item)
	_update_start()


## Tombol Mulai baru aktif setelah kloter pertama dipilih.
func _update_start() -> void:
	var ok := Game.chosen_village >= 0
	%StartBtn.disabled = not ok
	%StartBtn.tooltip_text = "" if ok else "Pilih kloter pertama dulu."


func _pick_energy(id: StringName, sound: bool = true) -> void:
	if sound:
		Audio.sfx(&"click")
	Game.chosen_energy = id
	var e := Game.db.get_energy(id)
	%EnergyInfo.text = e.description + " Energi ini hanya menyebar ke desa yang cocok dengannya; desa lain menunggu energi yang cocok dibuka."


func _on_start() -> void:
	if Game.chosen_village < 0:
		return
	Audio.sfx(&"click")
	Game.chosen_name = %NameEdit.text.strip_edges()
	Game.new_game()
	Game.goto("game")
