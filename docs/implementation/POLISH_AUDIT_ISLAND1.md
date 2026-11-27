# Polish audit — Pulau 1, dunia & visual (PolishWorldVisuals)

Metode: `scenes/world/island_game.tscn` (start_in_menu=false, seed 42 dan 7) dirender di jendela 1280×720 (Compatibility, RX 5500M). Pemain asli dipindahkan hanya untuk posisi kamera (throwaway `tmp/` script, sudah dihapus), 40 frame ditunggu, viewport disimpan. Area: spawn/pantai, hutan/simbol, reruntuhan/energi, dataran tinggi/summit, arena boss, dermaga/gerbang, titik pandang, plus tampilan jauh tiap landmark dan garis pantai.
Bukti before/after (kiri = sebelum, kanan = sesudah): `docs/implementation/evidence/polish/world_s42_*.png`, `world_s7_*.png`.

## Daftar cacat (urut prioritas) dan status

| # | Cacat (sebelum) | Dampak | Status |
|---|---|---|---|
| 1 | **Pencahayaan datar.** Rig lab memakai `KeyLight` energi 0.1 + ambient putih 0.35 + langit warna polos. Bayangan nyaris tak terbaca, bentuk tidak punya sisi terang/gelap. | Semua area terlihat seperti diorama datar. | Diperbaiki: matahari hangat energi 0.6 (-40°/-32°), ambient netral-dingin 0.36, bayangan 2 split / 80 m, tonemap filmic + kontras/saturasi ringan. |
| 2 | **Langit tanpa gradien dan tanpa kabut.** Latar satu warna `#BEDEFF`, horizon laut berupa garis tajam, objek jauh sama tajam dengan objek dekat. | Tidak ada kedalaman atmosfer; garis horizon keras. | Diperbaiki: `ProceduralSkyMaterial` (zenit→horizon), kabut eksponensial 0.0022 berwarna horizon (hanya objek jauh yang memudar), awan low-poly berputar lambat. |
| 3 | **Air bergaris/kotak di jarak jauh dan tanpa tepi pantai.** Normal dihitung per-vertex pada plane 7.5 m/sel sehingga muncul pola papan catur; air biru jenuh memotong pasir dengan garis keras. | Pantai terlihat seperti potongan; horizon laut berkedip pola. | Diperbaiki: normal per fragmen (riak analitik, memudar di jauh), tekstur pantai R8 hasil `terrain.height_at` → tint dangkal, garis busa beranimasi, alpha menipis di dangkal. Warna lebih lembut, kilap matahari lewat specular. |
| 4 | **Landmark tidak terbaca dari jauh.** Totem/obelisk/spire/gerbang lebih rendah dari kanopi pohon (5–8 m); tidak ada aksen di atasnya. | Pemain tidak bisa mengarah ke tujuan tanpa papan. | Diperbaiki: tiang cahaya aditif tipis di atas gerbang, totem, obelisk, spire, pilar gerbang pulau, dan bendera (shader `landmark_beam`, 6 draw call, tanpa script per-frame), lentera amber di gerbang, kristal es di puncak spire. |
| 5 | **Tanah monoton.** Pasir/rumput warna vertex mulus tanpa detail; di spawn ±40% layar adalah satu warna. | Area spawn terasa kosong. | Dikurangi: noise triplanar dunia-ruang (0.88–1.04) mengalikan warna vertex; tidak menambah draw call. Layout/dekor tidak diubah (di luar kepemilikan). |
| 6 | **Checkpoint nyaris tak terlihat.** Kristal tidak aktif `(0.25,0.3,0.35)` emisi 0.1 hampir hitam-abu di pasir; dibaca sebagai batu. | Titik spawn/checkpoint tidak jadi landmark. | Diperbaiki: warna tidak aktif biru pucat `(0.45,0.62,0.9)`, kristal naik-turun + berputar (`ambient_bob.gd`). Warna aktif (hijau) tidak berubah. |
| 7 | **Spanduk gerbang pulau 1.6 m merah jenuh rata** menjadi bidang merah terbesar saat arena dipandang dari dermaga. | Harsh color, mencuri fokus dari telegraph boss. | Diperbaiki: spanduk 0.9×1.5 merah tua dengan sedikit emisi dan list merah, tiang cahaya merah di atas pilar. |
| 8 | **Pohon/semak kaku**, pohon dan semak neon (hijau jenuh + batang jingga). | Tidak ada gerak ambient; warna keras. | Diperbaiki: material shader sway angin (pohon 0.11 m, semak 0.035 m, fase per instance, tanpa draw call tambahan), saturasi 0.9 + sedikit hangat; partikel debu/serbuk (90 partikel, 1 draw call) mengikuti kamera. |
| 9 | **Slab segel merah di ujung arena boss** (`GateSeal` di `gatekeeper_arena.gd`, ~4 m flat merah jenuh) dan dinding arena abu-abu gelap rata. | Harsh color di arena. | **Belum**: di luar kepemilikan (scripts/boss). Direkomendasikan: emisi + warna lebih redup, mis. `_seal_color` (0.7,0.15,0.12) dengan ring runik. Setelah pencahayaan baru dinding arena tampak lebih berbentuk tetapi tetap datar. |
| 10 | **Dermaga/gerbang** — hanya diperiksa lewat shot dock/boss; tidak ditemukan objek melayang/tembus. | — | Tidak diubah. |
| 11 | **Pelataran summit**: tepi platform berwarna sama dengan lereng sehingga kontur tepi hilang (shot summit seed 42). | Keterbacaan lompat. | Dibantu lampu baru (sisi gelap/terang terbaca). Perbaikan material pelataran adalah ranah objektif → tidak disentuh. |
| 12 | **Performa.** 584 draw call (baseline), bayangan 4 split sampai 100 m, setiap objek jauh dibayangi. | — | Draw call median turun (lihat bawah) karena bayangan 2 split / 80 m. |

