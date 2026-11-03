# Daftar aset dummy

Semua file di bawah ini adalah **placeholder**. Cara paling mudah mengganti: **timpa file dengan nama, format, dan ukuran yang sama**. Godot akan mengimpor ulang otomatis saat jendela editor difokuskan.

Jika ingin memakai nama atau format lain (misalnya musik `.ogg`), buka file data yang memakainya di Inspector lalu arahkan ulang. Aset tampilan umum dan audio diatur di `data/ui_assets.tres`; ikon upgrade, aksi, energi, gambar event, dan slide diatur di file `.tres` masing-masing di folder `data/`.

## Kotak Peristiwa (kiri bawah)
- Menampilkan gambar peristiwa terbaru: kartu event (`image` di `data/events/*.tres`), tawaran pemerintah (`image` di `data/offers/*.tres`), dan berita yang punya `image` di `data/news/*.tres`.
- Berita tanpa `image` tidak masuk kotak (hanya ticker). Jadi untuk menambah/menghapus berita dari kotak, cukup isi atau kosongkan field `image`-nya.
- Ukuran gambar 320x180 (16:9). Riwayat menyimpan 12 peristiwa terakhir.

## Peta wilayah
Peta berisi **24 wilayah** yang mencakup ke-38 provinsi. Peta memenuhi lebar layar dengan proporsi asli (x 20–1260, y sekitar 138–598); panel kiri dan kanan bisa dilipat supaya peta terlihat. Setiap wilayah = **satu PNG 1280x720 transparan** di `assets/map/regions/<id>.png`, sejajar persis dengan `map_background.png`. Kamu tidak perlu membuat 24 PNG ini dengan tangan; `tools/make_map.py` yang membuatnya.

Daftar wilayah dan provinsi anggotanya (diatur di `tools/wilayah.py`):
  - `aceh` Aceh
  - `sumut` Sumatera Utara
  - `riau` Riau, Sumatera Barat, Kepulauan Riau
  - `sumsel` Sumatera Selatan, Jambi, Kepulauan Bangka Belitung
  - `lampung` Lampung, Bengkulu
  - `jabar` Jawa Barat, DKI Jakarta, Banten
  - `jateng` Jawa Tengah, DI Yogyakarta
  - `jatim` Jawa Timur
  - `bali` Bali
  - `ntb` Nusa Tenggara Barat
  - `ntt` Nusa Tenggara Timur
  - `kalbar` Kalimantan Barat
  - `kalteng` Kalimantan Tengah
  - `kalsel` Kalimantan Selatan
  - `kaltim` Kalimantan Timur, Kalimantan Utara
  - `sulut` Sulawesi Utara, Gorontalo
  - `sulteng` Sulawesi Tengah
  - `sulsel` Sulawesi Selatan, Sulawesi Barat
  - `sultra` Sulawesi Tenggara
  - `maluku` Maluku
  - `malut` Maluku Utara
  - `pabar` Papua Barat, Papua Barat Daya
  - `papua` Papua
  - `papteng` Papua Tengah, Papua Pegunungan, Papua Selatan

**Placeholder sekarang** digambar dari batas provinsi asli (GeoJSON 38 provinsi, lisensi CC BY 4.0, lihat bagian Atribusi). Garis abu tipis di dalam wilayah adalah batas antarprovinsi.

### Cara memakai peta Indonesia buatanmu
Pilih salah satu.

**A. Gambar di atas template (paling mudah, disarankan)**
1. Buka `tools/geo/template_peta_38_provinsi.png` (1280x720, satu warna per provinsi) sebagai layer paling bawah di Krita/Photoshop/Aseprite.
2. Gambar daratan di atasnya dengan posisi yang sama. Gaya bebas; boleh berwarna.
3. Ekspor **daratan saja** (latar transparan) sebagai `daratan.png` 1280x720, dan **lautnya** sebagai `assets/map/map_background.png`.
4. Jalankan `python3 tools/make_map.py --geojson tools/geo/indonesia-38-provinces.geojson --art daratan.png`, lalu `python3 tools/build_kloter.py`. Terakhir `python3 tools/make_cells.py` untuk membagi wilayah menjadi sel kloter (`assets/map/cells.png`, `data/map_cells.json`).

