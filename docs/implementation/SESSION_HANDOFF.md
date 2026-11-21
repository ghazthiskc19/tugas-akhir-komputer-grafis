# Session handoff — 22 November 2026

## Instruksi pengguna terbaru

Batch prototype **sudah dicoba dan diterima pengguna**. Commit/push perubahan yang relevan, simpan progres, compact konteks, lalu lanjut **P09: blockout pulau tetap dan jalur eksplorasi**. Tidak perlu mengulang brainstorming/asset hunting atau meminta persetujuan ulang untuk batch ini. Shader polish dikerjakan sesudah gameplay inti stabil, sebelum regression/export akhir.

Handoff ini adalah konteks minimum untuk kelanjutan; arsip percakapan bukan prasyarat kerja.

## Runtime dan review

- Godot **4.7.2 Standard**, GDScript, renderer **Compatibility**; executable `C:/Godot/godot.exe`.
- Review gabungan: `scenes/tests/adventure_lab.tscn` (F6). `project.godot` masih menjalankan scene preview lama saat F5; jangan mengira arena sudah menjadi main scene.
- Launch: `C:/Godot/godot.exe --path . res://scenes/tests/adventure_lab.tscn`.
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
6. Session runtime: respawn 2 s ke checkpoint, HP/stamina penuh, potion tersisa tetap, collected IDs/killed IDs tetap. Projectile dibersihkan, musuh hidup reset ke spawn; musuh mati tetap mati. **Baseline persistence semua musuh arena**; belum aturan seluruh pulau atau save permanen. Death volume y < -8.
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

Belum full A01–A25, belum full regression sesudah seluruh tuning, controller fisik belum diuji, encounter campuran/stagger-edge/potion-completion-order belum lengkap, belum build/export/fresh clone/perf target. Jangan centang acceptance release secara massal. User acceptance adalah playtest prototype, bukan klaim semua risiko sudah hilang.

## Selanjutnya setelah compact

1. Baca handoff ini + tracker P09 dan spesifikasi puzzle/ascent/boss, bukan arsip chat.
2. Buat blockout tetap pulau baseline **250×250 m**: Grassland spawn/camp, cabang Forest dan Rocky Highlands, gate/boss socket dan akses dock. Belum noise/procedural penuh.
3. Sambungkan jalur utama/alternatif, landmark, shortcut dan sockets dua puzzle/ascent/checkpoint/encounter. Validasi slope, jump gap, collision dan perjalanan dari kamera gameplay; jangan hanya landscape visual.
4. Gunakan module combat/session/interactor yang sudah ada; jangan membuat paralel convention atau meregresikan kontrol pengguna.
5. Setelah traversal blockout terbukti, integrasi puzzle Pilar Simbol, Jalur Energi, pendakian artefak dan boss Penjaga Gerbang. Boss retry snapshot **belum ada**; butuh implementasi P08/P13, bukan memakai respawn eksplorasi biasa.
6. Seed/procedural generation setelah playable level tetap. Final art/recolor dan shader polish sesudah gameplay stabil.

## Repo, lisensi dan workflow aman

- Remote GitHub `ghazthiskc19/tugas-akhir-komputer-grafis`, branch main; **repo PUBLIC**, bukan private.
- Basis KayKit/Kenney/CC0 + golem; asset penting tersedia, jangan berburu paket lagi tanpa gap nyata. Portable Blender di tools ignored.
- File mentah Mixamo, downloads/tools/tmp, arsip chat dan gambar pribadi **jangan ikut commit/push**. Credit tidak mengubah larangan redistribusi raw Mixamo. Jangan commit `docs/brainstorming/arsip-chat-lengkap.md` atau file `codex-session-*.md`.
- Commit hanya baris/file milik kerja melalui eval `commit` namespace, bukan git add/commit. Agent files kadang perlu `take` eksplisit. Review unattributed DrinkAnimation import/helper dan scenes yang memang ditulis agent, jangan mengambil file pengguna lain.
- Commit batch yang diterima: `f73ee59` player/resource/sprint/preferences; `d4f7d7b` tiga musuh/projectile; `a92be0e` interaction/session/respawn. Commit integrasi arena + handoff mengikuti ketiganya; lihat hasil commit/push atau riwayat terkini untuk SHA tip. Sebelum batch: `8b0a7ac` free-turn, `742615b` layering, `129e940` single melee.
- LSP belum terkonfigurasi; tool status sebelumnya menegaskan ini. Edit file existing wajib via edit; write untuk file baru. Runtime proof yang sudah lolos jangan diulang hanya untuk konfirmasi.
