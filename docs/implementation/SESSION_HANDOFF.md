# Session handoff — 22 November 2026

## Status saat ini — 25 November 2026 (acuan terbaru)

Bagian ini berlaku bila bertentangan dengan bagian bertanggal lebih lama di bawah (22–23 Nov), yang dipertahankan sebagai riwayat. Cakupan hanya **Pulau 1**; Pulau 2/3 dan save lintas pulau di luar scope. Dokumen ini cukup untuk menulis laporan progres tanpa arsip chat.

**Terkirim di Pulau 1 (kode):** pulau penuh + tiga artefak + dua puzzle + pendakian/shortcut + boss + ending (`scripts/world/island_game.gd`); terrain/layout prosedural (`island_terrain.gd`, `island_layout.gd`); objektif (`scripts/objectives/`); musuh (`scripts/enemies/enemy.gd`); boss (`scripts/boss/gatekeeper_*.gd`); pemain/kamera (`scripts/player/ground_player.gd`, `scripts/camera/orbit_camera.gd`); sesi/checkpoint (`session_progress.gd`); save disk (`island_save.gd`); landmark/sign/hint biome (`island_landmarks.gd`); HUD/menu/jeda/pengaturan/peta M/blur+transisi (`scripts/ui/`); VFX/hitmarker (`scripts/vfx/combat_vfx.gd`); font Cinzel + Nunito, ikon game-icons, UI/border Kenney dimuat runtime lewat `ui_theme.gd` (klaim lama "font/logo belum dimuat di runtime" tidak berlaku untuk font dan ikon; logo game belum).

**Kontrol:** WASD, mouse/scroll, Shift, Space, LMB combo tiga hit, RMB blok, Alt dodge, Q potion, E interaksi, Esc jeda + pengaturan (blur latar), **M** peta pulau (permainan dijeda; M/Esc/tombol menutup).

**Kontrak combat baru (diimplementasikan; terverifikasi harness + playthrough dirender, lihat Area bukti):**
- Musuh biasa: standard = combo dua pukulan; heavy = pendekatan dipercepat + sapuan lebar tertunda; ranged = semburan tiga tembakan sambil bergerak. Telegraph baru per serangan, kunci bidikan/asal terlambat, recovery akhir dibatasi, sekali per pukulan; reset/stagger/mati membatalkan rantai/baut; LOS/cover memotong (termasuk moncong). HP/damage baseline tidak berubah. Observer: `get_attack_windup()`, `get_attack_reach()`, `has_pending_followup`; `enemy_pattern_regression.gd` final 72/0 (lihat Area bukti).
- Boss: fase 1 dua pukulan beruntun, fase 2 (HP ≤ 50%) dua atau tiga pukulan (dibatasi, tidak selalu tiga); windup cepat/tertunda, telegraph baru per pukulan, recovery penuh di akhir, pemilihan serangan sadar-jarak; target lock tidak mengikuti pemain. HP 420, damage 24/38/30, ambang 50% tidak berubah. `get_attack_timing` = readout QA. `boss_pattern` 122/0 + playthrough dirender PASS.
- Blok: sebelumnya hanya drain 18/s tanpa dampak per hit. Rumus **dikonfirmasi**: tiap hit diblok memakai stamina `max(8, damage × 0,8)`; kurang → guard break (damage penuh; audio `action_refused` + VFX hurt biasa; tanpa hook UI baru); terbayar → 25% omni-arah; kontrol tidak berubah. `combat_edge` 269/0 (harness). Angka blok di bagian lama historis.
- Cleanup shutdown (kepemilikan node/resource dilepas, tanpa ObjectDB/resource bocor) dan biome hint.

**Save/retry:** `user://island_save.json`, autosave 5 detik + milestone, simpan manual di jeda, Continue memulihkan checkpoint dengan resource persis; snapshot boss diambil sekali di altar dan dipakai tiap retry (juga setelah Continue); New Run meminta konfirmasi bila ada save.

**Prosedural:** seed menggeser akar modul, jalan, 3–5 pack, potion, checkpoint, biome, dermaga (axis-aligned), Pilar Simbol/Jalur Energi bertukar barat–timur; **puzzle internal dan boss tetap authored**.

**Menjalankan/export:** `godot --path .` (Godot 4.7.2 Standard); export preset "Windows Desktop", folder output dibuat dulu; target `exports/island-one/the-lost-island.exe`. QA: `godot --headless --fixed-fps 60 --path . res://scenes/world/island_game.tscn -- --qa-playthrough`.