Batas wilayah diambil dari template. Gradasi gambarmu dipakai sebagai tekstur di dalam wilayah, dan warna status dikalikan dengan tekstur itu. Detail gambarmu tetap terlihat, sedangkan warnanya mengikuti status.

**B. Peta dengan batas sendiri**
- Kalau garis pantai atau letak pulau berbeda dari template, warnai tiap provinsi dengan **satu warna polos** tanpa anti-aliasing.
- Isi daftar warnanya di file JSON dengan format seperti `tools/geo/legenda_warna.json`.
- Jalankan `python3 tools/make_map.py --color-map peta.png --legend legenda.json`.
- Bisa juga mengekspor satu PNG transparan per provinsi ke satu folder (nama file = nama provinsi, misalnya `Jawa Barat.png`), lalu jalankan `--layers-dir folder/`.

**Hasil dari setiap cara:**
- 24 PNG wilayah.
- Posisi label di `tools/map_layout.json`. Label wilayah kecil bisa digeser lewat `LABEL_OFFSET` di `tools/wilayah.py`.
- Cek tetangga darat antarwilayah.
- Opsi `--preview cek.png` membuat gambar pratinjau.

Catatan:
- Gambar wilayah dengan putih atau abu terang. Bagian yang lebih gelap akan tampak sebagai bayangan.
- Garis batas luar wilayah digambar otomatis oleh game.
- Piksel yang tidak transparan bisa diklik. Pulau kecil sudah dilebarkan 3 piksel ke laut supaya mudah diklik.

Gaya: pixel art. Proyek sudah memakai filter *Nearest* (tidak blur). Usahakan ukuran asli sama, atau kelipatan bulatnya.

Lisensi: catat sumber dan lisensi setiap aset yang bukan buatan sendiri di tabel log di bawah, untuk lampiran proposal.

