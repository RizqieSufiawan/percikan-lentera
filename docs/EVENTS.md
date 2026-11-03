# Daftar event dan kejadian

## Status desa
| Status | Warna | Artinya |
| --- | --- | --- |
| Gelap | Abu gelap | Belum ada listrik |
| Fosil | Coklat asap | Berlistrik dari PLTU, PLTD, atau genset |
| Rapuh | Kuning | Energi bersih, warga belum mampu merawat |
| Mandiri | Hijau | Energi bersih dirawat warga sendiri (Komunitas provinsi ≥ 45) |

Jumlah desa fosil awal per provinsi ada di `data/provinces/*.tres` → `fossil_villages` (angka desain).

## Desa contoh dan ciri desa
Setiap wilayah berisi kloter desa di `data/provinces/<id>.tres` → `village_list`. Satu kloter = ±500 desa nyata dari satu provinsi asal (`size`, `origin`), diwakili satu nama desa fiktif. Tiap kloter punya ciri (`data/traits/*.tres`), status awal (`start_fossil`), dan kecocokan energi provinsi asalnya (`compat`).

Kecocokan energi di sebuah kloter = 0.2 + 0.35 × kecocokan provinsi asal + bonus ciri desa (dibatasi 0.15–1.0). Angka di `game_config.tres` → *Kecocokan per desa*.

Kecocokan provinsi asal (`compat`) berasal dari potensi EBT per provinsi di Perpres 22/2017 (RUEN). Jumlah desa, status awal, dan ciri berasal dari Podes 2024 (BPS). Semuanya dihasilkan oleh `python3 tools/build_kloter.py`; cara hitung dan angka sumbernya ada di `docs/SUMBER_DATA.md`.

| Ciri | Bonus kecocokan | Disasar bencana |
| --- | --- | --- |
| Pesisir berangin | Angin +0.5, PLTS +0.15 | Badai Pesisir |
| Sungai deras | Mikrohidro +0.5 | Banjir Bandang, Kemarau Panjang |
| Lahan terik | PLTS +0.5 | |
| Limbah perkebunan | Biomassa +0.5 | Kebakaran Hutan dan Lahan |
| Limbah organik | Biomassa +0.3 | |
| Dekat gunung api | Panas bumi +0.5 | Erupsi Gunung Api |
| Hutan berkabut | PLTS −0.3, Angin −0.3 | Kebakaran Hutan dan Lahan |
| Lembah tertutup | Angin −0.4 | |

Aturan penting:
- **Pemain memilih energi per desa** (panel provinsi → klik desa → Bangun: <energi>). Kecocokannya terungkap setelah dibangun.
- **Sebaran meniru contoh:** desa hanya mengadopsi energi yang sudah dipakai di desa asal sebaran atau di provinsinya sendiri.
- **Energi yang kurang cocok lebih sering rusak** (desa rapuh bisa gagal sendiri; dikurangi komunitas yang kuat) dan **lebih lambat menjadi mandiri**.
- Desa yang gagal kembali ke kondisi awalnya: fosil jika dulu memakai fosil, selain itu gelap.

## Tonggak waktu (soft deadline)
Kalender: selama KKN 1 tik = 1 minggu. Setelah KKN 1 tik = `weeks_per_tick_after_kkn` minggu (2).

Saat tanggal cerita sampai di tahun tonggak, muncul evaluasi capaian dibanding target, lalu permainan **berlanjut**. Tonggak tidak menentukan menang atau kalah.

- **2030, 2045, 2060** (`major = true`): popup besar yang menjeda.
- **2040, 2050** (`major = false`): notifikasi kecil di tengah atas, permainan tetap berjalan.
- Semua tonggak masuk ke kotak Peristiwa dengan teks lengkap.

| Tonggak | Tahun | Target resmi | Batas "di jalur 2060" (angka desain) |
| --- | --- | --- | --- |
| Semua Desa Berlistrik | 2030 | Semua desa/dusun berlistrik 2029–2030 (ESDM, siaran pers No. 002.Pers/04/SJI/2026). Popup juga menampilkan sisa desa gelap | ≥ 3% bersih, ≥ 1% mandiri |
| Target KEN 2040 | 2040 | Bauran EBT 36–40% (PP 40/2025 Pasal 10) | ≥ 18% bersih, ≥ 10% mandiri |
| Indonesia Emas 2045 | 2045 | Visi Indonesia Emas 2045 (RPJPN 2025–2045) | ≥ 30% bersih, ≥ 18% mandiri |
| Target KEN 2050 | 2050 | Bauran EBT 53–55% (PP 40/2025) | ≥ 45% bersih, ≥ 28% mandiri |
| Target Nasional 2060 | 2060 | Bauran EBT 70–72% dan Net Zero 2060 (PP 40/2025) | Target: ≥ 70% bersih, ≥ 50% mandiri (`win_access`, `win_independent`) |

