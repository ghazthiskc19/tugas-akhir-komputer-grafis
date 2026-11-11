# Puzzle 02: Jalur Energi

Status: ditetapkan pengguna pada 11 November 2026 sebagai puzzle kedua Level 1. Dokumen ini menetapkan desain; sistem puzzle belum diimplementasikan.

## Tujuan dan lokasi

Jalur Energi merupakan puzzle penyambungan jalur di reruntuhan Forest. Pemain memutar tiga panel batu untuk menghubungkan energi dari kristal sumber menuju altar artefak. Puzzle ini menggunakan pengamatan hubungan ruang dan manipulasi orientasi objek.

Target awal penyelesaian adalah 15–45 detik setelah mekanik dipahami. Durasi tersebut perlu diperiksa melalui playtest.

## Elemen

- Tiga panel batu putar dengan ukiran jalur lurus atau siku.
- Satu kristal sumber dan satu altar tujuan dengan posisi tetap dalam modul.
- Satu artefak yang terkunci oleh segel pada altar.
- Feedback arah aliran energi, cahaya, dan audio untuk menunjukkan sambungan serta penyelesaian.

Ukiran dan arah aliran harus cukup untuk membaca sambungan. Warna mendukung keterbacaan, sehingga pemain tidak perlu mengandalkan warna sebagai satu-satunya petunjuk.

## Alur interaksi

1. Pemain menemukan reruntuhan dan kristal sumber yang menyala.
2. Pemain mengamati jalur pada tiga panel serta lokasi altar tujuan.
3. Pemain mendekati panel dan menekan tombol interaksi untuk memutarnya 90°.
4. Energi mengalir sejauh jalur yang sudah tersambung dari sumber.
5. Saat sumber terhubung ke altar melalui jalur yang sesuai, segel terbuka dan artefak dapat diperoleh.

Pemain bebas mencoba susunan panel. Tidak ada damage, timer, atau batas percobaan. Susunan yang belum menyambungkan sumber dan tujuan tidak membuka segel; feedback aliran membantu pemain menentukan panel yang perlu diputar.

## Aturan dunia dan progres

- Modul memiliki tiga panel putar serta titik sumber dan tujuan yang tetap.
- Sambungan yang benar langsung mendapat feedback visual dan audio.
- Puzzle yang selesai tetap terbuka setelah pemain mati dan respawn dalam sesi yang sama.
- Status puzzle selesai dan artefak terkumpul dicatat secara terpisah agar artefak yang belum diambil tetap tersedia setelah respawn.
- Reruntuhan dibuat sebagai modul dengan susunan internal terkontrol dan ditempatkan pada lokasi valid oleh generator pulau.
- Setiap susunan awal yang digunakan harus dapat diselesaikan. Perubahan seed tidak boleh merusak solusi, keterbacaan, atau akses ke panel dan artefak.

## Batas implementasi

Energi divisualisasikan mengikuti sambungan panel. Validasi cukup memeriksa koneksi antarjalur dari sumber ke tujuan. Desain ini tidak membutuhkan simulasi cahaya fisik, pantulan cermin, atau ray tracing.

## Kriteria penerimaan

1. Tiga panel dapat diputar 90° per interaksi.
2. Bentuk jalur, sumber, dan tujuan terbaca melalui kamera permainan.
3. Feedback aliran sesuai dengan sambungan yang sudah terhubung dari sumber.
4. Segel hanya terbuka ketika sumber terhubung ke altar.
5. Pemain dapat mencoba ulang tanpa penalti damage, timer, atau batas percobaan.
6. Respawn mempertahankan status puzzle selesai dan progres artefak yang sudah diambil.
7. Modul tetap dapat diselesaikan dan diakses pada setiap hasil generation yang dinyatakan valid.

## Detail produksi berikutnya

Pola jalur spesifik, orientasi awal panel, arah putaran, jarak interaksi, tombol, animasi, suara, dan bentuk segel belum dirinci. Detail tersebut mengikuti keterbacaan serta playtest tanpa mengubah aturan inti yang telah ditetapkan.

Exploration challenge untuk memperoleh artefak ketiga belum ditetapkan. Puzzle pertama mengikuti [desain Pilar Simbol](puzzle-01-pilar-simbol.md).
