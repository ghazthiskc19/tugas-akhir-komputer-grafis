# Kamera Perspective Follow

Status: kontrol mouse-look dan scroll zoom diterima pengguna setelah review `scenes/tests/third_person_lab.tscn`; auto-zoom obstacle dimatikan. Iterasi berikutnya hanya melee satu hit ke dummy, tanpa combo/stamina/AI. Dokumen ini menggantikan aturan top-down, MMB-hold dan mouse-world aiming sebelumnya.

## Posisi dan proyeksi

Kamera memakai proyeksi Perspective dengan elevated third-person follow. Jarak dan ketinggian kamera harus memperlihatkan karakter, jalur di sekitarnya, musuh, serta telegraph boss. Framing tidak terlalu dekat ke bahu karakter agar puzzle, traversal, dan kelompok musuh tetap terbaca.

Kamera mengikuti perpindahan posisi pemain dengan smooth damping. Perubahan ketinggian saat melompat diikuti secara halus agar lompatan tidak menghasilkan hentakan kamera. Rotasi kamera hanya berubah oleh mouse-look atau right stick; arah karakter maupun serangan tidak memutarnya.

## Kontrol aktif: mouse-look, gerak, dan zoom

- Mouse selalu tertangkap (captured) selama arena berjalan. Gerakan mouse langsung memutar kamera: yaw bebas 360°, pitch dibatasi `20°–65°`, sensitivitas `0,003 rad/pixel`. Tidak ada tombol tengah mouse (MMB) dan tidak ada mode orbit terpisah.
- **WASD relatif kamera**: W maju, S mundur ke arah kamera, A/D menyamping, sesuai arah pandang kamera. Karakter berputar menghadap arah gerak termasuk S, yaitu berbalik menghadap kamera; kamera tidak ikut berputar.
- **Scroll zoom**: roda mouse mengubah panjang offset kamera, langkah `1 m` per notch. Awal `11,4 m`, minimum `4 m`, maksimum `14 m`; obstacle tidak mengubah jarak tersebut.
- **Esc** menjeda/melanjutkan arena nyata; saat jeda cursor terlihat dan tombol Lanjutkan tersedia. Kehilangan fokus jendela juga menjeda tanpa menangkap ulang mouse otomatis; lanjutkan secara eksplisit lewat tombol atau Esc.
- Analog kanan tetap mengatur yaw/pitch (deadzone radial `0,2`, kecepatan penuh `2 rad/s`). Mapping gamepad lainnya belum dirinci.
- **Arah melee (rencana)**: serangan melee kelak menghadap arah karakter. Tidak ada aim ke titik dunia di bawah mouse dan tidak ada lock-on. Arah dikunci per hit sesuai aturan combat; detail input attack ditentukan saat combat dikerjakan setelah izin pengguna.

Mouse-look sebelumnya (MMB-hold orbit dan mouse-world aiming) sudah digantikan; lihat bagian baseline historis di bawah.

## Collision

**Revisi setelah review mouse-look:** auto-mendekat karena penghalang dimatikan pada `third_person_lab.tscn`. Jarak kamera ditentukan scroll, bukan obstruction. Pengguna menerima pemain tertutup obstacle dan kamera menembus geometri; sudut pandang diatur manual dengan mouse. Implementasi collision lama hanya dipertahankan pada lab pembanding, bukan perilaku gameplay aktif.

Framing tetap perlu diuji pada lereng, jalur tebing, reruntuhan puzzle dan arena boss dengan sudut kamera yang diatur pemain.

## Kriteria penerimaan

1. Kamera gameplay menggunakan Perspective dan mengikuti posisi pemain dengan framing elevated third-person.
2. Pergerakan dan lompatan pemain tidak menghasilkan perpindahan kamera yang menghentak.
3. Perubahan arah serangan karakter tidak otomatis memutar kamera.
4. Mouse yang tertangkap memutar yaw 360° tanpa tombol tambahan; pitch dibatasi `20°–65°`.
5. WASD bergerak relatif kamera; karakter menghadap arah gerak (S berbalik menghadap kamera) tanpa memutar kamera.
6. Scroll mengubah jarak kamera dalam rentang `4–14 m` dengan langkah `1 m`; analog kanan dapat memutar kamera.
7. Obstacle tidak mengubah jarak kamera; scroll tetap bekerja. Occlusion dan clipping geometri diterima pada baseline ini.
8. Simbol puzzle, jarak lompatan, posisi musuh, dan telegraph boss terbaca melalui framing kamera.

## Detail produksi berikutnya

FOV, framing, damping, dan collision margin tetap baseline prototype yang ditentukan lewat review. Nilai zoom `11,4/4/14/1 m`, pitch `20°–65°`, dan sensitivitas `0,003` adalah keputusan yang dipertahankan; kenyamanan masih perlu review pengguna.

## Baseline historis I06–I08 (superseded)

Bagian ini mencatat bukti prototype lama di `aiming_lab.tscn` (MMB orbit dan mouse-world aiming). **Bukan instruksi kontrol saat ini**; kontrol aktif ada di bagian di atas. Angka collision dan follow di bawah masih berlaku kecuali disebut sebaliknya.

- Follow: FOV 50°, offset awal `(0, 7, 9)`, focus height 1 m, damping horizontal `8/s` dan vertikal `5/s`.
- Orbit (superseded): MMB-hold, sensitivitas `0,003 rad/pixel`, yaw bebas, pitch `20°–65°`. Release/Esc/focus loss melepas capture dan memulihkan posisi cursor; fokus kembali tidak menangkap ulang. Sensitivitas dan batas pitch dipertahankan pada kontrol aktif.
- Right stick: deadzone radial `0,2`, rescale di luar deadzone, kecepatan penuh `2 rad/s`. Diuji dengan event sintetis, bukan perangkat fisik.
- Collision: sphere radius `0,25 m`, margin `0,1 m`, near plane `0,1 m`; mask world `1`, exclude RID pemain. Fokus, orbit, cast dan penempatan memakai langkah fisika yang sama agar arah baru tidak memakai batas collision lama. Jarak langsung memendek, kembali dengan damping `4/s`. Fokus yang overlap dicari ulang menuju target; bila seluruh lintasan fokus gagal, kamera ditahan pada posisi terakhir. Framing sangat dekat belum memakai character fade.
- Aiming (superseded, dihapus): ray ke world dengan penanda merah `#930031`, fallback bidang kaki dengan cap `50 m`, dan model Rogue berputar terpisah dari arah WASD. Digantikan oleh karakter menghadap arah gerak; tidak ada mouse-world aim.

Bukti runtime: [collision](../implementation/evidence/i07-blocked.png) dan [hit platform 0,8 m](../implementation/evidence/i08-surface.png). Cast dan aim diuji pada arena kotak; slope, canopy, cliff, boss dan input attack saat orbit belum bisa dinyatakan lolos. Kamera collision mengikuti physics tick; kenyamanan pada monitor refresh tinggi masih perlu review.
