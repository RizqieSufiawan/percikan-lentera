class_name MilestoneData
extends Resource
## Tonggak waktu (soft deadline): saat tanggal cerita sampai di tahun ini, muncul popup evaluasi
## seberapa jauh capaian pemain dari target. Permainan TETAP berlanjut, tidak ada kalah/menang.

@export var id: StringName
@export var year: int = 2060
@export var title: String
## Konteks dan sumber target (ditampilkan di atas statistik).
@export_multiline var intro: String
@export var image: Texture2D
## true = popup besar yang menjeda permainan; false = notifikasi kecil, permainan tetap berjalan.
@export var major: bool = true
## Target persen desa berenergi bersih (0..1). -1 = pakai syarat menang (win_access).
@export var target_access: float = -1.0
## Target persen desa mandiri (0..1). -1 = pakai syarat menang (win_independent).
@export var target_independent: float = -1.0
## true = tonggak ini menilai sisa desa gelap (target: 0 desa tanpa listrik).
@export var target_no_dark: bool = false
## Batas minimum "di jalur menuju target 2060" pada tahun ini (0..1). -1 = tidak dinilai.
## Angka desain dari uji bot: pemain di atas batas ini umumnya mencapai syarat menang
## (70% bersih, 50% mandiri, sesuai target KEN 2060) sebelum 2060.
@export var on_track_access: float = -1.0
@export var on_track_independent: float = -1.0
## Sumber singkat di bawah popup.
@export var source: String
