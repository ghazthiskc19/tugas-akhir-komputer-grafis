# Boss Akhir: Penjaga Gerbang

Status: ditetapkan pengguna pada 11 November 2026, dengan revisi retry berbasis snapshot. Dokumen ini menetapkan desain; boss belum diimplementasikan.

## Identitas dan tujuan

Penjaga Gerbang merupakan golem batu dengan inti energi yang menjaga gerbang keluar pulau. Boss aktif setelah pemain memasang tiga artefak dan berinteraksi untuk memulai pertarungan. Kemenangan membuka gerbang; pemain melewatinya untuk menyelesaikan Level 1.

Pertarungan menguji pembacaan telegraph, movement, dodge, block, serta pemilihan panjang combo. HP dan damage boss perlu diuji agar pertarungan tidak bergantung pada pengulangan serangan terhadap HP yang terlalu tinggi.

## Arena dan aktivasi

- Arena berupa pelataran rata di depan gerbang, dengan ruang movement dan batas yang jelas.
- Framing kamera harus memperlihatkan tubuh boss serta tanda serangan pada tanah.
- Checkpoint tersedia sebelum arena.
- Pemasangan tiga artefak dan interaksi pemain memicu animasi bangun singkat, lalu pertarungan dimulai.
- Arena tertutup selama pertarungan. Tidak ada musuh tambahan.
- Arena menggunakan modul terkontrol; variasi terrain berdasarkan seed tidak boleh menghalangi ruang menghindar atau akses gerbang.

## Pola serangan

| Serangan | Telegraph | Respons pemain | Recovery boss |
|---|---|---|---|
| Sapuan lengan | Boss menarik satu lengan ke belakang dan menampilkan area sapuan. | Mundur atau dodge keluar jangkauan. | Jeda pendek untuk serangan balasan terbatas. |
| Hantaman tanah | Boss mengangkat kedua tangan; lingkaran menandai area hantaman. | Keluar dari lingkaran atau memakai dodge dengan timing yang sesuai. | Tangan tertahan di tanah; recovery terpanjang. |
| Terjangan lurus | Boss merendahkan badan; garis menandai arah terjangan. | Bergerak atau dodge ke samping. | Boss berhenti untuk menyeimbangkan badan. |

Arah atau posisi serangan dikunci menjelang serangan dilepas. Boss tidak terus mengarahkan serangan kepada pemain setelah target dikunci. Telegraph harus sesuai dengan area damage yang terjadi.

Block mengurangi damage sesuai aturan defense umum. Semua serangan dapat dihindari melalui posisi di luar area damage atau dodge selama i-frames aktif. Boss tidak memiliki pengecualian serangan yang menembus aturan block atau i-frames.

## Fase pertarungan

Pada HP di atas 50%, boss memakai satu serangan lalu memasuki recovery. Pada HP 50% atau kurang, inti energi menyala lebih terang dan boss sesekali merangkai dua serangan sebelum recovery panjang, misalnya sapuan lengan diikuti hantaman tanah.

Fase kedua mempertahankan telegraph dan timing dasar setiap serangan. Peningkatan tekanan berasal dari rangkaian serangan. Recovery hantaman harus memungkinkan combo tiga hit jika pemain mendekat tepat waktu; recovery pendek mendorong pemain membatasi serangan balasan menjadi satu atau dua hit.

## Snapshot dan retry

Snapshot diambil tepat sebelum pertarungan pertama dimulai, setelah pemasangan artefak dan sebelum pemain dapat menerima damage boss. Snapshot mencatat HP, stamina, dan jumlah potion yang dibawa pada saat itu. Pembuatan snapshot tidak memberikan healing gratis.

Jika pemain mati selama pertarungan:

1. Pemain kembali ke titik retry yang aman sebelum arena.
2. HP, stamina, dan jumlah potion dipulihkan persis ke nilai snapshot. Potion yang dipakai dalam percobaan gagal dikembalikan melalui pemulihan jumlah tersebut.
3. HP boss kembali penuh, fase kembali ke fase pertama, dan serangan aktif dibersihkan.
4. Artefak, puzzle selesai, shortcut, dan progres eksplorasi di luar pertarungan tetap tersimpan selama sesi.
5. Pemain cukup berinteraksi untuk mencoba lagi, tanpa memasang ulang artefak atau mengulang animasi pembuka.

Snapshot yang sama dipakai untuk seluruh retry dalam rangkaian pertarungan ini. Pemulihan potion menetapkan jumlah ke nilai snapshot, bukan menambahkan potion ke jumlah yang tersisa. Kegagalan berulang tidak mengurangi persediaan awal atau menggandakan item.

Aturan ini merupakan pengecualian terhadap respawn eksplorasi biasa yang memulihkan HP penuh dan tidak mengembalikan healing terpakai. Retry boss mengembalikan HP dan stamina ke nilai snapshot, yang dapat berada di bawah maksimum jika pemain memulai pertarungan dalam kondisi tersebut.

Setelah boss dikalahkan, resource yang tersisa dari percobaan berhasil dipertahankan dan snapshot retry tidak diterapkan lagi. Pertarungan harus tetap dapat diselesaikan tanpa potion agar pemain yang datang tanpa healing memiliki kesempatan menang.

## Kemenangan

Boss runtuh, energi pengunci padam, dan gerbang terbuka. Pemain melewati gerbang untuk memicu layar penyelesaian Level 1.

## Kriteria penerimaan

1. Pertarungan hanya dapat dimulai setelah ketiga artefak dipasang dan pemain melakukan interaksi aktivasi.
2. Ketiga serangan memiliki telegraph yang terlihat dan sesuai dengan area damage.
3. Arah atau posisi serangan berhenti mengikuti pemain setelah target dikunci.
4. Perubahan fase pada 50% HP mengubah rangkaian serangan tanpa menghilangkan telegraph yang telah dipelajari.
5. Recovery hantaman memungkinkan combo tiga hit ketika pemain memilih posisi dan timing yang sesuai.
6. Block dan dodge mengikuti aturan defense umum, termasuk i-frames terhadap serangan boss.
7. Setelah memakai potion lalu mati, HP, stamina, dan jumlah potion kembali ke nilai snapshot; retry berulang tidak menggandakan potion.
8. Boss kembali ke HP penuh dan fase pertama setelah kegagalan, sementara progres pulau tetap tersimpan.
9. Retry tidak mengharuskan pemasangan ulang artefak atau pemutaran ulang animasi pembuka.
10. Kemenangan mempertahankan resource tersisa, membuka gerbang, dan memungkinkan penyelesaian Level 1.

## Detail produksi berikutnya

Ukuran arena, HP, damage, waktu penguncian target, durasi telegraph, recovery, serta frekuensi rangkaian serangan ditentukan melalui prototype dan playtest. Perilaku stagger boss dan aturan keluar sukarela dari rangkaian pertarungan belum ditetapkan. Snapshot merupakan state sesi; penyimpanan permanen ke disk belum menjadi keputusan desain.
