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


func _ready() -> void:
	hide()


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


func _on_button(index: int) -> void:
	Audio.sfx(&"click")
	var cb: Callable = _current["callback"]
	_current = {}
	_in_callback = true
	if cb.is_valid():
		cb.call(index)
	_in_callback = false
	_show_next()
