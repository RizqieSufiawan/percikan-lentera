class_name GameConfig
extends Resource
## SEMUA angka penyeimbang permainan ada di sini (angka desain, bukan data nyata).
## Ubah lewat Inspector: buka data/game_config.tres.

## Kunci pengubah yang dikenali di UpgradeData.modifiers:
const MODIFIER_KEYS := [
	"spread_mult",          # + kecepatan sebar
	"community_gain",       # + kecepatan Kekuatan Komunitas tumbuh sendiri
	"community_decay_mult", # - peluruhan komunitas (nilai negatif = lebih awet)
	"independence_rate",    # + kecepatan desa menjadi mandiri
	"blue_growth_mult",     # - pertumbuhan resistensi biru (negatif = lebih lambat)
	"red_growth_mult",      # - pertumbuhan resistensi merah
	"crisis_mult",          # - dampak krisis (negatif = lebih ringan)
	"welfare_per_tick",     # + kesejahteraan per tik
	"money_per_tick",       # + ekonomi per tik
	"points_mult",          # + pengali Poin Dukungan
	"build_time_mult",      # - lama pembangunan (negatif = lebih cepat)
	"blue_per_tick",        # perubahan resistensi biru per tik (negatif = turun terus)
	# Upgrade cabang energi. Ganti <energi> dengan id energi, mis. "quality:plts".
	"quality:<energi>",     # - peluang rusak & dampak bencana desa berenergi ini (0.4 = 40% lebih jarang)
	"output:<energi>",      # + Poin dan Ekonomi dari desa berenergi ini
	"build:<energi>",       # - lama pembangunan energi ini (0.3 = 30% lebih cepat)
	"fit:<energi>",         # + kecocokan energi ini di semua desa (0.1 = naik satu langkah kecil)
	"indep:<energi>",       # + kecepatan desa berenergi ini menjadi mandiri (warga bisa merawat sendiri)
]

@export_group("Waktu")
## Detik per tik (1 tik = 1 minggu cerita) pada kecepatan 1x setelah KKN.
@export var tick_seconds: float = 1.0
## Detik per tik selama KKN (diperlambat agar KKN 6 bulan ~ 2 menit).
@export var kkn_tick_seconds: float = 4.5
## Awal pasca-KKN dibuat pelan dulu: detik per tik mulai dari sini lalu turun ke tick_seconds
## selama early_ramp_ticks tik (52 = setahun cerita).
@export var early_tick_seconds: float = 2.2
@export var early_ramp_ticks: int = 52
## Lama KKN dalam tik (26 = 6 bulan).
@export var kkn_ticks: int = 26
@export var start_year: int = 2026
## Setelah KKN, satu tik = sekian minggu cerita (KKN tetap 1 tik = 1 minggu).
## 2 = rentang 2026-2060 muat dalam +-15 menit main.
@export var weeks_per_tick_after_kkn: int = 2
## Batas waktu opsional dalam tik. 0 = tanpa batas: permainan hanya berakhir jika kalah atau
## semua desa sudah memakai energi bersih.
@export var max_ticks: int = 0
## FALLBACK: matikan waktu real-time, ganti dengan tombol "Berikutnya".
@export var turn_based_mode: bool = false
## Tik per klik "Berikutnya" (4 = 1 bulan).
@export var turn_ticks: int = 4
## Detik (waktu nyata, kecepatan 1x) antar gelembung aksi di peta.
@export var bubble_interval: float = 9.0
## Gelembung hilang jika tidak diklik dalam sekian detik.
@export var bubble_lifetime: float = 6.0

@export_group("Awal")
@export var start_points: float = 8.0
@export var start_money: float = 50.0
@export var start_welfare: float = 40.0
@export var start_community: float = 10.0
@export var start_blue: float = 15.0
## Bonus Poin jika energi pembuka tidak cocok dengan daerah awal.
@export var mismatch_bonus_points: float = 6.0

@export_group("Poin & Ekonomi")
@export var kkn_points_per_tick: float = 1.4
@export var points_per_lit: float = 0.02
@export var points_per_independent: float = 0.10
## Per provinsi dengan komunitas 100.
@export var points_per_community: float = 0.06
@export var money_base_per_tick: float = 0.05
@export var money_per_independent: float = 0.03
## Ekonomi tidak bisa dibelanjakan di bawah angka ini.
@export var money_reserve: float = 5.0
@export var bubble_points: float = 1.5
## Kalah jika Ekonomi berada di nol selama sekian tik berturut-turut.
@export var economy_grace_ticks: int = 26