Catatan: garis cyan diagonal yang terlihat di satu shot obelisk adalah telegraph proyektil musuh ranged, bukan cacat dunia.

## Perubahan (file)

- `scripts/world/island_atmosphere.gd` (baru): lingkungan/langit/kabut/matahari, tekstur pantai, detail tanah, sway foliage, awan, serbuk. Dipasang dari `island_game.gd` (3 baris, setelah landmark).
- `shaders/island/island_water.gdshader` (ditulis ulang), `landmark_beam.gdshader`, `foliage_sway.gdshader` (baru).
- `scripts/world/island_landmarks.gd`: material spanduk/bendera, helper `_beam`, lentera gerbang, ujung spire, spanduk pilar.
- `scenes/world/checkpoint.tscn`: warna tidak aktif + `scripts/world/ambient_bob.gd`.
- Tidak berubah: layout/terrain/rute, balance, kontrol, logika puzzle.

## Pengukuran (1280×720, seed 42, jendela RX 5500M)

| Titik | Sebelum | Sesudah |
|---|---|---|
| Median frame, vsync on (spawn/symbol/summit/boss) | 16.65 / 16.89 / 16.71 / 16.66 ms | 16.70 / 16.88 / 16.67 / 16.70 ms |
| Median frame, vsync off (kerja GPU/CPU sebenarnya) | 4.25 / 4.87 / 4.02 / 3.17 ms | 4.29 / 6.11 / 4.61 / 4.12 ms |
| Draw call median | 523 / 762 / 721 / 378 | 266 / 436 / 370 / 275 |

Frame time vsync-on tetap di batas 16.7 ms (cap monitor); vsync-off naik ≤ 1.2 ms (< 0.5 ms rata-rata di spawn, titik simbol paling berat karena banyak pohon bersway). Draw call turun karena bayangan.

## Batas yang diketahui

- Rasa/warna subjektif belum dinilai manusia; angka dipilih dari pembacaan screenshot.
- Sway hanya pada pohon/semak MultiMesh; rumput tidak ada di Pulau 1. Reruntuhan/batu tetap statis.
- Pola tanah triplanar adalah noise, bukan tekstur; dari jarak sangat dekat terlihat lembut-bercak.
- Awan hanya terlihat saat kamera menengadah (pitch kamera dibatasi 20–65°), jadi efeknya halus.
- Kabut/sky tidak diterapkan di `combat_arena.tscn` / lab lain (hanya `island_game`).
