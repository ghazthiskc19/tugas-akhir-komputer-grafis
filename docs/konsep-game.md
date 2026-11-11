# Konsep The Lost Island

Status: konsolidasi keputusan desain yang telah tercatat. Dokumen ini belum menjadi GDD final dan tidak menyatakan seluruh sistem sudah diimplementasikan.

## Identitas

The Lost Island merupakan judul sementara untuk gim 3D exploration adventure dengan puzzle, traversal, dan combat. Kamera menggunakan Perspective dengan elevated third-person follow. Platform sasaran adalah PC, single-player, fully offline. Engine aktif adalah Godot 4.7.2 Standard dengan GDScript.

Pemain merupakan awak kapal yang terdampar setelah badai. Kapalnya rusak dan jalan menuju dermaga terlindung di sisi lain pulau ditutup oleh gerbang kuno. Penjaga Gerbang berupa golem batu dengan inti energi menjaga akses tersebut.

## Scope Level 1

Pengerjaan saat ini mencakup satu level pada satu pulau dengan elevasi moderat. Baseline area daratan yang dapat dimainkan adalah sekitar 250 × 250 meter, untuk diuji melalui prototype. Dunia dibagi menjadi Grassland, Forest, dan Rocky Highlands. Main path menghubungkan area penting, dengan jalur alternatif, hidden area, shortcut, dan landmark untuk orientasi.

Grassland menjadi area kedatangan dan pengenalan kontrol. Forest dan Rocky Highlands bercabang dari jalur penghubung. Gerbang menjadi landmark yang dapat terlihat dari beberapa lokasi. Shortcut mengurangi pengulangan perjalanan dari area objektif.

Pemain memperoleh tiga artefak melalui dua puzzle ringan dan satu exploration challenge. Urutan objektif fleksibel dengan arahan lingkungan. Ketiga artefak mengaktifkan boss di gerbang akhir. Kemenangan atas boss membuka gerbang dan menyelesaikan Level 1.

Campaign, level selection, dan save lintas level belum menjadi scope saat ini. Pengguna mengizinkan durasi permainan lebih panjang daripada usulan awal 15–20 menit; rentang tersebut tidak menjadi batas final. Durasi sesi ditentukan melalui playtest berdasarkan perjalanan, puzzle, encounter, dan boss. Luas pulau tidak digunakan sebagai pengganti pengukuran durasi atau kepadatan aktivitas. Target 5–10 menit pada draft historis juga tidak lagi menjadi acuan.

## Cerita dan penyampaian

Pulau merupakan bekas tempat penjagaan jalur pelayaran kuno. Tiga artefak berfungsi sebagai kunci energi yang tersebar di reruntuhan Grassland, instalasi energi Forest, dan menara pengamatan Rocky Highlands. Reruntuhan di puncak menjadi lokasi altar artefak exploration challenge.

Pemasangan ketiga artefak mengaktifkan kembali sistem gerbang beserta golem penjaganya. Golem masih menjalankan perintah lama untuk menolak penyusup. Pemain mengalahkannya agar dapat membuka gerbang dan mencapai dermaga.

Cerita disampaikan melalui pembukaan singkat, relief lingkungan, dan penutup. Penyampaian ini tidak membutuhkan NPC atau dialog panjang. Nama, penampilan, serta jenis senjata karakter pemain belum ditetapkan.

## Eksplorasi dan visual

Pemain bergerak dan melompat untuk melewati obstacle lingkungan. Visual menggunakan stylized low-poly, warna cerah, dan komposisi pemandangan yang mendukung eksplorasi.

Terrain memakai procedural mesh dengan variasi berdasarkan seed. Lokasi objective, puzzle, checkpoint, dan arena boss perlu dibentuk atau dipilih berdasarkan aturan keterjangkauan. Perubahan seed tidak boleh membuat progres wajib mustahil dicapai.

Kamera Perspective memakai elevated third-person follow dengan smooth damping, termasuk saat pemain melompat. Mouse tetap digunakan untuk aiming; menahan tombol tengah mouse mengaktifkan orbit horizontal 360 derajat, sedangkan orbit vertikal dibatasi. Analog kanan mengatur orbit. Kamera tidak otomatis berputar mengikuti arah serangan dan memakai collision agar tidak menembus lingkungan. Aturan lengkap tersedia pada [desain kamera](desain/kamera-perspective-follow.md).

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

- Pemain menggunakan satu senjata melee, diarahkan oleh posisi mouse di dunia permainan.
- Attack memakai satu tombol dengan combo tiga hit: dua serangan cepat dan satu finisher.
- Input lanjutan harus berada pada timing window. Early input tidak disimpan dan hold-to-auto-combo tidak dipilih.
- Animasi attack yang sudah dimulai diselesaikan sebelum block atau dodge. Movement tetap tersedia dengan kecepatan berkurang.
- Arah dikunci selama satu hit; arah baru dibaca saat hit selanjutnya dimulai.
- Attack dan combo tidak memakai stamina.
- Musuh mencakup dua tipe melee dan satu tipe ranged, ditambah satu boss akhir.

Jenis senjata spesifik pemain, nama dan penampilan musuh, parameter damage, serta angka timing belum ditetapkan.

## Musuh biasa

| Tipe | Perilaku yang ditetapkan |
|---|---|
| Melee biasa | Mendekati pemain lalu melakukan satu swing singkat dengan recovery pendek. |
| Heavy melee | Bergerak lebih lambat, mengangkat senjata sebelum hantaman kuat, lalu memasuki recovery panjang. |
| Ranged | Menembakkan proyektil lurus dengan persiapan yang terbaca. Pemain dapat menghindar atau menggunakan perlindungan. |

