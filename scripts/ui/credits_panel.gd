extends Control
## Halaman Kredit (dibuka dari menu utama). Isi diubah di SECTIONS di bawah.

signal closed

## Isi nama tim di sini sebelum build dikirim.
const TEAM := "Tim Percikan Lentera\n(isi nama anggota tim di scripts/ui/credits_panel.gd)\nS1 Fakultas Informatika, Universitas Telkom"

## [judul, isi]. Baris kosong di isi = jarak antar-paragraf.
const SECTIONS := [
	["Huruf", "Pixeloid Sans oleh GGBotNet, lisensi SIL Open Font License 1.1.\nm6x11 oleh Daniel Linssen (managore.itch.io/m6x11), bebas dipakai dengan mencantumkan kredit."],
	["Data", "Badan Pusat Statistik (BPS), Statistik Potensi Desa Indonesia 2024 (Podes 2024): jumlah dan kondisi listrik desa per provinsi. \"Desa\" di permainan ini = wilayah setingkat desa: 75.753 desa, 8.486 kelurahan, dan 37 UPT/SPT, total 84.276.\nPerpres No. 22 Tahun 2017 tentang Rencana Umum Energi Nasional (RUEN), Lampiran I: potensi energi terbarukan per provinsi.\nPP No. 40 Tahun 2025 tentang Kebijakan Energi Nasional (KEN): target dan tonggak tahun.\nSiaran pers Kementerian ESDM yang dikutip di kartu peristiwa (nomor siaran pers tertulis di kartunya)."],
	["Peta", "Garis pantai dan kedalaman laut: Natural Earth (naturalearthdata.com), domain publik.\nBatas provinsi: \"Indonesia GeoJSON & TopoJSON Maps (38 Provinces)\", lisensi CC BY 4.0. Diubah: disederhanakan menjadi 24 wilayah dan digambar ulang sebagai pixel art."],
	["Gambar", "Semua pixel art (peta, kartu, ikon, UI, layar judul) dibuat untuk permainan ini."],
	["Musik dan suara", "(isi sumber musik dan efek suara)"],
	["Dibuat dengan", "Godot Engine (godotengine.org), lisensi MIT."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Kredit"
	title.theme_type_variation = &"PixelTitle"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 480)
	box.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(596, 0)
	col.add_theme_constant_override("separation", 4)
	scroll.add_child(col)
	var team := Label.new()
	team.text = TEAM
	team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	team.add_theme_color_override("font_color", Palette.CREAM)
	col.add_child(team)
	for sec in SECTIONS:
		_section(col, sec[0], sec[1])
	# Teks lisensi Godot wajib ikut di setiap game yang dibuat dengan Godot.
	_section(col, "Lisensi Godot Engine", Engine.get_license_text())
	var close := Button.new()
	close.text = "Tutup"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close)
	box.add_child(close)
	close.grab_focus()


func _section(col: VBoxContainer, head: String, body: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var h := Label.new()
	h.text = head
	h.theme_type_variation = &"HudTitle"
	h.add_theme_color_override("font_color", Palette.LIT)
	col.add_child(h)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(596, 0)
	col.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	Audio.sfx(&"click")
	closed.emit()
	queue_free()
