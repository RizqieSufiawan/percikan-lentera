@tool
extends TextureRect
## Gambar pratinjau HANYA untuk editor Godot: kebanyakan isi layar (latar, peta, tombol) dibuat
## oleh script saat game berjalan, jadi di editor scene tampak kosong. Node ini menampilkan
## screenshot layar itu sebagai acuan. Saat game berjalan node ini langsung dihapus.
## Sembunyikan lewat ikon mata di panel Scene bila ingin melihat node aslinya.
## Gambar dimuat lewat path (bukan ext_resource), jadi folder assets/editor_preview tidak ikut build.

@export_file("*.png") var image := ""


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if image != "" and ResourceLoader.exists(image):
		texture = load(image)
