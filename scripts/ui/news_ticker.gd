extends PanelContainer
## Ticker berita biasa (tidak menjeda game).

const SHOW_SECONDS := 5.0

var _queue: Array = []  # [text, icon]
var _timer: float = 0.0

@onready var label: Label = %TickerLabel
@onready var icon_rect: TextureRect = %TickerIcon


func push(text: String, icon: Texture2D) -> void:
	_queue.append([text, icon])
	if _queue.size() > 6:
		_queue.pop_front()
	if _timer <= 0.0:
		_next()


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_next()


func _next() -> void:
	if _queue.is_empty():
		return
	var item: Array = _queue.pop_front()
	label.text = item[0]
	icon_rect.texture = item[1]
	label.modulate.a = 0.0
	create_tween().tween_property(label, "modulate:a", 1.0, 0.3)
	_timer = SHOW_SECONDS