**Masih manual / tidak diklaim:** gamepad fisik, audio/kesulitan/kontrol subjektif, komputer anggota lain, tinjauan visual asset (0 VERIFIED di inventaris), data portal/dosen/tahun ajaran (jangan dikarang).

**Area bukti (final, dilaporkan parent 25 Nov):** save 82/0; layout 16 seed 0 gagal; completion 384/0; `--seeds-full` 37.620/0; `enemy_pattern` 72/0; `boss_pattern` 122/0; `combat_edge` 269/0; traversal fisik `all_ok`, 91 collision/0 terlewat, apex 1,370 m; terrain 20 seed PASS tanpa leak; shutdown pause 43/0, shutdown-menu 36/0, window 38/0, source `--quit-after 5 -- --qa-no-save` exit 0, tanpa error leak/resource. **Playthrough dirender (sumber) seed 42 PASS** 229,9 s sim: 4 kill, boss attempt 1, 2 kematian, 3 artefak, kedua puzzle, shortcut, boss fase 2, completion dermaga. **EXE `exports/island-one/the-lost-island.exe` (SHA-256 `81ed42e9f85ed5754a575a14b3da407549cddacde5ee07b1ee9f72b382364449`) `--headless --fixed-fps 60 -- --qa-playthrough --seed 42`: PASS 200,4 s sim**, 3 kill, boss attempt 1, 0 kematian, 3 artefak, kedua puzzle + shortcut + gerbang + ending dermaga, tanpa SCRIPT ERROR/leak/resource error, exit 0 (variasi normal dibanding run sumber). Build/ZIP tidak di-commit (lokal). Bukti portabel + screenshot: `docs/implementation/evidence/release/island-one-final.txt`, `island-one-spawn.png`, `island-one-artifact.png`, `island-one-boss.png`. Commit = milestone Pulau 1 pada `main` (lihat riwayat Git). **Tersisa manual saja:** gamepad fisik, audio/kesulitan/kontrol subjektif, komputer anggota lain, review visual asset. Angka 36.099 / 248 dan playthrough 119,8 s historis (22 Nov).

## Pembaruan Pulau 1 — 23 November 2026 (historis; diperbarui bagian 25 November di atas)

Bagian ini menggantikan pernyataan lama di bawah yang menyebut layout tetap, tanpa save disk, atau run hanya di memori; teks lama dipertahankan sebagai riwayat.

- **Layout prosedural:** mode prosedural menggeser deterministik akar modul, jalan, 3–5 pack encounter, potion, checkpoint, biome dan dermaga, semuanya axis-aligned. Puzzle internal (Pilar Simbol, Jalur Energi, pendakian puncak) dan boss tetap authored/fixed.
- **Swap sisi:** Pilar Simbol dan Jalur Energi bertukar barat–timur deterministik per seed (103 bertukar / 97 normal pada 200 seed, tanpa gagal generate; terukur agen); rute/viewpoint/biome mengikuti sisi sebenarnya. Checkpoint pakai offset authored: puncak +(−4, 18), boss +(−10, 12,5). Anchor `(-65,0,0)`/`(60,0,0)` di Kontrak modul adalah baseline tanpa swap.
- **Tutup jendela:** X / Alt+F4 memakai jalur simpan-lalu-keluar yang sama dengan menu; pengujian UI oleh agen masih pending.
- **Save:** JSON lokal `user://island_save.json`; autosave 5 detik + milestone; simpan manual di menu jeda. **Continue** memuat dari checkpoint dengan HP/stamina/potion persis; bila boss sudah dimulai, snapshot retry boss yang asli dipulihkan. Menu awal tidak menimpa save yang ada; **New Run** meminta konfirmasi penggantian.
- **Umpan balik/landmark:** hitmarker + SFX hit; landmark dan sign per biome.
- **Cakupan:** hanya Pulau 1. Pulau 2 dan 3 belum dibuat. Tidak ada klaim lintas perangkat, audio subjektif manusia atau controller fisik.
- **Fakta uji 23 Nov (historis, tidak lengkap):** layout data 16 seed lolos; terrain seed 42/777/20261117 lolos sebelum resume; regresi save 82 check, 4 suite, 0 gagal. Hasil untuk kode 25 Nov: lihat bagian 25 November di atas (belum ada).
- **Build target:** `exports/island-one/the-lost-island.exe` (uncommitted, belum ada hash). Rilis `90d2976` adalah historis.

