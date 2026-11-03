extends PanelContainer
## Kotak "Peristiwa" di kiri bawah: gambar peristiwa terbaru + riwayat singkat.
## Isi: kartu event, tawaran pemerintah, dan berita yang punya `image` di data/news/*.tres.

const MAX_HISTORY := 12

var _entries: Array[Dictionary] = []  # {image, title, subtitle, detail}
var _index: int = -1

@onready var image_rect: TextureRect = %FeedImage
@onready var title_label: Label = %FeedTitle
@onready var subtitle_label: Label = %FeedSubtitle
@onready var counter_label: Label = %FeedCounter
@onready var prev_btn: Button = %FeedPrev
@onready var next_btn: Button = %FeedNext


func _ready() -> void:
	prev_btn.pressed.connect(func(): _show(_index - 1))
	next_btn.pressed.connect(func(): _show(_index + 1))
	_show(-1)


## Tambah peristiwa baru dan langsung tampilkan.
func push(image: Texture2D, title: String, subtitle: String, detail: String = "") -> void:
	_entries.append({"image": image, "title": title, "subtitle": subtitle, "detail": detail})
	if _entries.size() > MAX_HISTORY:
		_entries.pop_front()
	_show(_entries.size() - 1)
	image_rect.modulate.a = 0.0
	create_tween().tween_property(image_rect, "modulate:a", 1.0, 0.35)


func _show(i: int) -> void:
	if _entries.is_empty():
		_index = -1
		image_rect.texture = null
		title_label.text = "Belum ada peristiwa"
		subtitle_label.text = ""
		counter_label.text = ""
		prev_btn.disabled = true
		next_btn.disabled = true
		return
	_index = clampi(i, 0, _entries.size() - 1)
	var e: Dictionary = _entries[_index]
	image_rect.texture = e["image"]
	title_label.text = e["title"]
	subtitle_label.text = e["subtitle"]
	image_rect.tooltip_text = e["detail"] if e["detail"] != "" else e["title"]
	counter_label.text = "%d/%d" % [_index + 1, _entries.size()]
	prev_btn.disabled = _index == 0
	next_btn.disabled = _index == _entries.size() - 1
