# Catatan proyek Percikan Lentera

Dulu bernama kerja "Nyalakan Desa 3T".

Prototipe ADIKARA 2026 sesuai GDD v2.1. Godot **4.7** + GDScript, renderer Compatibility (ringan, bisa diekspor ke Web).

## GitHub
Folder ini sudah siap jadi repo: `.gitignore` membuang `.godot/` (cache, dibuat ulang otomatis) dan `build/` (hasil ekspor), `.gitattributes` menjaga akhir baris dan file biner.
- GitHub Desktop: File > Add local repository > pilih folder ini > "create a repository" > Publish repository.
- Terminal: `git init`, `git add .`, `git commit -m "Percikan Lentera: prototipe awal"`, `git branch -M main`, `git remote add origin https://github.com/<akun>/percikan-lentera.git`, `git push -u origin main`.

## Membuka proyek
1. Buka Godot 4.7 (versi standar atau .NET, keduanya bisa).
2. Import, lalu pilih file `project.godot` di folder ini.
3. Tekan **F5** untuk main dari layar judul, atau buka `scenes/game.tscn` lalu **F6** untuk langsung masuk peta (otomatis mulai di Sumatera Utara).

Kontrol: klik wilayah untuk aksi, `Spasi` jeda, `1/2/3` kecepatan, `U` pohon upgrade, `B` bangun otomatis nyala/mati, `Tab` lipat/buka semua panel (atau tombol `-`/`+` di pojok tiap panel), `Esc` menu (berisi Panduan, pengaturan berita & musik, dan kembali ke menu utama).

**Tombol debug** (hanya saat dijalankan dari editor): tekan `F1` di layar permainan. Daftar lengkap tombol, event, berita, dan syarat akhir ada di `docs/EVENTS.md`. Kodenya di `scripts/ui/debug_tools.gd`.

## Yang sudah jalan
- Layar judul, intro cerita 4 slide, panduan 10 slide, setup (wilayah + energi + nama komunitas), permainan, layar akhir.
- **Petunjuk menit pertama:** 5 langkah di tengah atas (lihat kloter, bangun otomatis, Pohon Upgrade, cabang energi, gelembung). Langkah maju otomatis saat dilakukan, dan bisa ditutup dengan tombol x. Kodenya di `_hint_steps()` di `scripts/ui/game_screen.gd`.
- Waktu real-time dengan jeda dan 1x/2x/3x. Selama KKN 1 tik = 1 minggu (6 bulan, sekitar 2 menit di 1x). Setelah KKN 1 tik = 2 minggu, jadi rentang 2026–2060 muat dalam sekitar 15 menit.
- **24 wilayah di peta (batas provinsi asli), berisi 38 provinsi dan 84.276 desa nyata** (Podes 2024). Penyebaran lewat tetangga darat atau selat pendek, benih lewat internet (wilayah benih bisa langsung dibangun), dan rute pesawat.
- **Data resmi:** kecocokan energi per provinsi dari Perpres 22/2017 (RUEN); jumlah desa, status awal (16.618 gelap, 67.658 fosil), ciri desa, dan peluang bencana dari BPS Podes 2024. Lihat `docs/SUMBER_DATA.md`.
- **Kloter desa:** setiap baris di panel = satu kloter berisi ±500 desa nyata dari satu provinsi asal (186 kloter), diwakili satu nama desa fiktif. Pemain memilih kloter dan energinya sendiri; sebaran meniru energi yang sudah dipakai; energi yang kurang cocok lebih sering rusak. Logika menghitung kloter, sedangkan angka di layar dan syarat menang menghitung desa nyata.
- **Tonggak waktu (soft deadline):** evaluasi pada 2030 (target ESDM: semua desa berlistrik), 2040 dan 2050 (target bauran EBT KEN, PP 40/2025), 2045 (Indonesia Emas), dan 2060 (target KEN 70–72% dan Net Zero).
  - Tahun 2030, 2045, dan 2060 muncul sebagai popup besar. Tahun 2040 dan 2050 muncul sebagai notifikasi kecil.
  - Setiap tonggak menilai apakah pemain **di jalur** menuju target 2060.