## Instruksi pengguna terbaru

Pengguna mengizinkan **seluruh backlog** diterapkan otonom selama ditinggal tidur, tanpa review per iterasi; commit/push milestone terverifikasi ke `main`, tuning konservatif boleh. Level lengkap dan executable sudah mencapai ending lewat input sungguhan. Penyelesaian saat ini mencakup diagnosis import fresh clone dan edge regression; jangan kembali mengerjakan P09 dari nol.

Handoff ini adalah konteks minimum untuk kelanjutan; arsip percakapan bukan prasyarat kerja.

### Batch otonom lanjutan — status aktif

Pengguna mengizinkan **seluruh backlog** diterapkan tanpa gate review per iterasi: level tetap sampai ending, procedural, final art/audio/UI, polish, regression, dan export. Commit per tahap yang terverifikasi dan push `main` disetujui. Tuning combat konservatif boleh; kontrol/preferensi yang diterima tetap. Pertanyaan scope sudah dijawab; jangan meminta persetujuan ulang.

Main scene sekarang `scenes/world/island_game.tscn`, integrator `scripts/world/island_game.gd`. Modul terrain, objective, boss dan presentasi sudah terpasang. Pulau baseline/procedural, dua puzzle, pendakian/shortcut, tiga artefak, socket, boss dua fase, exact snapshot retry dan ending tersedia. Scene lama tetap lab historis.

Baseline reset eksplorasi pulau: musuh yang mati tetap mati selama sesi, musuh hidup kembali ke spawn saat respawn; potion/artefak tidak dapat di-farm lewat death. Boss memakai snapshot terpisah. `New Run` melepas seluruh root lama sebelum memasang root baru agar group session/interaksi tidak terduplikasi.

## Runtime dan review

- Godot **4.7.2 Standard**, GDScript, renderer **Compatibility**; executable `C:/Godot/godot.exe`.
- Game aktif: `scenes/world/island_game.tscn` (F5 project). `scenes/tests/adventure_lab.tscn` tetap arena review lama dan memiliki F5 reload musuh khusus lab.
- Launch project: `C:/Godot/godot.exe --path .`; build lokal `exports/windows/the-lost-island.exe`. ZIP distribusi ada di `exports/`, identitas/hash akhir dicatat pada README dan `VERSION.txt` paket.
- `start` pernah tidak memunculkan window bagi pengguna; peluncuran langsung via supervised bash service berhasil, renderer terkonfirmasi. Jangan menutup window milik pengguna tanpa diminta.
- Main scene lama dan lab I01–I08 tetap pembanding/historis, bukan pulau final.

## Keputusan yang tidak boleh diregresikan

- Mouse-look langsung, cursor tertangkap; **bukan MMB-hold** dan **bukan mouse-world aiming**.
- WASD relatif kamera, karakter menghadap arah gerak. **Rotasi tetap bebas selama menyerang**, hitbox mengikuti arah hadap terkini.
- **Tidak ada slowdown movement saat attack**. AnimationTree memadukan kaki locomotion dengan upper-body swing memakai filter spine/keturunannya, tanpa hips/legs.
- **Auto-zoom obstacle dimatikan** pada third-person/arena. Occlusion pemain dan clipping kamera diterima pengguna; jarak diatur mouse wheel.
- Esc menjeda SceneTree, melepas cursor; tombol Lanjutkan/Esc menangkap kembali. Focus loss menjeda, focus return tidak auto-resume.
- Model tidak perlu diremodel agar identik concept art. Pakai asset tersedia; recolor/skala/attachment ringan cukup. Palet pengguna: `docs/desain/palettes/`.

## Kontrol/default terakhir

| Aksi | Kontrol / nilai |
|---|---|
| Gerak / sprint | WASD 6 m/s; tahan Shift 9 m/s, animasi Running_A dan efek debu/jejak ringan |
| Attack | LMB; 3-hit combo, default setiap swing penuh 0,2 s; damage 20/20/35 |
| Block | tahan RMB; damage ×0,25 semua arah; drain stamina 18/s; movement ×0,6 |
| Dodge | Alt; biaya 25 stamina, 0,25 s, iframe 0,18 s, kecepatan awal 12 m/s |
| Potion | Q; channel authored 1,5 s, movement ×0,5; heal 40 + konsumsi satu hanya saat completion |
| Interaksi / lompat | E / Space |
| Reload musuh (lab) | F5 di arena: hidupkan ulang ketiga musuh di spawn awal (dibuat ulang, projectile dibersihkan, killed ID arena dihapus). HP/potion/artefak/checkpoint/preferensi pemain tidak berubah; diabaikan saat jeda/echo |
| Kamera | mouse-look; pitch 20°–65°, sensitivitas default 0,003; wheel jarak 4–14 m |
| Resource | HP 100, stamina 100; awal 3 potion, kapasitas 5; regen stamina 25/s setelah 0,75 s |

