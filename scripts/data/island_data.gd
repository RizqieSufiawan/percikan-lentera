class_name IslandData
extends Resource
## Template pulau. Perbedaan BESAR antar daerah ada di sini.
## Semua angka adalah angka desain, bukan data nyata.

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
## Kecocokan energi: id energi -> nilai (1.0 cocok, 0.5 sedang, 0.15 tidak cocok).
@export var energy_compat: Dictionary[StringName, float] = {}
## Pengali kecepatan sebar dasar di pulau ini.
@export var base_spread: float = 1.0
## Resistensi awal tambahan jika pemain mulai di pulau ini.
@export var base_resistance: float = 0.0
@export_multiline var challenge: String