- **Akhir permainan:** permainan hanya selesai jika kalah, atau jika **semua desa** sudah memakai energi bersih. Tidak ada batas waktu.
- **Perayaan kota:** notifikasi kecil saat ibu kota provinsi merayakan, yaitu saat separuh desa di provinsinya sudah bersih.
- **Masa pembangunan:** pembangkit yang dibangun pemain baru menyala setelah 2–4 bulan (8–16 minggu). Bencana bisa menundanya, terutama untuk energi yang rentan. Program Teknisi Desa mempercepat 25%, dan cabang energi "pemasangan cepat" 35% untuk energi itu. Kecocokan terungkap saat pembangkit menyala. Sebaran antardesa tetap langsung.
- **Bencana alam** (banjir, badai, kemarau, erupsi, karhutla) yang menyasar desa dengan ciri tertentu dan paling merusak energi yang rentan.
- Status desa gelap (belum ada listrik) / fosil (PLTU, PLTD, genset) / rapuh (energi bersih, belum dirawat warga) / mandiri (dirawat warga), desa turun saat krisis.
- Ciri alam per provinsi saat hover, di panel, dan di setup (`hint_strong`/`hint_medium` di `data/energies/*.tres`, atau `nature_hints` per provinsi). Kecocokan energi baru terungkap setelah membangun.
- Energi realistis untuk KKN: PLTS, mikrohidro, biomassa (`kkn_available`). Angin terbuka setelah KKN, panas bumi setelah menerima tawaran pemerintah.
- Resistensi satu bar dua warna (biru warga, merah Kepentingan Lama).
- Poin Dukungan (mahasiswa, lalu komunitas) dan Ekonomi.
- Pohon upgrade 5 kategori (81 upgrade), digambar sebagai pohon dari atas ke bawah (baris = kedalaman, kolom = cabang, garis = syarat; node = ikon + nama). Gaya Plague Inc: semua cabang bisa dibeli, tapi setiap upgrade yang dibeli membuat upgrade berikutnya `upgrade_cost_growth` (5%) lebih mahal. Satu-satunya aksi di panel wilayah adalah Bangun; semua kemampuan lain lewat pohon upgrade dan berlaku di semua wilayah.
- **Cabang per energi** (tab Sumber Energi): buka energi, lalu bercabang dua. Kiri: Output Listrik I (+20%) > II (+30%) > III (+30%) (`output:<energi>`, Poin & Ekonomi dari desa itu). Kanan: Material Bangunan I (+25%) > II (+30%) > III (+30%) (`quality:<energi>`, lebih jarang rusak & tahan bencana). Keduanya bertemu di **Teknisi Warga**, lalu **Pusat Pelatihan** (mandiri lebih cepat, lebih cocok, sebar +5%) (`indep:<energi>` lebih cepat mandiri, `build:<energi>` pemasangan lebih cepat, `fit:<energi>` lebih cocok).
- Teks efek (di bawah ikon dan di panel detail) dibuat otomatis dari `modifiers` oleh `scripts/ui/upgrade_text.gd`, jadi angka yang tampil selalu sama dengan angka di data.
- Menambah upgrade: duplikat `.tres`, isi `requires` dengan id upgrade induknya, lalu daftarkan di `data/database.tres`. Posisinya di pohon dihitung otomatis dari `requires`.
- **Kekuatan Komunitas tumbuh sendiri** di wilayah yang sudah punya desa berenergi bersih (`community_growth`), dan di wilayah awal selama KKN (`kkn_community_per_tick`, mahasiswa melatih warga). Dipercepat upgrade Edukasi & Warga (`community_gain`).
- **Internet Desa** (upgrade): semua wilayah berenergi bersih otomatis tersambung. **Forum Musyawarah Desa** (upgrade): resistensi biru turun tiap minggu.
- 9 event A/B (termasuk 3 event Kepentingan Lama), 3 versi tawaran pemerintah dari Skor Kelayakan.
- Misi KKN, gelembung aksi, berita (popup menjeda untuk berita penting, ticker untuk yang lain).
- Kotak **Peristiwa** di kiri bawah: gambar peristiwa terbaru + riwayat 12 peristiwa (`scripts/ui/event_feed.gd`).
- Layar akhir: tipe akhir dan tiga keputusan penentu.
- Audio dummy (11 SFX, 2 musik).