Sprint tidak menambah drain stamina. Early attack input dibuang; hold tidak auto-combo. Timing active/combo dihitung dari klip sumber dan dinormalisasi ke durasi preferensi. Seluruh klip swing dimainkan dengan TimeScale cabang attack saja; kaki/drink/dodge tidak ikut dipercepat. Attack yang sedang berjalan memiliki prioritas atas block/dodge/potion; grounded start, tidak jump saat swing. Hit, dodge, attack, fall atau death membatalkan drink tanpa konsumsi. Damage musuh wajib lewat `player.receive_damage()`.

### Preferensi pemain

**Esc → Pengaturan**: slider gerak, sprint (tidak kurang dari gerak), durasi swing 0,1–0,6 s, sensitivitas mouse, jarak kamera awal. Terapkan mengaktifkan + menyimpan ke `user://control_preferences.cfg`; Reset Default menyiapkan default, lalu Terapkan. Nilai swing baru berlaku mulai ayunan berikutnya, bukan me-retime ayunan aktif. Preferensi lokal bukan save progres dan tidak masuk repo. Damage/stamina/aturan combo bukan slider preferensi.

## Yang sudah diimplementasikan

1. Asset lab, preview clip/weapon attachment, camera-relative movement, jump/landing, follow/orbit, revisi mouse-look. Shader belum dibuat.
2. Player combo/resource/defense/potion; health dan death sekali; hit dedupe per korban per swing, world cover memblok melee.
3. Tiga archetype dalam satu module enemy:
   - Standard: Rogue + sword, HP60, damage12, windup/active/recovery 0,6/0,15/0,75 s.
   - Heavy: Barbarian + axe, HP160, damage32, 1,15/0,2/1,6 s; lebih lambat, tidak stagger saat windup/active.
   - Ranged: Ranger + crossbow, HP40, damage10; projectile lurus non-homing, sweep/impact/lifetime, cover dunia memblok.
   - Detection/LOS, chase/leash/return, ray-feeler avoidance (bukan Navigation), telegraph area, stagger dan death/corpse. Friendly fire antarmusuh nonaktif.
4. Interactor memilih satu target terdekat dalam range/LOS, E press; state attack/dodge/drink/dead menolak interaksi.
5. Pickup potion capacity-safe dan artefak satu kali memakai stable IDs; checkpoint tidak memberi heal/potion gratis.
6. Session runtime: respawn 2 s ke checkpoint, HP/stamina penuh, potion tersisa tetap, collected IDs/killed IDs tetap. Projectile dibersihkan, musuh hidup reset ke spawn; musuh mati tetap mati. **Baseline persistence semua musuh arena** (keterangan arena lama; aturan dan save pulau saat ini ada di bagian Pulau 1 di atas). Death volume y < -8.
7. Arena tetap **44×44 m** dengan tiga encounter, cover, step traversal, camp/checkpoint/potion/artefak, HUD resource/state/prompt/progres. Bukan pulau 250×250 atau terrain procedural.

## Peta file dan interface

