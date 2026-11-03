extends Control
## Slide intro cerita / panduan. Isi dari data/slides/*.tres (urutan di database.tres).

var _slides: Array[SlideData] = []
var _index: int = 0


func _ready() -> void:
	_slides = Game.db.intro_slides if Game.slides_mode == "intro" else Game.db.guide_slides
	%PrevBtn.pressed.connect(func(): _go(_index - 1))
	%NextBtn.pressed.connect(func(): _go(_index + 1))
	%SkipBtn.pressed.connect(_finish)
	_go(0)


func _go(i: int) -> void:
	Audio.sfx(&"click")
	if i >= _slides.size():
		_finish()
		return
	_index = clampi(i, 0, _slides.size() - 1)
	var s := _slides[_index]
	%SlideImage.texture = s.image
	%SlideTitle.text = s.title
	%SlideText.text = s.text
	%Counter.text = "%d / %d" % [_index + 1, _slides.size()]
	%PrevBtn.disabled = _index == 0
	%NextBtn.text = "Lanjut" if _index < _slides.size() - 1 else "Selesai"
	%SlideImage.modulate.a = 0.0
	create_tween().tween_property(%SlideImage, "modulate:a", 1.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT, KEY_SPACE, KEY_ENTER]:
			_go(_index + 1)
		elif event.keycode == KEY_LEFT:
			_go(_index - 1)
		elif event.keycode == KEY_ESCAPE:
			_finish()


func _finish() -> void:
	if Game.slides_mode == "intro":
		Game.intro_seen = true
	Game.goto(Game.slides_next)
