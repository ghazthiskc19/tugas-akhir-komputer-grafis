# Kebutuhan development

## Versi project

| Komponen | Versi atau konfigurasi | Kebutuhan |
|---|---|---|
| Godot Engine | **4.7.2 Standard**, stable | Wajib untuk membuka dan menjalankan project |
| Bahasa script | GDScript | Sudah didukung Godot Standard |
| Renderer | Compatibility (`gl_compatibility`) | Konfigurasi fondasi saat ini |
| Git | Versi yang tersedia pada komputer anggota | Untuk clone, pull, dan kolaborasi |
| Export templates | **4.7.2**, Standard | Hanya diperlukan saat membuat executable |
| Godot Editor MCP addon | **2026.10.20.1** | Sudah disertakan di `addons/godot_mcp/` |
| Godot Editor MCP server | **2026.10.20.1** | Opsional, untuk anggota yang menggunakan AI agent |
| Python | **3.11 atau lebih baru** | Hanya diperlukan oleh server MCP |
| uv | Package manager untuk memasang server MCP | Hanya diperlukan pada workflow MCP di panduan ini |

Versi engine dicatat di `godot-version.txt`. Semua anggota menggunakan patch version yang sama. Perubahan versi engine, renderer, dan plugin perlu diperbarui pada panduan ini dan README.

## Menjalankan project

1. Unduh **Godot 4.7.2 Standard** dari [arsip resmi](https://godotengine.org/download/archive/4.7.2-stable/), lalu ekstrak. Pilih paket yang sesuai dengan sistem operasi dan arsitektur komputer.
2. Clone repository atau jalankan `git pull` pada salinan yang sudah ada.
3. Buka Godot Project Manager, pilih **Import**, kemudian pilih `project.godot` di root repository.
4. Tunggu import awal selesai, lalu tekan **F5** untuk menjalankan main scene.

Main scene saat ini adalah `scenes/main.tscn`. Isinya masih fondasi 3D; terrain procedural, pemain, puzzle, dan combat belum diimplementasikan.

Godot Standard sudah cukup untuk project ini. Unity, .NET SDK, Python, uv, dan server MCP tidak diperlukan untuk sekadar membuka serta menjalankan scene. Jika server MCP tidak dijalankan, status plugin yang belum terhubung merupakan keadaan normal dan tidak menghalangi game.

Untuk Windows, penambahan executable Godot ke PATH bersifat opsional. Perintah `godot` di bawah mengasumsikan PATH sudah disiapkan; pengguna juga dapat menjalankan executable melalui path lengkap.

```powershell
git clone https://github.com/ghazthiskc19/tugas-akhir-komputer-grafis.git
cd tugas-akhir-komputer-grafis
godot --editor --path .
```

Jika repository bersifat private, akun GitHub anggota perlu memperoleh akses collaborator sebelum clone.

## AI agent dan MCP

Bagian ini hanya diperlukan oleh anggota yang ingin menghubungkan AI agent dengan Godot Editor.

1. Siapkan Python 3.11+ dan [uv](https://docs.astral.sh/uv/getting-started/installation/).
2. Pasang server dengan versi yang sama dengan addon:

```powershell
uv tool install godot-editor-mcp==2026.10.20.1
```

3. Untuk pengguna Codex, daftarkan server:

```powershell
codex mcp add godotMCP --env GODOT_MCP_DEFAULT_TOOLSETS=inspection,scene_edit,scripts,physics,runtime,scene_3d,project,editor -- godot-editor-mcp
```

4. Mulai sesi Codex baru dan buka project di Godot. Addon yang disertakan sudah diaktifkan melalui `project.godot` dan akan menghubungi server lokal pada port **9080**.

Jika executable server tidak ditemukan, periksa PATH atau gunakan path lengkap `godot-editor-mcp` pada konfigurasi client. Python, executable server, dan konfigurasi client dipasang pada komputer masing-masing; binary serta kredensialnya tidak dibagikan lewat Git.

Jika Unity MCP masih terdaftar pada komputer anggota, nonaktifkan untuk workspace ini melalui pengaturan MCP lokal. Konfigurasi lokal `.codex/` diabaikan Git. Jangan mematikan Unity MCP untuk project lain tanpa kebutuhan.

## Membuat executable Windows

1. Di Godot, buka **Editor > Manage Export Templates**, lalu pasang templates **4.7.2 Standard**.
2. Buka **Project > Export** dan pilih preset **Windows Desktop**.
3. Export ke `exports/windows/the-lost-island.exe` sesuai preset.

Templates diperlukan di komputer yang melakukan export. Pemain yang menerima hasil export tidak perlu memasang Godot, Python, atau MCP. Addon editor MCP dikecualikan dari preset export. Build Windows belum diverifikasi pada fondasi ini.

## Berkas kolaborasi

- Commit sumber scene, Resource, script, asset, file `.uid`, dan konfigurasi import `.import` yang menyertai asset.
- Cache `.godot/`, executable hasil export, token, dan konfigurasi client lokal tidak di-commit.
- Gunakan **Godot 4.7.2** saat membuka project agar perubahan format akibat versi berbeda tidak masuk ke commit tanpa sengaja.
