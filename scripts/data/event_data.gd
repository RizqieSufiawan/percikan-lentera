class_name EventData
extends Resource
## Kartu event. Kebanyakan event berjalan otomatis: hasilnya (pilihan A = siap, B = tidak siap)
## ditentukan Kesiapan dari upgrade & Komunitas. Hanya event kerja sama yang meminta keputusan pemain.

@export var id: StringName
@export var title: String
@export_multiline var body: String
## Satu fakta singkat edukatif. Tandai jika fiksi atau beri sumber.
@export_multiline var fact: String
@export var image: Texture2D
## Kosong = semua pulau. Isi dengan id pulau untuk event khas daerah.
@export var island_tags: Array[StringName] = []
@export var min_stage: int = 2
@export var weight: float = 1.0
@export var cooldown_ticks: int = 80
## Event ini butuh provinsi target yang punya desa menyala.
@export var requires_lit: bool = true
## Event tekanan Kepentingan Lama: bobotnya naik saat Resistensi merah tinggi.
@export var opposition: bool = false
## Bencana alam: menghantam desa dengan ciri tertentu.
@export var is_disaster: bool = false
## Desa sasaran harus punya salah satu ciri ini (kosong = desa mana saja).
@export var target_traits: Array[StringName] = []
## Desa yang memakai energi ini rusak lebih parah saat krisis event ini.
@export var vulnerable_energies: Array[StringName] = []
## false = pemain memilih sendiri (event kerja sama, mis. tawaran investor).
@export var auto_resolve: bool = true
@export var option_a: EventOption
@export var option_b: EventOption
