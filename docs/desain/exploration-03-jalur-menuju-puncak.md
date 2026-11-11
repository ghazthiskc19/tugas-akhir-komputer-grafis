# Exploration Challenge: Jalur Menuju Puncak

Status: ditetapkan pengguna pada 11 November 2026 sebagai exploration challenge untuk salah satu dari tiga artefak Level 1. Dokumen ini menetapkan desain; challenge belum diimplementasikan.

## Tujuan dan lokasi

Jalur Menuju Puncak berada di biome Rocky Highlands. Pemain menemukan rute naik melalui lereng dan jalur tebing, menghadapi musuh penjaga, lalu mencapai altar artefak di reruntuhan dataran tinggi. Hadiah eksplorasi mencakup artefak, viewpoint pulau, dan shortcut turun.

Artefak ini dapat diperoleh tanpa menyelesaikan kedua puzzle terlebih dahulu. Penyebutan artefak ketiga merupakan pembagian konten Level 1, bukan urutan pengambilan yang wajib.

## Tahapan rute

| Tahap | Aktivitas pemain | Encounter |
|---|---|---|
| Kaki bukit | Mengamati reruntuhan di atas dan menemukan jalur naik. Checkpoint tersedia sebelum rute tantangan. | Satu musuh melee pada area yang cukup luas untuk bertarung. |
| Jalur tebing | Mengikuti jalur berkelok dan melewati satu atau dua lompatan pendek. | Area lompatan memiliki ruang aman untuk membaca jarak dan melakukan traversal. |
| Pelataran penjaga | Memilih cara mendekati penjaga sebelum tanjakan terakhir. Jalur samping dan batu memberikan pilihan posisi serta perlindungan. | Satu musuh melee dan satu ranged. |
| Altar puncak | Mengambil artefak, melihat pemandangan, dan membuka shortcut menuju jalur utama. | Area istirahat setelah tantangan. |

## Navigasi dan combat

- Susunan batu, sisa anak tangga, vegetasi yang lebih renggang, serta bagian reruntuhan membantu pemain membaca arah rute.
- Jalur samping dapat membawa pemain ke posisi yang lebih menguntungkan atau ke viewpoint kecil.
- Encounter ditempatkan pada pelataran yang cukup lebar untuk movement, block, dan dodge.
- Musuh melee memberikan tekanan jarak dekat; ranged mendorong pemain memperhatikan posisi dan perlindungan.
- Syarat memperoleh artefak adalah mencapai altar. Pemain boleh melawan atau melewati musuh; pengambilan artefak tidak mensyaratkan semua penjaga dikalahkan.
- Baseline awal adalah maksimal dua musuh aktif bersamaan pada encounter rute ini. Angka tersebut perlu diuji melalui playtest.

Challenge ini memakai tipe musuh yang sudah direncanakan pada Level 1 dan tidak menambahkan miniboss atau tipe musuh baru.

## Checkpoint dan kegagalan

- Checkpoint kaki bukit tersedia sebelum bagian traversal dan encounter utama.
- Jatuh keluar area permainan atau mati mengembalikan pemain ke checkpoint rute yang aktif.
- Artefak yang terkumpul dan puzzle yang selesai tetap tersimpan sesuai aturan progres sesi.
- Musuh pada rute ini yang sudah dikalahkan tetap mati selama sesi, termasuk setelah pemain gagal dan respawn.
- Status musuh yang sudah dikalahkan dipertahankan agar kegagalan traversal tidak memaksa pengulangan seluruh combat.
- Aktivasi checkpoint belum ditetapkan sebagai sumber healing tambahan. Ketentuan HP penuh saat respawn mengikuti desain kegagalan umum.

Aturan musuh tetap mati ini berlaku untuk Jalur Menuju Puncak. Aturan reset encounter biasa di area lain belum ditetapkan. Boss memakai aturan retry berbasis snapshot yang dijelaskan pada [desain Penjaga Gerbang](boss-penjaga-gerbang.md).

## Puncak dan shortcut

Altar menjadi tujuan yang dapat dikenali dan menyediakan ruang mengambil artefak serta menikmati viewpoint pulau. Shortcut berupa jembatan pendek yang diaktifkan dari sisi puncak untuk kembali menuju jalur utama melalui rute yang lebih singkat.

Artefak yang sudah diambil tidak muncul kembali setelah respawn. Detail interaksi dan state shortcut yang belum dibuka akan dirinci saat implementasi.

## Procedural generation

Rute menggunakan modul traversal terkontrol. Lereng, jarak lompatan, ruang bertarung, dan akses altar harus divalidasi. Terrain serta dekorasi di sekitarnya dapat bervariasi berdasarkan seed tanpa merusak jalur wajib.

## Kriteria penerimaan

1. Pemain dapat menemukan rute menuju altar melalui petunjuk lingkungan yang terbaca dari kamera permainan.
2. Rute dapat diselesaikan tanpa memperoleh artefak dari kedua puzzle terlebih dahulu.
3. Lompatan dapat dilewati menggunakan kemampuan traversal pemain dan tidak memaksa pertarungan pada area sempit saat melompat.
4. Encounter awal serta pelataran penjaga mendukung baseline maksimal dua musuh aktif bersamaan.
5. Pemain dapat memperoleh artefak dengan mencapai altar tanpa syarat membunuh seluruh penjaga.
6. Jatuh atau mati mengembalikan pemain ke checkpoint aktif dengan progres sesi yang sesuai.
7. Musuh rute yang telah dikalahkan tidak muncul kembali setelah respawn selama sesi yang sama.
8. Shortcut dapat dibuka dari sisi puncak dan menyediakan rute kembali yang lebih singkat.
9. Setiap hasil generation yang diterima menyediakan akses valid ke checkpoint, rute naik, altar, dan shortcut.

## Detail produksi berikutnya

Ukuran rute, jarak lompatan, distribusi perlindungan, perilaku aggro/leash, penempatan checkpoint, tampilan altar, serta animasi shortcut mengikuti pengujian traversal, combat, dan keterbacaan kamera. Durasi challenge belum diberi target final.
