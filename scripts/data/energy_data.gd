class_name EnergyData
extends Resource
## Satu sumber energi bersih (PLTS, mikrohidro, dst.).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Warna yang dipakai di peta/UI untuk energi ini.
@export var color: Color = Color(1, 0.8, 0.3)
## Bisa dipilih sebagai energi pembuka (realistis dibawa tim KKN).
@export var kkn_available: bool = true
## Ciri alam yang menandakan energi ini SANGAT cocok (kecocokan 1.0).
@export var hint_strong: String
## Ciri alam yang menandakan energi ini lumayan cocok (kecocokan 0.5).
@export var hint_medium: String
