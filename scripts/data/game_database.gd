class_name GameDatabase
extends Resource
## Daftar semua data game. Menambah provinsi/event/upgrade baru:
## buat file .tres-nya lalu tambahkan ke array yang sesuai di data/database.tres.

@export var config: GameConfig
@export var ui: UiAssets
@export var islands: Array[IslandData] = []
@export var provinces: Array[ProvinceData] = []
@export var energies: Array[EnergyData] = []
@export var traits: Array[TraitData] = []
@export var upgrades: Array[UpgradeData] = []
@export var actions: Array[ActionData] = []
@export var events: Array[EventData] = []
@export var news: Array[NewsData] = []
@export var offers: Array[GovOfferData] = []
@export var missions: Array[MissionData] = []
## Tonggak waktu (soft deadline), misalnya target 2030 dan Indonesia Emas 2045.
@export var milestones: Array[MilestoneData] = []
## Ibu kota provinsi, per nama pendek provinsi asal kloter (VillageData.origin). Dirayakan dengan
## notifikasi kecil saat sebagian besar desa di provinsinya sudah memakai energi bersih.
@export var cities: Dictionary[String, String] = {}
@export var intro_slides: Array[SlideData] = []
@export var guide_slides: Array[SlideData] = []


func get_province(id: StringName) -> ProvinceData:
	for p in provinces:
		if p.id == id:
			return p
	return null


func get_energy(id: StringName) -> EnergyData:
	for e in energies:
		if e.id == id:
			return e
	return null


func get_upgrade(id: StringName) -> UpgradeData:
	for u in upgrades:
		if u.id == id:
			return u
	return null


func get_island(id: StringName) -> IslandData:
	for i in islands:
		if i.id == id:
			return i
	return null


## Kecocokan energi provinsi (data RUEN di compat_override), jatuh ke kecocokan pulau jika kosong.
func province_compat(p: ProvinceData, energy_id: StringName) -> float:
	if p.compat_override.has(energy_id):
		return p.compat_override[energy_id]
	return p.island.energy_compat.get(energy_id, 0.15)


## Ciri alam provinsi untuk tooltip/panel. Tidak menyebut nama energi, supaya pemain menebak sendiri.
func nature_hints(p: ProvinceData) -> String:
	if p.nature_hints.strip_edges() != "":
		return p.nature_hints
	var strong: Array[String] = []
	var medium: Array[String] = []
	for e in energies:
		var c: float = province_compat(p, e.id)
		if c >= 0.9 and e.hint_strong != "":
			strong.append(e.hint_strong)
		elif c >= 0.45 and e.hint_medium != "":
			medium.append(e.hint_medium)
	var lines: Array[String] = []
	if not strong.is_empty():
		lines.append("Paling menonjol:")
		for h in strong:
			lines.append("- " + h)
	if not medium.is_empty():
		lines.append("Ada juga:")
		for h in medium:
			lines.append("- " + h)
	return "\n".join(lines)


func get_trait(id: StringName) -> TraitData:
	for t in traits:
		if t.id == id:
			return t
	return null


## Ringkasan ciri desa di satu provinsi, mis. "4 pesisir berangin, 3 lahan terik".
func trait_summary(p: ProvinceData) -> String:
	var counts: Dictionary = {}
	for v in p.village_list:
		for t in v.traits:
			counts[t] = counts.get(t, 0) + v.size
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var parts: Array[String] = []
	for k in keys:
		var td := get_trait(k)
		parts.append("- %s desa %s" % [Simulation.ribu(counts[k]), td.display_name.to_lower() if td else String(k)])
	return "\n".join(parts)
