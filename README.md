# The Lost Island

Project gim 3D untuk mata kuliah **Komputer Grafis**. Engine aktif adalah **Godot 4.7.2 Standard**, menggunakan **GDScript**. Target permainan adalah PC single-player dan fully offline.

## Panduan tim

- [Kebutuhan development dan setup komputer anggota](docs/kebutuhan-development.md): versi Godot, cara menjalankan, MCP opsional, dan export Windows.
- [Konsep game terbaru](docs/konsep-game.md): scope Level 1, eksplorasi, puzzle, combat, checkpoint, dan keputusan yang masih terbuka.
- [Laporan visual dan Canva](docs/laporan/README.md): dokumen A4, logo game, identitas anggota, dan source layout laporan.
- `godot-version.txt` mencatat patch version engine yang dipakai bersama: **4.7.2**.

Untuk membuka dan menjalankan project, anggota cukup menggunakan Godot Standard. Server MCP dan Python hanya dibutuhkan bila menggunakan workflow AI agent.

## Membuka project

1. Install atau ekstrak [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/). Versi .NET tidak diperlukan.
2. Clone repository ini.
3. Di Godot Project Manager, pilih **Import**, kemudian pilih `project.godot` di root repository.
4. Buka project dan tekan **F6** untuk menjalankan scene aktif atau **F5** untuk menjalankan main scene.

Melalui terminal:

```powershell
godot --editor --path .
godot --path .
godot --headless --editor --path . --import
godot --headless --path . --quit-after 120
```

`scenes/main.tscn` berisi fondasi 3D dengan camera, lighting, environment, dan permukaan preview. Sistem gameplay belum diimplementasikan. Kamera preview dan renderer Compatibility merupakan konfigurasi awal yang dapat dievaluasi saat prototyping.

## Struktur

```text
project.godot          Konfigurasi project
scenes/main.tscn       Main scene awal
icon.svg              Icon sementara
addons/godot_mcp/     Plugin editor untuk AI tooling
docs/brainstorming/    Catatan desain dan riwayat diskusi
docs/migrasi-godot.md  Keputusan migrasi dan pemetaan teknologi
export_presets.cfg    Preset Windows Desktop
```

## AI tooling

Project menyertakan **Godot Editor MCP 2026.10.20.1**, plugin komunitas dari [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp), dengan lisensi MIT. Plugin aktif melalui `project.godot` dan terhubung ke server lokal di `ws://127.0.0.1:9080`.

Konfigurasi client bersifat lokal pada masing-masing komputer. Untuk memasang server:

```powershell
uv tool install godot-editor-mcp==2026.10.20.1
codex mcp add godotMCP --env GODOT_MCP_DEFAULT_TOOLSETS=inspection,scene_edit,scripts,physics,runtime,scene_3d,project,editor -- godot-editor-mcp
```

Plugin MCP digunakan selama development. Folder plugin dikecualikan dari export game agar build pemain tetap offline dan tidak membawa tooling editor. Jangan memasukkan token atau path mesin pribadi ke repository.

## Export Windows

Install export templates **4.7.2** melalui **Editor > Manage Export Templates**, lalu gunakan preset **Windows Desktop** pada **Project > Export**. Preset tersedia; kesiapan build final tetap harus diuji setelah gameplay dibuat.

## Riwayat Unity

Unity 6000.3.27f1 telah diganti oleh Godot. Versi Unity terakhir tersimpan pada branch `archive/unity-before-godot`. Catatan brainstorming lama dipertahankan sebagai riwayat; acuan teknologi terbaru ada di [catatan migrasi](docs/migrasi-godot.md).

File `.godot/` dan hasil export tidak di-commit. File `.tscn`, `.tres`, `.gd`, `.uid`, dan file sumber lainnya harus disimpan di Git.
