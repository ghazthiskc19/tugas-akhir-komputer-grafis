# The Lost Island

Project gim 3D untuk mata kuliah **Komputer Grafis**. Engine aktif adalah **Godot 4.7.2 Standard**, menggunakan **GDScript**. Target permainan adalah PC single-player dan fully offline.

## Panduan tim

- [Kebutuhan development dan setup komputer anggota](docs/kebutuhan-development.md): versi Godot, cara menjalankan, MCP opsional, dan export Windows.
- [Konsep game terbaru](docs/konsep-game.md): scope Level 1, eksplorasi, puzzle, combat, checkpoint, dan keputusan yang masih terbuka.
- [Implementation Tracker](docs/implementation/IMPLEMENTATION_TRACKER.md): checklist pengadaan asset, implementasi sistem, playtest, polish, dan release; terhubung ke inventaris asset serta acceptance checklist.
- [Audit ekosistem asset online](docs/implementation/ASSET_ECOSYSTEM_AUDIT.md): cakupan keluarga KayKit/pelengkap, tier gratis/berbayar, sumber preview, gap dan risiko modifikasi; bukan daftar asset yang sudah diunduh atau diuji.
- [Rencana sumber asset yang dipilih](docs/implementation/ASSET_SOURCE_PLAN.md): keluarga inti KayKit disetujui, sumber pelengkap per kebutuhan, rencana edit agent serta gate akun/biaya/lisensi; belum berarti file/rig/clip siap pakai.
- [Konteks lanjutan OMP](docs/brainstorming/konteks-lanjutan-the-lost-island.md#handoff-omp--17-november-2026): hasil impor session, keputusan terakhir, status pekerjaan, dan titik lanjut.
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

## Asset yang tersedia

Basis KayKit, Kenney, model Rock Golem, UI, audio dan source shader tersimpan di `assets/third_party/`. Sumber/lisensi tersedia di [Third-party notices](THIRD_PARTY_NOTICES.md) dan [Catatan Unduhan](docs/implementation/ASSET_DOWNLOADS.md). Pakai model yang sudah ada; remodel untuk menyamai concept art tidak wajib. Recolor, skala dan attachment ringan diprioritaskan.

Repository ini **public**. Motion FBX Mixamo tidak ikut clone; anggota tim memperoleh file melalui akun masing-masing sesuai [petunjuk lokal](assets/third_party/mixamo/README.md). Tidak ada gameplay scene saat ini yang bergantung pada FBX lokal tersebut. Arsip download, Blender portable, dan cache kerja tetap lokal; Blender tidak diperlukan untuk membuka model GLB yang sudah dikonversi.

Model tersedia tidak berarti puzzle, terrain procedural, retarget animasi atau gameplay sudah selesai. Lihat inventaris untuk membedakan file yang dapat diimpor dari hasil integrasi yang sudah diuji.

### Review I01: asset lab statis

1. Buka `scenes/tests/asset_lab.tscn` di Godot **4.7.2 Standard**.
2. Tekan **F6** untuk menjalankan scene tersebut. F5 tetap menjalankan main scene lama; main scene tidak diubah untuk showroom ini.
3. Bandingkan kandidat **Rogue, Rogue Hooded, dan Ranger**, basis musuh, golem serta sampel lingkungan. Periksa ukuran relatif, arah hadap, material dan kecocokan warna dengan [referensi palet pengguna](docs/desain/palettes/README.md).
4. Sampaikan pilihan pemain serta bagian warna/skala yang perlu direvisi. Ukuran showroom adalah baseline review, bukan ukuran final gameplay.

Scene ini sengaja statis: belum ada kontrol pemain, animasi, combat, collision gameplay atau generator pulau. Material/tekstur model asal dipertahankan sebagai pembanding; palet mengarahkan lantai, display dan suasana, bukan klaim semua model sudah direcolor. **I01 telah disetujui pengguna; kelanjutan dibatasi ke preview animasi I02.**

[Bukti render I01 1280×720](docs/implementation/evidence/i01-asset-lab.png) diambil dari Godot 4.7.2 Compatibility. Ini pemeriksaan visual agent, bukan persetujuan akhir pengguna.

Cara menjalankan langsung lewat terminal:

```powershell
godot --path . res://scenes/tests/asset_lab.tscn
```

### Review I02: preview animasi Rogue

1. Buka `scenes/tests/animation_lab.tscn`, lalu tekan **F6**.
2. Klik tombol **Idle**, **Jalan**, **Lari**, dan **Serang**. Tiga gerak pertama berulang di tempat; serangan diputar sekali lalu kembali idle.
3. Periksa pose tubuh, transisi gerak, dan apakah pedang mengikuti tangan kanan tanpa terlepas. Coba pindah dari serangan ke jalan/lari sebelum serangan selesai, serta klik serangan lagi untuk mengulang.

Rogue tanpa hood dipakai sebagai **baseline sementara**, bukan pilihan pemain final yang ditetapkan pengguna. Scene ini hanya preview model/clip: tidak ada kontrol WASD, damage, combo, stamina, animasi Mixamo atau generator pulau. Model sumber dan asset lab I01 tidak diubah. **I02 telah disetujui pengguna; iterasi berikutnya dibatasi ke gerak darat I03.**

```powershell
godot --path . res://scenes/tests/animation_lab.tscn
```

### Review I03: gerak WASD

Buka `scenes/tests/movement_lab.tscn` lalu **F6**. Klik jendela game agar menerima keyboard, kemudian gunakan **W/A/S/D**. W menuju atas layar; arah gerak relatif kamera tetap. Coba diagonal, berbalik arah, lepas tombol, dan berjalan menabrak batas serta dinding oranye. Karakter memakai animasi idle/jalan; belum ada lompat, combat atau kamera follow.

Baseline yang boleh dituning setelah review: kecepatan `4 m/s`, akselerasi `20 m/s²`, perlambatan `25 m/s²`, dan turn rate `12/s`. Tombol diikat lewat physical keycode untuk posisi WASD. Layer world `1`, player `2`, mask player `1`; capsule radius `0.45 m`, tinggi `2.18 m`. Rasa gerak dan foot sliding masih perlu penilaian pengguna; loop jalan bukan bukti stride cocok dengan kecepatan dunia.

[Preview arena I03](docs/implementation/evidence/i03-movement.png). I03 tetap menguji gerak darat tanpa lompat; **I03 telah disetujui pengguna**, dan lompat tersedia terpisah pada I04. I01, I02 dan main scene lama tidak diubah.

```powershell
godot --path . res://scenes/tests/movement_lab.tscn
```

### Review I04: lompat dan platform

Buka `scenes/tests/jump_lab.tscn` lalu **F6**. Gunakan **WASD + Space** untuk naik ke platform oranye **0,45 m**, lalu menyeberang ke platform **0,8 m**. Coba melompat diam, berjalan turun dari tepi, menahan Space sampai landing, dan menekan ulang saat masih di udara.

Hanya press baru saat grounded yang melompat. Tinggi baseline sekitar **1,37 m terukur**, tanpa double-jump atau hold auto-jump; kamera masih tetap. I04 telah disetujui pengguna. Scene lama ini tetap tersedia sebagai pembanding; follow ditambahkan terpisah pada I05.

[Preview I04](docs/implementation/evidence/i04-jump-lab.png)

```powershell
godot --path . res://scenes/tests/jump_lab.tscn
```

### Review I05: kamera follow

Buka `scenes/tests/follow_lab.tscn` lalu **F6**, gunakan **WASD + Space**. Kamera mengikuti posisi dan ketinggian secara halus dengan arah pandang tetap; berputar arah gerak tidak memutar kamera. Nilai framing, kelancaran mengikuti lompatan dan apakah damping terasa tertinggal atau terlalu cepat.

Baseline: FOV 50°, focus height 1 m, offset `(0, 7, 9)`, damping horizontal `8/s` dan vertikal `5/s`. [Preview follow](docs/implementation/evidence/i05-follow.png) dan [lompat](docs/implementation/evidence/i05-jump.png).

Scene I05 sendiri tetap **tanpa orbit/collision** sebagai pembanding. Review kontrol terbaru ada di bawah; main scene dan lab terdahulu tidak diubah.

```powershell
godot --path . res://scenes/tests/follow_lab.tscn
```

### Review kontrol third-person: mouse-look, zoom dan collision

Buka **`scenes/tests/third_person_lab.tscn` lalu F6**. Ini menggantikan `aiming_lab.tscn` (MMB orbit dan mouse-world aiming sudah dihapus):

1. **Mouse** (selalu tertangkap): memutar kamera 360°, pitch `20°–65°`, sensitivitas `0,003`. Tidak perlu menahan tombol apa pun.
2. **WASD + Space**: gerak relatif kamera. Karakter menghadap arah gerak; **S** berbalik menghadap kamera. Kamera tidak ikut berputar.
3. **Scroll**: zoom langkah `1 m`, awal `11,4 m`, rentang `4–14 m`.
4. **Esc**: menjeda/melanjutkan arena dan menampilkan cursor saat jeda; tombol **Lanjutkan (Esc)** juga melanjutkan. Pindah fokus jendela menjeda dan tidak menangkap ulang mouse otomatis.
5. **Auto-zoom karena obstacle dimatikan** pada scene third-person atas keputusan pengguna. Jarak hanya diatur lewat scroll; pemain boleh tertutup obstacle dan kamera dapat menembus geometri. Putar kamera sendiri untuk mencari sudut pandang. Lab collision lama tetap tersedia sebagai pembanding.
6. **Right stick** juga memutar kamera (deadzone radial `0,2`); mapping gamepad lainnya belum ada. Bukti hanya input simulasi, **belum perangkat fisik**.

Serangan melee kelak menghadap arah karakter; tidak ada aim ke titik mouse di dunia dan tidak ada lock-on. Belum ada attack/damage.

Bukti I06–I08 lama (MMB orbit dan aiming) **superseded**: [collision lama](docs/implementation/evidence/i07-blocked.png) · [aiming lama](docs/implementation/evidence/i08-surface.png). Lab orbit/collision kini juga memakai kontrol baru. Uji runtime revisi lolos untuk gerak, facing, zoom, clamp, collision posisi uji serta pause/klik Lanjutkan: [preview](docs/implementation/evidence/mouse-look-review.png) · [jeda](docs/implementation/evidence/mouse-look-pause.png). Review kenyamanan pengguna serta terrain/slope/canopy/boss belum dilakukan.

```powershell
godot --path . res://scenes/tests/third_person_lab.tscn
```

### Review melee satu hit

Buka `scenes/tests/melee_lab.tscn` lalu **F6**. **Klik kiri** untuk satu swing ke arah hadap karakter; tahan klik tidak mengulang serangan. Dummy memperlihatkan HP dan hanya menerima satu damage per swing. Coba di depan/belakang, di luar jangkauan dan dengan dinding di antara pemain-dummy.

Ini iterasi dasar, **belum combo, stamina, block/dodge, potion atau enemy AI**. Kamera tanpa auto-zoom obstacle; Esc menjeda, **R** mengulang lab. Serangan mulai grounded dan lompat ditahan selama swing. **Movement full speed dan rotasi bebas; hitbox mengikuti arah hadap terkini**, kaki idle/jalan dan upper-body swing dipadukan. Dummy 60 HP, damage 20/swing.

Shader/material/lighting/air/efek dipoles setelah gameplay inti stabil, sesuai palet pengguna dan anggaran performa renderer Compatibility; belum dikerjakan pada iterasi ini.

## Struktur

```text
project.godot          Konfigurasi project
scenes/main.tscn       Main scene awal
icon.svg              Icon sementara
assets/third_party/   Asset sumber yang boleh dibagikan beserta lisensi
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
