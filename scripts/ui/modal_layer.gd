extends Control
## Kartu modal generik (event, hasil, tawaran, berita penting, menu jeda).
## Kartu diantre, dan game dijeda selama ada kartu yang tampil.

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _in_callback: bool = false

@onready var title_label: Label = %MTitle
@onready var image_rect: TextureRect = %MImage
@onready var body_label: Label = %MBody
@onready var fact_label: Label = %MFact
@onready var buttons_box: HFlowContainer = %MButtons


const CARD_W := 600.0
const IMG_SIZE := Vector2(256, 144)
var _scroll: ScrollContainer
var _fit_pending := false


func _ready() -> void:
	hide()
	# Kartu dibuat ringkas: teks panjang (berita, tonggak) bisa digulir, gambar lebih kecil.
	var vbox: VBoxContainer = body_label.get_parent()
	var card: Control = vbox.get_parent()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image_rect.custom_minimum_size = IMG_SIZE
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_FILL
	_scroll.custom_minimum_size = Vector2(CARD_W - 20.0, 0)
	var inner := VBoxContainer.new()
	inner.custom_minimum_size = Vector2(CARD_W - 44.0, 0)
	inner.add_theme_constant_override("separation", 10)
	_scroll.add_child(inner)
	vbox.add_child(_scroll)
	vbox.move_child(_scroll, body_label.get_index())
	for n: Control in [body_label, fact_label]:
		n.reparent(inner, false)
		# Lebar tetap (tidak ikut lebar scrollbar) supaya baris teks tidak berubah-ubah dan
		# tata letak tidak berputar tanpa henti.
		n.custom_minimum_size = Vector2(CARD_W - 44.0, 0)
		n.size_flags_horizontal = Control.SIZE_FILL


## buttons: teks tombol. callback menerima index tombol yang dipilih.
func show_card(title: String, image: Texture2D, body: String, fact: String, buttons: Array, callback: Callable = Callable()) -> void:
	_queue.append({"title": title, "image": image, "body": body, "fact": fact, "buttons": buttons, "callback": callback})
	Game.hold(&"modal")
	if _current.is_empty() and not _in_callback:
		_show_next()


func current_title() -> String:
	return _current.get("title", "")


## Tutup kartu sekarang tanpa memanggil callback (mis. Esc di panduan).
func dismiss() -> void:
	if _current.is_empty():
		return
	Audio.sfx(&"click")
	_current = {}
	_show_next()


func is_busy() -> bool:
	return not _current.is_empty()


func _show_next() -> void:
	if _queue.is_empty():
		_current = {}
		hide()
		Game.release(&"modal")
		return
	_current = _queue.pop_front()
	title_label.text = _current["title"]
	image_rect.texture = _current["image"]
	image_rect.visible = _current["image"] != null
	body_label.text = _current["body"]
	fact_label.text = _current["fact"]
	fact_label.visible = _current["fact"] != ""
	for c in buttons_box.get_children():
		c.queue_free()
	var labels: Array = _current["buttons"]
	# Menu dengan banyak tombol: lebar seragam supaya susunan tidak berubah saat teks tombol
	# berganti (mis. "Musik: Nyala" -> "Musik: Mati").
	var w := 200.0 if labels.size() >= 4 else 160.0
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(w, 40)
		b.pressed.connect(_on_button.bind(i))
		buttons_box.add_child(b)
	show()
	if not _fit_pending:
		_fit_pending = true
		_fit_scroll.call_deferred()


## Tinggi area teks = isi teks, tapi tidak melebihi sisa layar (selebihnya digulir).
func _fit_scroll() -> void:
	_fit_pending = false
	if _scroll == null or not visible:
		return
	_scroll.scroll_vertical = 0
	var content := body_label.get_combined_minimum_size().y
	if fact_label.visible:
		content += fact_label.get_combined_minimum_size().y + 10.0
	var used := title_label.get_combined_minimum_size().y + buttons_box.get_combined_minimum_size().y + 90.0
	if image_rect.visible:
		used += IMG_SIZE.y + 10.0
	var avail := maxf(120.0, get_viewport_rect().size.y - 80.0 - used)
	_scroll.custom_minimum_size = Vector2(CARD_W - 20.0, minf(content, avail))


func _on_button(index: int) -> void:
	Audio.sfx(&"click")
	var cb: Callable = _current["callback"]
	_current = {}
	_in_callback = true
	if cb.is_valid():
		cb.call(index)
	_in_callback = false
	_show_next()