Catatan:
- **Batas jalur** diambil dari uji bot. Pemain di atas batas itu umumnya menang sebelum 2060. Batas ini lebih rendah dari angka KEN karena gerakan di game mulai dari nol di tingkat desa, sedangkan KEN mengukur bauran energi nasional yang sekarang sudah sekitar 16%.
- Batas bisa diubah di `on_track_access` dan `on_track_independent` di `data/milestones/*.tres`.
- Dalam uji bot, pemain yang membaca ciri desa menang sekitar 2045–2060, sedangkan pemain yang asal memilih energi sekitar 2055–2071.
- Popup memberi status **DI JALUR** atau **KELUAR JALUR**, beserta jumlah desa yang perlu dikejar.
- Di layar akhir, setiap tonggak muncul sebagai satu baris ringkasan. Kemenangan juga dibandingkan dengan 2060 ("Target tercapai pada 2053, 7 tahun lebih cepat dari Target Nasional 2060").

## Perayaan kota
- Saat ≥ 50% desa di sebuah provinsi (`city_celebrate_share`) memakai energi bersih, ibu kota provinsinya dirayakan, misalnya "Kupang merayakan! 52% desa di NTT kini memakai energi bersih."
- Muncul sebagai notifikasi kecil dan di ticker, tanpa menjeda.
- Daftar 38 ibu kota ada di `data/database.tres` → `cities`, dengan kunci nama pendek provinsi asal kloter.

## Masa pembangunan
- Aksi **Bangun Bersama Warga** memesan pembangkit di satu kloter. Biaya dibayar saat itu juga, dan pembangkit baru menyala setelah `build_weeks_min`–`build_weeks_max` minggu (8–16).
- Selama dibangun, kloter tidak bisa dibangun ulang dan tidak ikut terkena sebaran.
- Di panel tertulis "[dibangun N mgg]", lengkap dengan persen kemajuannya. Kecocokan energi terungkap saat pembangkit menyala.
- Bencana atau krisis di wilayah itu bisa menunda pembangunan. Peluangnya = keparahan × `crisis_build_delay_chance` × kerentanan. Lama tundanya `crisis_build_delay_weeks` × kerentanan (6 minggu, dikali 0,5 sampai 2). Energi rentan dan ciri sasaran memperparah. Hasil kartu menyebut jumlah kloter yang tertunda.
- Upgrade **Program Teknisi Desa**: `build_time_mult` −0,25. Cabang energi (Modul PLTS Siap Pasang, Turbin Buatan Bengkel Lokal, dst.): `build:<energi>` 0,35.
- Kekalahan "semua padam" tidak terjadi selama masih ada pembangkit yang sedang dibangun.
- Saklar: `enable_build_time` di `game_config.tres`.

## Bencana alam
Bencana menghantam desa dengan ciri tertentu. Provinsi yang lebih sering mengalami bencana itu menurut Podes 2024 Tabel 15.2 (`disaster_rates` di file provinsi) lebih sering disasar: bobot = persen desa terdampak ÷ `disaster_rate_ref` (10%), minimal `disaster_rate_floor` (1%). Persen dihitung gabungan provinsi anggota wilayah.

Desa yang memakai energi rentan rusak 2× lebih parah, desa dengan ciri sasaran 1.5×, desa lain 0.5×. Upgrade Sensor Peringatan Dini dan Telemedicine mengurangi dampak.

