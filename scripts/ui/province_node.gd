class_name ProvinceNode
extends Control
## Satu titik provinsi di peta. Tampilannya di scenes/ui/province_node.tscn.

signal pressed(id: StringName)

var province_id: StringName
var _last_on: int = -1
var _last_independent: int = -1
var _uses_region: bool = false

@onready var button: TextureButton = $Button
@onready var selected_ring: TextureRect = $Selected
@onready var name_label: Label = $NameLabel
@onready var count_label: Label = $CountLabel
@onready var internet_mark: Label = $InternetMark


func _ready() -> void:
	button.pressed.connect(func(): pressed.emit(province_id))
	pivot_offset = Vector2(size.x / 2.0, 16)


func setup(data: ProvinceData) -> void:
	province_id = data.id
	name_label.text = data.short_name if data.short_name != "" else data.display_name
	# Jika provinsi punya gambar wilayah, warna wilayah sudah menunjukkan status:
	# ikon bulat disembunyikan, tinggal label (klik diteruskan ke peta).
	if data.region_mask:
		button.visible = false
		selected_ring.visible = false
		_uses_region = true


func refresh(state: Simulation.ProvinceState, ui: UiAssets, reachable: bool) -> void:
	match state.status():
		&"independent":
			button.texture_normal = ui.node_independent
		&"lit":
			button.texture_normal = ui.node_lit
		&"seed":
			button.texture_normal = ui.node_seed
		_:
			button.texture_normal = ui.node_dark
	# Persen desa nyata yang sudah memakai energi bersih.
	count_label.text = "%d%%" % roundi(100.0 * state.on_desa() / maxf(1.0, state.total_desa()))
	internet_mark.visible = state.internet
	button.modulate = Color.WHITE if reachable or state.on() > 0 else Color(0.75, 0.75, 0.8)
	if _last_on >= 0 and (state.on() != _last_on or state.independent != _last_independent):
		pulse()
	_last_on = state.on()
	_last_independent = state.independent


func set_selected(value: bool) -> void:
	selected_ring.visible = value and not _uses_region


func pulse() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