Rancangan awal ranged tidak memakai proyektil homing dan heavy tidak memakai combo panjang. Perbedaan timing serta posisi menjadi pembeda awal. Istilah ini merupakan tipe perilaku, bukan nama karakter final. Detection range, chase/leash, stagger, serta distribusi ketiga tipe di seluruh pulau masih memerlukan rincian produksi dan playtest.

## Boss akhir

**Penjaga Gerbang** telah ditetapkan sebagai boss akhir. Setelah tiga artefak dipasang, pemain berinteraksi untuk membangunkan golem batu dengan inti energi di pelataran gerbang. Arena rata menyediakan ruang menghindar, checkpoint sebelum arena, dan batas yang jelas. Pertarungan tidak menambahkan musuh lain.

Boss memakai sapuan lengan, hantaman tanah, dan terjangan lurus dengan telegraph yang sesuai area damage. Target serangan dikunci menjelang pelepasan. Pada HP di atas 50%, boss menyerang sekali lalu recovery; pada HP 50% atau kurang, boss sesekali merangkai dua serangan. Telegraph dan timing dasar tetap dipertahankan. Recovery hantaman memungkinkan combo tiga hit jika posisi serta timing pemain sesuai.

Retry menggunakan snapshot HP, stamina, dan jumlah potion sebelum pertarungan pertama. Kegagalan mengembalikan resource pemain ke nilai snapshot dan mereset boss, sementara progres pulau tetap tersimpan. Kemenangan membuka gerbang; melewati gerbang menyelesaikan Level 1. Aturan lengkap tersedia pada [desain Penjaga Gerbang](desain/boss-penjaga-gerbang.md).

## Defense dan resource

Block dan dodge menggunakan satu pool stamina. Block mengurangi damage dari semua arah untuk melee dan proyektil, serta menguras stamina selama ditahan. Dodge memakai biaya tetap saat dimulai dan memberikan i-frames singkat. Stamina beregenerasi setelah jeda singkat sejak berhenti block atau dodge. Jika stamina tidak mencukupi, aksi defense ditolak; movement dan attack tetap tersedia.

HP ditampilkan dengan bar dan angka. Potion healing terbatas ditemukan di dunia atau dari drop musuh, disimpan, lalu digunakan manual. Besaran HP, kapasitas healing, drop rate, dan angka stamina masih memerlukan baseline playtesting.

Penggunaan potion memiliki animasi minum yang batal jika pemain terkena serangan. HP pulih dan jumlah potion berkurang hanya saat animasi selesai. Jika animasi terinterupsi, pemain tidak mendapat healing dan potion belum terpakai. Pemain dapat berjalan dengan kecepatan berkurang selama minum, tetapi tidak dapat menyerang bersamaan. Durasi minum serta interaksi dengan block/dodge dan serangan yang diblock dirinci saat prototype.

## Kegagalan dan checkpoint

Saat eksplorasi biasa, mati mengembalikan pemain ke checkpoint terakhir dengan HP penuh. Artefak yang terkumpul dan puzzle yang selesai dipertahankan selama sesi. Healing yang tersisa tetap dimiliki dan tidak bertambah karena respawn; item yang telah digunakan tidak otomatis dikembalikan.

Retry boss menggunakan pengecualian snapshot: HP, stamina, dan jumlah potion dikembalikan persis ke kondisi sebelum pertarungan pertama. Snapshot tidak memberikan healing gratis dan tidak diperbarui oleh percobaan gagal. Pemulihan menetapkan jumlah potion ke nilai snapshot agar tidak terjadi penggandaan. Boss kembali ke HP penuh dan fase pertama. Artefak, puzzle, shortcut, dan progres eksplorasi tetap tersimpan; pemasangan artefak serta animasi pembuka tidak diulang. Setelah menang, resource yang tersisa dari percobaan berhasil dipertahankan.

Aktivasi checkpoint belum ditetapkan sebagai sumber healing. Pada Jalur Menuju Puncak, musuh yang telah dikalahkan tetap mati selama sesi. Aturan reset musuh di area lain, proteksi respawn, jumlah checkpoint keseluruhan, serta save permanen belum final.

## Keputusan untuk finalisasi

1. Prototype kamera, movement, dan mouse aiming untuk menguji framing serta perpindahan mode orbit.
2. Blockout pulau dengan baseline 250 × 250 meter untuk mengukur panjang rute, kepadatan aktivitas, distribusi encounter, dan durasi sesi.
3. Rincian kontrol, perilaku chase/leash dan stagger musuh, serta interaksi potion dengan aksi defense.
4. Nama dan penampilan karakter pemain serta musuh, jenis senjata spesifik, dan teks pembukaan/penutup sesuai lore yang telah ditetapkan.

Angka movement, damage, HP, stamina, dan timing dapat disusun sebagai baseline yang diberi label lalu diuji melalui prototype. Angka baru tidak dianggap sebagai keputusan lama yang sudah disepakati.

## Status implementasi

Fondasi Godot, scene preview, konfigurasi Git, serta integrasi MCP sudah tersedia. Sistem gameplay pada dokumen ini belum diimplementasikan. Rincian dan asal keputusan dipertahankan pada [catatan brainstorming](brainstorming/konteks-lanjutan-the-lost-island.md).
