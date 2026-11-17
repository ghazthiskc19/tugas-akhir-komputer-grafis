# Laporan visual The Lost Island

Laporan A4 berisi 19 halaman: cover, disclaimer AI, gambaran game, lore, core loop, pulau, kamera, dua puzzle, exploration challenge, combat, musuh, resource/retry, boss, visual/audio/UI, teknologi, PRD ringkas, rencana produksi, dan sumber.

- [Canva versi revisi](https://www.canva.com/d/MAsNN3ZNfx8kkdX), design ID `DAHbLuL-xrc`.
- [PDF laporan](../../output/pdf/the-lost-island-laporan-proyek.pdf).
- [Logo game transparan](assets/the-lost-island-logo.png).
- [Identitas cover](identitas.json).

## Status cover

Empat nama dan NIM telah dimasukkan sesuai data pengguna. Nama tim telah ditetapkan sebagai **Aku Suka Embegeh**. Nama dosen dan tahun ajaran masih menunggu data pengguna; kedua placeholder harus diisi sebelum laporan dikumpulkan.

## Penyuntingan

Versi Canva memakai teks yang dapat diedit di atas latar visual. Ilustrasi, skema, dan elemen dekoratif menjadi bagian latar; perubahan elemen tersebut dilakukan dari source lalu diimpor kembali. Dokumen menggunakan komposisi halaman yang bervariasi dengan palet cream, teal, sage, navy, dan coral.

Revisi 17 November 2026 menggunakan judul dan label bagian berbahasa Inggris, dengan isi berbahasa Indonesia formal. Ilustrasi pulau dari cover pertama dikembalikan. Enam concept art tambahan menjelaskan dua puzzle, jalur pendakian, combat, tiga peran musuh, dan boss. Penampilan karakter, senjata, simbol, serta layout pada ilustrasi tidak menetapkan detail produksi yang sebelumnya belum dipilih.

PDF dibuat melalui layout grafis berposisi, kemudian versi HTML dimasukkan ke Canva. MS Word, Google Docs, dan aplikasi word processor tidak digunakan. Impor PDF langsung sempat mengubah posisi teks di Canva; versi HTML di atas menjadi versi yang digunakan.

Jika teks diubah langsung di Canva, export ulang melalui menu Download sebagai PDF. Source lokal tidak otomatis mengikuti perubahan di Canva.

## Membangun ulang

Source membutuhkan Python, PyMuPDF, serta font Arial, Bahnschrift, dan Georgia pada Windows. Jalankan dari root repository:

```powershell
python docs/laporan/build_report.py
python docs/laporan/build_report.py --background-only
python docs/laporan/build_canva_html.py
```

`build_report.py` menghasilkan PDF dan manifest layout. Mode background menyiapkan latar visual sementara di `tmp/pdfs`. `build_canva_html.py` menghasilkan HTML dengan 19 page element dan teks terpisah untuk menghindari reflow saat impor. `tmp/` tidak disimpan dalam Git.

## Asset dan sumber

- `logo-filkom.png`: salinan gambar yang disediakan pengguna, digunakan tanpa perubahan bentuk atau warna.
- `the-lost-island-logo.png`: logo game dengan alpha transparency, dihasilkan melalui built-in imagegen.
- `island-concept.jpg`: ilustrasi konsep pulau melalui built-in imagegen; dikonversi ke JPEG untuk ukuran file laporan.
- `original-island-cover.png`: ilustrasi dari cover pertama, dipakai kembali dari asset Canva `MAHanPGm6EE` pada draft `DAHanNpL4Ts`. Salinan lokal diambil melalui preview terisolasi; draft asli tidak diubah.
- `symbol-ruins.jpg`, `energy-ruins.jpg`, dan `summit-route.jpg`: concept art untuk puzzle dan exploration challenge.
- `combat-scene.jpg`, `enemy-lineup.jpg`, dan `gatekeeper-boss.jpg`: concept art combat, eksplorasi penampilan musuh, dan boss.
- [Prompt asset](prompts.json) mencatat instruksi generasi asset imagegen. Semua gambar merupakan identitas atau ilustrasi konsep, bukan screenshot gameplay.
- Isi gameplay mengacu pada [konsep aktif](../konsep-game.md) dan `docs/desain/`. Milestone, audio, serta elemen UX yang belum dikunci ditandai sebagai usulan/baseline.

## Pemeriksaan

PDF sumber diperiksa secara visual dan melalui ekstraksi teks. Versi Canva diperiksa melalui preview 19 halaman dan pembacaan teks hasil impor, termasuk empat NIM, proyeksi Perspective, ukuran pulau, puzzle, serta snapshot retry. Sistem gameplay dan build akhir belum dinyatakan selesai.