- `scripts/player/ground_player.gd`: pemilik movement/state/AnimationTree/resource; combat opt-in, lab noncombat tetap bisa dijalankan. `Health`, `receive_damage(int)->bool`, `is_dead`, `can_interact`, `add_potions(int)->int`, `restore_for_respawn`, `get_action_state`, `is_sprinting`, `set_attack_duration(float)`. Signals `resources_changed`, `died`, attack/potion/damage events.
- `scripts/player/drink_animation.gd`: animasi authored dan transform bottle; `player_sprint_effects.gd`: CPUParticles world-space dibuat sekali.
- `scripts/combat/damageable.gd`: `apply_damage`, `heal`, `restore_full`; state diubah sebelum signal, death sekali per life.
- `scripts/enemies/enemy.gd`: konfigurasi/state tiga archetype; `enemy_projectile.gd`. Scenes di `scenes/enemies/`. `Health`, hurtbox layer bit4 metadata `damageable=../Health`; body bit8, mask11. `defeated(enemy_id)`, `reset_encounter()` hanya untuk yang hidup; group `enemies`.
- `scripts/world/session_progress.gd`: group `session`, collected/killed IDs, checkpoint, respawn; `initialize(player)`, `register_enemy`, `get_status`.
- `scripts/interaction/{interactable,interactor,pickup,checkpoint}.gd`; scenes di `scenes/world/`.
- `scripts/tests/adventure_lab.gd` + scene: integrasi arena; inherits melee lab untuk rig/sword/camera, mengganti world/dummy/HUD review lama.
- `scripts/ui/game_preferences.gd`: slider, Apply/save/load/default; Settings masuk pause panel asli kamera.
- `scripts/camera/orbit_camera.gd`: mouse-look/pause/zoom; `set_zoom_distance` dipakai preferensi. Collision script/lab lama tetap ada sebagai pembanding, **disabled pada arena**.
- `project.godot`: InputMap attack/block/dodge/potion/interact/sprint; main scene belum diubah.

## Bukti yang benar-benar dijalankan

Runtime nyata Godot 4.7.2 Compatibility/OpenGL, Radeon RX 5500M, 1280×720 (bukan hanya parser/headless):

- Combo 20+20+35 tepat sekali per hit; early press tidak dibuffer; hold satu swing saja. Versi fast: klip pertama 6,8333× memainkan seluruh klip dalam 0,2 s; combo tetap damage75, layer selesai.
- Full-speed + free turning saat swing; kaki dan lengan benar-benar berubah pose bersamaan. Versi fast mencapai gerak6/sprint9, Running_A, sprint tetap saat attack; Alt dodge terpicu terpisah.
- Block mengurangi 20→5, drain; dodge menghindari hit dalam iframe, kena setelahnya; kurang stamina menolak; regen/clamp lolos (baseline defense awal sebelum tuning durasi).
- Potion hit-cancel tidak mengurangi item; completion heal40/konsumsi1; pose minum diperiksa render.
- Tiga encounter AI nyata masing-masing memberi 12/32/10 setelah telegraph; projectile diserap cover, defeated sekali dan tercatat session.
- E checkpoint tanpa heal gratis; potion3→5 sekali; artefak satu kali; potion dipakai5→4, mati/respawn mempertahankan4 + artefak/killed/pickup states, HP/stamina penuh.
- Settings GUI klik tombol + keyboard slider, Apply, save file, reload scene, Reset Default lolos. Mengubah durasi 0,2→0,3 saat pause tidak mengubah swing aktif.
- Bukti tersimpan: `docs/implementation/evidence/fast-sprint.png`, `preferences-menu.png`; screenshot iterasi lama tetap historis. Harness sementara sudah dihapus setelah proof.

Level sudah tamat melalui rendered full-input run, release EXE headless (119,8 s sim) dan EXE hasil ZIP final `90d2976` pada path berspasi (ber-jendela, 120,7 s sim). `island_regression.gd` mencatat 36.099 checks, 0 gagal; `combat_edge_regression.gd` 248 checks, 0 gagal. 20 seed acceptance lolos data; baseline seluruh rute lolos physics traversal. Perf renderer RX5500M/1280×720: wall median 16,65 ms/p95 17,27 ms saat vsync, bukan TIME_PROCESS. Fresh remote clone `08d5702` pada mesin yang sama lolos import, full-input, regression, export dan EXE; satu crash native import pertama (font reimport, `0xc0000005`) tidak muncul lagi dalam 16 import bersih. Belum seluruh A01–A25 ditandatangani: controller fisik, mix audio subjektif, komputer anggota lain dan audit visual lengkap tetap manusia.

## Kelanjutan dan pemeriksaan akhir

