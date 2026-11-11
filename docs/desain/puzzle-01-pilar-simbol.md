# Puzzle 01: Pilar Simbol

Status: ditetapkan pengguna pada 11 November 2026 sebagai puzzle pertama Level 1. Dokumen ini menetapkan desain; sistem puzzle belum diimplementasikan.

## Tujuan dan lokasi

Pilar Simbol merupakan puzzle observasi lingkungan di sebuah reruntuhan kecil pada biome Grassland. Pemain mengaktifkan empat pilar dalam urutan yang ditunjukkan oleh relief batu untuk membuka segel satu artefak.

Puzzle ini memperkenalkan interaksi dengan objek dan pembacaan petunjuk lingkungan. Target awal penyelesaian adalah 15–45 detik setelah petunjuk dipahami; durasinya perlu diperiksa melalui playtest.

## Elemen

- Empat pilar dengan simbol yang berbeda secara bentuk.
- Relief batu di dekat pintu masuk reruntuhan, menampilkan urutan simbol yang benar.
- Satu artefak di bagian tengah reruntuhan yang masih terkunci oleh segel.
- Feedback cahaya dan audio saat pilar diaktifkan, saat urutan salah, dan ketika puzzle selesai.

Warna dapat mendukung feedback, tetapi bentuk simbol harus cukup untuk membedakan keempat pilar. Petunjuk tetap tersedia selama pengerjaan puzzle dan dapat dilihat kembali.

## Alur interaksi

1. Pemain menemukan reruntuhan dan mengamati relief.
2. Pemain mendekati pilar yang sesuai dan menekan tombol interaksi.
3. Pilar yang dipilih menyala dan mengeluarkan suara singkat.
4. Pemain melanjutkan aktivasi hingga empat simbol membentuk urutan yang benar.
5. Segel terbuka dan artefak dapat diperoleh.

Jika urutan salah, cahaya pilar padam dan rangkaian aktivasi diulang dari awal. Kesalahan tidak memberikan damage, mengurangi item, atau memaksakan cooldown panjang.

## Aturan dunia dan progres

- Musuh tidak mengganggu pemain selama mengerjakan puzzle pembuka ini.
- Setelah puzzle selesai, segel tetap terbuka ketika pemain mati dan respawn dalam sesi yang sama.
- Status puzzle selesai dan status artefak terkumpul dicatat secara terpisah agar artefak yang belum diambil tetap tersedia setelah respawn.
- Area puzzle dibuat sebagai satu modul reruntuhan dengan susunan internal yang terkontrol.
- Generator pulau menempatkan modul pada area yang dapat dijangkau, dengan ruang interaksi dan pembacaan petunjuk yang memadai.
- Variasi seed tidak boleh membuat petunjuk tidak cocok dengan solusi atau memutus akses menuju pilar dan artefak.

## Kriteria penerimaan

1. Keempat simbol dapat dibedakan berdasarkan bentuk dan terbaca melalui kamera permainan.
2. Relief menampilkan satu urutan solusi yang cocok dengan pilar yang tersedia.
3. Urutan benar membuka segel artefak dan menghasilkan feedback penyelesaian.
4. Urutan salah mereset rangkaian aktivasi tanpa penalti damage atau item.
5. Pemain dapat kembali memeriksa relief sebelum puzzle selesai.
6. Respawn mempertahankan status puzzle yang sudah selesai dan progres artefak yang sudah diambil.
7. Modul dan semua interaksinya dapat diakses pada setiap hasil generation yang dinyatakan valid.
8. Area puzzle terlindung dari gangguan encounter musuh saat pemain berinteraksi.

## Detail produksi berikutnya

Bentuk keempat simbol, urutan spesifik, jarak interaksi, tombol, durasi animasi, suara, dan bentuk segel belum dirinci. Penentuan detail tersebut mengikuti keterbacaan visual dan playtest tanpa mengubah aturan inti di atas.

Puzzle kedua telah ditetapkan sebagai [Jalur Energi](puzzle-02-jalur-energi.md), menggunakan rotasi panel dan penyambungan jalur. Exploration challenge untuk artefak lainnya mengikuti [desain Jalur Menuju Puncak](exploration-03-jalur-menuju-puncak.md).
