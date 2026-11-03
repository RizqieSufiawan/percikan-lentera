class_name GovOfferData
extends Resource
## Satu versi tawaran pemerintah. Versi dipilih dari Skor Kelayakan.

@export var tier: StringName  ## rapuh / biasa / lancar
@export var title: String
@export_multiline var body: String
@export var money: float = 0.0
@export var points: float = 0.0
## Berapa pulau dibuka rute pesawatnya (0 = tidak ada, 99 = semua).
@export var airplane_islands: int = 0
## Target: tambahan desa menyala yang harus dicapai...
@export var target_villages: int = 0
## ...dalam sekian tik (minggu).
@export var target_ticks: int = 0
## Hukuman jika target gagal.
@export var fail_red: float = 0.0
@export var fail_score_penalty: float = 0.0
@export var accept_effects: Dictionary[StringName, float] = {}
@export var refuse_effects: Dictionary[StringName, float] = {}
@export var image: Texture2D