## Struktur folder
| Folder | Isi |
| --- | --- |
| `assets/` | Semua gambar & audio **dummy**. Daftar lengkap: `docs/ASSETS.md` |
| `data/` | Semua isi game sebagai file `.tres` (edit di Inspector) |
| `data/database.tres` | Daftar semua data. Data baru harus didaftarkan di sini |
| `data/game_config.tres` | Semua angka penyeimbang (waktu, poin, sebar, resistensi, ambang menang) |
| `data/ui_assets.tres` | Aset tampilan umum & audio yang dipakai kode |
| `scripts/data/` | Definisi tipe data (Resource) |
| `scripts/core/simulation.gd` | **Semua logika permainan** (tanpa tampilan) |
| `scripts/core/game.gd` | Autoload `Game`: waktu, jeda, pindah layar |
| `scripts/core/audio_manager.gd` | Autoload `Audio` |
| `scripts/ui/` | Skrip layar dan panel |
| `scenes/` | Layar (`title`, `slides`, `setup`, `game`, `end`) dan `ui/province_node.tscn` |
| `assets/ui/main_theme.tres` | Tema UI (warna panel, tombol, font). Ganti di sini untuk restyle semua UI |
| `tests/` | Tes otomatis (lihat bawah) |

## Mengganti aset dummy
Cara termudah: **timpa file dengan nama, format, dan ukuran yang sama**. Detail tiap file ada di `docs/ASSETS.md`.

- **Peta:** latar laut `assets/map/map_background.png` (1280x720) dan **satu PNG per wilayah** di `assets/map/regions/<id>.png` (1280x720, transparan, gambar putih/abu terang). Game mewarnai wilayah sesuai status, menggambar garis batas, dan mendeteksi klik dari piksel. Label provinsi digeser lewat `data/provinces/<id>.tres` → `map_position`. Detail di `docs/ASSETS.md`.
- **Ikon status provinsi:** `assets/map/node_*.png` (32x32). Hanya tampil untuk provinsi yang belum punya gambar wilayah; jika ada gambar wilayah, status ditunjukkan oleh warna yang menyebar dari satu titik (`shaders/region_spread.gdshader`, kecepatan di `GROW_SPEED` pada `scripts/ui/map_view.gd`). Tata letak label di `scenes/ui/province_node.tscn`.
- **Ikon & gambar kartu:** timpa file, atau ganti field `icon`/`image` di `.tres`-nya.
- **Font:** taruh file font di `assets/ui/`, buka `main_theme.tres`, isi *Default Font*.
- **Musik format lain (.ogg/.mp3):** taruh file, lalu arahkan `music_menu`/`music_game` di `data/ui_assets.tres`.