| File | Ukuran | Dipakai untuk | Sumber |
| --- | --- | --- | --- |
| `assets/ui/app_icon.png` | 64x64 | Ikon aplikasi/jendela | Buat sendiri |
| `assets/ui/title_background.png` | 640x360 | Latar layar judul | Buat sendiri |
| `assets/images/end/lose.png` | 320x180 | Ilustrasi layar kalah | Buat sendiri |
| `assets/images/end/win.png` | 320x180 | Ilustrasi layar menang | Buat sendiri |
| `assets/images/events/bakar_lahan.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/hoaks_panel.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/investor_plta.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/izin_ditahan.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/lobi_hoaks.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/plts_rusak.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/solar_subsidi.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/events/tawaran_pemerintah.png` | 320x180 | Gambar kartu tawaran pemerintah | Buat sendiri |
| `assets/images/events/titik_api.png` | 320x180 | Gambar kartu event | Buat sendiri |
| `assets/images/news/airplane_opened.png` | 320x180 | Kotak Peristiwa untuk berita `airplane_opened` | Buat sendiri |
| `assets/images/news/kkn_end.png` | 320x180 | Kotak Peristiwa untuk berita `kkn_end` | Buat sendiri |
| `assets/images/news/kkn_start.png` | 320x180 | Gambar pertama kotak Peristiwa saat permainan dimulai (`data/ui_assets.tres` → feed_start) | Buat sendiri |
| `assets/images/news/offer_target_failed.png` | 320x180 | Kotak Peristiwa untuk berita `offer_target_failed` | Buat sendiri |
| `assets/images/news/province_first_lit.png` | 320x180 | Kotak Peristiwa untuk berita `province_first_lit` | Buat sendiri |
| `assets/images/news/province_independent.png` | 320x180 | Kotak Peristiwa untuk berita `province_independent` | Buat sendiri |
| `assets/images/news/red_high.png` | 320x180 | Kotak Peristiwa untuk berita `red_high` | Buat sendiri |
| `assets/images/news/seed_ignited.png` | 320x180 | Kotak Peristiwa untuk berita `seed_ignited` | Buat sendiri |
| `assets/images/news/stage_3.png` | 320x180 | Kotak Peristiwa untuk berita `stage_3` | Buat sendiri |
| `assets/images/news/stage_4.png` | 320x180 | Kotak Peristiwa untuk berita `stage_4` | Buat sendiri |
| `assets/images/news/stage_5.png` | 320x180 | Kotak Peristiwa untuk berita `stage_5` | Buat sendiri |
| `assets/images/news/stage_6.png` | 320x180 | Kotak Peristiwa untuk berita `stage_6` | Buat sendiri |
| `assets/images/news/village_down.png` | 320x180 | Kotak Peristiwa untuk berita `village_down` | Buat sendiri |
| `assets/images/slides/guide_1.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_2.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_3.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_4.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_5.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_6.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/guide_7.png` | 320x180 | Slide panduan | Buat sendiri |
| `assets/images/slides/intro_1.png` | 320x180 | Slide intro cerita | Buat sendiri |
| `assets/images/slides/intro_2.png` | 320x180 | Slide intro cerita | Buat sendiri |
| `assets/images/slides/intro_3.png` | 320x180 | Slide intro cerita | Buat sendiri |
| `assets/images/slides/intro_4.png` | 320x180 | Slide intro cerita | Buat sendiri |
| `assets/audio/music/game.wav` | audio | Musik saat bermain | Boleh cari |
| `assets/audio/music/menu.wav` | audio | Musik menu & layar akhir | Boleh cari |
| `assets/audio/sfx/buy.wav` | audio | Efek suara (kunci: buy) | Boleh cari |
| `assets/audio/sfx/click.wav` | audio | Efek suara (kunci: click) | Boleh cari |
| `assets/audio/sfx/dark.wav` | audio | Efek suara (kunci: dark) | Boleh cari |
| `assets/audio/sfx/event.wav` | audio | Efek suara (kunci: event) | Boleh cari |
| `assets/audio/sfx/independent.wav` | audio | Efek suara (kunci: independent) | Boleh cari |
| `assets/audio/sfx/lit.wav` | audio | Efek suara (kunci: lit) | Boleh cari |
| `assets/audio/sfx/news.wav` | audio | Efek suara (kunci: news) | Boleh cari |
| `assets/audio/sfx/offer.wav` | audio | Efek suara (kunci: offer) | Boleh cari |
| `assets/audio/sfx/point.wav` | audio | Efek suara (kunci: point) | Boleh cari |
| `assets/audio/sfx/stage.wav` | audio | Efek suara (kunci: stage) | Boleh cari |
| `assets/audio/sfx/warning.wav` | audio | Efek suara (kunci: warning) | Boleh cari |
| `assets/icons/energy/angin.png` | 32x32 | Ikon sumber energi (juga dipakai upgrade energi) | Buat sendiri |
| `assets/icons/energy/biomassa.png` | 32x32 | Ikon sumber energi (juga dipakai upgrade energi) | Buat sendiri |
| `assets/icons/energy/mikrohidro.png` | 32x32 | Ikon sumber energi (juga dipakai upgrade energi) | Buat sendiri |
| `assets/icons/energy/panas_bumi.png` | 32x32 | Ikon sumber energi (juga dipakai upgrade energi) | Buat sendiri |
| `assets/icons/energy/plts.png` | 32x32 | Ikon sumber energi (juga dipakai upgrade energi) | Buat sendiri |
| `assets/icons/stats/community.png` | 32x32 | Ikon nilai di HUD | Boleh cari |
| `assets/icons/stats/money.png` | 32x32 | Ikon nilai di HUD | Boleh cari |
| `assets/icons/stats/points.png` | 32x32 | Ikon nilai di HUD | Boleh cari |
| `assets/icons/stats/resistance.png` | 32x32 | Ikon nilai di HUD | Boleh cari |
| `assets/icons/stats/welfare.png` | 32x32 | Ikon nilai di HUD | Boleh cari |
| `assets/icons/actions/build.png` | 32x32 | Ikon tombol aksi provinsi | Buat sendiri |
| `assets/icons/actions/dialog.png` | 32x32 | Ikon tombol aksi provinsi | Buat sendiri |
| `assets/icons/actions/internet.png` | 32x32 | Ikon tombol aksi provinsi | Buat sendiri |
| `assets/icons/actions/train.png` | 32x32 | Ikon tombol aksi provinsi | Buat sendiri |
| `assets/icons/upgrades/internet_desa.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/jalur_antar_desa.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/kader_desa.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/klarifikasi.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/koperasi_energi.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/latih_teknisi.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/pekerjaan_hijau.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/rute_udara.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/sekolah_daring.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/sensor.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/telemedicine.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/tokoh_adat.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/upgrades/umkm.png` | 32x32 | Ikon upgrade di pohon upgrade | Buat sendiri |
| `assets/icons/news/government.png` | 24x24 | Ikon berita (ticker & popup) | Boleh cari |
| `assets/icons/news/impact.png` | 24x24 | Ikon berita (ticker & popup) | Boleh cari |
| `assets/icons/news/opposition.png` | 24x24 | Ikon berita (ticker & popup) | Boleh cari |
| `assets/icons/news/progress.png` | 24x24 | Ikon berita (ticker & popup) | Boleh cari |
| `assets/icons/news/warning.png` | 24x24 | Ikon berita (ticker & popup) | Boleh cari |
| `assets/map/bubble.png` | 24x24 | Gelembung aksi yang bisa diklik | Buat sendiri |
| `assets/images/milestones/target_2030.png` | 320x180 | Gambar popup tonggak 2030 (semua desa berlistrik) | Buat sendiri |
| `assets/images/milestones/emas_2045.png` | 320x180 | Gambar popup tonggak Indonesia Emas 2045 | Buat sendiri |
| `assets/map/map_background.png` | 1920x1080 | Lebih luas 320/180 px di tiap sisi dari peta 1280x720, supaya layar lebar tetap menampilkan laut dan negara tetangga). Laut malam pixel art sesuai kedalaman (Natural Earth, domain publik), dibuat `tools/make_sea.py --night`. Kilau ombak ditambahkan shader `shaders/sea.gdshader` | Otomatis (boleh diganti) |
| `assets/map/regions/aceh.png` | 1280x720 | Wilayah `aceh` (Aceh); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sumut.png` | 1280x720 | Wilayah `sumut` (Sumatera Utara); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/riau.png` | 1280x720 | Wilayah `riau` (Riau, Sumatera Barat, Kepulauan Riau); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sumsel.png` | 1280x720 | Wilayah `sumsel` (Sumatera Selatan, Jambi, Kepulauan Bangka Belitung); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/lampung.png` | 1280x720 | Wilayah `lampung` (Lampung, Bengkulu); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/jabar.png` | 1280x720 | Wilayah `jabar` (Jawa Barat, DKI Jakarta, Banten); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/jateng.png` | 1280x720 | Wilayah `jateng` (Jawa Tengah, DI Yogyakarta); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/jatim.png` | 1280x720 | Wilayah `jatim` (Jawa Timur); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/bali.png` | 1280x720 | Wilayah `bali` (Bali); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/ntb.png` | 1280x720 | Wilayah `ntb` (Nusa Tenggara Barat); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/ntt.png` | 1280x720 | Wilayah `ntt` (Nusa Tenggara Timur); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/kalbar.png` | 1280x720 | Wilayah `kalbar` (Kalimantan Barat); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/kalteng.png` | 1280x720 | Wilayah `kalteng` (Kalimantan Tengah); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/kalsel.png` | 1280x720 | Wilayah `kalsel` (Kalimantan Selatan); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/kaltim.png` | 1280x720 | Wilayah `kaltim` (Kalimantan Timur, Kalimantan Utara); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sulut.png` | 1280x720 | Wilayah `sulut` (Sulawesi Utara, Gorontalo); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sulteng.png` | 1280x720 | Wilayah `sulteng` (Sulawesi Tengah); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sulsel.png` | 1280x720 | Wilayah `sulsel` (Sulawesi Selatan, Sulawesi Barat); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/sultra.png` | 1280x720 | Wilayah `sultra` (Sulawesi Tenggara); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/maluku.png` | 1280x720 | Wilayah `maluku` (Maluku); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/malut.png` | 1280x720 | Wilayah `malut` (Maluku Utara); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/pabar.png` | 1280x720 | Wilayah `pabar` (Papua Barat, Papua Barat Daya); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/papua.png` | 1280x720 | Wilayah `papua` (Papua); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/map/regions/papteng.png` | 1280x720 | Wilayah `papteng` (Papua Tengah, Papua Pegunungan, Papua Selatan); dibuat oleh `tools/make_map.py` | Otomatis |
| `assets/icons/traits/gunung_api.png` | 24x24 | Ikon ciri desa `gunung_api` | Buat sendiri |
| `assets/icons/traits/hutan_berkabut.png` | 24x24 | Ikon ciri desa `hutan_berkabut` | Buat sendiri |
| `assets/icons/traits/lahan_terik.png` | 24x24 | Ikon ciri desa `lahan_terik` | Buat sendiri |
| `assets/icons/traits/lembah_tertutup.png` | 24x24 | Ikon ciri desa `lembah_tertutup` | Buat sendiri |
| `assets/icons/traits/limbah_perkebunan.png` | 24x24 | Ikon ciri desa `limbah_perkebunan` | Buat sendiri |
| `assets/icons/traits/pesisir_berangin.png` | 24x24 | Ikon ciri desa `pesisir_berangin` | Buat sendiri |
| `assets/icons/traits/peternakan.png` | 24x24 | Ikon ciri desa `peternakan` | Buat sendiri |
| `assets/icons/traits/sungai_deras.png` | 24x24 | Ikon ciri desa `sungai_deras` | Buat sendiri |
| `assets/images/events/banjir_bandang.png` | 320x180 | Kartu bencana `banjir_bandang` | Buat sendiri |
| `assets/images/events/badai_pesisir.png` | 320x180 | Kartu bencana `badai_pesisir` | Buat sendiri |
| `assets/images/events/kemarau_panjang.png` | 320x180 | Kartu bencana `kemarau_panjang` | Buat sendiri |
| `assets/images/events/erupsi.png` | 320x180 | Kartu bencana `erupsi` | Buat sendiri |
| `assets/map/node_dark.png` | 32x32 | Titik provinsi gelap | Buat sendiri |
| `assets/map/node_independent.png` | 32x32 | Titik provinsi mandiri | Buat sendiri |
| `assets/map/node_lit.png` | 32x32 | Titik provinsi dipantik (ada desa menyala) | Buat sendiri |
| `assets/map/node_seed.png` | 32x32 | Titik provinsi benih (tersentuh internet) | Buat sendiri |
| `assets/map/node_selected.png` | 40x40 | Cincin provinsi terpilih | Buat sendiri |

## Log lisensi (isi saat mengganti aset)

| File | Sumber/pembuat | Lisensi | Link |
| --- | --- | --- | --- |
| | | | |


## Atribusi
- **Batas provinsi (placeholder peta dan template):** "Indonesia GeoJSON & TopoJSON Maps (38 Provinces)", github.com/denyherianto/indonesia-geojson-topojson-maps-with-38-provinces. Lisensi **CC BY 4.0**; salinannya ada di `tools/geo/DATA_LICENSE.md`. Batas tersebut diproyeksikan, diregangkan secara vertikal, dan dikelompokkan menjadi 24 wilayah. Jika peta final masih memakai batas ini (cara A), cantumkan atribusi tersebut di kredit game dan di proposal.
- **Latar laut (kedalaman, daratan negara tetangga):** Natural Earth 1:10m, naturalearthdata.com (domain publik, atribusi tidak wajib tetapi dianjurkan: "Made with Natural Earth"). Dibuat dengan `python3 tools/make_sea.py --ne <folder natural-earth-vector>`.