| Bencana | Desa sasaran | Energi paling rentan | Pilihan A | Pilihan B |
| --- | --- | --- | --- | --- |
| Banjir Bandang | Sungai deras | Mikrohidro | Evakuasi & amankan turbin (Poin −3, Ekonomi −4, krisis ringan) | Tunggu surut (Kesejahteraan −4, krisis penuh) |
| Badai Pesisir | Pesisir berangin | Angin, PLTS | Ikat & turunkan peralatan (Poin −3, Ekonomi −3, krisis ringan) | Biarkan (Kesejahteraan −3, krisis penuh) |
| Kemarau Panjang | Sungai deras | Mikrohidro | PLTS cadangan (Ekonomi −6, Poin −2, krisis ringan) | Genset sementara (Ekonomi −2, merah +3, krisis sedang) |
| Erupsi Gunung Api | Dekat gunung api | Panas bumi, PLTS | Evakuasi & bersihkan abu (Poin −4, Kesejahteraan −2) | Tunggu reda (Kesejahteraan −6, krisis berat) |
| Kebakaran Hutan dan Lahan | Limbah perkebunan, hutan berkabut | Biomassa | Regu siaga | Abaikan (krisis penuh) |

## Energi
| Energi | Kapan tersedia |
| --- | --- |
| PLTS, Mikrohidro, Biomassa | Bisa dibawa tim KKN (pilihan awal) atau dibuka lewat pohon upgrade |
| Turbin Angin Kecil | Upgrade, terbuka setelah KKN selesai |
| Panas Bumi | Upgrade, terbuka setelah menerima satu tawaran pemerintah |

Dibuat dari isi `data/` saat prototipe dikirim. Kalau data diubah, tabel ini tidak ikut berubah.
Semua angka adalah angka desain.

## Kejadian sistem (otomatis, bukan kartu)

| Kejadian | Kapan | Akibat | Tampil |
| --- | --- | --- | --- |
| Kartu pembuka KKN | Awal permainan | Penjelasan misi | Popup |
| Misi KKN selesai | Pembangkit pertama menyala / beli 2 upgrade / Komunitas wilayah awal 30 selama KKN | Poin +3 sampai +4, resistensi biru turun | Ticker |
| KKN selesai (fase ujian) | Minggu ke-26 | Desa rapuh di provinsi berkomunitas < 30 punya peluang 40% padam. Poin mahasiswa berhenti | Kartu khusus |
| Naik tahap 2 sampai 6 | Pasca-KKN; 2 provinsi menyala; tawaran pertama dijawab; 2 provinsi mandiri; akses 60% | Membuka event Kepentingan Lama (tahap 3) dan tawaran (tahap 3+) | Ticker / popup |
| Desa beralih ke energi bersih (rapuh) | Pemain membangun di desa pilihannya, atau sebaran (meniru energi desa asal) | Desa fosil yang beralih menaikkan resistensi merah +0.12. Desa masih rapuh sampai warganya mampu merawat | Ticker |
| Desa rapuh gagal sendiri | Tiap minggu, peluang kecil jika energinya kurang cocok | Kembali ke kondisi awal (fosil/gelap) | Ticker |
| Kecocokan energi terungkap | Pertama kali membangun di suatu provinsi dengan suatu energi | Panel provinsi menampilkan "terbukti cocok/sedang/tidak cocok" | Ticker |
| Desa rapuh → mandiri | Komunitas provinsi ≥ 45 | Desa dirawat warga, memberi Poin & Ekonomi | Ticker |
| Provinsi mandiri | ≥ 50% desanya mandiri | Status provinsi berubah | Popup |
| Desa turun / padam | Pilihan event yang memicu krisis | Desa rapuh bisa gagal (kembali ke fosil atau gelap, sesuai bagian desa fosil provinsinya); desa mandiri di provinsi berkomunitas < 55 bisa turun jadi rapuh | Ticker |
| Benih internet | Provinsi ber-internet, peluang kecil tiap minggu | Provinsi jauh jadi "benih" (lebih siap, aksi pertama lebih murah) | Ticker |
| Benih menyala sendiri | Provinsi benih, peluang kecil tiap minggu | 1 desa menyala tanpa aksi pemain | Popup |
| Rute pesawat dibuka | Tawaran biasa/lancar diterima, atau upgrade Rute Udara | Sebar & aksi ke pulau lain | Popup |
| Target pemerintah tercapai / gagal | Saat target tawaran selesai / lewat batas | Gagal: resistensi merah naik, skor kelayakan turun | Ticker / popup |
| Kepentingan Lama bergerak | Resistensi merah > 30 (sekali) | Peringatan | Popup |
| Gelembung aksi | Tiap ±9 detik (kecepatan 1x) | Klik: Poin +1.5 | Di peta |

## Akhir permainan