## Mengubah isi game
- **Tonggak waktu:** `data/milestones/*.tres` (tahun, judul, teks, gambar, target). Target kosong (-1) = pakai syarat menang. `target_no_dark` = menilai sisa desa gelap. Daftarkan di `data/database.tres` → `milestones`.
- **Kloter desa:** buka `data/provinces/<id>.tres` → `village_list`. Tiap kloter punya `display_name` (nama desa wakil, fiktif), `traits`, `start_fossil`, `size` (jumlah desa nyata), `origin` (provinsi asal), dan `compat` (kecocokan energi provinsi asal). Wilayah punya `member_provinces` dan `short_name` (label peta).
- **Ciri desa:** `data/traits/*.tres` → nama, deskripsi, ikon, dan `energy_bonus` (pengaruh ke kecocokan energi).
- **Bencana:** event dengan `is_disaster`, `target_traits` (ciri desa sasaran), dan `vulnerable_energies`.
- **Teks event, berita, slide, upgrade:** buka file di `data/events`, `data/news`, `data/slides`, `data/upgrades`, edit di Inspector.
- **Menambah event/upgrade/provinsi:** duplikat file `.tres` yang mirip (klik kanan → Duplicate), ubah `id` dan isinya, lalu tambahkan ke array yang sesuai di `data/database.tres`.
- **Kecocokan energi:** `data/provinces/<id>.tres` → `compat_override` (1.0 cocok, 0.5 sedang, 0.15 kurang). Jika kosong, dipakai `data/islands/<id>.tres` → `energy_compat`.
- **Wilayah, tetangga, dan pengubah gameplay:** `tools/wilayah.py`.
- **Peta:** `python3 tools/make_map.py --geojson tools/geo/indonesia-38-provinces.geojson` menghasilkan 24 PNG wilayah dan posisi label. Cara memakai gambar petamu sendiri ada di `docs/ASSETS.md`.
- **Membangun ulang data resmi:** `python3 tools/build_kloter.py` menulis ulang ke-24 file wilayah dan daftar wilayah di `data/database.tres`, lalu jalankan `python3 tools/make_cells.py` (sel kloter di peta harus mengikuti urutan kloter yang baru). Sumbernya `tools/podes_2024.json` (hasil `tools/extract_podes.py <PDF Podes>`), `tools/ruen_2017.py`, `tools/wilayah.py`, dan `tools/map_layout.json`. Ukuran kloter = `KLOTER` di skrip. Edit manual di file wilayah akan tertimpa, jadi ubah lewat skrip.
- **Kunci efek event** (field `effects` di pilihan A/B): `points`, `money`, `welfare`, `blue`, `red`, `community`, `lit`, dan `count_<nama>` untuk penghitung layar akhir.
- **Kunci pengubah upgrade** (`modifiers`): lihat daftar `MODIFIER_KEYS` di `scripts/data/game_config.gd`.
- **Trigger berita** yang dikenali: `province_first_lit`, `village_lit`, `village_independent`, `province_independent`, `village_down`, `build_started`, `build_delayed`, `kkn_end`, `stage_2`…`stage_6`, `seed_planted`, `seed_ignited`, `internet_installed`, `airplane_opened`, `offer_target_met`, `offer_target_failed`, `red_high`, `mission_done`.

## Peta: sel kloter dan warna energi
- Setiap kloter punya area sendiri di peta (`assets/map/cells.png`, `data/map_cells.json`, dibuat `tools/make_cells.py`). Kloter diletakkan di provinsi asalnya; kloter berciri pesisir dekat pantai, berciri gunung/sungai/hutan/lembah di pedalaman. Ini perkiraan, bukan koordinat desa sebenarnya.
- Warna sel = energi kloter itu (`color` di `data/energies/*.tres`): PLTS kuning, mikrohidro biru, biomassa hijau zaitun, angin putih kebiruan, panas bumi oranye. Bergaris = rapuh, penuh = mandiri, titik kecil bergaris = sedang dibangun. Coklat hangat = fosil, biru keunguan = gelap. Legenda ada di panel atas.
- **Prinsip warna (color theory):** laut biru tua yang sejuk dan gelap (nilai paling rendah), daratan belum bersih di tengah, energi bersih paling terang dan jenuh. Kontras komplementer biru (laut) vs kuning-oranye (energi, fosil) membuat perubahan langsung terlihat. Negara tetangga dibuat redup supaya fokus di Indonesia.
- **Supaya peta tidak terasa mati:** tekstur halus di daratan, cahaya tipis di garis pantai, lampu kecil berkelip di desa yang sudah berlistrik (fosil sedikit dan jingga, mandiri lebih banyak dan putih), dan kilau ombak di laut (`shaders/sea.gdshader`). Desa tanpa listrik tidak punya lampu.
- **Laut:** `assets/map/map_background.png`, dibuat `python3 tools/make_sea.py --ne <folder natural-earth-vector> --night` dari data kedalaman Natural Earth (domain publik), pixel art 4x dengan palet malam.
- Klik sel di peta membuka kloter itu di panel kanan; kloter yang dipilih disorot di peta.
- Shader: `shaders/region_cells.gdshader`.

## Aturan sebar per energi
- Desa hanya ikut menyebar atau dibangun otomatis jika salah satu energi yang SUDAH DIBUKA minimal "sedang" cocok di sana (`adopt_min_compat` = 0,45). Desa yang tidak cocok menunggu sampai energi yang cocok dibuka, atau upgrade "+cocok" menaikkan kecocokannya.
- Bangun manual (pilih kloter + energi sendiri) tetap boleh di mana saja, dengan risiko rusak lebih sering.
- Mulai dengan energi yang tidak cocok tetap bisa, tapi lambat (contoh: setelah 2,5 tahun, NTT + PLTS 3/7 kloter bersih, NTT + mikrohidro 1/7).

