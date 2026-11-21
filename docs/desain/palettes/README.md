# Referensi palet warna — The Lost Island

Enam gambar diberikan pengguna pada 21 November 2026 sebagai acuan agar warna asset serupa. Gambar disalin tanpa diubah; nomor file mengikuti urutan kiriman. Kode HEX diambil dari piksel pada bagian tengah masing-masing bidang warna, **urut dari atas ke bawah**, bukan ditebak dari tampilannya.

| File | Penamaan / kelompok penggunaan | HEX dari atas ke bawah |
|---|---|---|
| [01-vegetasi-hijau.png](01-vegetasi-hijau.png) | Rumput, semak, daun; hijau terang hingga bayangan gelap | `#E8F5E9`, `#A5D6A7`, `#66BB6A`, `#1B5E20` |
| [02-tanah-pasir-kayu.png](02-tanah-pasir-kayu.png) | Tanah, pasir, kayu dan transisi vegetasi | `#CE7F20`, `#EEDFC7`, `#607938`, `#533416` |
| [03-aksen-karakter-feedback.png](03-aksen-karakter-feedback.png) | Aksen karakter, objek penting dan kandidat warna feedback | `#BEDEFF`, `#FFF2A7`, `#FFA500`, `#930031` |
| [04-laut-biru.png](04-laut-biru.png) | Laut: biru dalam hingga air dangkal; kandidat aksen energi kuno | `#1B365D`, `#005A9C`, `#60C1E5`, `#A0E0EF` |
| [05-reruntuhan-batu-lumut.png](05-reruntuhan-batu-lumut.png) | Batu krem, reruntuhan, lumut dan kandidat warna penjaga/golem | `#EBEBD8`, `#637545`, `#455230`, `#9BA685` |
| [06-langit-laut-pantai.png](06-langit-laut-pantai.png) | Langit/laut, horizon dan pantai berpasir hangat | `#086288`, `#4D8DBA`, `#97D7FF`, `#FFEFC4` |

## Cara memakai

- Pembagian di atas menamai referensi dan mengusulkan peran warna, bukan memfinalkan material setiap objek atau warna setiap state gameplay.
- Pilih subset yang serasi: tidak semua warna wajib digunakan sekaligus. Palet 02/06 memberi alternatif pasir; palet 04/06 memberi alternatif air/langit.
- Prioritaskan asset yang sudah ada dengan recolor/material override seperlunya. Tidak perlu remodel agar mengikuti warna referensi.
- Nilai HEX adalah warna gambar sumber. Lighting, exposure dan material dapat membuat hasil render berbeda; nilai kecocokan dari tampilan Godot saat review I01, bukan dari HEX saja.
- Feedback gameplay tetap harus terbaca melalui bentuk/ikon/animasi, bukan warna saja. Makna final warna bahaya, heal, energi dan keberhasilan perlu diuji kontrasnya.
- Folder ini berisi **referensi desain**, bukan texture runtime yang otomatis dipasang ke model. Scene `scenes/tests/asset_lab.tscn` (I01) memakai warna acuan untuk suasana, lantai dan display; material/tekstur model asal dipertahankan untuk perbandingan. Pilihan warna final menunggu review pengguna.
- Lima gambar pertama berasal dari file pengguna bernama Color Hunt Palette; asal gambar keenam tidak dinyatakan. Penyimpanan referensi ini tidak menyatakan gambar tersebut asset CC0 atau memberi lisensi baru atas gambar sumber.
