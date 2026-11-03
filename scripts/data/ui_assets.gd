class_name UiAssets
extends Resource
## Satu tempat untuk semua aset tampilan & audio yang dipakai kode.
## Ganti file di folder assets/ dengan NAMA SAMA, atau arahkan ulang di sini.

@export_group("Peta")
@export var map_background: Texture2D
@export var node_dark: Texture2D
@export var node_seed: Texture2D
@export var node_lit: Texture2D
@export var node_independent: Texture2D
@export var node_selected: Texture2D
@export var bubble: Texture2D

@export_group("Layar")
@export var title_background: Texture2D
@export var end_win: Texture2D
@export var end_lose: Texture2D
## Gambar pertama di kotak Peristiwa saat permainan dimulai.
@export var feed_start: Texture2D

@export_group("Ikon nilai")
@export var icon_points: Texture2D
@export var icon_money: Texture2D
@export var icon_welfare: Texture2D
@export var icon_community: Texture2D
@export var icon_resistance: Texture2D

@export_group("Audio")
## Kunci: click, buy, point, lit, independent, dark, event, news, warning, stage, offer
@export var sfx: Dictionary[StringName, AudioStream] = {}
@export var music_menu: AudioStream
@export var music_game: AudioStream
