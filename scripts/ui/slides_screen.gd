extends Control
## Slide intro cerita / panduan. Isi dari data/slides/*.tres (urutan di database.tres).

const CLOUD_TRANSITION := preload("res://scripts/ui/cloud_transition.gd")

var _slides: Array[SlideData] = []
var _index: int = 0
var _leaving := false


func _ready() -> void:
	_slides = Game.db.intro_slides if Game.slides_mode == "intro" else Game.db.guide_slides
	%PrevBtn.pressed.connect(func(): _go(_index - 1))
	%NextBtn.pressed.connect(func(): _go(_index + 1))
	%SkipBtn.pressed.connect(_finish)
	_go(0)
	if CLOUD_TRANSITION.resting != null:
		# Datang dari menu lewat awan: awan jadi latar, slide muncul pelan di atasnya.
		$Bg.color = Color(Palette.NIGHT, 0.5)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _go(i: int) -> void:
	if _leaving:
		return
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
	if _leaving:
		return
	_leaving = true
	if Game.slides_mode == "intro":
		Game.intro_seen = true
	if CLOUD_TRANSITION.resting == null:
		Game.goto(Game.slides_next)
		return
	# Slide memudar, awan naik menutup lagi, peta dimuat di baliknya, lalu awan membuka.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): CLOUD_TRANSITION.resume(func(): Game.goto(Game.slides_next)))
