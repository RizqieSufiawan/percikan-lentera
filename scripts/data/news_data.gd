class_name NewsData
extends Resource
## Satu headline berita. Boleh memakai {province} dan {island}.
## Trigger yang dikenali: lihat Simulation (fungsi _news).

@export var trigger: StringName
@export var headline: String
## true = popup yang menjeda game. false = ticker.
@export var important: bool = false
@export var icon: Texture2D
## Gambar di kotak Peristiwa (kiri bawah). Kosong = berita ini tidak masuk kotak.
@export var image: Texture2D
## Judul ringkas untuk kotak Peristiwa (maks. 2 baris). Kosong = pakai headline.
## Headline lengkap tetap tampil saat gambar di kotak itu disorot.
@export var feed_title: String