## Bangun otomatis dan kloter awal
- Di layar persiapan pemain memilih wilayah (klik peta), **kloter pertama** (atau "Otomatis"), dan energi. Kloter itu langsung mulai dibangun; biayanya sama dengan klik Bangun.
- Tombol **Otomatis** (B) di bar bawah: warga membangun kloter berikutnya sendiri, maksimal satu per tik, dengan energi paling cocok. Hanya di wilayah yang Komunitasnya minimal `auto_build_min_community` (kecuali kloter pertama wilayah itu), dan Poin disisakan `auto_build_reserve`. Wilayah yang sedang dipilih didahulukan.
- Angkanya di `data/game_config.tres`, grup "Bangun otomatis". Bot di `tests/sim_test.gd` tidak memakai bangun otomatis.
- Hasil cek: Otomatis saja tanpa membeli upgrade tidak pernah menang (macet di 36–66% desa bersih); Otomatis + membeli upgrade menang 6/6 (sekitar 2063–2069).

## Saklar fallback (checkpoint 1 November)
Semua ada di `data/game_config.tres`:
- `enable_red_resistance` = off → komponen merah (Kepentingan Lama) dan event-nya hilang.
- `enable_village_downgrade` = off → desa mandiri tidak turun saat krisis.
- `max_ticks` > 0 → batas waktu kembali aktif (akhir "Belum Tuntas").
- `turn_based_mode` = on → timer mati, muncul tombol **Berikutnya** (1 klik = `turn_ticks` minggu).
- `enable_build_time` = off → pembangkit langsung menyala saat dibangun (tanpa masa pembangunan).
- Kurangi provinsi/upgrade/event: hapus dari array di `data/database.tres` (filenya tidak perlu dihapus).

## Angka desain dan data
- **Dari data resmi:** kecocokan energi per provinsi (RUEN), proporsi desa gelap/fosil, ciri desa, dan peluang bencana per provinsi (Podes 2024). Sumber lengkapnya ada di `docs/SUMBER_DATA.md`.
- **Angka desain:** angka di `game_config.tres`, ukuran kloter (500), pembagian 38 provinsi ke 24 wilayah, faktor peluang ciri desa, dan nama desa wakil (fiktif).
- **Peta SDG dan Asta Cita:** `docs/SDG_ASTA_CITA.md`. Teks fakta di tiap kartu event sudah bersumber resmi (BNPB, ESDM, RUEN, MK, Kemkomdigi); daftar dan rujukannya di `docs/SUMBER_DATA.md` bagian 7.

## Tes
Jalankan dari terminal di folder proyek (ganti `godot` dengan path Godot-mu):
- `godot --headless -s res://tests/sim_test.gd`: bot memainkan banyak ronde dengan 3 strategi lalu mencetak hasil. Pakai ini setelah mengubah `game_config.tres`. Hasil terakhir (81 upgrade, biaya naik 5% per upgrade): seimbang menang 6/6 (2054–2064, sekitar 14–19 menit untuk bot), asal pilih 6/6, ngebut 0/6, pasif 0/6. Ke-24 wilayah awal bisa dimenangkan dengan energi KKN paling cocok (3/3). Tambahkan `-- quick` untuk melewati uji per wilayah.
- `godot --headless res://tests/realtime_test.tscn`: cek timer, jeda otomatis, KKN selesai, mode giliran.
- `godot --headless res://tests/debug_test.tscn`: menekan semua tombol debug sekali dan memastikan tidak ada error.
- `godot res://tests/screenshot_tour.tscn -- <folder>`: memainkan otomatis dan menyimpan screenshot tiap layar.

## Ekspor
`Project → Export`. Preset **Windows Desktop** (`build/windows/PercikanLentera.exe`) dan **Web** (`build/web/index.html`) sudah ada. Pertama kali, unduh template lewat `Editor → Manage Export Templates`. Build Web bisa diunggah ke itch.io sebagai game HTML5 supaya juri bisa main tanpa unduh.
