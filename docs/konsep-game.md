# Konsep The Lost Island

Status: konsolidasi keputusan desain yang telah tercatat. Dokumen ini belum menjadi GDD final dan tidak menyatakan seluruh sistem sudah diimplementasikan.

## Identitas

The Lost Island merupakan judul sementara untuk gim 3D exploration adventure dengan puzzle, traversal, dan combat. Kamera menggunakan Perspective dengan elevated third-person follow. Platform sasaran adalah PC, single-player, fully offline. Engine aktif adalah Godot 4.7.2 Standard dengan GDScript.

Pemain merupakan awak kapal yang terdampar setelah badai. Kapalnya rusak dan jalan menuju dermaga terlindung di sisi lain pulau ditutup oleh gerbang kuno. Penjaga Gerbang berupa golem batu dengan inti energi menjaga akses tersebut.

## Scope Level 1

Pengerjaan saat ini mencakup satu level pada satu pulau dengan elevasi moderat. Baseline area daratan yang dapat dimainkan adalah sekitar 250 × 250 meter, untuk diuji melalui prototype. Dunia dibagi menjadi Grassland, Forest, dan Rocky Highlands. Main path menghubungkan area penting, dengan jalur alternatif, hidden area, shortcut, dan landmark untuk orientasi.

Grassland menjadi area kedatangan dan pengenalan kontrol. Forest dan Rocky Highlands bercabang dari jalur penghubung. Gerbang menjadi landmark yang dapat terlihat dari beberapa lokasi. Shortcut mengurangi pengulangan perjalanan dari area objektif.

Pemain memperoleh tiga artefak melalui dua puzzle ringan dan satu exploration challenge. Urutan objektif fleksibel dengan arahan lingkungan. Ketiga artefak mengaktifkan boss di gerbang akhir. Kemenangan atas boss membuka gerbang dan menyelesaikan Level 1.

Campaign, level selection, dan save lintas level belum menjadi scope saat ini; yang dibangun hanya **Pulau 1**, sedangkan Pulau 2 dan 3 belum dibuat. Pengguna mengizinkan durasi permainan lebih panjang daripada usulan awal 15–20 menit; rentang tersebut tidak menjadi batas final. Durasi sesi ditentukan melalui playtest berdasarkan perjalanan, puzzle, encounter, dan boss. Luas pulau tidak digunakan sebagai pengganti pengukuran durasi atau kepadatan aktivitas. Target 5–10 menit pada draft historis juga tidak lagi menjadi acuan.

## Cerita dan penyampaian

Pulau merupakan bekas tempat penjagaan jalur pelayaran kuno. Tiga artefak berfungsi sebagai kunci energi yang tersebar di reruntuhan Grassland, instalasi energi Forest, dan menara pengamatan Rocky Highlands. Reruntuhan di puncak menjadi lokasi altar artefak exploration challenge.

Pemasangan ketiga artefak mengaktifkan kembali sistem gerbang beserta golem penjaganya. Golem masih menjalankan perintah lama untuk menolak penyusup. Pemain mengalahkannya agar dapat membuka gerbang dan mencapai dermaga.

Cerita disampaikan melalui pembukaan singkat, relief lingkungan, dan penutup. Penyampaian ini tidak membutuhkan NPC atau dialog panjang. Nama karakter pemain belum ditetapkan; arah penampilan dan senjata ditetapkan pada bagian berikut.

## Eksplorasi dan visual

Pemain bergerak dan melompat untuk melewati obstacle lingkungan. Visual menggunakan stylized low-poly, warna cerah, dan komposisi pemandangan yang mendukung eksplorasi.

### Arah karakter dan musuh — ditetapkan 20 November 2026

