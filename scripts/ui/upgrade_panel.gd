extends PanelContainer
## Pohon upgrade 5 kategori (tab). Isi diambil dari data/upgrades/*.tres.
## Tiap tab digambar sebagai pohon dari atas ke bawah: baris = kedalaman (berapa upgrade yang
## harus dibeli dulu), kolom = cabang, garis = syarat "requires". Node berupa ikon + nama di bawahnya. Gaya Plague Inc: semua cabang bisa dibeli, tapi setiap pembelian
## membuat upgrade berikutnya lebih mahal (GameConfig.upgrade_cost_growth).

const COL_W := 88.0
const ROW_H := 108.0
const NODE_SIZE := Vector2(52, 52)
const LABEL_W := 84.0
const LABEL_H := 42.0
const PAD := Vector2(4, 6)

var _selected: UpgradeData
var _buttons: Dictionary = {}  # UpgradeData -> Button
var _canvases: Array[Control] = []

@onready var tabs: TabContainer = %Tabs
@onready var points_label: Label = %UPoints
@onready var u_icon: TextureRect = %UIcon
@onready var u_name: Label = %UName
@onready var u_desc: Label = %UDesc
@onready var u_cost: Label = %UCost
@onready var u_state: Label = %UState
@onready var buy_button: Button = %BuyBtn


## Satu kalimat tujuan per tab (urutan = UpgradeData.CATEGORY_NAMES).
const TAB_HINTS := [
	"Buka energi baru agar desa lain mau ikut, lalu perkuat energi yang kamu pakai.",
	"Naikkan Komunitas: 20 = warga membangun sendiri, 45 = desa jadi Mandiri. Juga menahan Ragu Warga.",
	"Tambah Ekonomi untuk upgrade mahal, dan tahan Kepentingan Lama.",
	"Siapkan desa menghadapi bencana (Kesiapan) dan buat Komunitas lebih awet.",
	"Sebarkan gerakan ke pulau lain dan dapatkan dukungan pemerintah.",
]
var _tab_hint: Label


func _ready() -> void:
	%UClose.pressed.connect(close)
	_tab_hint = Label.new()
	_tab_hint.add_theme_font_size_override("font_size", 13)
	_tab_hint.add_theme_color_override("font_color", Palette.LIT)
	_tab_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vbox: VBoxContainer = tabs.get_parent().get_parent()
	vbox.add_child(_tab_hint)
	vbox.move_child(_tab_hint, 1)
	tabs.tab_changed.connect(func(i): _tab_hint.text = TAB_HINTS[i] if i < TAB_HINTS.size() else "")
	buy_button.pressed.connect(_on_buy)
	for i in UpgradeData.CATEGORY_NAMES.size():
		var scroll := ScrollContainer.new()
		scroll.name = UpgradeData.CATEGORY_NAMES[i]
		tabs.add_child(scroll)
		_build_tree(scroll, i)
	_select(Game.db.upgrades[0])
	_tab_hint.text = TAB_HINTS[0]


func _make_button(u: UpgradeData) -> Button:
	var b := Button.new()
	b.icon = u.icon
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = NODE_SIZE
	b.size = NODE_SIZE
	b.tooltip_text = u.display_name
	b.pressed.connect(_select.bind(u))
	_buttons[u] = b
	# Nama di bawah ikon (maksimal dua baris).
	var l := Label.new()
	l.text = u.display_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.clip_text = true
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_constant_override("line_spacing", -3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("label", l)
	# Efek utama di bawah nama, mis. "+25% listrik".
	var fx := Label.new()
	fx.text = UpgradeText.short(u)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.clip_text = true
	fx.add_theme_font_size_override("font_size", 10)
	fx.add_theme_color_override("font_color", Palette.LIT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("effect", fx)
	return b


# ---------------------------------------------------------------- tata letak pohon

## Syarat yang berada di kategori yang sama (syarat lintas kategori ditulis di keterangan).
func _parents(u: UpgradeData, list: Array) -> Array:
	var out: Array = []
	for r in u.requires:
		for x in list:
			if x.id == r:
				out.append(x)
	return out


func _build_tree(scroll: ScrollContainer, category: int) -> void:
	var list: Array = []
	for u in Game.db.upgrades:
		if u.category == category:
			list.append(u)
	# Kedalaman = 1 + kedalaman syarat terdalam.
	var depth: Dictionary = {}
	var changed := true
	for u in list:
		depth[u] = 0
	while changed:
		changed = false
		for u in list:
			for p in _parents(u, list):
				if depth[u] < depth[p] + 1:
					depth[u] = depth[p] + 1
					changed = true
	# Anak-anak tiap node (anak pertama melanjutkan baris induknya, anak lain membuka baris baru).
	var children: Dictionary = {}
	for u in list:
		children[u] = []
	for u in list:
		var ps := _parents(u, list)
		if not ps.is_empty():
			children[ps[0]].append(u)
	var row: Dictionary = {}
	var next_row := [0]
	for u in list:
		if _parents(u, list).is_empty():
			_place(u, next_row[0], children, row, next_row)
			next_row[0] += 1
	# Pohon ke bawah: cabang = kolom, kedalaman = baris.
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(PAD.x * 2 + next_row[0] * COL_W, PAD.y * 2 + (_max(depth) + 1) * ROW_H)
	canvas.set_meta("list", list)
	canvas.draw.connect(_draw_links.bind(canvas))
	# Pohon kecil ditaruh di tengah tab.
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.use_top_left = false
	scroll.add_child(center)
	center.add_child(canvas)
	_canvases.append(canvas)
	for u in list:
		var b := _make_button(u)
		var cell := PAD + Vector2(row.get(u, 0) * COL_W, depth[u] * ROW_H)
		canvas.add_child(b)
		b.position = cell + Vector2((COL_W - NODE_SIZE.x) / 2.0, 0)
		b.size = NODE_SIZE
		var l: Label = b.get_meta("label")
		canvas.add_child(l)
		l.position = cell + Vector2((COL_W - LABEL_W) / 2.0, NODE_SIZE.y + 2)
		l.size = Vector2(LABEL_W, 28)
		var fx: Label = b.get_meta("effect")
		canvas.add_child(fx)
		fx.position = cell + Vector2((COL_W - LABEL_W) / 2.0, NODE_SIZE.y + 29)
		fx.size = Vector2(LABEL_W, 14)


func _place(u: UpgradeData, r: int, children: Dictionary, row: Dictionary, next_row: Array) -> void:
	if row.has(u):
		return
	row[u] = r
	var first := true
	for c in children[u]:
		if row.has(c):
			continue
		if first:
			_place(c, r, children, row, next_row)
			first = false
		else:
			next_row[0] += 1
			_place(c, next_row[0], children, row, next_row)


func _max(d: Dictionary) -> int:
	var m := 0
	for k in d:
		m = maxi(m, d[k])
	return m


## Garis siku dari bawah nama syarat ke atas ikon upgrade. Hijau jika syaratnya sudah dimiliki.
func _draw_links(canvas: Control) -> void:
	var sim := Game.sim
	var list: Array = canvas.get_meta("list")
	for u in list:
		var b: Button = _buttons[u]
		for p in _parents(u, list):
			var pb: Button = _buttons[p]
			var a := pb.position + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y + LABEL_H + 2)
			var z := b.position + Vector2(NODE_SIZE.x / 2.0, 0)
			var mid := z.y - (ROW_H - NODE_SIZE.y - LABEL_H - 2) / 2.0
			var col := Palette.MUTED * Color(1, 1, 1, 0.6)
			if sim and sim.owned_upgrades.has(p.id):
				col = Palette.INDEPENDENT
			canvas.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(z.x, mid), z]), col, 2.0)


