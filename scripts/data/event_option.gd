class_name EventOption
extends Resource
## Satu pilihan (A atau B) di kartu event.

@export var label: String
@export_multiline var result_text: String
## Kunci efek: points, money, welfare, blue, red, community (provinsi target),
## lit (desa menyala +/- di provinsi target), count_<nama> (penghitung untuk layar akhir).
@export var effects: Dictionary[StringName, float] = {}
## 0 = tidak ada kerusakan. 1 = krisis penuh (desa bisa padam / turun status).
@export_range(0.0, 2.0) var crisis_severity: float = 0.0
