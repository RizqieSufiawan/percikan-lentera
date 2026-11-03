class_name TraitData
extends Resource
## Ciri alam sebuah desa (pesisir berangin, dekat sungai deras, dst.).
## Ciri mengubah kecocokan energi di desa itu, dan menjadi sasaran bencana tertentu.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Tambahan kecocokan per energi untuk desa dengan ciri ini (+ lebih cocok, - kurang cocok).
## Kecocokan desa = kecocokan pulau + jumlah bonus semua cirinya, dibatasi 0.15 sampai 1.0.
@export var energy_bonus: Dictionary[StringName, float] = {}
