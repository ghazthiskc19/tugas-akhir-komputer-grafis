# Riset Asset Environment — The Lost Island

Diperiksa **20 November 2026**. Fokus: satu keluarga nature untuk pulau cerah dan satu kit reruntuhan batu. **Tiga kandidat di bawah hanya untuk persetujuan visual**: tidak ada paket model/arsip yang diunduh, pembelian, import, atau perubahan status inventaris menjadi `VERIFIED`. Kompatibilitas Godot 4.7.2 belum diuji.

## Shortlist: satu nature terpilih + satu ruins

| Kandidat | Tier, format, dan batas isi menurut pembuat | Kecocokan dan kekurangan dari preview resmi |
|---|---|---|
| **Kenney Nature Kit** — prioritas nature dengan lisensi halaman jelas | **Gratis, CC0, 330 files** menurut halaman resmi; bundle All-in-1 berbayar adalah opsi terpisah, bukan syarat mendapatkan kit individual. Halaman paket tidak merinci format per rilis. Panduan 3D resmi membahas OBJ/FBX/GLB dan menyatakan glTF Kenney didistribusikan sebagai GLB; **ini bukan pemeriksaan daftar file Nature Kit**. [Paket](https://kenney.nl/assets/nature-kit), [Panduan format](https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines). | Preview resmi memperlihatkan pinus/pohon hijau, palma, batu, jalur dan modul elevasi/tebing bertingkat; paling menarik untuk bentuk cliff pada acuan pulau. Warna bawaan sangat turquoise–oranye dengan varian putih: perlu palette batu abu-beige dan foliage hijau alami yang lebih lembut. Susunan cliff terlihat modular/blocky, bukan otomatis terrain pulau organik siap main. [Gambar K1](https://kenney.nl/media/pages/assets/nature-kit/2d81fc716e-1677698893/preview.png). |
| **Ultimate Nature Pack** — keluarga nature utama | Paket gratis; **150 model**, **FBX, OBJ, Blend**; halaman menandai tidak beranimasi dan tidak bertekstur. Tidak mencantumkan glTF/GLB. Tombol download terpisah dari dukungan Patreon/penawaran Source; konten eksklusif pendukung tidak diasumsikan termasuk. [Halaman paket](https://quaternius.com/packs/ultimatenature.html), [FAQ](https://quaternius.com/faq.html). | Preview memperlihatkan pohon hijau berdaun lebar, konifer, palma, semak, batu bersudut, tunggul dan batang; bentuk faceted cocok sebagai kandidat forest/rocks pulau stylized. **Sebagian isi bersalju, autumn, pohon gundul, dan kaktus/desert**: gunakan subset hijau, jangan anggap semua variasi sesuai pulau cerah. Batuan kecil–besar terlihat, tetapi preview tidak membuktikan modul cliff tinggi yang bisa disambung atau terrain pulau siap pakai. [Gambar resmi N1](https://quaternius.com/assets/images/fullres/ultimatenature.jpg). |
| **Ultimate Modular Ruins Pack** — struktur batu utama | Paket gratis; **90 model**, **FBX, OBJ, Blend**; pembuat menyebut modular ruins/dungeons, karakter beranimasi dan props, serta menandai textured/animated pada tingkat paket. Bukan bukti setiap prop beranimasi. Tidak mencantumkan glTF/GLB. Penawaran Patreon/Source terpisah tidak dihitung sebagai isi gratis. [Halaman paket](https://quaternius.com/packs/ultimatemodularruins.html). | Preview memperlihatkan lantai ubin, dinding bata batu dengan bagian terputus, dinding melengkung, pilar, arch/pintu, patung dan vegetasi menempel. Ini memang kit **ruins/dungeon menurut pembuat**, bukan Castle Kit yang sekadar dinamai ulang. Namun scene contoh masih terasa dungeon/medieval—rak buku, peti, tong, banner, pintu kayu, dan patung hewan bukan identitas peradaban kuno game. Pilih modul batu/vegetasi, adaptasi simbol, dan bangun komposisi outdoor terbuka; jangan salin keseluruhan scene. [Gambar resmi R1](https://quaternius.com/assets/images/fullres/ultimatemodularruins.jpg). |

**Keputusan yang disarankan:** prioritaskan **Kenney Nature Kit + Ultimate Modular Ruins** untuk approval visual; **Ultimate Nature** adalah alternatif nature jika foliage faceted Quaternius lebih disukai, bukan kit ketiga yang wajib dicampur. Untuk acuan pinus hijau, cliff abu-beige bertingkat, pantai pasir dan laut turquoise: Kenney mendekati kebutuhan bentuk cliff tetapi perlu recolor; Quaternius Nature mendekati foliage hijau tetapi cliff besar belum terbukti. Ruins mendekati arch batu, namun perlu palette beige, tata ruang outdoor terbuka, dan stairs/elevasi sesuai jalur—bukan benteng castle utuh. Laut/pasir dan lighting tetap custom. Keselarasan skala/material antarpaket belum diuji; lisensi Quaternius belum diputuskan (bagian berikut). [K1](https://kenney.nl/media/pages/assets/nature-kit/2d81fc716e-1677698893/preview.png), [N1](https://quaternius.com/assets/images/fullres/ultimatenature.jpg), [R1](https://quaternius.com/assets/images/fullres/ultimatemodularruins.jpg).

## Lisensi: ada ketidakkonsistenan sumber resmi

- Kedua halaman paket menampilkan **CC0**; FAQ juga menyebut semua model CC0 dan gratis untuk proyek personal, pendidikan, serta komersial tanpa atribusi wajib. [Nature](https://quaternius.com/packs/ultimatenature.html), [Ruins](https://quaternius.com/packs/ultimatemodularruins.html), [FAQ](https://quaternius.com/faq.html).
- Tetapi halaman lisensi global kini menampilkan **Quaternius Asset License (QAL) v1.0**, diperbarui **28 Agustus 2026**: penggunaan/modifikasi dan distribusi dalam produk diperbolehkan tanpa biaya/atribusi, sedangkan redistribusi atau penjualan asset mentah sebagai asset dilarang. Ini **bukan ketentuan CC0 yang identik**. [Lisensi global resmi](https://quaternius.com/license.html).
- Karena arsip belum diambil, **lisensi file rilis yang akan diperoleh belum dipastikan**. Jangan menulis “CC0 terverifikasi” atau membagikan model mentah di repository publik berdasarkan halaman paket saja. Sebelum pengadaan produksi, cocokkan lisensi yang menyertai rilis dengan keterangan pembuat; jika tetap bertentangan, diperlukan klarifikasi pembuat. Approval visual tidak menyelesaikan konflik lisensi ini. [Halaman paket](https://quaternius.com/packs/ultimatemodularruins.html), [Lisensi global](https://quaternius.com/license.html).

## Gambar asli untuk persetujuan

Kedua URL berikut ditautkan langsung oleh halaman paket first-party dan **sudah dibuka sebagai gambar** saat riset. Yang terlihat adalah render/presentasi model kit, bukan concept art game atau gambar AI yang dibuat untuk usulan ini. Pencahayaan, layout scene, dan teks promosi pada gambar tidak otomatis berarti scene demo/material siap dipakai di Godot. [Halaman Nature](https://quaternius.com/packs/ultimatenature.html), [Halaman Ruins](https://quaternius.com/packs/ultimatemodularruins.html).

### N1 — Nature: pilih subset hijau

![Preview resmi Ultimate Nature Pack: pohon, palma, batu dan variasi biome](https://quaternius.com/assets/images/fullres/ultimatenature.jpg)

URL exact: <https://quaternius.com/assets/images/fullres/ultimatenature.jpg>

### R1 — Ruins: pilih batu, pilar dan arch

![Preview resmi Ultimate Modular Ruins Pack: modul batu dan contoh dungeon](https://quaternius.com/assets/images/fullres/ultimatemodularruins.jpg)

URL exact: <https://quaternius.com/assets/images/fullres/ultimatemodularruins.jpg>

Catatan akses: tautan gambar kedua pada masing-masing halaman (`ultimatenature2.jpg` dan `ultimatemodularruins2.jpg`) menghasilkan HTTP 404 saat diperiksa; bukan bukti isi tambahan dan tidak digunakan untuk approval. [Tautan Nature kedua](https://quaternius.com/assets/images/fullres/ultimatenature2.jpg), [Tautan Ruins kedua](https://quaternius.com/assets/images/fullres/ultimatemodularruins2.jpg).

## Pekerjaan custom yang tetap diperlukan

Daftar berikut adalah kebutuhan proyek, **bukan klaim isi kit**; halaman resmi tidak menjanjikan sistem puzzle/gate khusus game. [Batas isi Nature](https://quaternius.com/packs/ultimatenature.html), [Batas isi Ruins](https://quaternius.com/packs/ultimatemodularruins.html).

- Terrain pulau, elevasi/cliff yang dapat dilalui, jalur menuju Rocky Highlands, collision, ocean/sky, dan lighting cerah; batu dekoratif tidak menggantikan terrain gameplay.
- Empat pilar interaktif dengan glyph berbeda dan relief urutan; tiga panel energi putar beserta konektor lurus/siku; source crystal, altar tujuan, serta feedback aktif/nonaktif.
- Ancient gate dengan **tiga socket artifact**, animasi/state terbuka–tertutup dan collision; mesh arch/pintu pada preview bukan bukti gate puzzle tersebut tersedia.
- Identitas reruntuhan: simbol peradaban kuno, permukaan rusak yang konsisten, arena boundary, dan landmark; hindari props medieval yang mengubah arah visual.

Tidak ada runtime/build/test yang dijalankan: keluaran ini hanya riset sumber dan pemeriksaan gambar untuk keputusan visual.

## K1 — Alternatif prioritas nature: Kenney

Gambar berikut juga sudah dibuka sebagai gambar asli dari halaman resmi, bukan gambar concept/AI usulan. Gunakan untuk menilai bentuk pohon, rocks, dan modul tebing; warna render bukan kewajiban palette final. [Halaman paket](https://kenney.nl/assets/nature-kit).

![Preview resmi Kenney Nature Kit: foliage, batu dan tebing modular](https://kenney.nl/media/pages/assets/nature-kit/2d81fc716e-1677698893/preview.png)

URL exact: <https://kenney.nl/media/pages/assets/nature-kit/2d81fc716e-1677698893/preview.png>
