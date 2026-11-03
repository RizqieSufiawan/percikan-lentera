class_name VillageData
extends Resource
## Satu KLOTER desa di dalam wilayah: sekelompok desa nyata (+-500) dari satu provinsi asal
## dengan ciri alam yang mirip. Diwakili satu nama desa fiktif. Dibuat oleh tools/build_kloter.py
## dari Podes 2024 (BPS) dan RUEN (Perpres 22/2017).

@export var display_name: String
## Ciri desa (id dari data/traits/*.tres). Menentukan energi apa yang cocok.
@export var traits: Array[StringName] = []
## true = desa-desa di kloter ini sudah berlistrik fosil (PLTU/PLTD/genset) saat permainan dimulai.
## false = masih ada keluarga yang belum memakai listrik (Podes 2024 Tabel 3.1).
@export var start_fossil: bool = false
## Jumlah desa nyata dalam kloter ini.
@export var size: int = 1
## Provinsi asal (nama pendek), misalnya "NTT".
@export var origin: String = ""
## Kecocokan energi di provinsi asal (potensi RUEN). Kosong = pakai kecocokan wilayah.
@export var compat: Dictionary[StringName, float] = {}