@export_group("Komunitas & Mandiri")
@export var community_decay: float = 0.03
## Kekuatan Komunitas tumbuh sendiri di wilayah yang sudah punya desa berenergi bersih
## (warga saling mengajari), dikali (1 + community_gain) dari upgrade Edukasi & Warga.
@export var community_growth: float = 0.2
## Selama KKN, mahasiswa melatih warga wilayah awal: tambahan per tik.
@export var kkn_community_per_tick: float = 0.8
@export var independence_threshold: float = 45.0
@export var independence_rate: float = 0.036
## Desa mandiri menaikkan komunitas provinsinya & tetangganya (memantik ulang).
@export var independent_community_boost: float = 0.02

@export_group("Penyebaran")
@export var spread_rate: float = 0.036
@export var local_spread_rate: float = 0.036
## Sebaran & bangun otomatis hanya ke kloter yang paling jauh sekian langkah (sel tetangga di peta)
## dari kloter yang sudah berenergi bersih. Warga meniru tetangga yang hasilnya sudah terbukti.
@export var spread_max_hops: int = 2
## Pengali sebar lewat rute pesawat.
@export var air_factor: float = 0.6
## Peluang per tik per sumber ber-internet menanam benih di provinsi jauh.
@export var seed_chance: float = 0.008
## Peluang per tik provinsi benih menyala sendiri (inisiatif warga).
@export var seed_self_ignite: float = 0.004
## Diskon Poin aksi pertama di provinsi benih.
@export var seed_build_discount: float = 0.5

@export_group("Kecocokan per desa")
## Kecocokan dasar setiap desa sebelum ciri dan pulau dihitung.
@export var village_base_compat: float = 0.2
## Seberapa besar kecocokan pulau ikut menentukan kecocokan desa.
@export var village_island_weight: float = 0.35

## Peluang per minggu desa rapuh gagal sendiri karena energinya kurang cocok
## (dikali 1 - kecocokan, dan dikurangi oleh komunitas yang kuat).
@export var misfit_failure_rate: float = 0.03
## Seberapa besar kecocokan energi memengaruhi kecepatan desa menjadi mandiri (0 = tidak sama sekali).
@export var fit_independence_weight: float = 0.8

@export_group("Desa fosil")
## Bobot desa fosil saat sebaran memilih desa yang beralih (1 = sama dengan desa gelap).
@export var fossil_convert_weight: float = 0.8
## Desa hanya ikut menyebar atau dibangun otomatis jika salah satu energi yang SUDAH DIBUKA
## minimal "sedang" cocok di sana (kecocokan >= nilai ini). Desa yang tidak cocok menunggu
## sampai energi yang cocok dibuka, atau upgrade "+cocok" menaikkan kecocokannya.
## Bangun manual (pilih kloter + energi sendiri) tetap boleh di desa mana pun.
@export var adopt_min_compat: float = 0.45
## Kalah "padam" hanya jika setelah KKN tidak ada satu pun pembangkit bersih (menyala atau sedang
## dibangun) selama sekian tik berturut-turut. Memberi waktu pemain membangun ulang secara manual.
@export var dark_grace_ticks: int = 26
## Resistensi merah tiap desa fosil beralih ke energi bersih.
@export var fossil_convert_red: float = 0.12
## Pengurang kesiapan warga di provinsi yang banyak memakai listrik fosil.
@export var fossil_readiness_penalty: float = 0.15
## Kesejahteraan naik saat desa gelap mendapat listrik bersih pertama kali.
@export var new_access_welfare: float = 0.4

@export_group("Resistensi")
@export var blue_base: float = 0.008
## Per desa menyala yang melebihi kesiapan komunitas.
@export var blue_per_fragile: float = 0.006
@export var blue_decay_per_independent: float = 0.002
@export var red_base: float = 0.006
@export var red_per_clean: float = 0.03
@export var red_max: float = 60.0
## Resistensi biru tambahan saat membangun di provinsi berkomunitas rendah.
@export var build_blue_outsider: float = 1.0

