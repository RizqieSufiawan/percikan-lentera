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
var _community_bar: CommunityMeter
var _selected := false
var _hovered := false


func _ready() -> void:
	button.pressed.connect(func(): pressed.emit(province_id))
	# Bar Komunitas kecil di bawah persen: tanda di 20 (warga membangun) dan 45 (Mandiri).
	_community_bar = CommunityMeter.new()
	_community_bar.position = Vector2(size.x / 2.0 - 18, 61)
	_community_bar.size = Vector2(36, 5)
	add_child(_community_bar)
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
	internet_mark.visible = false  # tanda internet di peta dihilangkan (terlalu ramai)
	# Supaya peta tidak penuh: bar Komunitas hanya tampil saat wilayah diklik (dipilih).
	_community_bar.set_value(state.community)
	_update_bar()
	button.modulate = Color.WHITE if reachable or state.on() > 0 else Color(0.75, 0.75, 0.8)
	if _last_on >= 0 and (state.on() != _last_on or state.independent != _last_independent):
		pulse()
	_last_on = state.on()
	_last_independent = state.independent


func set_selected(value: bool) -> void:
	selected_ring.visible = value and not _uses_region
	_selected = value
	_update_bar()


func set_hovered(value: bool) -> void:
	_hovered = value


func _update_bar() -> void:
	if _community_bar:
		# Layar persiapan (peta pratinjau) tidak punya Komunitas: bar tidak pernah tampil di sana.
		_community_bar.visible = _selected and Game.sim != null and not get_meta("preview", false)


func pulse() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)

