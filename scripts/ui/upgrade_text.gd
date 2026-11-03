class_name UpgradeText
## Menerjemahkan modifiers upgrade menjadi teks efek yang jelas angkanya.
## Satu baris pendek untuk di bawah ikon pohon, dan daftar lengkap untuk panel detail.


static func _energy_name(id: String) -> String:
	var e := Game.db.get_energy(StringName(id))
	return e.display_name if e else id


static func _pct(v: float) -> String:
	return "%d%%" % roundi(absf(v) * 100.0)


## [teks pendek, teks lengkap] untuk satu kunci modifier.
static func describe(key: String, v: float) -> Array:
	if ":" in key:
		var parts := key.split(":")
		var en := _energy_name(parts[1])
		match parts[0]:
			"output": return ["+%s listrik" % _pct(v), "Output listrik %s +%s (Poin dan Ekonomi dari desa %s)" % [en, _pct(v), en]]
			"quality": return ["+%s awet" % _pct(v), "Material bangunan %s: %s lebih jarang rusak dan tahan bencana" % [en, _pct(v)]]
			"build": return ["+%s cepat" % _pct(v), "Pemasangan %s %s lebih cepat" % [en, _pct(v)]]
			"fit": return ["+cocok", "%s lebih cocok di semua desa (+%d poin kecocokan)" % [en, roundi(v * 100.0)]]
			"indep": return ["+%s mandiri" % _pct(v), "Desa %s %s lebih cepat menjadi mandiri" % [en, _pct(v)]]
	match key:
		"community_gain": return ["+%s komunitas" % _pct(v), "Kekuatan Komunitas tumbuh %s lebih cepat" % _pct(v)]
		"community_decay_mult": return ["komunitas awet", "Kekuatan Komunitas %s lebih awet" % _pct(v)]
		"spread_mult": return ["+%s sebar" % _pct(v), "Energi bersih menyebar %s lebih cepat" % _pct(v)]
		"independence_rate": return ["+%s mandiri" % _pct(v), "Desa %s lebih cepat menjadi mandiri" % _pct(v)]
		"blue_growth_mult":
			if v < 0.0:
				return ["-%s keraguan" % _pct(v), "Resistensi biru (keraguan warga) tumbuh %s lebih lambat" % _pct(v)]
			return ["+%s keraguan" % _pct(v), "Rugi: resistensi biru tumbuh %s lebih cepat" % _pct(v)]
		"red_growth_mult": return ["-%s lawan" % _pct(v), "Resistensi merah (Kepentingan Lama) tumbuh %s lebih lambat" % _pct(v)]
		"crisis_mult": return ["-%s bencana" % _pct(v), "Dampak krisis dan bencana %s lebih ringan" % _pct(v)]
		"welfare_per_tick": return ["+sejahtera", "Kesejahteraan naik pelan setiap minggu"]
		"money_per_tick": return ["+ekonomi", "Ekonomi +%.2f setiap minggu" % v]
		"points_mult": return ["+%s Poin" % _pct(v), "Poin Dukungan %s lebih banyak" % _pct(v)]
		"build_time_mult": return ["+%s cepat" % _pct(v), "Semua pembangunan %s lebih cepat" % _pct(v)]
		"blue_per_tick": return ["keraguan turun", "Resistensi biru turun sedikit setiap minggu"]
	return ["", "%s %+.2f" % [key, v]]


## Efek utama (modifier terbesar) untuk di bawah ikon.
static func short(u: UpgradeData) -> String:
	if u.unlock_energy != &"":
		return "buka energi"
	if u.flags.has(&"internet"):
		return "internet otomatis"
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
