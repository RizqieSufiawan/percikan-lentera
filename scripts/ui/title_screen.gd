extends Control
## Layar judul.


func _ready() -> void:
	%Background.texture = Game.db.ui.title_background
	%StartBtn.pressed.connect(_on_start)
	%GuideBtn.pressed.connect(func():
		Audio.sfx(&"click")
		Game.slides_mode = "guide"
		Game.slides_next = "title"
		Game.goto("slides"))
	%QuitBtn.pressed.connect(func(): get_tree().quit())
	%QuitBtn.visible = OS.get_name() != "Web"
	Audio.music(&"menu")
	%StartBtn.grab_focus()


func _on_start() -> void:
	Audio.sfx(&"click")
	if Game.intro_seen:
		Game.goto("setup")
	else:
		Game.slides_mode = "intro"
		Game.slides_next = "setup"
		Game.goto("slides")
