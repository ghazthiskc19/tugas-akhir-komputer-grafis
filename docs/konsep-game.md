# Konsep The Lost Island

Status: konsolidasi keputusan desain yang telah tercatat. Dokumen ini belum menjadi GDD final dan tidak menyatakan seluruh sistem sudah diimplementasikan.

## Identitas

The Lost Island merupakan judul sementara untuk gim 3D top-down exploration adventure dengan puzzle, traversal, dan combat. Platform sasaran adalah PC, single-player, fully offline. Engine aktif adalah Godot 4.7.2 Standard dengan GDScript.

Premis awal menempatkan pemain di pulau misterius dengan gerbang kuno sebagai jalan keluar. Penjaga Gerbang berupa golem batu dengan inti energi menjaga akses keluar. Cerita, identitas karakter pemain, serta asal-usul artefak dan boss belum dirinci.

## Scope Level 1

Pengerjaan saat ini mencakup satu level pada satu pulau besar dengan elevasi moderat. Dunia dibagi menjadi Grassland, Forest, dan Rocky Highlands. Main path menghubungkan area penting, dengan jalur alternatif, hidden area, shortcut, dan landmark untuk orientasi.

Pemain memperoleh tiga artefak melalui dua puzzle ringan dan satu exploration challenge. Urutan objektif fleksibel dengan arahan lingkungan. Ketiga artefak mengaktifkan boss di gerbang akhir. Kemenangan atas boss membuka gerbang dan menyelesaikan Level 1.

Campaign, level selection, dan save lintas level belum menjadi scope saat ini. Target 5–10 menit pada draft awal merupakan usulan lama yang belum diuji setelah penambahan combat dan boss.

## Eksplorasi dan visual

Pemain bergerak dan melompat untuk melewati obstacle lingkungan. Visual menggunakan stylized low-poly, warna cerah, dan komposisi pemandangan yang mendukung eksplorasi.

Terrain memakai procedural mesh dengan variasi berdasarkan seed. Lokasi objective, puzzle, checkpoint, dan arena boss perlu dibentuk atau dipilih berdasarkan aturan keterjangkauan. Perubahan seed tidak boleh membuat progres wajib mustahil dicapai.

Proyeksi kamera belum final. Camera3D pada scene fondasi hanya dipakai untuk preview. Cinemachine merupakan pilihan historis saat memakai Unity dan telah digantikan pendekatan camera rig native Godot.

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

- Pemain menggunakan satu senjata melee, diarahkan oleh posisi mouse di dunia permainan.
- Attack memakai satu tombol dengan combo tiga hit: dua serangan cepat dan satu finisher.
- Input lanjutan harus berada pada timing window. Early input tidak disimpan dan hold-to-auto-combo tidak dipilih.
- Animasi attack yang sudah dimulai diselesaikan sebelum block atau dodge. Movement tetap tersedia dengan kecepatan berkurang.
- Arah dikunci selama satu hit; arah baru dibaca saat hit selanjutnya dimulai.
- Attack dan combo tidak memakai stamina.
- Musuh mencakup dua tipe melee dan satu tipe ranged, ditambah satu boss akhir.

Jenis senjata, identitas musuh biasa, parameter damage, serta angka timing belum ditetapkan. Agile Melee dan Heavy Melee merupakan elaborasi asisten pada catatan sumber, bukan nama karakter final.

## Boss akhir

**Penjaga Gerbang** telah ditetapkan sebagai boss akhir. Setelah tiga artefak dipasang, pemain berinteraksi untuk membangunkan golem batu dengan inti energi di pelataran gerbang. Arena rata menyediakan ruang menghindar, checkpoint sebelum arena, dan batas yang jelas. Pertarungan tidak menambahkan musuh lain.

Boss memakai sapuan lengan, hantaman tanah, dan terjangan lurus dengan telegraph yang sesuai area damage. Target serangan dikunci menjelang pelepasan. Pada HP di atas 50%, boss menyerang sekali lalu recovery; pada HP 50% atau kurang, boss sesekali merangkai dua serangan. Telegraph dan timing dasar tetap dipertahankan. Recovery hantaman memungkinkan combo tiga hit jika posisi serta timing pemain sesuai.

Retry menggunakan snapshot HP, stamina, dan jumlah potion sebelum pertarungan pertama. Kegagalan mengembalikan resource pemain ke nilai snapshot dan mereset boss, sementara progres pulau tetap tersimpan. Kemenangan membuka gerbang; melewati gerbang menyelesaikan Level 1. Aturan lengkap tersedia pada [desain Penjaga Gerbang](desain/boss-penjaga-gerbang.md).

## Defense dan resource

Block dan dodge menggunakan satu pool stamina. Block mengurangi damage dari semua arah untuk melee dan proyektil, serta menguras stamina selama ditahan. Dodge memakai biaya tetap saat dimulai dan memberikan i-frames singkat. Stamina beregenerasi setelah jeda singkat sejak berhenti block atau dodge. Jika stamina tidak mencukupi, aksi defense ditolak; movement dan attack tetap tersedia.

HP ditampilkan dengan bar dan angka. Healing terbatas ditemukan di dunia atau dari drop musuh, disimpan, lalu digunakan manual. Besaran HP, kapasitas healing, drop rate, dan angka stamina masih memerlukan baseline playtesting.

## Kegagalan dan checkpoint

Saat eksplorasi biasa, mati mengembalikan pemain ke checkpoint terakhir dengan HP penuh. Artefak yang terkumpul dan puzzle yang selesai dipertahankan selama sesi. Healing yang tersisa tetap dimiliki dan tidak bertambah karena respawn; item yang telah digunakan tidak otomatis dikembalikan.

Retry boss menggunakan pengecualian snapshot: HP, stamina, dan jumlah potion dikembalikan persis ke kondisi sebelum pertarungan pertama. Snapshot tidak memberikan healing gratis dan tidak diperbarui oleh percobaan gagal. Pemulihan menetapkan jumlah potion ke nilai snapshot agar tidak terjadi penggandaan. Boss kembali ke HP penuh dan fase pertama. Artefak, puzzle, shortcut, dan progres eksplorasi tetap tersimpan; pemasangan artefak serta animasi pembuka tidak diulang. Setelah menang, resource yang tersisa dari percobaan berhasil dipertahankan.

Aktivasi checkpoint belum ditetapkan sebagai sumber healing. Pada Jalur Menuju Puncak, musuh yang telah dikalahkan tetap mati selama sesi. Aturan reset musuh di area lain, proteksi respawn, jumlah checkpoint keseluruhan, serta save permanen belum final.

## Keputusan untuk finalisasi

1. Ukuran area permainan, panjang rute, distribusi encounter, dan durasi sesi; detail produksi mengikuti desain dua puzzle, Jalur Menuju Puncak, dan Penjaga Gerbang yang sudah ditetapkan.
2. Proyeksi serta framing kamera yang mendukung eksplorasi, mouse aiming, dan keterbacaan telegraph boss.
3. Identitas karakter pemain, senjata, musuh biasa, serta narasi singkat yang menghubungkan pulau, artefak, dan gerbang.

Angka movement, damage, HP, stamina, dan timing dapat disusun sebagai baseline yang diberi label lalu diuji melalui prototype. Angka baru tidak dianggap sebagai keputusan lama yang sudah disepakati.

## Status implementasi

Fondasi Godot, scene preview, konfigurasi Git, serta integrasi MCP sudah tersedia. Sistem gameplay pada dokumen ini belum diimplementasikan. Rincian dan asal keputusan dipertahankan pada [catatan brainstorming](brainstorming/konteks-lanjutan-the-lost-island.md).