- Pemain adalah manusia awak kapal/petualang dengan pakaian ringan, bukan kesatria berzirah penuh. Senjata pemain adalah **pedang satu tangan**, mengikuti aturan satu senjata melee dan combo tiga hit yang telah disepakati.
- Musuh biasa adalah penjaga pulau kuno dalam satu keluarga visual: standard melee bersiluet ramping, heavy melee bertubuh lebih besar dengan senjata berat, dan ranged dengan senjata jarak jauh yang terbaca jelas.
- Boss tetap **Penjaga Gerbang**, golem batu dengan inti energi. Kontras petualang manusia dengan sistem pertahanan kuno menyatukan cerita, reruntuhan, puzzle energi, dan musuh.
- Gaya tetap stylized low-poly cerah. Pengguna lebih menyukai **KayKit/chibi** daripada kandidat non-chibi, tetapi prioritas pemilihan adalah **kelengkapan ekosistem asset online yang serasi**, bukan kemiripan satu model dengan concept art laporan. Proporsi gambar laporan tidak menjadi syarat mutlak model produksi.
- Pengadaan model mengandalkan sumber online. Penyesuaian material, mesh, aksesori, skala, dan perakitan modul dikerjakan agent bila diperlukan. Recolor/attachment/kitbash dibedakan dari remodel, re-rig, dan pembuatan animasi besar; kebutuhan kategori terakhir tetap dicatat sebagai risiko, bukan dijanjikan sebagai tweak ringan.
- **Keluarga inti ditetapkan pengguna:** KayKit Adventurers + Character Animations + Forest Nature + Dungeon Pack. Pelengkap online dicari untuk kebutuhan yang belum tertutup; bentuk sedikit berbeda boleh menjadi basis modifikasi agent. Pemilihan inti bukan bukti seluruh model/clip sudah tersedia atau lolos import, dan bukan persetujuan membeli tier berbayar.
- Pekerjaan aktif adalah menutup gap dengan sumber asset konkret dan rencana edit yang jelas, bukan memperbanyak katalog generik. Preferensi ini tidak otomatis mengganti penjaga kuno menjadi undead atau boss batu menjadi golem tulang. Gameplay, procedural terrain, retargeting dan perakitan puzzle tetap memerlukan implementasi serta verifikasi meskipun model dasarnya berasal dari online.
- **Kebijakan asset terkini (21 November 2026):** model yang mirip/cukup sudah memadai dan recolor diutamakan daripada ubah bentuk; bahan awal dari basis gratis yang sudah ter-import cukup untuk memulai, sehingga tidak ada download model atau paket berbayar yang wajib lagi. Gap nyata: retarget/aplikasi animasi minum dan boss, authoring wake/charge boss, serta kode (terrain procedural, puzzle, UI, perakitan scene). Rock Golem cukup dengan recolor + skala seragam + crystal attachment; shipwreck opsional. [Rencana Sumber Asset](implementation/ASSET_SOURCE_PLAN.md) dan [inventaris](implementation/ASSET_INVENTORY.md#audit-kecukupan-asset--21-november-2026-ambang-visual-dilonggarkan) memuat bukti dan status; hasil renderer, retarget, dan gameplay tetap belum terverifikasi. Pengadaan berbayar dan reproportion pada catatan 20 November bersifat historis. [Audit ekosistem](implementation/ASSET_ECOSYSTEM_AUDIT.md) dipertahankan sebagai dasar perbandingan.

Terrain memakai procedural mesh dengan variasi berdasarkan seed. Lokasi objective, puzzle, checkpoint, dan arena boss perlu dibentuk atau dipilih berdasarkan aturan keterjangkauan. Perubahan seed tidak boleh membuat progres wajib mustahil dicapai.

Kamera Perspective memakai elevated third-person follow dengan smooth damping, termasuk saat pemain melompat. Mouse tertangkap langsung memutar kamera (yaw 360°, pitch dibatasi); scroll mengatur zoom terbatas. WASD relatif kamera dan karakter menghadap arah gerak. Analog kanan juga memutar kamera. Kamera tidak otomatis mengikuti arah karakter/serangan dan tidak auto-mendekat karena obstacle. Occlusion pemain dan clipping kamera diterima; pemain mengatur sudut sendiri. Aturan lengkap ada pada [desain kamera](desain/kamera-perspective-follow.md).

Camera3D pada scene fondasi hanya dipakai untuk preview dan belum mewakili implementasi kamera gameplay yang disepakati. Cinemachine merupakan pilihan historis saat memakai Unity dan telah digantikan pendekatan camera rig native Godot.

## Puzzle pertama

**Pilar Simbol** telah ditetapkan sebagai puzzle pertama. Di reruntuhan Grassland, pemain membaca relief lalu mengaktifkan empat pilar bersimbol berbeda dalam urutan yang benar. Urutan benar membuka segel satu artefak; urutan salah mereset rangkaian tanpa damage atau kehilangan item.

Petunjuk tetap dapat dilihat, simbol dibedakan melalui bentuk, dan musuh tidak mengganggu pengerjaan puzzle. Status selesai bertahan setelah respawn selama sesi. Generator menempatkan satu modul reruntuhan yang terkontrol pada lokasi valid. Rincian aturan dan kriteria penerimaan tersedia pada [desain Pilar Simbol](desain/puzzle-01-pilar-simbol.md).

## Puzzle kedua

**Jalur Energi** telah ditetapkan sebagai puzzle kedua. Di reruntuhan Forest, pemain memutar tiga panel batu berukiran jalur lurus atau siku sebesar 90° per interaksi. Energi mengalir mengikuti sambungan dari kristal sumber; hubungan lengkap menuju altar membuka segel satu artefak.

Pemain bebas mencoba tanpa damage, timer, atau batas percobaan. Ukiran dan arah aliran membantu keterbacaan, sementara cahaya dan audio menunjukkan sambungan yang benar. Status selesai bertahan setelah respawn selama sesi. Modul ditempatkan secara terkontrol agar perubahan seed tidak merusak solusi. Rincian aturan dan kriteria penerimaan tersedia pada [desain Jalur Energi](desain/puzzle-02-jalur-energi.md).

## Exploration challenge

**Jalur Menuju Puncak** telah ditetapkan untuk artefak di Rocky Highlands. Pemain mencari rute naik menuju altar di dataran tinggi, melewati lereng dan lompatan pendek, serta menghadapi musuh penjaga. Checkpoint tersedia di kaki bukit. Encounter awal memakai satu melee; pelataran berikutnya memakai satu melee dan satu ranged dengan perlindungan serta jalur pendekatan samping.

Pemain boleh melawan atau melewati musuh, dan artefak dapat diambil tanpa menyelesaikan kedua puzzle terlebih dahulu. Musuh rute yang telah dikalahkan tetap mati selama sesi setelah pemain respawn. Puncak menyediakan artefak, viewpoint, dan jembatan shortcut yang dibuka dari sisi puncak untuk kembali ke jalur utama.

Rute menggunakan modul traversal terkontrol. Baseline maksimal dua musuh aktif bersamaan perlu diuji melalui playtest. Aturan lengkap tersedia pada [desain Jalur Menuju Puncak](desain/exploration-03-jalur-menuju-puncak.md).

## Combat

- Pemain menggunakan satu senjata melee yang menghadap arah karakter. Tidak ada aim ke titik mouse di dunia dan tidak ada lock-on.
- Attack memakai satu tombol dengan combo tiga hit: dua serangan cepat dan satu finisher.
- Input lanjutan harus berada pada timing window. Early input tidak disimpan dan hold-to-auto-combo tidak dipilih.
- Animasi attack yang sudah dimulai diselesaikan sebelum block atau dodge. Movement tetap full speed tanpa slowdown; animasi kaki idle/jalan berjalan bersamaan dengan swing badan atas.
- Rotasi tetap bebas selama serangan mengikuti arah gerak; hitbox mengikuti arah hadap karakter terkini, bukan arah saat swing dimulai.
- Attack dan combo tidak memakai stamina.
- Musuh mencakup dua tipe melee dan satu tipe ranged, ditambah satu boss akhir.

Senjata pemain telah ditetapkan sebagai pedang satu tangan. Model spesifik, nama musuh, parameter damage, serta angka timing belum ditetapkan.

## Musuh biasa

| Tipe | Perilaku yang ditetapkan |
|---|---|
| Melee biasa | Combo dua pukulan; tiap pukulan ber-telegraph baru, recovery akhir terbatas. |
| Heavy melee | Lebih lambat, tetapi pendekatan dipercepat lalu sapuan lebar tertunda dengan telegraph panjang dan recovery terbatas. |
| Ranged | Bergerak sambil menembakkan semburan tiga proyektil lurus dengan bidikan terkunci terlambat; cover dan LOS memblokir. |

Proyektil ranged tidak homing. **Kontrak baru (25 Nov 2026):** musuh biasa memakai kombinasi serangan (rangkaian beberapa pukulan atau tembakan) dengan varian timing agar lebih mengancam tanpa menaikkan HP; heavy tetap lebih lambat dengan telegraph panjang. Angka persis ada di `ARCHETYPES` (`scripts/enemies/enemy.gd`), belum final dan menunggu playtest. Rancangan awal "satu swing singkat" dan "heavy tanpa combo" kini historis. Istilah ini merupakan tipe perilaku, bukan nama karakter final. Detection range, chase/leash, stagger, serta distribusi ketiga tipe di seluruh pulau masih memerlukan rincian produksi dan playtest.

## Boss akhir

**Penjaga Gerbang** telah ditetapkan sebagai boss akhir. Setelah tiga artefak dipasang, pemain berinteraksi untuk membangunkan golem batu dengan inti energi di pelataran gerbang. Arena rata menyediakan ruang menghindar, checkpoint sebelum arena, dan batas yang jelas. Pertarungan tidak menambahkan musuh lain.

Boss memakai sapuan lengan, hantaman tanah, dan terjangan lurus dengan telegraph yang sesuai area damage. Target serangan dikunci menjelang pelepasan dan tidak mengikuti pemain. **Kontrak baru (25 Nov 2026):** pada HP di atas 50% (fase 1) boss merangkai **dua pukulan beruntun**; pada HP 50% atau kurang (fase 2) **dua atau tiga pukulan (dibatasi, tidak selalu tiga)**, dengan windup cepat/tertunda, telegraph baru per pukulan, recovery penuh di akhir rangkaian, dan pemilihan serangan sadar-jarak. HP (420), damage dan ambang 50% tidak berubah; kesulitan naik lewat rangkaian dan timing. Recovery akhir memungkinkan combo tiga hit jika posisi serta timing pemain sesuai. (Rancangan lama: satu serangan lalu recovery; kini historis.) Uji menunggu bukti parent.

Retry menggunakan snapshot HP, stamina, dan jumlah potion sebelum pertarungan pertama. Kegagalan mengembalikan resource pemain ke nilai snapshot dan mereset boss, sementara progres pulau tetap tersimpan. Kemenangan membuka gerbang; melewati gerbang menyelesaikan Level 1. Aturan lengkap tersedia pada [desain Penjaga Gerbang](desain/boss-penjaga-gerbang.md).

## Defense dan resource

Block dan dodge menggunakan satu pool stamina. Block mengurangi damage dari semua arah untuk melee dan proyektil serta menguras stamina selama ditahan. **Kontrak baru (25 Nov 2026):** tiap hit yang diblok juga memakai stamina `max(8, damage × 0,8)`; bila stamina tidak cukup terjadi guard break dan damage penuh masuk, bila terbayar pengurangan omni-arah 25% tetap berlaku. Dodge memakai biaya tetap saat dimulai dan memberikan i-frames singkat. Stamina beregenerasi setelah jeda singkat sejak berhenti block atau dodge. Jika stamina tidak mencukupi, aksi defense ditolak; movement dan attack tetap tersedia.

HP ditampilkan dengan bar dan angka. Potion healing terbatas ditemukan di dunia atau dari drop musuh, disimpan, lalu digunakan manual. Besaran HP, kapasitas healing, drop rate, dan angka stamina masih memerlukan baseline playtesting.

Penggunaan potion memiliki animasi minum yang batal jika pemain terkena serangan. HP pulih dan jumlah potion berkurang hanya saat animasi selesai. Jika animasi terinterupsi, pemain tidak mendapat healing dan potion belum terpakai. Pemain dapat berjalan dengan kecepatan berkurang selama minum, tetapi tidak dapat menyerang bersamaan. Durasi minum serta interaksi dengan block/dodge dan serangan yang diblock dirinci saat prototype.

## Kegagalan dan checkpoint

Saat eksplorasi biasa, mati mengembalikan pemain ke checkpoint terakhir dengan HP penuh. Artefak yang terkumpul dan puzzle yang selesai dipertahankan selama sesi. Healing yang tersisa tetap dimiliki dan tidak bertambah karena respawn; item yang telah digunakan tidak otomatis dikembalikan.

Retry boss menggunakan pengecualian snapshot: HP, stamina, dan jumlah potion dikembalikan persis ke kondisi sebelum pertarungan pertama. Snapshot tidak memberikan healing gratis dan tidak diperbarui oleh percobaan gagal. Pemulihan menetapkan jumlah potion ke nilai snapshot agar tidak terjadi penggandaan. Boss kembali ke HP penuh dan fase pertama. Artefak, puzzle, shortcut, dan progres eksplorasi tetap tersimpan; pemasangan artefak serta animasi pembuka tidak diulang. Setelah menang, resource yang tersisa dari percobaan berhasil dipertahankan.

Aktivasi checkpoint belum ditetapkan sebagai sumber healing. Pada Jalur Menuju Puncak, musuh yang telah dikalahkan tetap mati selama sesi. Aturan reset musuh di area lain, proteksi respawn dan jumlah checkpoint keseluruhan belum final.

### Save lokal dan Continue (diimplementasikan untuk Pulau 1)

Progres Pulau 1 disimpan sebagai JSON lokal `user://island_save.json`: autosave tiap 5 detik dan pada milestone, serta simpan manual dari menu jeda. **Continue** memulihkan dari checkpoint dengan HP, stamina, dan potion persis seperti tersimpan. Bila save dibuat setelah boss dimulai, Continue memulihkan snapshot retry boss yang asli. Menu awal tidak menimpa save; **New Run** meminta konfirmasi sebelum menggantinya. Save bersifat lokal per perangkat dan belum mencakup lintas level.

### Layout prosedural (perilaku saat ini)

Seed menggeser secara deterministik akar modul, jalan, 3–5 pack encounter, potion, checkpoint, biome, dan dermaga, semuanya sejajar sumbu. Puzzle internal dan boss tetap authored/fixed agar solusi dan aturan tidak berubah. Setiap biome memiliki landmark dan sign untuk orientasi; serangan yang mengenai target memberi hitmarker dan SFX. Pernyataan lama tentang layout tetap atau tanpa save adalah riwayat.

Modul Pilar Simbol dan Jalur Energi bertukar sisi barat–timur secara deterministik per seed (terukur agen: 103 bertukar / 97 normal pada 200 seed, tanpa kegagalan generate); rute, viewpoint, dan biome mengikuti sisi sebenarnya. Checkpoint puncak dan boss memakai offset authored (puncak +(−4, 18), boss +(−10, 12,5)). Menutup jendela game (X/Alt+F4) memakai jalur simpan-lalu-keluar yang sama dengan menu.

## Keputusan untuk finalisasi

1. Prototype kamera mouse-look, movement relatif kamera, dan zoom untuk menguji framing; arah melee mengikuti karakter.
2. Blockout pulau dengan baseline 250 × 250 meter untuk mengukur panjang rute, kepadatan aktivitas, distribusi encounter, dan durasi sesi.
3. Rincian kontrol, perilaku chase/leash dan stagger musuh, serta interaksi potion dengan aksi defense.
4. Pilihan model spesifik untuk petualang manusia dengan pedang satu tangan dan keluarga penjaga kuno, serta teks pembukaan/penutup sesuai lore yang telah ditetapkan. Nama karakter pemain belum final; arah visual tidak menunggu nama tersebut.

Angka movement, damage, HP, stamina, dan timing dapat disusun sebagai baseline yang diberi label lalu diuji melalui prototype. Angka baru tidak dianggap sebagai keputusan lama yang sudah disepakati.

## Status implementasi

Gameplay Level 1 pada dokumen ini sudah diimplementasikan untuk **Pulau 1** (lihat README dan Implementation Tracker untuk status dan bukti). Pulau 2 dan 3 belum dibuat. Belum ada review subjektif manusia untuk kontrol/audio, uji gamepad fisik, atau uji di komputer anggota lain. Rincian dan asal keputusan dipertahankan pada [catatan brainstorming](brainstorming/konteks-lanjutan-the-lost-island.md).
