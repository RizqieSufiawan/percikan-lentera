extends Control
## Layar judul: Lanjutkan, Permainan Baru, Muat Permainan, Pengaturan, Panduan, Keluar.


func _ready() -> void:
	%Background.texture = Game.db.ui.title_background
	var vbox: VBoxContainer = %StartBtn.get_parent()
	%StartBtn.text = "Permainan Baru"
	%StartBtn.pressed.connect(_on_start)
	# Lanjutkan: permainan terakhir yang belum selesai (simpan otomatis atau slot).
	var cont := _make_button("Lanjutkan")
	vbox.add_child(cont)
	vbox.move_child(cont, %StartBtn.get_index())
	var last := Game.latest_slot()
	cont.disabled = last == ""
	if last != "":
		var m := Game.save_info(last)
		cont.text = "Lanjutkan  (%s, %s)" % [m.get("name", ""), m.get("date", "")]
		cont.pressed.connect(func():
			Audio.sfx(&"click")
			if Game.load_game(last):
				Game.goto("game"))
	var load_btn := _make_button("Muat Permainan")
	vbox.add_child(load_btn)
	vbox.move_child(load_btn, %StartBtn.get_index() + 1)
	load_btn.pressed.connect(func():
		Audio.sfx(&"click")
		add_child(LoadPanel.new()))
	var settings := _make_button("Pengaturan")
	vbox.add_child(settings)
	vbox.move_child(settings, load_btn.get_index() + 1)
	settings.pressed.connect(func():
		Audio.sfx(&"click")
		add_child(SettingsPanel.new()))
	%GuideBtn.pressed.connect(func():
		Audio.sfx(&"click")
		Game.slides_mode = "guide"
		Game.slides_next = "title"
		Game.goto("slides"))
	%QuitBtn.pressed.connect(func(): get_tree().quit())
	%QuitBtn.visible = OS.get_name() != "Web"
	Audio.music(&"menu")
	(cont if not cont.disabled else %StartBtn).grab_focus()


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.clip_text = true
	return b


func _on_start() -> void:
	Audio.sfx(&"click")
	if Game.intro_seen:
		Game.goto("setup")
	else:
		Game.slides_mode = "intro"
		Game.slides_next = "setup"
		Game.goto("slides")
