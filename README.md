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

## Status saat ini — 25 November 2026

Bagian ini adalah acuan **status terkini**. Bagian lab I01–I08, "Arsip review melee awal", tuning encounter lama dan rilis `90d2976` di bawah adalah **riwayat**; jika bertentangan, bagian ini yang berlaku. Cakupan hanya **Pulau 1**; Pulau 2/3 dan save lintas pulau di luar scope dan belum dibuat.

### Fitur Pulau 1 yang sudah dikirim (kode ada di repo)

| Fitur | Modul utama |
|---|---|
| Pulau penuh, tiga artefak, dua puzzle, pendakian + shortcut, boss, ending | `scripts/world/island_game.gd` (integrator), `scenes/world/island_game.tscn` |
| Terrain prosedural berbenih, layout modul, validasi + fallback baseline | `scripts/world/island_terrain.gd`, `scripts/world/island_layout.gd` |
| Pilar Simbol, Jalur Energi, rute puncak | `scripts/objectives/symbol_pillars.gd`, `energy_path.gd`, `summit_route.gd`, `objective_kit.gd` |
| Penjaga kuno (tiga archetype: standard, heavy, ranged) | `scripts/enemies/enemy.gd`, `enemy_projectile.gd`, `guard_appearance.gd` |
| Boss Penjaga Gerbang (arena, socket, altar, telegraph, snapshot retry, gerbang) | `scripts/boss/gatekeeper_encounter.gd`, `gatekeeper_arena.gd`, `boss_telegraph.gd`, `golem_animations.gd` |
| Pemain: gerak, combo, block, dodge, potion, sprint | `scripts/player/ground_player.gd`, `drink_animation.gd`, `scripts/camera/orbit_camera.gd` |
| Sesi, checkpoint, respawn, interaksi | `scripts/world/session_progress.gd`, `scripts/interaction/` |
| Save/Continue disk | `scripts/world/island_save.gd` (`user://island_save.json`) |
| Landmark + sign per biome | `scripts/world/island_landmarks.gd` |
| HUD, menu utama, intro/outro, jeda, pengaturan, peta pulau (M), transisi + blur | `scripts/ui/island_presentation.gd`, `island_map.gd`, `ui_theme.gd`, `game_preferences.gd` |
| VFX tempur dan hitmarker | `scripts/vfx/combat_vfx.gd` |
| Tema UI: font Cinzel + Nunito (SIL OFL), ikon game-icons, UI/border Kenney (CC0) | `assets/third_party/fonts/`, `game_icons/`, `kenney/ui_pack_adventure/`, `kenney/fantasy_ui_borders/` |

### Kontrol (termasuk peta dan jeda)

