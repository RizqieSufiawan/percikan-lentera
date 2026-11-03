extends Control
## Layar akhir: tipe akhir, alasan, dan tiga keputusan penentu.


func _ready() -> void:
	var sim := Game.sim
	var win := sim.result == &"win"
	%EndImage.texture = Game.db.ui.end_win if win else Game.db.ui.end_lose
	%EndTitle.text = ("Menang: " if win else "Selesai: ") + sim.ending_title()
	%EndReason.text = sim.ending_reason()
	%EndStats.text = "%s  |  %s dari %s desa memakai energi bersih, %s mandiri  |  Tahap %d  |  Resistensi %d%%" % [
		sim.date_text(), Simulation.ribu(sim.desa_on()), Simulation.ribu(sim.desa_total()), Simulation.ribu(sim.desa_independent()), sim.stage, int(sim.total_resistance())]
	var lines: Array[String] = []
	for d in sim.key_decisions():
		lines.append("- " + d)
	%Decisions.text = "\n".join(lines)
	%Message.text = "Keberhasilan terbesar adalah saat kita tidak lagi dibutuhkan." if win else "Menyalakan lampu itu mudah. Menjaganya tetap menyala yang sulit."
	%AgainBtn.pressed.connect(func(): Game.goto("setup"))
	%MenuBtn.pressed.connect(func(): Game.goto("title"))
	Audio.sfx(&"stage" if win else &"dark")
	Audio.music(&"menu")
