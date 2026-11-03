class_name Palette
## Warna tema "malam yang perlahan terang". Satu warna = satu arti.

const NIGHT := Color(0.086, 0.102, 0.227)
## Biru keunguan malam: masih ada warga tanpa listrik.
const DARK := Color(0.30, 0.33, 0.52)
const LIT := Color(1.0, 0.77, 0.25)
## Coklat asap: desa berlistrik energi fosil.
const FOSSIL := Color(0.62, 0.45, 0.31)
const INDEPENDENT := Color(0.38, 0.78, 0.47)
const BLUE := Color(0.35, 0.63, 0.94)
const RED := Color(0.77, 0.28, 0.22)
const CREAM := Color(0.96, 0.92, 0.82)
const MUTED := Color(0.62, 0.62, 0.7)


static func compat_word(value: float) -> String:
	if value >= 0.9:
		return "Cocok"
	if value >= 0.45:
		return "Sedang"
	return "Tidak cocok"


static func compat_color(value: float) -> Color:
	if value >= 0.9:
		return INDEPENDENT
	if value >= 0.45:
		return LIT
	return RED