Tabel kontrol lengkap ada di [Memainkan The Lost Island](#memainkan-the-lost-island-level-1). Tambahan yang berlaku sekarang: **M** membuka/menutup peta pulau (permainan dijeda; M, Esc atau tombol tutup menutup), **Esc** membuka jeda + pengaturan dengan **blur latar** (naik saat dibuka, turun saat ditutup; panel tetap tajam; headless hanya dimmer warna). Perpindahan layar memakai fade hitam + blur.

### Kontrak combat baru (diimplementasikan dan diverifikasi harness + playthrough dirender; bukan buff HP)

Tujuan batch ini: musuh lebih mengancam lewat **kombinasi serangan dan variasi timing**, bukan penambahan HP.

- **Musuh biasa (diimplementasikan):** **standard = combo dua pukulan**; **heavy = pendekatan dipercepat + sapuan lebar tertunda**; **ranged = semburan tiga tembakan sambil bergerak**. Tiap pukulan/tembakan punya telegraph baru, kunci bidikan/titik asal dilakukan terlambat, recovery akhir dibatasi, dan damage diberikan sekali per pukulan lewat `player.receive_damage()` (block dan i-frame berlaku). Reset, stagger dan kematian membatalkan rantai/baut yang tertunda; LOS dan cover (termasuk di moncong) memotong tembakan. HP dan damage baseline tidak diubah. Metode observer QA: `get_attack_windup()`, `get_attack_reach()`, `has_pending_followup`; `scripts/tests/enemy_pattern_regression.gd` final 72 check, 0 gagal (lihat Area bukti).
- **Boss Penjaga Gerbang:** **fase 1 = dua pukulan beruntun; fase 2 (HP ≤ 50%) = dua atau tiga pukulan (dibatasi, tidak selalu tiga)**, dengan windup cepat/tertunda (varian timing), telegraph baru per pukulan, recovery penuh di akhir rangkaian, dan pemilihan serangan sadar-jarak. HP 420, damage 24/38/30 dan ambang fase 50% **tidak diubah**. Target dikunci menjelang pelepasan dan tidak mengikuti pemain. Fungsi `get_attack_timing` tersedia sebagai readout untuk QA.
- **Blok per hit (rumus dikonfirmasi):** sebelumnya blok hanya menguras 18/s tanpa dampak per serangan masuk. Kini tiap hit yang diblok memakai stamina `max(8, damage × 0,8)`; stamina tidak cukup → **guard break** (damage penuh masuk, audio `action_refused` + VFX hurt biasa); terbayar → pengurangan omni-arah 25% tetap. Kontrol dan UI tidak berubah. Angka blok lama (A06, 22 Nov) historis. `combat_edge_regression.gd` 269/0 mencakup dampak guard (harness; lihat Area bukti).
- **Cleanup shutdown:** kepemilikan node/resource (overlay, material, projectile, telegraph) dilepas pada jalur keluar normal dan New Run agar tidak ada ObjectDB/resource bocor.
- **Biome hint:** sign dan landmark per biome memberi petunjuk arah modul.

Status: kode combat/guard selesai dan tercakup bukti harness + playthrough dirender (lihat Area bukti).

### Peta untuk laporan teman

- **Prosedural:** seed menggeser akar modul, jalan, 3–5 pack encounter, potion, checkpoint, biome, dermaga, semuanya axis-aligned; Pilar Simbol dan Jalur Energi bertukar barat–timur per seed. **Puzzle internal dan boss tetap authored/fixed** — hanya posisi modulnya yang bergeser. Layout gagal validasi diganti hingga empat percobaan lalu fallback baseline.
- **Save:** `user://island_save.json` (lokal, bukan repo); autosave 5 detik + milestone; simpan manual di jeda; Continue memulihkan checkpoint dengan HP/stamina/potion persis; New Run meminta konfirmasi bila ada save.
- **Boss retry:** snapshot HP/stamina/potion diambil sekali saat altar pertama; retry memulihkan nilai itu (bukan heal penuh) dan boss kembali penuh fase 1; Continue setelah boss dibangunkan memakai snapshot asli.
- **Cara menjalankan:** Godot 4.7.2 Standard, `godot --path .` (lihat [Membuka project](#membuka-project)). **Export:** lihat [Export Windows](#export-windows).
- **Batas yang masih manual:** gamepad fisik, penilaian subjektif audio/kesulitan/kontrol, uji di komputer anggota lain, tinjauan visual asset (Gate B).
- Tidak ada data portal, dosen atau tahun ajaran di repo; jangan dicantumkan di laporan kecuali tim memberikannya.

### Area bukti (gameplay final, dilaporkan parent, 25 Nov 2026)

Hasil di bawah **dilaporkan parent**; log lokal `tmp/island-final/`; ringkasan portabel di `docs/implementation/evidence/release/island-one-final.txt`. Seluruh pemeriksaan sumber, playthrough dirender seed 42 dan EXE export **PASS**. Yang tersisa hanya gate manual.

| Pemeriksaan | Hasil | Catatan |
|---|---|---|
| Regresi save | 82 check, 4 suite, 0 gagal | `save.log` |
| Regresi layout | 16 seed termasuk swap 42/777/7: 0 gagal | `layout.log` |
| Completion (harness state/teleport) | 384 check, 0 gagal | `completion.log`; bukan bukti perjalanan |
| State penuh `--seeds-full` | 37.620 check, 0 gagal | `state.log`; harness state/teleport |
| Pola musuh `enemy_pattern_regression.gd` | 72 check, 0 gagal (final) | `enemy_pattern-final.log` |
| Tepi tempur `combat_edge_regression.gd` | 269 check, 0 gagal; dampak guard tercakup | `combat_edge-final.log` |
| Traversal fisik terrain | `all_ok=true`; collision diperiksa 91, terlewat 0; apex lompat 1,370 m | `traversal.log` |
| Terrain acceptance final (20 seed) | semua valid, fallback 0, 20/20 berbeda, reproduksibel, fallback paksa valid; RESULT PASS, tanpa leak | `terrain` log final |
| Shutdown normal | pause 43/0; shutdown-menu 36/0; window 38/0 (headless `--verbose --fixed-fps 60`), tanpa error leak/resource; source `--headless --verbose --quit-after 5 -- --qa-no-save` exit 0 tanpa error leak (fix: drain AudioServer async memakai jam dinding nyata, bukan jam simulasi) | LULUS |
| Pola boss `boss_pattern` | 122 check, 0 gagal (setelah perbaikan clipping lane rintangan rendah, ray lutut nyata) | log final |
| Playthrough input nyata **dirender**, seed 42 | **RESULT PASS**, 229,9 detik simulasi: 4 kill, boss attempt 1, 2 kematian, 3 artefak, kedua puzzle terkumpul, shortcut puncak, boss fase 2, completion dermaga; tanpa peringatan cleanup engine | `tmp/island-final/rendered-playthrough-final.log`; screenshot spawn/artefak/boss_phase2/ending (ending saat tengah fade, bukan UI akhir terbaca) |
| Export + hash `exports/island-one/the-lost-island.exe` | **PASS.** SHA-256 `81ed42e9f85ed5754a575a14b3da407549cddacde5ee07b1ee9f72b382364449`. EXE `--headless --fixed-fps 60 -- --qa-playthrough --seed 42`: RESULT PASS, 200,4 detik simulasi, 3 kill, boss attempt 1, 0 kematian, 3 artefak, kedua puzzle + shortcut puncak + gerbang + ending dermaga; tanpa SCRIPT ERROR/leak/resource error, exit 0. (Variasi normal vs run sumber dirender 229,9 s/2 kematian; dicatat terpisah.) Commit: milestone Pulau 1 pada `main` (lihat riwayat Git) | Build/ZIP tidak di-commit. Bukti portabel: [island-one-final.txt](docs/implementation/evidence/release/island-one-final.txt); screenshot `island-one-spawn.png`, `island-one-artifact.png`, `island-one-boss.png` |

Hasil di atas memverifikasi implementasi gameplay Pulau 1 yang tercakup; **bukan** seluruh A01–A25 (gamepad fisik, audio/kesulitan/kontrol subjektif, komputer anggota lain tetap manual).

Bukti lama (22–23 Nov, build `90d2976` dan sebelumnya) tetap historis di [Test Runs](docs/implementation/ACCEPTANCE_CHECKLIST.md#test-runs).

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

`scenes/world/island_game.tscn` adalah main scene dan game penuh (terrain prosedural berbenih, tiga objektif, boss, HUD/menu, audio); lihat [Memainkan The Lost Island](#memainkan-the-lost-island-level-1). `scenes/main.tscn` hanya fondasi preview lama. Renderer Compatibility dipakai.

**Tuning encounter pulau (historis, layout baseline lama):** 9 penjaga dalam tiga kelompok melee/ranged; pada layout prosedural jumlah pack ditentukan generator. Damage/kecepatan era itu 26/42/22 dan 4,4/3,1/3,6 m/s. Nilai aktif ada di `ARCHETYPES` pada `scripts/enemies/enemy.gd` dan `ATTACKS` pada `scripts/boss/gatekeeper_encounter.gd`; kontrak combo baru ada di [Status saat ini](#status-saat-ini--25-november-2026).
Build percobaan lokal lama `exports/enemy-tuning/the-lost-island.exe` bersifat historis.

## Asset yang tersedia

Basis KayKit, Kenney, model Rock Golem, UI, audio dan source shader tersimpan di `assets/third_party/`. Sumber/lisensi tersedia di [Third-party notices](THIRD_PARTY_NOTICES.md) dan [Catatan Unduhan](docs/implementation/ASSET_DOWNLOADS.md). Pakai model yang sudah ada; remodel untuk menyamai concept art tidak wajib. Recolor, skala dan attachment ringan diprioritaskan.

Repository ini **public**. Motion FBX Mixamo tidak ikut clone dan **tidak dibutuhkan**: tidak ada scene atau script yang me-load-nya; clip minum dan golem dibuat dari kode. Arsip download, Blender portable, dan cache kerja tetap lokal; Blender tidak diperlukan untuk membuka model GLB yang sudah dikonversi.

Model tersedia tidak berarti terverifikasi visual. Lihat [inventaris](docs/implementation/ASSET_INVENTORY.md) untuk pemetaan 54 kebutuhan ke implementasi pulau dan statusnya; lab I01–I05 di bawah adalah riwayat tinjauan, bukan status terkini.

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

### Arsip review melee awal (sebelum batch combo/resource)

Buka `scenes/tests/melee_lab.tscn` lalu **F6**. **Klik kiri** untuk satu swing ke arah hadap karakter; tahan klik tidak mengulang serangan. Dummy memperlihatkan HP dan hanya menerima satu damage per swing. Coba di depan/belakang, di luar jangkauan dan dengan dinding di antara pemain-dummy.

Ini iterasi dasar, **belum combo, stamina, block/dodge, potion atau enemy AI**. Kamera tanpa auto-zoom obstacle; Esc menjeda, **R** mengulang lab. Serangan mulai grounded dan lompat ditahan selama swing. **Movement full speed dan rotasi bebas; hitbox mengikuti arah hadap terkini**, kaki idle/jalan dan upper-body swing dipadukan. Dummy 60 HP, damage 20/swing.

Shader/material/lighting/air/efek dipoles setelah gameplay inti stabil, sesuai palet pengguna dan anggaran performa renderer Compatibility; belum dikerjakan pada iterasi ini.

### Review arena batch terbaru

Jalankan `scenes/tests/adventure_lab.tscn` dengan **F6** (arena prototipe terpisah, bukan pulau penuh; pulau ada di [Memainkan The Lost Island](#memainkan-the-lost-island-level-1)). Arena tetap ini menggabungkan combo, defense, potion, tiga musuh, pickup dan checkpoint.

Baseline default fast-paced: **WASD** 6 m/s, **Shift tahan** sprint 9 m/s + jejak debu, **Alt** dodge, **LMB** combo, **RMB tahan** block, **Q** potion, **E** interaksi, **Space** lompat, **Esc** jeda. Sprint tanpa drain stamina tambahan; block/dodge memakai stamina. Default swing **0,2 s** mencakup playback penuh dan timing hit/combo. Serangan tanpa slowdown dan rotasi bebas.

Checkpoint tidak memberi heal gratis. Respawn memulihkan HP/stamina, mempertahankan potion tersisa, artefak/pickup yang sudah diambil dan musuh yang sudah mati selama sesi. **Batch diterima pengguna pada 22 November 2026.** Progres, batas verifikasi dan urutan berikutnya dicatat di [Session Handoff](docs/implementation/SESSION_HANDOFF.md).

**Esc → Pengaturan** menyediakan slider kecepatan gerak/sprint, durasi swing, sensitivitas mouse dan jarak kamera awal. **Terapkan** mengaktifkan sekaligus menyimpan lokal ke `user://control_preferences.cfg`; **Reset Default → Terapkan** mengembalikan default. Nilai swing baru berlaku mulai ayunan berikutnya, bukan memotong ayunan yang sedang berjalan. Scroll masih dapat mengatur jarak saat bermain. Damage/stamina/aturan combo tidak berubah melalui menu ini. [Preview pengaturan](docs/implementation/evidence/preferences-menu.png).

## Memainkan The Lost Island (Level 1)

Scene permainan penuh adalah **`scenes/world/island_game.tscn`**, yang kini menjadi main scene project (F5 atau `godot --path .`). Dapat juga dijalankan langsung:

```powershell
godot --path . res://scenes/world/island_game.tscn
```

Cerita: awak kapal terdampar setelah badai di pulau yang tidak ada di peta. Sebuah gerbang kuno hanya terbuka bagi pemegang **tiga artefak**, dan penjaganya tidak pernah tidur.

**Tujuan:** kumpulkan tiga artefak — dari **Pilar Simbol** (puzzle 1), **Jalur Energi** (puzzle 2), dan **Jalur Menuju Puncak** (pendakian dengan penjaga kuno, lompat, dan tuas jembatan) — pasang di tiga socket arena gerbang, bangunkan **Penjaga Gerbang** (boss golem batu), kalahkan, lalu lewati gerbang ke dermaga untuk menamatkan level.

| Kontrol | Aksi |
|---|---|
| W A S D | Gerak relatif kamera |
| Mouse / scroll | Putar kamera / zoom |
| Shift (tahan) | Lari |
| Space | Lompat |
| Klik kiri | Serang (combo tiga hit) |
| Klik kanan (tahan) | Blok (memakai stamina) |
| Alt | Berguling (dodge) |
| Q | Minum ramuan |
| E | Interaksi (pilar, panel, socket, altar, pickup, tuas, checkpoint) |
| Esc | Jeda dan pengaturan (volume, kontrol) |
| M | Buka/tutup peta pulau |

Hint kontrol dan prompt `[E]` pada layar dibaca dari input map sehingga mengikuti tombol aktual. Right-stick memutar kamera; mapping gamepad lain belum ada dan belum diuji di perangkat fisik.

**Run baru dan seed.** Menu utama dan layar selesai memiliki kolom **Seed** (bilangan bulat −2.147.483.648 s.d. 2.147.483.647), tombol **Acak**, dan kotak **Pulau prosedural dari seed**. Prosedural mati = layout baseline tetap. Prosedural hidup = terrain dan tata letak dari seed yang sama selalu identik; layout yang gagal validasi diganti hingga empat percobaan lalu kembali ke baseline yang valid. **Run Baru** membuang seluruh run lama dan membuat session baru; bila sudah ada save, menu meminta konfirmasi sebelum menggantinya. Mati hanya mengembalikan ke checkpoint dan **tidak** meregenerasi pulau.

**Layout prosedural (perilaku saat ini).** Pada mode prosedural, seed menentukan secara deterministik posisi akar modul, jalan penghubung, 3–5 pack encounter, pickup potion, checkpoint, biome serta dermaga, semuanya sejajar sumbu (axis-aligned). Puzzle internal (Pilar Simbol, Jalur Energi, pendakian puncak) dan boss tetap **fixed/authored**; hanya posisi modulnya yang bergeser. Catatan lama di dokumen riwayat yang menyebut layout tetap atau progres hanya di runtime merujuk iterasi sebelum pekerjaan ini.

**Penempatan sisi dan jalur keluar.** Pada layout prosedural, modul Pilar Simbol dan Jalur Energi bertukar sisi barat–timur secara deterministik per seed (agen mengukur 103 bertukar / 97 normal pada 200 seed, tanpa kegagalan generate); rute, viewpoint dan biome mengikuti sisi sebenarnya. Checkpoint memakai offset authored aktual: puncak +(−4, 18), boss +(−10, 12,5). Menutup jendela Godot (tombol X atau Alt+F4) menjalankan jalur simpan-lalu-keluar yang sama dengan menu; pengujian UI-nya masih menunggu.

**Simpan dan Continue.** Progres disimpan sebagai JSON lokal di `user://island_save.json` (bukan di repo, bukan sinkron antar perangkat). Autosave tiap 5 detik dan pada milestone (mis. artefak, puzzle, checkpoint); **Esc → jeda** menyediakan simpan manual. **Continue** di menu awal memuat dari checkpoint dengan HP/stamina/potion persis seperti tersimpan. Bila disimpan setelah boss dibangunkan, Continue memulihkan snapshot retry boss yang asli (bukan resource saat save). Membuka menu awal tidak menimpa save yang ada; hanya **Run Baru** yang menggantinya, setelah konfirmasi. Cakupan: **hanya Pulau 1**.

**Umpan balik dan landmark.** Serangan yang mengenai target memunculkan hitmarker dan SFX hit; tiap biome memiliki landmark dan papan petunjuk (sign) agar arah modul terbaca.

**Peta pulau (M).** Peta menampilkan garis pantai, jalan dan titik objektif dari layout run yang sedang dimainkan, bukan gambar layout tetap. Posisi/arah pemain, jarak objektif, artefak yang sudah diambil dan checkpoint aktif ditampilkan. Permainan dijeda saat peta terbuka; tekan **M**, **Esc**, atau tombol tutup untuk kembali. Peta tidak menyediakan fast travel atau radar musuh.

**Transisi UI.** Latar transparan menu/jeda memakai blur layar yang naik saat dibuka dan turun saat ditutup; panel, teks dan tombol tetap tajam. Perpindahan layar tetap melalui fade hitam, kini disertai blur masuk/keluar. Blur memakai shader canvas Compatibility; mode headless hanya memakai dimmer warna.

**Cakupan level.** Yang ada hanya **Pulau 1**. Pulau 2 dan 3 **belum dibuat**; tidak ada pemilihan level atau save lintas level.

**Jika mati:** HP/stamina dipulihkan di checkpoint, ramuan yang sudah dipakai tidak kembali, artefak dan puzzle yang selesai tetap, musuh yang kalah tetap kalah. Selama melawan boss, pulihnya HP/stamina/ramuan sama dengan kondisi saat boss pertama kali dibangunkan, dan boss kembali penuh.

**Bukti dan pengujian (historis, 22 Nov 2026, build `90d2976`).** Hasil run bounded (terrain 20 seed data, traversal, playthrough input nyata, regresi state, performa) ada di [Test Runs](docs/implementation/ACCEPTANCE_CHECKLIST.md#test-runs). Ringkas: hanya dengan input pemain, game ditamatkan dalam jendela nyata 1280×720 (120,6 detik simulasi) dan pada exe rilis headless (119,8 detik simulasi, nol kematian); performa pada RX 5500M vsync median 16,65 ms/frame. Ini **tidak otomatis berlaku** untuk kode 25 Nov. Perintah QA: `godot --headless --fixed-fps 60 --path . res://scenes/world/island_game.tscn -- --qa-playthrough`, atau pada exe rilis `<game>.exe --headless --fixed-fps 60 -- --qa-playthrough`.

### Batas yang diketahui

- Belum ada persetujuan atau penilaian subjektif manusia untuk kontrol di pulau penuh dan audio (mix, loop, transisi).
- Belum diuji dengan gamepad fisik atau di komputer anggota lain; fresh clone hanya diuji pada mesin pengembang. Rilis lengkap belum dinyatakan.
- **Intermiten yang diketahui:** satu kali import pertama pada clone baru crash native di editor (`0xc0000005` saat reimport font); tidak muncul lagi pada 16 import bersih berikutnya. Jika terjadi, ulangi import sekali.
- Validasi 20 seed baru berupa data layout (DATA_PASS); run penuh per seed belum dilakukan.
- Regresi state penuh (`--seeds-full`, 36.099 check, 0 gagal) dan regresi tepi tempur (248 check, 0 gagal) lolos pada kode 22 Nov (historis); peringatan sebelumnya berasal dari runner dan sudah diperbaiki.
- Save lokal (`user://island_save.json`) hanya mencakup Pulau 1 dan belum diuji lintas perangkat; tidak ada save lintas level. Font Cinzel/Nunito dan ikon game-icons dimuat di runtime lewat `scripts/ui/ui_theme.gd`; logo game (`docs/laporan/assets/`) belum dimuat di runtime.
- Hitmarker/SFX hit, sign dan landmark belum dinilai manusia; tidak ada klaim lulus audio subjektif maupun gamepad/controller fisik.
- Bukti pengujian parsial untuk kode 25 Nov 2026 ada di [Area bukti](#area-bukti-parsial-dilaporkan-parent-25-nov-2026); playthrough input nyata penuh dan build akhir **belum** selesai. Angka regresi 22 Nov (36.099 / 248 check) historis.
- Asset: 53 dari 54 kebutuhan berstatus IMPORTED (runtime terintegrasi, Gate B penuh belum ditutup), M27 MISSING (opsional); **belum ada VERIFIED** ([inventaris](docs/implementation/ASSET_INVENTORY.md)).

### Kredit

KayKit (Kay Lousberg): Adventurers, Character Animations, Forest Nature, Dungeon, Medieval Hexagon · Kenney: Interface Sounds, RPG Audio, UI Pack - Adventure, Fantasy UI Borders, Input Prompts · Rock Golem — Joseph George (BlendSwap) · Crystal — iPoly3D (Poly Pizza) · Audio OpenGameArt: Tinysized SFX, rubberduck RPG SFX, TinyWorlds forest ambience, RandomMind sea sounds, heartade musik eksplorasi, CleytonKauffman musik boss. Semua di atas CC0. Font Cinzel dan Nunito (SIL OFL 1.1). Ikon HUD dari [game-icons.net](https://game-icons.net) oleh Lorc, Delapouite, Skoll dan Sbed ([CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)) serta Zeromancer (CC0). Shader laut, shader/efek penjaga kuno, clip golem, clip minum, terrain, puzzle, boss, tata letak UI dan teks cerita dibuat oleh tim. Tidak ada FBX Mixamo mentah yang dibutuhkan. Detail lisensi: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).

## Struktur

```text
project.godot          Konfigurasi project
scenes/world/island_game.tscn  Pulau penuh Level 1 (root scripts/world/island_game.gd)
scenes/main.tscn       Preview fondasi lama (bukan main scene lagi)
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

Install export templates **4.7.2** melalui **Editor > Manage Export Templates**, lalu gunakan preset **Windows Desktop** pada **Project > Export**. **Buat folder output lebih dulu** (mis. `mkdir -p exports/island-one`): Godot tidak membuatnya dan export gagal tanpa folder itu. Template resmi 4.7.2 terpasang dan SHA512 terverifikasi di mesin pengembang. Preset memakai `all_resources` dengan pengecualian folder private, FBX Mixamo mentah, docs, addons, tooling dan tmp. Hasil export tidak di-commit. Contoh CLI: `godot --headless --path . --export-release "Windows Desktop" exports/island-one/the-lost-island.exe`.

**Build Pulau 1 saat ini (25 Nov 2026):** `exports/island-one/the-lost-island.exe`, SHA-256 `81ed42e9f85ed5754a575a14b3da407549cddacde5ee07b1ee9f72b382364449`. EXE ini menjalankan `--headless --fixed-fps 60 -- --qa-playthrough --seed 42` dengan RESULT PASS (lihat [Area bukti](#area-bukti-gameplay-final-dilaporkan-parent-25-nov-2026)). Build dan ZIP tidak di-commit (lokal, bukan biner GitHub). Paragraf rilis `90d2976` di bawah adalah historis dan tidak mewakili build ini.

**Rilis historis `90d2976` (bukan build saat ini; kode sudah berubah sejak itu):** pack diaudit 1.393 entri tanpa resource terlarang; `exports/windows/the-lost-island.exe` (SHA-256 `ff80cd44fe42c9c4ff6e9c0ca0fca42be3b5e6dd691d1397b56f58cf511b8d18`) dan ZIP `exports/the-lost-island-windows-90d2976.zip` (SHA-256 `c61c39d371b58aeab2e7b6f95836b04dc2f5e16cf9fdb732214ac0d4594e5eed`, 23 file). Exe itu lolos QA playthrough headless sampai ending (119,8 detik simulasi); fresh clone `08d5702` pada mesin yang sama lolos import, playthrough, regresi 36.099/0 gagal, export. Belum dibuktikan untuk rilis itu: mesin anggota lain dan run dengan jaringan dimatikan secara terpisah.

Build uji lama di `exports/island-one/` (hash `e5397e51…b4fa`, UI/peta/blur) sudah digantikan kode terbaru dan tidak mewakili status saat ini.

## Riwayat Unity

Unity 6000.3.27f1 telah diganti oleh Godot. Versi Unity terakhir tersimpan pada branch `archive/unity-before-godot`. Catatan brainstorming lama dipertahankan sebagai riwayat; acuan teknologi terbaru ada di [catatan migrasi](docs/migrasi-godot.md).

File `.godot/` dan hasil export tidak di-commit. File `.tscn`, `.tres`, `.gd`, `.uid`, dan file sumber lainnya harus disimpan di Git.