1. Jangan mengulang implementasi P09–P14; main scene sudah level lengkap. Pertahankan kontrol dan prinsip resource yang diterima.
2. Bila import pertama crash native, jalankan import sekali lagi; penyebab belum terbukti. Edge tempur: `godot --headless --fixed-fps 60 --path . --script res://scripts/tests/combat_edge_regression.gd`.
3. QA full-input: `godot --headless --fixed-fps 60 --path . res://scenes/world/island_game.tscn -- --qa-playthrough`; EXE: `<game>.exe --headless --fixed-fps 60 -- --qa-playthrough`. Runner Node hanya aktif lewat flag eksplisit, normal UI tidak menampilkan debug. Jangan gunakan `--script` untuk runner ini; release EXE tidak mendukungnya.
4. State regression tetap SceneTree: `godot --headless --fixed-fps 60 --path . --script res://scripts/tests/island_regression.gd -- --seeds-full`. Harness ini memakai teleport sebagai setup; bukan bukti perjalanan. Full-input runner tidak teleport, mengubah AI, memberi item/HP, atau noclip.
5. Source `90d2976` dan docs sebelumnya sudah dipush (riwayat). Build/ZIP sengaja tidak di-commit; export butuh `mkdir -p exports/windows` (atau folder target) dulu. Hash `90d2976` ada di `exports/windows/VERSION.txt`/README/acceptance dan hanya berlaku untuk rilis lama. **Target build baru:** `exports/island-one/the-lost-island.exe` (uncommitted); hash dan hasil uji menunggu bukti akhir parent, jangan dikarang.
6. Review berikutnya oleh pengguna: feel kontrol, keterbacaan puzzle/boss, audio; oleh anggota tim: standalone di komputer lain. Laporan dosen/tahun ajaran dan upload portal bukan data yang boleh dikarang.

### Kontrak modul level

- Terrain: `island_terrain.gd`, `configure(seed, procedural)` sebelum masuk tree; anchors spawn `(0,0,85)`, simbol `(-65,0,0)`, energi `(60,0,0)`, summit `(0,0,-50)`, boss `(0,0,-100)`. Terrain dan dekorasi memakai stream terpisah; maksimal empat kandidat lalu baseline.
- Objective IDs: `forest_artifact`, `energy_artifact`, `summit_artifact`; solved keys `symbol_pillars`, `energy_path`, `summit_shortcut`. Solusi simbol `[2,0,3,1]`; energi awal `[0,1,2]`, enam press menjadi `[1,3,1]`.
- Summit main lane lokal x=1,5, z+22..−22; underpass R4 >=3,95 m. Route dunia `summit_boss` mengikuti lane ini. Jangan pindahkan summit kembali ke z−65: itu dahulu menimbun retry boss.
- Boss snapshot ditangkap pada altar sebelum wake, sekali; retry menetapkan HP/stamina/potion snapshot, bukan heal penuh eksplorasi. Arena tidak bisa dibatalkan sukarela; quit membuang sesi.
- Presentasi: `island_presentation.gd`, setup player/session/interactor/boss; menu/intro/outro/pause/audio/preferensi. Jangan hitung flag shortcut/socket/boss sebagai puzzle; puzzle hanya dua.
- Penjaga: `guard_appearance.gd` per-instance stone/rune, tidak mengubah material Rogue pemain. `_exit_tree` membersihkan overlay/material agar New Run tidak membawa resource renderer lama.

## Repo, lisensi dan workflow aman

- Remote GitHub `ghazthiskc19/tugas-akhir-komputer-grafis`, branch main; **repo PUBLIC**, bukan private.
- Basis KayKit/Kenney/CC0 + golem; asset penting tersedia, jangan berburu paket lagi tanpa gap nyata. Portable Blender di tools ignored.
- File mentah Mixamo, downloads/tools/tmp, arsip chat dan gambar pribadi **jangan ikut commit/push**. Credit tidak mengubah larangan redistribusi raw Mixamo. Jangan commit `docs/brainstorming/arsip-chat-lengkap.md` atau file `codex-session-*.md`.
- Commit hanya baris/file milik kerja melalui eval `commit` namespace, bukan git add/commit. Agent files kadang perlu `take` eksplisit. Review unattributed DrinkAnimation import/helper dan scenes yang memang ditulis agent, jangan mengambil file pengguna lain.
- Commit batch yang diterima: `f73ee59` player/resource/sprint/preferences; `d4f7d7b` tiga musuh/projectile; `a92be0e` interaction/session/respawn. Commit integrasi arena + handoff mengikuti ketiganya; lihat hasil commit/push atau riwayat terkini untuk SHA tip. Sebelum batch: `8b0a7ac` free-turn, `742615b` layering, `129e940` single melee.
- LSP belum terkonfigurasi; tool status sebelumnya menegaskan ini. Edit file existing wajib via edit; write untuk file baru. Runtime proof yang sudah lolos jangan diulang hanya untuk konfirmasi.