| Hasil | Syarat |
| --- | --- |
| Menang (permainan selesai) | **Semua** 84.276 desa memakai energi bersih (tidak ada desa gelap atau fosil). Tidak ada batas waktu (`max_ticks` = 0). Judul akhir: "Cepat dan Tahan" (sebelum 2055), "Tepat Waktu" (sampai 2060), "Pelan tapi Tahan" (setelah 2060), atau "Bersih tapi Rapuh" jika kurang dari 50% desa mandiri |
| Kalah: Ditolak Warga | Resistensi biru + merah ≥ 100 |
| Kalah: Kesejahteraan | Kesejahteraan 0 |
| Kalah: Ekonomi | Ekonomi 0 selama 26 minggu berturut-turut |
| Kalah: Padam | Setelah KKN, tidak ada desa yang memakai energi bersih |
| Belum Tuntas | Batas pengaman 1300 minggu (25 tahun) |

Tipe akhir: "Cepat dan Tahan" / "Pelan tapi Tahan" (menang), "Cepat tapi Rapuh" (kalah dengan sedikit desa mandiri), "Ditolak Warga", "Padam", "Belum Tuntas".

## Event kartu (pilihan A/B)

| # | Event (`id`) | Muncul di | Tahap min. | Pilihan A | Pilihan B |
| --- | --- | --- | --- | --- | --- |
| 2 | Hoaks Viral (`hoaks_panel`) | Semua pulau | 2 | **Kampanye klarifikasi (mahal, efektif)**: Resistensi biru -6, Poin -3 | **Abaikan**: Resistensi biru +6 |
| 3 | Titik Api Dekat Desa (`titik_api`) | sumatra, kalimantan | 2 | **Kerahkan regu siaga**: Poin -3, Kesejahteraan -1, krisis 0.2 | **Abaikan**: Kesejahteraan -5, krisis 1.0 |
| 4 | Investor PLTA Besar (`investor_plta`) | papua, kalimantan, sulawesi | 2 | **Terima**: Resistensi biru +8, Desa berlistrik +2, Ekonomi +6, Kesejahteraan -4 | **Tolak, pilih mikrohidro warga**: Resistensi biru -3, Komunitas provinsi +10, Poin -2 |
| 5 | Panel Mulai Rusak (`plts_rusak`) | Semua pulau | 2 | **Latih teknisi sekarang**: Komunitas provinsi +12, Poin -4 | **Biarkan**: Resistensi biru +3, krisis 0.8 |
| 6 | Warga Membakar Sisa Lahan (`bakar_lahan`) | sumatra, kalimantan, sulawesi, nusa_tenggara | 2 | **Olah jadi biomassa**: Ekonomi -6, Resistensi merah -2, Kesejahteraan +2 | **Larang tanpa solusi**: Resistensi biru +6 |
| 7 | Solar Tiba-tiba Murah (`solar_subsidi`) | Semua pulau (Kepentingan Lama) | 3 | **Tunjukkan hitungan jangka panjang**: Poin -3, Resistensi merah -3 | **Biarkan warga memilih**: 1 desa rapuh kembali ke fosil, Resistensi merah +3 |
| 8 | Izin Proyek Ditahan (`izin_ditahan`) | Semua pulau (Kepentingan Lama) | 3 | **Lapor ke pemerintah daerah**: Poin -4, Resistensi merah -4 | **Tunggu saja**: Resistensi biru +4, Kesejahteraan -2 |
| 9 | Kampanye Tandingan (`lobi_hoaks`) | Semua pulau (Kepentingan Lama) | 3 | **Ajak pekerja lama bergabung**: Komunitas provinsi +6, Ekonomi -6, Resistensi merah -5 | **Balas dengan spanduk**: Resistensi biru +5, Resistensi merah +2 |

## Tawaran pemerintah

| Versi | Judul | Jika diterima | Target | Jika ditolak |
| --- | --- | --- | --- | --- |
| rapuh | Proyek dari Atas | Ekonomi +12, Poin +3, rute pesawat tidak ada; Resistensi biru +6 | 4 desa dalam 52 minggu (gagal: merah +6) | Resistensi biru -2 |
| biasa | Kerja Sama Bersyarat | Ekonomi +25, Poin +6, rute pesawat 1 pulau; Resistensi biru +2 | 8 desa dalam 78 minggu (gagal: merah +8) | Resistensi biru -2 |
| lancar | Mitra Program Nasional | Ekonomi +40, Poin +12, rute pesawat semua pulau; Resistensi biru -3 | 6 desa dalam 104 minggu (gagal: merah +4) | Resistensi biru -3 |

