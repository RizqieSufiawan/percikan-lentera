class_name UpgradeData
extends Resource
## Satu node di pohon upgrade (berlaku global).

enum Category { ENERGY, EDUCATION, ECONOMY, DIGITAL, NETWORK }

const CATEGORY_NAMES := ["Sumber Energi", "Edukasi & Warga", "Ekonomi", "Layanan Digital", "Jaringan & Pemerintah"]

@export var id: StringName
@export var display_name: String
## Tulis untung DAN rugi bawaan.
@export_multiline var description: String
@export var category: Category = Category.ENERGY
@export var icon: Texture2D
@export var cost_points: int = 5
@export var cost_money: int = 0
## Upgrade lain yang harus dimiliki dulu.
@export var requires: Array[StringName] = []
## Flag permainan yang harus aktif (mis. "airplane" dari tawaran pemerintah).
@export var requires_flag: StringName
## Jika diisi, membuka energi ini.
@export var unlock_energy: StringName
## Pengubah global. Kunci yang dikenali: lihat GameConfig.MODIFIER_KEYS.
@export var modifiers: Dictionary[StringName, float] = {}
## Flag yang diaktifkan saat dibeli (mis. "internet").
@export var flags: Array[StringName] = []
