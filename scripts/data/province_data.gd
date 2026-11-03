class_name ProvinceData
extends Resource
## Satu node di peta: WILAYAH berisi satu atau beberapa provinsi asli, dengan kloter desa di dalamnya.

@export var id: StringName
@export var display_name: String
## Nama pendek untuk label di peta (kosong = display_name).
@export var short_name: String
@export var island: IslandData
## Bentuk wilayah provinsi: PNG 1280x720 transparan, sejajar dengan map_background.
## Gambar dengan warna putih/abu terang; game mewarnainya sesuai status.
## Bagian tidak transparan = bisa diklik.
@export var region_mask: Texture2D
## Posisi label & ikon status provinsi, dalam koordinat referensi 1280x720.
@export var map_position: Vector2
## Geser label nama dari map_position (map_position tetap titik di dalam wilayah, dipakai untuk klik & sebaran).
@export var label_offset: Vector2 = Vector2.ZERO
## Tetangga darat (id provinsi). Sebaran darat hanya lewat sini.
@export var neighbors: Array[StringName] = []
## Jumlah desa (abstrak) di provinsi ini.
@export var villages: int = 10
## Berapa dari desa itu yang sudah berlistrik dari energi fosil saat permainan dimulai (angka desain).
@export var fossil_villages: int = 0
## Opsional: ciri alam khusus provinsi ini. Kosong = dibuat otomatis dari kecocokan energi pulau.
@export_multiline var nature_hints: String
## Desa contoh di provinsi ini (nama, ciri, status awal). Jika diisi, `villages` dan
## `fossil_villages` di atas diabaikan dan dihitung dari daftar ini.
@export var village_list: Array[VillageData] = []
## Geser resistensi awal jika mulai di sini (+ lebih sulit, - lebih mudah).
@export var start_resistance_mod: float = 0.0
## Pengali sebar khusus provinsi ini.
@export var spread_mod: float = 1.0
## Kecocokan energi provinsi ini (menimpa kecocokan pulau). Diisi dari potensi EBT per provinsi
## (Perpres 22/2017 RUEN) lewat tools/apply_data.py. 1.0 cocok, 0.5 sedang, 0.15 kurang.
@export var compat_override: Dictionary[StringName, float] = {}
## Persen desa yang mengalami bencana (id event -> persen), dari Podes 2024 Tabel 15.2.
## Menentukan seberapa sering bencana itu menyasar provinsi ini. Kosong = rata-rata.
@export var disaster_rates: Dictionary[StringName, float] = {}
## Provinsi asli yang tergabung di wilayah ini (nama lengkap).
@export var member_provinces: PackedStringArray = []
@export_multiline var note: String


## Daftar provinsi anggota, kosong jika wilayah ini hanya satu provinsi dengan nama yang sama.
func members_text() -> String:
	if member_provinces.size() <= 1 and (member_provinces.is_empty() or member_provinces[0] == display_name):
		return ""
	return ", ".join(member_provinces)