# ---------------------------------------------------------------- buka / tutup

func open() -> void:
	%UpgradeDim.show()
	show()
	Game.hold(&"upgrades")
	refresh()


func close() -> void:
	%UpgradeDim.hide()
	hide()
	Game.release(&"upgrades")


func refresh() -> void:
	if not visible:
		return
	var sim := Game.sim
	points_label.text = "Poin %d  |  Ekonomi %d  |  Upgrade dibeli %d (biaya +%d%%)" % [int(sim.points), int(sim.money),
		int(sim.counters.get(&"upgrades_bought", 0)), roundi(100.0 * Game.db.config.upgrade_cost_growth * int(sim.counters.get(&"upgrades_bought", 0)))]
	for u: UpgradeData in _buttons:
		var b: Button = _buttons[u]
		var l: Label = b.get_meta("label")
		var state := sim.upgrade_state(u)
		var col := Color.WHITE
		if state == "owned":
			col = Palette.INDEPENDENT.lightened(0.3)
		elif state.begins_with("Butuh") or state.begins_with("Terbuka") or state.begins_with("Belum"):
			col = Color(0.5, 0.5, 0.56)
		elif state != "":
			col = Color(0.8, 0.8, 0.86)  # terbuka tapi Poin/Ekonomi belum cukup
		b.modulate = col
		l.modulate = col
		b.get_meta("effect").modulate = col
		# Ikon yang dimiliki diberi bingkai hijau, yang terpilih bingkai krem.
		b.add_theme_stylebox_override("normal", _node_style(state == "owned", u == _selected))
	for c in _canvases:
		c.queue_redraw()
	_show_detail()


func _node_style(owned: bool, selected: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.15, 0.3)
	st.set_corner_radius_all(6)
	st.set_border_width_all(3 if selected else 2)
	st.border_color = Palette.CREAM if selected else (Palette.INDEPENDENT if owned else Color(0.35, 0.37, 0.5))
	st.set_content_margin_all(6)
	return st


func _select(u: UpgradeData) -> void:
	_selected = u
	if visible:
		refresh()
	else:
		_show_detail()


func _show_detail() -> void:
	if _selected == null or Game.sim == null:
		return
	var u := _selected
	u_icon.texture = u.icon
	u_name.text = u.display_name
	var why := UpgradeText.purpose(u)
	u_desc.text = ("Gunanya: %s\n\n" % why if why != "" else "") + "Efek:\n- " + "\n- ".join(UpgradeText.lines(u)) + "\n\n" + u.description
	var pts := Game.sim.upgrade_cost(u)
	var cost := "Biaya: %d Poin" % pts
	if pts != u.cost_points:
		cost += " (dasar %d)" % u.cost_points
	if u.cost_money > 0:
		cost += " + %d Ekonomi" % u.cost_money
	u_cost.text = cost
	var state := Game.sim.upgrade_state(u)
	if state == "owned":
		u_state.text = "Sudah dimiliki."
	elif state == "":
		u_state.text = "Bisa dibeli. Setiap upgrade yang dibeli membuat upgrade lain %d%% lebih mahal." % roundi(100.0 * Game.db.config.upgrade_cost_growth)
	else:
		u_state.text = state + "."
	buy_button.disabled = state != ""


func _on_buy() -> void:
	if _selected and Game.sim.buy_upgrade(_selected):
		Audio.sfx(&"buy")
		refresh()
