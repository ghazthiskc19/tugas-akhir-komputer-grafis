# Kamera Perspective Follow

Status: ditetapkan pengguna pada 11 November 2026. Dokumen ini menggantikan konsep kamera top-down sebelumnya. Prototype I05–I08 tersedia; batch orbit/collision/aiming menunggu review pengguna di `scenes/tests/aiming_lab.tscn`. Combat belum dibuat.

## Posisi dan proyeksi

Kamera memakai proyeksi Perspective dengan elevated third-person follow. Jarak dan ketinggian kamera harus memperlihatkan karakter, jalur di sekitarnya, musuh, serta telegraph boss. Framing tidak terlalu dekat ke bahu karakter agar puzzle, traversal, dan kelompok musuh tetap terbaca.

Kamera mengikuti perpindahan posisi pemain dengan smooth damping. Perubahan ketinggian saat melompat diikuti secara halus agar lompatan tidak menghasilkan hentakan kamera. Rotasi kamera tidak otomatis mengikuti perubahan arah serangan karakter.

## Orbit dan aiming

- Saat tombol tengah mouse tidak ditahan, mouse digunakan untuk mengarahkan serangan ke posisi di dunia permainan.
- Menahan tombol tengah mouse mengaktifkan orbit; melepasnya mengembalikan mouse ke fungsi aiming.
- Orbit horizontal mendukung rotasi 360 derajat.
- Orbit vertikal dibatasi agar kamera tidak terbalik atau masuk ke tanah.
- Analog kanan digunakan untuk mengatur orbit. Mapping kontrol gamepad lainnya belum dirinci.

Mode orbit harus memiliki pengelolaan input yang jelas agar gerakan mouse tidak mengubah kamera dan aiming secara tidak sengaja pada saat yang sama. Prioritas input attack selama orbit serta perilaku cursor saat pergantian mode dirinci dan diuji saat prototype. Mouse-world aiming tetap menjadi aturan combat yang dipertahankan.

## Collision

Ketika ada penghalang di antara pemain dan posisi kamera yang diinginkan, kamera mendekat ke pemain agar tidak menembus tembok atau objek lingkungan. Setelah jalur kamera kembali terbuka, kamera kembali ke jarak semula secara mulus.

Collision perlu diuji pada lereng, jalur tebing, reruntuhan puzzle, dan arena boss. Perubahan jarak kamera tidak boleh membuat petunjuk atau serangan boss kehilangan keterbacaan.

## Kriteria penerimaan

1. Kamera gameplay menggunakan Perspective dan mengikuti posisi pemain dengan framing elevated third-person.
2. Pergerakan dan lompatan pemain tidak menghasilkan perpindahan kamera yang menghentak.
3. Perubahan arah serangan karakter tidak otomatis memutar kamera.
4. Orbit horizontal 360 derajat bekerja saat tombol tengah mouse ditahan; melepas tombol mengembalikan kontrol mouse ke aiming.
5. Orbit vertikal memiliki batas yang menjaga orientasi kamera dan mencegah posisi di bawah tanah.
6. Analog kanan dapat mengatur orbit.
7. Kamera mendekat ketika terhalang, tidak menembus penghalang, dan kembali secara mulus ketika ruang terbuka.
8. Simbol puzzle, jarak lompatan, posisi musuh, dan telegraph boss terbaca melalui framing kamera.

## Detail produksi berikutnya

FOV, jarak dan ketinggian follow, batas pitch, sensitivitas orbit, damping, collision margin, dan perilaku input selama orbit ditentukan melalui prototype. Camera3D pada scene fondasi tetap merupakan preview sampai sistem ini diimplementasikan.

## Baseline prototype I06–I08

- Follow: FOV 50°, offset awal `(0, 7, 9)`, focus height 1 m, damping horizontal `8/s` dan vertikal `5/s`.
- Orbit: MMB-hold, sensitivitas `0,003 rad/pixel`, yaw bebas, pitch `20°–65°`. Release/Esc/focus loss melepas capture dan memulihkan posisi cursor; fokus kembali tidak menangkap ulang.
- Right stick: deadzone radial `0,2`, rescale di luar deadzone, kecepatan penuh `2 rad/s`. Diuji dengan event sintetis, bukan perangkat fisik.
- Collision: sphere radius `0,25 m`, margin `0,1 m`, near plane `0,1 m`; mask world `1`, exclude RID pemain. Fokus, orbit, cast dan penempatan memakai langkah fisika yang sama agar arah baru tidak memakai batas collision lama. Jarak langsung memendek, kembali dengan damping `4/s`. Fokus yang overlap dicari ulang menuju target; bila seluruh lintasan fokus gagal, kamera ditahan pada posisi terakhir. Framing sangat dekat belum memakai character fade.
- Aiming: ray ke world dengan exclude pemain, penanda merah `#930031` pada hit + normal `0,03 m`; hanya model Rogue yang berputar, bukan body/arah WASD. Saat orbit atau kehilangan fokus, arah dibekukan dan penanda disembunyikan. Tidak ada serangan yang dipicu.
- Cursor miss: fallback bidang setinggi kaki, cap jarak horizontal `50 m`; ray paralel/ke atas atau bidang di belakang kamera tidak membuat target baru dan mempertahankan heading terakhir.

Bukti runtime: [collision](../implementation/evidence/i07-blocked.png) dan [hit platform 0,8 m](../implementation/evidence/i08-surface.png). Cast dan aim diuji pada arena kotak; slope, canopy, cliff, boss dan input attack saat orbit belum bisa dinyatakan lolos. Kamera collision mengikuti physics tick; kenyamanan pada monitor refresh tinggi masih perlu review.
