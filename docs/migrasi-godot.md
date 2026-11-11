# Migrasi ke Godot

Tanggal keputusan: 11 November 2026.

Pengguna memilih Godot sebagai engine aktif untuk The Lost Island. Fondasi Unity diganti dengan project Godot di root repository. Keputusan gameplay yang telah dicatat tetap berlaku; migrasi engine tidak menetapkan mekanik atau balancing baru.

## Pemetaan teknologi

| Sebelumnya | Pengganti aktif |
|---|---|
| Unity 6000.3.27f1 | Godot 4.7.2 Standard |
| C# untuk script project | GDScript |
| GameObject dan Component | Node dan scene |
| Prefab | PackedScene dan scene instancing |
| ScriptableObject | Resource kustom bila dibutuhkan |
| Cinemachine | Camera3D dan camera rig native Godot |
| Mathf.PerlinNoise | FastNoiseLite untuk implementasi noise berikutnya |
| Unity procedural Mesh | ArrayMesh atau SurfaceTool saat generator diimplementasikan |
| URP | Renderer native Godot; Compatibility dipakai untuk fondasi awal |
| Unity MCP | Godot Editor MCP 2026.10.20.1 |

Pemetaan ini menunjukkan arah implementasi. Generator terrain, controller pemain, camera follow, puzzle, combat, dan boss belum dibuat pada migrasi ini.

## Acuan desain

Catatan `brainstorming/konteks-lanjutan-the-lost-island.md` memuat keputusan gameplay yang lebih baru daripada ringkasan awal percakapan: scope Level 1, tiga artefak, dua puzzle, exploration challenge, combat, stamina, healing, checkpoint, dan boss akhir. Keputusan tersebut dipertahankan.

Referensi Unity, C#, Cinemachine, dan API Unity di catatan historis perlu dibaca dengan pemetaan di atas. Penentuan proyeksi kamera, ukuran dunia, angka traversal, detail puzzle, dan balancing tetap memerlukan pembahasan atau baseline playtesting tersendiri.

## Cadangan dan pemulihan

Branch `archive/unity-before-godot` mempertahankan commit Unity terakhir. File Unity yang ada di workspace, termasuk perubahan lokal pada VersionControlSettings, dipindahkan ke cadangan lokal sebelum migrasi. Cadangan tersebut berada di luar repository dan tidak diunggah.

Untuk memeriksa versi lama, gunakan checkout atau worktree terpisah dari branch arsip agar tidak mencampurkan kedua engine di satu project aktif.

## Verifikasi migrasi

Pemeriksaan pada 11 November 2026:

- Godot 4.7.2 berhasil mengimpor project beserta plugin editor.
- Main scene berhasil dijalankan headless selama 120 iterasi dan keluar dengan kode 0.
- Log import, runtime, dan editor tidak menunjukkan script error atau parse error.
- Koneksi MCP melalui stdio berhasil menggunakan protokol 2025-11-25; server dan addon sama-sama memakai versi 2026.10.20.1.
- MCP berhasil membaca identitas project, versi engine, dan scene tree `TheLostIsland` dari Editor yang berjalan.
- Konfigurasi awal mengekspos 85 tool dari kategori inspection, scene editing, scripting, physics, runtime, 3D, project, dan editor.

Export executable Windows belum diuji karena export templates 4.7.2 belum terpasang pada mesin migrasi. Hasil verifikasi ini mencakup fondasi project dan integrasi tooling; gameplay dan kualitas permainan tetap memerlukan implementasi serta pengujian berikutnya.