## Berita

| Trigger | Tampil | Headline |
| --- | --- | --- |
| `province_first_lit` | Ticker | Lampu pertama menyala di {province}! |
| `village_lit` | Ticker | Satu desa lagi di {province} kini berlistrik. |
| `village_independent` | Ticker | Warga {province} kini merawat pembangkitnya sendiri. |
| `province_independent` | Popup (menjeda) | {province} kini sebagian besar mandiri! Komunitas warga mengambil alih. |
| `build_started` | Ticker | Warga {village} ({province}) mulai membangun pembangkit. Butuh 2-4 bulan sampai menyala. |
| `build_delayed` | Ticker | Bencana di {province} menunda pembangunan pembangkit. |
| `village_down` | Ticker | Krisis di {province}: desa yang belum kuat kembali gelap. |
| `kkn_end` | Popup (menjeda) | KKN selesai. Tim mahasiswa pulang. Apakah desa tetap menyala tanpa kita? |
| `stage_2` | Ticker | Tahap 2: Pasca-KKN. Komunitas warga yang melanjutkan. |
| `stage_3` | Popup (menjeda) | Tahap 3: Desa tetangga mulai tertarik ikut menyala. |
| `stage_4` | Popup (menjeda) | Tahap 4: Pemerintah daerah mulai memperhatikan program ini. |
| `stage_5` | Popup (menjeda) | Tahap 5: Jaringan antar-desa terbentuk. |
| `stage_6` | Popup (menjeda) | Tahap 6: Gerakan nasional. Desa-desa saling memantik. |
| `seed_planted` | Ticker | Grup daring komunitas menjangkau warga {province}. Benih sudah tertanam. |
| `seed_ignited` | Popup (menjeda) | Warga {province} menyalakan pembangkit pertama mereka sendiri! |
| `internet_installed` | Ticker | Internet desa tersambung di {province}. |
| `airplane_opened` | Popup (menjeda) | Rute pesawat dibuka. Peralatan bisa dikirim ke pulau yang jauh. |
| `offer_target_met` | Ticker | Target kerja sama pemerintah tercapai. |
| `offer_target_failed` | Popup (menjeda) | Target pemerintah gagal. Kepercayaan pemerintah turun. |
| `red_high` | Popup (menjeda) | Kepentingan energi lama mulai bergerak menghambat program. |
| `mission_done` | Ticker | Misi KKN selesai: {province} |

Catatan: event Kepentingan Lama hanya muncul jika `enable_red_resistance` aktif, dan bobotnya naik saat resistensi merah tinggi. Event bertag pulau hanya muncul jika ada provinsi menyala di pulau itu. Peluang event 3% per minggu setelah KKN, dengan jeda ulang 80 minggu per event.

## Tombol debug

Aktif hanya saat dijalankan dari editor (build Release tidak memuatnya). Tekan **F1** di layar permainan.

| Tombol | Fungsi |
| --- | --- |
| F1 | Tampilkan / sembunyikan daftar tombol |
| F2 | +50 Poin, +30 Ekonomi |
| PageDown | Tonggak waktu berikutnya (2030, 2040, 2045, 2050, 2060) |
| F3 / Shift+F3 | Event/bencana berikutnya / sebelumnya (berurutan, 13 kartu) |
| F4 | Tawaran pemerintah: rapuh, biasa, lancar bergantian |
| F5 / Shift+F5 | Akhiri KKN dengan fase ujian asli (desa bisa padam) / mode aman (desa tidak padam) |
| F6 / Shift+F6 | Alihkan 1 / 5 desa ke energi bersih di provinsi terpilih |
| F7 | Jadikan provinsi terpilih mandiri |
| F8 | Krisis penuh di provinsi terpilih |
| F9 / Shift+F9 / Ctrl+F9 | Resistensi biru +15 / merah +15 / reset 0 |
| F10 | Buka semua upgrade gratis |
| F11 / Shift+F11 | Benih di provinsi terpilih / rute pesawat semua pulau |
| F12 / Shift+F12 / Ctrl+F12 | Menang / kalah resistensi / kalah padam |
| Insert | Lompat 1 tahun (berhenti jika ada kartu) |
| Home | Naik tahap |
| End | Munculkan gelembung aksi |
| PageUp | Berita berikutnya (tes popup & ticker) |
