class_name UpgradeText
## Menerjemahkan modifiers upgrade menjadi teks efek yang jelas angkanya.
## Satu baris pendek untuk di bawah ikon pohon, dan daftar lengkap untuk panel detail.


static func _energy_name(id: String) -> String:
	var e := Game.db.get_energy(StringName(id))
	return e.display_name if e else id


static func _pct(v: float) -> String:
	return "%d%%" % roundi(absf(v) * 100.0)


## [teks pendek, teks lengkap, gunanya] untuk satu kunci modifier.
## Istilah sama dengan HUD: Poin Dukungan, Ekonomi, Kesejahteraan, Komunitas,
## Ragu Warga (resistensi biru), Kepentingan Lama (resistensi merah), Kesiapan bencana.
static func describe(key: String, v: float) -> Array:
	if ":" in key:
		var parts := key.split(":")
		var en := _energy_name(parts[1])
		match parts[0]:
			"output": return ["+%s hasil desa" % _pct(v), "Desa %s menghasilkan %s lebih banyak Poin dan Ekonomi" % [en, _pct(v)],
				"Lebih banyak Poin & Ekonomi dari desa yang memakai %s." % en]
			"quality": return ["+%s tahan rusak" % _pct(v), "Pembangkit %s %s lebih jarang rusak, juga saat bencana" % [en, _pct(v)],
				"Desa %s lebih jarang padam." % en]
			"build": return ["+%s cepat" % _pct(v), "Warga memasang %s %s lebih cepat" % [en, _pct(v)],
				"Kloter baru %s lebih cepat menyala." % en]
			"fit": return ["+cocok", "%s lebih cocok di semua desa (+%d kecocokan)" % [en, roundi(v * 100.0)],
				"Lebih banyak desa mau memakai %s." % en]
			"indep": return ["+%s Mandiri" % _pct(v), "Desa %s %s lebih cepat menjadi Mandiri" % [en, _pct(v)],
				"Desa %s cepat Mandiri dan lebih SIAP saat bencana." % en]
	match key:
		"community_gain": return ["+%s Komunitas" % _pct(v), "Komunitas tumbuh %s lebih cepat" % _pct(v),
			"Komunitas 20 = warga membangun sendiri, 45 = desa jadi Mandiri."]
		"community_decay_mult": return ["Komunitas stabil", "Komunitas turun %s lebih lambat" % _pct(v),
			"Komunitas yang sudah dibangun tidak cepat hilang."]
		"spread_mult": return ["+%s sebaran" % _pct(v), "Desa tetangga ikut %s lebih cepat" % _pct(v),
			"Energi bersih menyebar lebih cepat."]
		"independence_rate": return ["+%s Mandiri" % _pct(v), "Desa %s lebih cepat menjadi Mandiri" % _pct(v),
			"Desa rapuh cepat jadi Mandiri, jadi tidak mudah padam."]
		"blue_growth_mult":
			if v < 0.0:
				return ["-%s Ragu Warga" % _pct(v), "Ragu Warga (resistensi biru) naik %s lebih lambat" % _pct(v),
					"Menahan Ragu Warga dan lebih SIAP menghadapi hoaks."]
			return ["+%s Ragu Warga" % _pct(v), "Rugi: Ragu Warga naik %s lebih cepat" % _pct(v), ""]
		"red_growth_mult": return ["-%s Kep. Lama" % _pct(v), "Kepentingan Lama (resistensi merah) naik %s lebih lambat" % _pct(v),
			"Menahan Kepentingan Lama yang makin kuat tiap tahun."]
		"crisis_mult": return ["+%s siaga" % _pct(v), "Kesiapan bencana naik, kerusakan %s lebih ringan" % _pct(v),
			"Sering TIDAK SIAP saat bencana? Beli ini."]
		"welfare_per_tick": return ["+Kesejahteraan", "Kesejahteraan naik pelan setiap minggu",
			"Menjaga Kesejahteraan (habis = kalah)."]
		"money_per_tick": return ["+Ekonomi/bln", "Ekonomi +%.1f setiap bulan" % (v * 2.17),
			"Ekonomi dipakai untuk upgrade yang mahal."]
		"points_mult": return ["+%s Poin" % _pct(v), "Poin Dukungan %s lebih banyak" % _pct(v), "Lebih banyak Poin untuk upgrade."]
		"build_time_mult": return ["+%s cepat" % _pct(v), "Semua pembangunan %s lebih cepat" % _pct(v),
			"Kloter baru lebih cepat menyala."]
		"blue_per_tick": return ["Ragu Warga turun", "Ragu Warga turun sedikit setiap minggu", "Menahan Ragu Warga."]
	return ["", "%s %+.2f" % [key, v], ""]


## Satu kalimat "Gunanya" untuk panel detail: dari efek terbesar upgrade ini.
static func purpose(u: UpgradeData) -> String:
	if u.unlock_energy != &"":
		return "Desa yang cocok dengan %s baru mau ikut setelah energi ini dibuka." % _energy_name(String(u.unlock_energy))
	if u.flags.has(&"internet"):
		return "Wilayah bersih tersambung internet: gerakan bisa menanam benih di pulau lain, dan cabang Layanan Digital terbuka."
	if u.id == &"rute_udara":
		return "Energi bersih bisa menyebar ke pulau lain lewat pesawat."
	var best := ""
	var best_v := -1.0
	for k in u.modifiers:
		var v: float = u.modifiers[k]
		var d := describe(String(k), v)
		if d[2] != "" and absf(v) > best_v:
			best_v = absf(v)
			best = d[2]
	return best


## Efek utama (modifier terbesar) untuk di bawah ikon.
static func short(u: UpgradeData) -> String:
	if u.unlock_energy != &"":
		return "buka energi"
	if u.flags.has(&"internet"):
		return "internet desa"
	if u.id == &"rute_udara":
		return "pesawat semua pulau"
	var best := ""
	var best_v := -1.0
	for k in u.modifiers:
		var v: float = u.modifiers[k]
		var d := describe(String(k), v)
		if d[0] != "" and absf(v) > best_v and not (String(k).begins_with("blue_growth") and v > 0.0):
			best_v = absf(v)
			best = d[0]
	return best


static func lines(u: UpgradeData) -> Array[String]:
	var out: Array[String] = []
	if u.unlock_energy != &"":
		out.append("Membuka energi %s untuk dibangun" % _energy_name(String(u.unlock_energy)))
	if u.flags.has(&"internet"):
		out.append("Semua wilayah berenergi bersih otomatis tersambung internet")
	if u.id == &"rute_udara":
		out.append("Rute pesawat dibuka ke semua pulau")
	for k in u.modifiers:
		out.append(describe(String(k), u.modifiers[k])[1])
	return out