@export_group("KKN selesai (fase ujian)")
## Desa menyala (belum mandiri) di provinsi berkomunitas di bawah ini bisa padam saat KKN berakhir.
@export var kkn_test_threshold: float = 30.0
@export var kkn_test_fail_chance: float = 0.4

@export_group("Krisis & desa turun")
@export var crisis_lit_loss: float = 0.35
@export var crisis_independent_loss: float = 0.5
## Desa mandiri di provinsi dengan komunitas di bawah ini bisa turun saat krisis.
@export var crisis_independent_threshold: float = 55.0
## Matikan untuk memotong fitur "desa turun" (fallback).
@export var enable_village_downgrade: bool = true
## Matikan untuk memotong komponen merah (fallback).
@export var enable_red_resistance: bool = true

@export_group("Perayaan kota")
## Kota (ibu kota provinsi) dirayakan saat bagian desa bersih di provinsinya mencapai angka ini.
@export var city_celebrate_share: float = 0.5

@export_group("Masa pembangunan")
## Pembangkit yang dibangun pemain baru menyala setelah beberapa minggu. Matikan = langsung menyala.
@export var enable_build_time: bool = true

@export_group("Pohon upgrade")
## Gaya Plague Inc: setiap upgrade yang dibeli membuat Poin upgrade berikutnya naik sekian persen
## (0.05 = +5% per upgrade). Energi bawaan tim KKN tidak dihitung.
@export var upgrade_cost_growth: float = 0.05

@export_group("Bangun otomatis")
## Warga membangun sendiri kloter berikutnya saat Poin cukup (bisa dimatikan pemain).
## Aturannya sama dengan pemain yang hati-hati: hanya di wilayah yang terjangkau dan
## Kekuatan Komunitas-nya minimal auto_build_min_community (kecuali kloter pertama di wilayah itu),
## energi dipilih yang paling cocok dengan ciri desa, dan Poin disisakan auto_build_reserve.
@export var auto_build_default: bool = true
@export var auto_build_min_community: float = 20.0
@export var auto_build_reserve: float = 4.0
## Lama pembangunan dalam minggu (8-16 = 2-4 bulan).
@export var build_weeks_min: int = 8
@export var build_weeks_max: int = 16
## Peluang bencana/krisis menunda pembangunan yang sedang berjalan (dikali keparahan & kerentanan).
@export var crisis_build_delay_chance: float = 0.6
## Lama tunda dasar (minggu), dikali kerentanan energi.
@export var crisis_build_delay_weeks: float = 6.0

@export_group("Event")
@export var event_chance: float = 0.03
## Persen desa terdampak yang dianggap "rata-rata" (Podes 2024 Tabel 15.2). Bencana di provinsi
## dengan persen lebih tinggi muncul lebih sering.
@export var disaster_rate_ref: float = 10.0
## Batas bawah persen, supaya bencana tetap mungkin terjadi walau datanya 0.
@export var disaster_rate_floor: float = 1.0

@export_group("Pemerintah")
@export var offer_min_score: float = 30.0
@export var offer_tier_biasa: float = 45.0
@export var offer_tier_lancar: float = 65.0
@export var max_offers: int = 3
@export var offer_cooldown_refuse: int = 78
@export var offer_cooldown_accept: int = 104

@export_group("Tahap")
@export var stage3_provinces: int = 2
@export var stage5_independent_provinces: int = 2
@export var stage6_access: float = 0.6

@export_group("Menang")
## Bagian desa yang memakai energi bersih (rapuh + mandiri) dari seluruh desa.
@export var win_access: float = 0.7
## Bagian desa mandiri dari seluruh desa.
@export var win_independent: float = 0.5
## Menang sebelum tik ini dianggap "cepat".
@export var fast_win_ticks: int = 700
## Menang sebelum tahun ini = akhir "Cepat dan Tahan".
@export var fast_win_year: int = 2055


## Detik nyata per tik pada kecepatan 1x: KKN lambat, awal pasca-KKN melambat lalu makin cepat.
func seconds_per_tick(kkn_active: bool, tick_count: int) -> float:
	if kkn_active:
		return kkn_tick_seconds
	var t := clampf(float(tick_count - kkn_ticks) / maxf(1.0, float(early_ramp_ticks)), 0.0, 1.0)
	return lerpf(early_tick_seconds, tick_seconds, t)
