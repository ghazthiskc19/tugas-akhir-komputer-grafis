# Implementation Tracker

Proyek: **The Lost Island** · Tim: **Aku Suka Embegeh** · Dibuat: **17 November 2026**.

Dokumen ini melacak implementasi Level 1 dan bukti verifikasinya. Bagian iterasi lama tetap historis; status aktif dan acceptance di bawah tidak menyatakan review manusia sudah selesai.

## Start Here

| Informasi | Status (25 November 2026) |
|---|---|
| Tahap aktif | **Penutupan Pulau 1 selesai secara implementasi:** fitur terkirim (layout prosedural, save/Continue, peta M, UI font/ikon, blur transisi, landmark/hint biome) plus kontrak combat baru (musuh, boss fase 1 dua pukulan / fase 2 dua atau tiga, guard per hit), terbukti harness + playthrough dirender + EXE `exports/island-one/the-lost-island.exe` (SHA-256 `81ed42e9…4449`, seed 42 PASS). Build tidak di-commit. Rilis `90d2976` adalah historis |
| Pekerjaan berikutnya | **Hanya manual QA:** gamepad fisik, audio/kesulitan/kontrol subjektif, komputer anggota lain, review visual asset. Build, hash dan verifikasi selesai |
| Fondasi yang tersedia | Godot 4.7.2 Compatibility, main scene `scenes/world/island_game.tscn`, modul terrain/objective/boss/UI/save/peta, template export resmi terverifikasi |
| Gameplay | **Hanya Pulau 1** (Pulau 2/3 dan save lintas pulau di luar scope). Seed prosedural menggeser akar modul, jalan, 3–5 pack encounter, potion, checkpoint, biome, dermaga (axis-aligned); puzzle internal dan boss **authored/fixed**. Dua puzzle, pendakian/shortcut, tiga artefak, boss dua fase, snapshot retry, ending tersedia |
| Simpan | JSON lokal `user://island_save.json`; autosave 5 detik + milestone; simpan manual di jeda; Continue di checkpoint dengan resource persis, snapshot boss asli bila boss sudah dimulai; menu awal tidak menimpa save, New Run meminta konfirmasi |
| UI dan asset | Font Cinzel + Nunito (OFL) dan ikon game-icons dimuat runtime via `scripts/ui/ui_theme.gd`; UI/border Kenney; HUD, menu, peta (M), blur latar menu/jeda dan transisi. 53/54 kebutuhan asset IMPORTED, M27 MISSING (opsional), **0 VERIFIED** (Gate B/C terbuka). Raw Mixamo bukan dependency |
| Hambatan yang diketahui | Semua pemeriksaan sumber, playthrough dirender seed 42 dan EXE export lulus. Belum (manual): gamepad fisik, review audio/kontrol/kesulitan manusia, komputer anggota lain, logo runtime. Crash import pertama fresh clone (historis, intermiten) tidak direproduksi |

Urutan utama: **asset sample → import audit → player/camera → combat → progress/retry → level blockout → objective/boss → playable level → procedural generation → final art → polish/QA → release**.

Pencarian asset berjalan bersama prototype. Tidak perlu menunggu seluruh dekorasi, musik, atau model final untuk mulai menguji gameplay. Asset yang belum tersedia menggunakan placeholder dengan ID dan peran yang sama.

- [Asset Inventory](ASSET_INVENTORY.md): daftar kebutuhan, kandidat sumber, status file, animasi, dan pemeriksaan kelengkapan.
- [Acceptance Checklist](ACCEPTANCE_CHECKLIST.md): skenario pengujian yang harus dibuktikan sebelum release.
- [Development Setup](../kebutuhan-development.md): versi Godot, menjalankan project, MCP opsional, dan export.

## Tracking Rules

1. `[ ]` berarti belum selesai. `[x]` hanya dipakai ketika hasil ada dan syarat selesai telah diperiksa. Pekerjaan parsial tetap `[ ]` dan dicatat pada log.
2. Sebelum bekerja, baca status Git, tracker, inventaris, dan spesifikasi sistem terkait. Pilih tugas yang dependensinya sudah terpenuhi.
3. Catat PIC dan hasil setiap sesi pada **Work Log**. Sertakan path scene/script, hasil uji atau screenshot/log, serta commit. Jangan mencentang pekerjaan hanya karena kode ditulis atau ZIP berhasil diunduh.
4. Setelah selesai, perbarui checkbox, inventaris asset bila relevan, skenario acceptance yang diuji, lalu posisi **Tahap aktif/Pekerjaan berikutnya**. Commit perubahan implementasi dan tracking yang saling terkait.
5. Jika asset atau sistem yang sudah diterima diganti, buka kembali pemeriksaan yang terdampak. Jangan mempertahankan centang lama untuk hasil yang belum diuji ulang.
6. Angka dan aturan yang belum dipilih pada desain dicatat sebagai **baseline prototype**, beserta alasan dan hasil uji. Perubahan desain inti diperbarui ke dokumen konsep sebelum dianggap final.

## Iterasi kecil dan persetujuan pengguna (historis)

**Historis:** aturan review satu iterasi pada 21 November. Pada 22 November pengguna mengizinkan seluruh backlog dikerjakan otonom, commit per milestone terverifikasi dan push tanpa gate review sela. Tuning konservatif boleh; kontrol yang diterima tidak boleh diregresikan.

1. Sebelum mengerjakan iterasi, sepakati scope dan cara pengguna mengujinya. Jangan menjalankan beberapa iterasi sekaligus tanpa persetujuan; batch I06–I08 (sudah selesai, kini superseded) adalah pengecualian lama, bukan izin yang berlaku sekarang.
2. Agent implementasikan hanya scope tersebut, jalankan pemeriksaan paling sempit dan buktikan permukaan visual bila berubah, lalu catat hasil serta batas verifikasinya.
3. Commit implementasi dan tracking yang saling terkait, lalu push ke `main`. Satu iterasi dapat memiliki commit perbaikan tambahan, tetapi jangan campur fitur iterasi berikutnya atau rewrite riwayat yang sudah dipush.
4. Serahkan hash commit, scene/cara menjalankan, serta checklist singkat untuk pengguna. Pengguna menguji kenyamanan dan kecocokan; lolos pemeriksaan agent tidak berarti disetujui pengguna.
5. **Berhenti menunggu tanggapan pengguna.** Jika perlu revisi, perbaiki iterasi aktif, kirim commit perbaikan, dan ulangi review. Lanjut hanya setelah pengguna menyatakan hasilnya oke.

### Batch pertama: asset lab → pemain dan kamera

| Iterasi | Rencana commit | Scope minimum | Yang diperiksa pengguna |
|---|---|---|---|
| I01 | `feat(asset-lab): add static asset comparison scene` | Scene `scenes/tests/asset_lab.tscn` berisi kandidat pemain, musuh, golem, pohon, batu, dan pilar; lantai, kamera tetap, lighting, label serta skala pembanding. Tidak mengubah main scene, gameplay atau bentuk asset. | Jalankan F6: model terlihat, ukuran relatif masuk akal, warna cukup serasi; pilih pemain dasar. |
| I02 | `feat(asset-lab): preview selected character animations` | Preview idle, walk/run dan satu serangan pada karakter terpilih; mapping serta loop yang relevan. Tidak retarget Mixamo, menambahkan combat atau mengubah bentuk model. | Gerak tidak merusak pose, animasi terbaca, senjata dapat ditempatkan pada tangan. |
| I03 | `feat(player): add camera-relative ground movement` | Arena uji sederhana dengan lantai/collision, kamera tetap, InputMap gerak dan pemain yang bisa berjalan/berhenti/berputar; angka movement dicatat sebagai baseline. | WASD responsif, arah sesuai kamera, pemain tidak menembus lantai atau tembok uji. |
| I04 | `feat(player): add jump gravity and landing` | Lompat, gravitasi, grounded/fall/landing, serta obstacle kecil untuk uji; tanpa combat. | Tinggi/jarak lompat dan landing nyaman; tidak bisa lompat berulang di udara. |
| I05 | `feat(camera): add elevated smooth follow` | Kamera Perspective elevated follow dengan damping posisi/ketinggian; tidak otomatis berputar mengikuti gerak atau attack. | Framing pemain, mengikuti lompatan, dan gerakan kamera nyaman. |
| I06 | `feat(camera): add hold-to-orbit controls` | **Superseded:** orbit MMB-hold diganti mouse-look selalu tertangkap. Semula: orbit horizontal/vertikal terbatas saat MMB ditahan, cursor capture/release serta focus loss. | Arsip; kontrol aktif lihat [Revisi kontrol kamera](#revisi-kontrol-kamera-21-november-2026). |
| I07 | `feat(camera): avoid world geometry occlusion` | Camera probe/collision, exclude pemain, dan pengembalian jarak kamera secara mulus. | Kamera tidak menembus tembok/tanah dan tidak bergetar saat dekat obstacle. |
| I08 | `feat(player): add mouse-world aiming` | **Superseded, dihapus:** mouse-world aiming dan `MouseWorldAim` diganti karakter menghadap arah gerak; melee kelak menghadap karakter, tanpa lock-on. Semula: aiming ke permukaan dengan fallback cursor miss; belum ada serangan. | Arsip. |

**Gate aktif:** implementasi otonom disetujui pengguna. Full-input playthrough telah mencapai ending pada renderer nyata dan executable release; penerimaan visual/feel oleh pengguna dan sign-off distribusi tim tetap terpisah.

Polish shader dikerjakan **setelah gameplay inti stabil**, sebelum regresi/export akhir. Pertahankan palet pengguna dan Compatibility; nilai visual serta frame time diuji bersama, bukan menambah efek berat di tengah prototype.

### Iterasi melee satu hit

Scene `scenes/tests/melee_lab.tscn`: klik kiri satu swing, mulai grounded dan tidak lompat saat swing. **Movement full speed, rotasi bebas selama swing, hitbox mengikuti arah hadap terkini**, kaki idle/jalan diblend dengan swing upper-body. Klip `Melee_1H_Attack_Slice_Horizontal` panjang `1,3667 s`; window aktif rasio `0,15–0,30` (~`0,205–0,410 s`). Dummy 60 HP, damage 20/swing; R mengulang lab.

Runtime Godot 4.7.2 Compatibility membuktikan hold tidak mengulang; dua hurtbox satu pemilik tidak menggandakan damage; target belakang/di luar jangkauan dan di balik world wall tidak kena; HP `60→40→20→0`, death sekali dan label KO. Klik GUI Lanjutkan tidak menyerang. [Bukti](evidence/melee-review.png). Belum combo/stamina/AI; arah visual dan timing masih perlu review pengguna.

Revisi layering teruji di runtime Godot 4.7.2 Compatibility: `AnimationTree` memakai base locomotion dan OneShot swing dengan filter spine/upper-body, tanpa hips/legs. Kecepatan berjalan dan saat menyerang sama-sama `4 m/s`; pose upperleg/lowerleg/foot dan upperarm/lowerarm/hand berubah bersamaan selama swing. Facing tetap terkunci, hit tetap satu kali (HP 60→40), pause membekukan jam serangan dan recovery selesai. [Preview layering](evidence/layered-melee.png). Kenyamanan blend masih menunggu review pengguna.

Revisi rotasi: runtime membuktikan arah berubah `1,428 rad` saat swing masih aktif, kecepatan tetap `4 m/s`, dan arah hitbox selaras dengan karakter. Aturan lock arah pada bukti sebelumnya sudah diganti.

### Tuning fast-paced dan preferensi lokal

Default gerak `6 m/s`, sprint Shift `9 m/s`, dodge Alt `12 m/s / 0,25 s` dengan iframe `0,18 s`; sprint memakai animasi Running_A dan debu/jejak ringan world-space. Default tiap swing `0,2 s`; TimeScale hanya pada cabang attack, active window/combo dinormalisasi, locomotion kaki tetap independen.

Esc → Pengaturan: slider gerak, sprint, durasi swing `0,1–0,6 s`, sensitivitas dan jarak kamera; Terapkan menyimpan ConfigFile lokal, Reset Default menyiapkan default untuk diterapkan. Swing aktif tidak di-retime; perubahan mulai swing berikutnya.

Runtime Godot 4.7.2 Compatibility membuktikan gerak 6/sprint 9, Running_A, sprint tetap saat menyerang, Alt dodge; timescale `6,8333×` memainkan klip pertama penuh dalam 0,2 s, combo tiga hit memberi 75 damage tepat satu per swing dan layer selesai. GUI diuji dengan klik tombol dan keyboard slider: Apply, file save, reload scene dan Reset Default lolos; mengganti durasi 0,2→0,3 saat pause tidak mengubah ayunan aktif. [Sprint](evidence/fast-sprint.png) · [Pengaturan](evidence/preferences-menu.png). Batch ini sudah dipush; review arena lama tetap historis.

### Revisi kontrol kamera (21 November 2026)

Disetujui pengguna dan diimplementasikan; review dilakukan di `scenes/tests/third_person_lab.tscn` (menggantikan `aiming_lab.tscn`; `MouseWorldAim` dihapus).

- Mouse selalu tertangkap dan memutar kamera; tanpa MMB. Pitch `20°–65°`, sensitivitas `0,003` dipertahankan.
- WASD relatif kamera; karakter menghadap arah gerak, S berbalik menghadap kamera.
- Scroll zoom: awal `11,4 m`, minimum `4 m`, maksimum `14 m`, langkah `1 m`. Setelah review pengguna, auto-zoom/collision obstacle **dimatikan pada scene third-person**; follow tetap aktif. Pemain tertutup obstacle dan kamera menembus geometri diterima. Runtime membuktikan jarak tetap `11,402 m` dengan/tanpa tembok dan scroll mengubahnya ke `10,402 m`.
- Esc menjeda arena nyata, menampilkan cursor dan tombol Resume. Kehilangan fokus menjeda tanpa menangkap ulang otomatis.
- Melee kelak menghadap karakter; tanpa mouse-ground aim dan tanpa lock-on.
- **Bukti runtime:** Godot 4.7.2 Compatibility/OpenGL, Radeon RX 5500M, 1280×720. Event input disuntikkan pada jendela terfokus: mouse tanpa MMB mengubah yaw, idle look tidak memutar karakter, W mengikuti kamera, S berbalik menghadap kamera; pitch 20°–65° dan zoom 4–14 m ter-clamp (arm kembali ke `13,987 m`). Sphere kamera bebas overlap pada posisi uji. Esc membekukan movement dan input kamera/zoom; kehilangan fokus tetap dijeda sampai Esc atau klik tombol Lanjutkan yang benar-benar diuji lewat GUI. Overlay diperiksa visual. [Arena](evidence/mouse-look-review.png) · [Pause](evidence/mouse-look-pause.png). Belum verifikasi controller fisik, terrain/slope/canopy/boss atau kenyamanan pengguna; A01–A03 tetap tidak dicentang penuh.

### Bukti lama batch I06–I08 (superseded)

- **I06 (superseded):** event mouse yang disuntikkan ke runtime membuktikan MMB capture, yaw, pitch clamp 65°, release dan focus-out/focus-in tanpa recapture. Arah model tetap selama orbit. Right-stick event sintetis membuktikan deadzone, rotasi dan neutral; controller fisik belum diuji. Bukti MMB tidak berlaku untuk kontrol baru.
- **I07:** sphere kamera bebas overlap pada sapuan yaw dekat batas arena. Tembok tinggi memperpendek arm ke `2,034 m`; setelah dihapus, arm kembali bertahap (`4,227 m` awal, `11,393 m` setelah settling). [Screenshot](evidence/i07-blocked.png).
- **I08 (superseded):** hit platform menghasilkan titik sekitar `(2,001; 0,800; 3,495)`; model membidik independen dari body saat WASD. Ray miss nyata memakai bidang kaki dengan cap 50 m; focus loss menyembunyikan marker. Fitur ini dihapus. [Screenshot](evidence/i08-surface.png).
- Uji lama berjalan pada **Godot 4.7.2, Compatibility/OpenGL, Radeon RX 5500M, 1280×720**, bukan headless. Harness sementara tidak menjadi test produksi. Belum ada attack, terrain, slope, canopy, boss atau pengujian kenyamanan pengguna; A01–A03 tidak dicentang penuh.

## Baseline Audit (historis, 17 November 2026)

Audit membaca file repository, tidak menjalankan ulang Godot atau MCP. Folder cache, addon, laporan, dan hasil export dikecualikan dari pencarian asset gameplay.

- [x] **B00-01** `project.godot` tersedia dan main scene menunjuk ke `scenes/main.tscn`.
- [x] **B00-02** `godot-version.txt` menetapkan Godot **4.7.2 Standard**; bahasa GDScript dan renderer Compatibility tercatat.
- [x] **B00-03** Main scene berisi environment, lighting, permukaan preview, dan kamera preview. Ini belum terrain atau kamera gameplay.
- [x] **B00-04** Git, panduan tim, preset Windows, dan addon editor MCP tersedia sebagai file. Status koneksi MCP saat ini belum diuji ulang.
- [x] **B00-05** Spesifikasi dua puzzle, exploration challenge, kamera, dan boss tersedia pada `docs/desain/`.
- [x] **B00-06** Audit tidak menemukan model `.glb/.gltf/.fbx/.obj/.blend`, audio game, atau script gameplay `.gd` di luar folder yang dikecualikan. Hanya satu scene gameplay foundation ditemukan.

## Milestones

| Milestone | Syarat selesai | Tahap |
|---|---|---|
| M1: Interaction Prototype | Karakter dapat bergerak relatif kamera, melompat, mouse-look, zoom, menyerang, bertahan, minum potion, dan mencoba ulang di test arena | P01–P08 |
| M2: Completable Level | Ketiga artefak, dua puzzle, pendakian, boss, retry, dan ending tersambung dalam satu run pada blockout tetap | P09–P14 |
| M3: Procedural Content Complete | Pulau berbasis seed valid, asset wajib terintegrasi, UI/audio/narasi tersedia | P15–P17 |
| M4: Release Candidate | Acceptance, performance, fresh clone, dan standalone build lolos; paket distribusi tersedia | P18–P20 |

## P01 — Asset Discovery & Collection

Dependensi: audit awal. Hasil: shortlist dan sampel yang dapat diuji, bukan kumpulan unduhan tanpa pemetaan kebutuhan.

- [x] **P01-01** Susun kebutuhan dan kandidat sumber resmi pada [Asset Inventory](ASSET_INVENTORY.md); bedakan sumber yang diperiksa dari file yang sudah tersedia.
- [x] **P01-02** Pilih satu kandidat utama karakter/animasi dan satu kandidat environment. Bandingkan proporsi, warna, bentuk low-poly, serta rig dengan concept art sebagai arah visual. — KayKit Adventurers + Character Animations + Forest + Dungeon (keputusan pengguna 20 Nov 2026); boss Rock Golem gratis.
- [x] **P01-03** Ambil sampel resmi: satu karakter, animasi locomotion/attack, satu senjata, pohon, batu, dan modul reruntuhan. Gunakan tier gratis yang memang memuat kebutuhan tersebut; biaya atau paket tambahan bukan dependensi otomatis.
- [x] **P01-04** Untuk setiap sampel, catat URL halaman/download, pembuat, nama paket/versi, tanggal, lisensi, file lisensi lokal, dan hash arsip pada inventaris. — [ASSET_DOWNLOADS](ASSET_DOWNLOADS.md)
- [x] **P01-05** Jalankan pencarian/scraping katalog hanya untuk kebutuhan yang belum tertutup. Gunakan download/API resmi yang tersedia; jangan melewati login atau paywall. Download massal tidak menggantikan pemeriksaan isi paket.
- [x] **P01-06** Tandai kebutuhan khusus yang perlu dibuat sendiri: pilar/relief simbol, panel energi, segel, altar, gate sockets, checkpoint, shortcut, dan boss bila paket tidak sesuai. — status `TURUNAN` di [Rencana Sumber Asset](ASSET_SOURCE_PLAN.md)

**Exit:** semua kebutuhan punya kandidat atau rencana custom/fallback; sampel minimum tersedia untuk P02. Asset yang belum diunduh tetap berstatus `MISSING`.

## P02 — Import & Asset Readiness

Dependensi: sampel P01. Test scene yang direncanakan: `scenes/tests/asset_lab.tscn`.

- [ ] **P02-01** Buat struktur `assets/third_party/`, `assets/custom/`, `scenes/`, `scripts/`, `resources/`, dan test scene sesuai kebutuhan. Simpan arsip besar/cache kerja di luar resource game yang diexport. — Parsial: `scenes/tests/asset_lab.tscn` dan `assets/third_party/` tersedia. I01 berupa scene statis tanpa script/resource terpisah; folder kosong yang belum dipakai tidak dibuat.
- [x] **P02-02** Import model dan material. Utamakan glTF/GLB yang tersedia; jika perlu konversi FBX/Blend, catat alat/versi dan simpan sumber yang boleh dibagikan. Periksa dependency `.bin` dan texture. — 1.281 file ter-import tanpa error; golem dikonversi Blender 4.5.16 LTS, sumber `.blend` disimpan dengan `.gdignore`.
- [ ] **P02-03** Uji skala, arah depan, pivot, material, normal, texture, dan silhouette dari kamera permainan. Tetapkan satu skala referensi karakter untuk seluruh kit.
- [ ] **P02-04** Uji skeleton, bone attachment, animasi, loop, transisi, serta in-place/root motion. Buktikan retargeting pada karakter terpilih sebelum bergantung pada library animasi.
- [ ] **P02-05** Buat wrapper/inherited scene karakter dan prop agar reimport tidak menimpa script, collision, animation mapping, dan material override gameplay.
- [ ] **P02-06** Cocokkan daftar clip nyata dengan tabel animasi inventaris. Siapkan animasi custom untuk clip yang tidak ada, terutama potion dan tiga pola boss.
- [ ] **P02-07** Periksa collision karakter, ground, batu, tangga, reruntuhan, dan kamera. Mesh dekoratif tidak otomatis menjadi collision yang sesuai.
- [ ] **P02-08** Perbarui path file/scene, bukti uji, lisensi, dan status sampel. Isi `THIRD_PARTY_NOTICES.md` untuk asset yang benar-benar masuk repo.

**Exit:** satu set visual/rig minimum terbukti bisa dipakai. Bila sampel gagal, ganti kandidat atau gunakan placeholder yang kompatibel agar prototype tidak berhenti. Kelengkapan final tetap diperiksa di P16.

## P03 — Runtime Foundation

Dependensi: project foundation. Dapat dimulai saat P01–P02 berlangsung.

- [ ] **P03-01** Buka project dengan versi yang dipin; jalankan main scene dan headless import. Jika memakai MCP, verifikasi bridge; game tetap harus berjalan tanpa MCP.
- [ ] **P03-02** Siapkan boot/main gameplay scene, test arena, dan mode debug terpisah. Preview lama tidak dihitung sebagai world gameplay.
- [ ] **P03-03** Definisikan InputMap untuk move, jump, attack, block, dodge, interact, potion, pause, mouse-look, scroll zoom, dan right-stick look. Rincian tombol ditulis sebagai baseline yang bisa diubah.
- [ ] **P03-04** Definisikan collision layers/masks untuk world, player, enemy, hitbox, hurtbox, projectile, interaction, dan camera probe.
- [ ] **P03-05** Buat resource konfigurasi untuk movement, attack, stamina, HP, potion, dan enemy. Simpan angka tuning di satu tempat yang mudah diubah.
- [ ] **P03-06** Siapkan session state sederhana dengan seed dan stable IDs untuk objective, artifact, checkpoint, enemy, serta shortcut. Pisahkan data progres dari instance scene.
- [ ] **P03-07** Catat baseline yang masih terbuka pada tabel **Prototype Decisions** sebelum perilakunya dipakai lintas sistem.

**Exit:** test arena bisa dijalankan dan input, collision, konfigurasi, serta session state memiliki tempat yang jelas. Tidak diperlukan framework umum di luar kebutuhan Level 1.

## P04 — Player Movement, Camera & Aiming

Dependensi: P03; gunakan placeholder atau karakter yang lolos P02. Acuan: [Camera Design](../desain/kamera-perspective-follow.md).

- [ ] **P04-01** Implementasikan movement, gravity, jump, grounded/fall/landing, collision, dan death volume. Uji tangga, slope, gap pendek, dan lereng sebelum world diperbesar.
- [x] **P04-02** Implementasikan kamera Perspective elevated follow dengan damping posisi dan ketinggian, tanpa rotasi otomatis mengikuti arah attack. — I05 follow tersedia; I06–I08 tidak menambahkan auto-yaw. Attack belum tersedia.
- [x] **P04-03** Implementasikan mouse-look selalu tertangkap (yaw 360°, pitch `20°–65°`, sensitivitas `0,003`), scroll zoom `4–14 m` (awal `11,4 m`, langkah `1 m`), Esc pause + Lanjutkan, dan right-stick. — Runtime mouse/zoom/pause lolos dan kamera diterima pengguna; right stick hanya diuji sintetis, controller fisik belum tersedia.
- [x] **P04-04** Revisi pengguna: matikan auto-zoom kamera karena obstacle pada scene third-person; zoom hanya lewat scroll. — Runtime dengan/tanpa tembok mempertahankan jarak. Implementasi collision I07 tetap hanya pada lab pembanding; occlusion/clipping gameplay diterima.
- [ ] **P04-05** Implementasikan WASD relatif kamera dengan karakter menghadap arah gerak (S menghadap kamera) sebagai dasar arah melee; tanpa mouse-ground aim dan tanpa lock-on. — Mouse-world aiming I08 dihapus. Terrain/attack belum dibuat; menunggu runtime check dan review.
- [ ] **P04-06** Uji Esc pause/Resume, focus loss tanpa recapture otomatis, cursor visible/captured, zoom bounds, dan perilaku input attack saat combat dikerjakan (setelah izin pengguna).
- [ ] **P04-07** Uji framing simbol puzzle, musuh, gap, serta boss telegraph melalui test objects. Tuning FOV, follow distance, dan pitch berdasarkan hasil ini.

**Exit:** player dan kamera nyaman dipakai pada test arena, termasuk jump dan orbit di dekat obstacle; jalankan A01–A03.

## P05 — Interaction & Combat Primitives

Dependensi: P03–P04.

- [x] **P05-01** Deteksi satu interactable terdekat yang valid, range/LOS, prompt E dan pembatasan state pemain tersedia; pickup/checkpoint diuji runtime.
- [x] **P05-02** Health/damage dan death sekali tersedia; damage musuh melalui `player.receive_damage()` agar defense/potion tidak dilewati.
- [x] **P05-03** Hurtbox dan daftar korban per swing tersedia; dua hurtbox satu pemilik terbukti tidak menggandakan hit.
- [ ] **P05-04** Definisikan state minimum player: locomotion, attack, block, dodge, potion, hurt/dead. Tetapkan prioritas serta pembatalan berdasarkan desain, bukan urutan callback kebetulan.
- [ ] **P05-05** Siapkan debug HP/stamina, hitbox, state, dan target interaksi yang dapat dimatikan untuk build pemain.

**Exit:** dummy dapat menerima satu hit yang benar, mati sekali, dan interaksi tidak terpicu ganda; jalankan A04.

## P06 — Player Combat, Defense & Potion

Dependensi: P05 dan mapping animasi minimum P02. Acuan: bagian combat/resource pada [konsep](../konsep-game.md).

- [x] **P06-01** Combo tiga hit berbasis press dalam timing window tersedia; early input dibuang dan hold tidak mengulang. Runtime damage 20+20+35 lolos.
- [x] **P06-02** Rotasi bebas, full-speed movement dan upper-body swing + kaki locomotion tersedia; attack tetap memiliki prioritas atas block/dodge.
- [ ] **P06-03** Sinkronkan animasi dan active hit window; attack tidak memakai stamina. Uji seluruh rangkaian terhadap dummy bergerak.
- [x] **P06-04** Stamina bersama block/dodge, drain/cost, regen delay, refusal dan clamp tersedia dan diuji runtime. Sprint tidak menambah drain stamina.
- [ ] **P06-05** Implementasikan block yang mengurangi damage semua arah dan dodge i-frames untuk melee, projectile, serta boss. Pisahkan collision fisik dari invulnerability.
- [ ] **P06-06** Implementasikan inventory potion terbatas, pickup/drop, HUD quantity, dan penggunaan manual. Angka kapasitas/heal/drop merupakan baseline playtest.
- [x] **P06-07** Animasi minum authored 1,5 s dengan movement ×0,5 tersedia; hit membatalkan tanpa konsumsi, heal 40 dan konsumsi satu hanya saat completion. Attack/dodge dapat membatalkan channel, bukan berjalan bersamaan.
- [ ] **P06-08** Uji interaksi potion dengan block/dodge, death, damage pada frame completion, pause, dan pemakaian berturut-turut sesuai baseline yang dicatat.

**Exit:** combat bisa dimainkan dengan resource yang konsisten, bukan hanya animasi yang terlihat; jalankan A05–A08.

## P07 — Enemy Archetypes

Dependensi: P05–P06. Model dapat berbagi rig/fondasi AI, tetapi perilaku harus berbeda.

- [ ] **P07-01** Buat state idle/patrol bila diperlukan, detect, approach, wind-up, attack, recovery, hurt, dan dead. Tetapkan detection, chase/leash, dan obstacle handling sebagai baseline.
- [x] **P07-02** Standard melee approach/single swing/recovery tersedia; encounter runtime memberi 12 damage setelah telegraph.
- [x] **P07-03** Heavy lambat/telegraph panjang/strong hit/recovery panjang tersedia; encounter runtime memberi 32 damage.
- [x] **P07-04** Ranged windup dan projectile lurus non-homing tersedia; encounter memberi 10 damage dan cover menyerap projectile.
- [x] **P07-05** Ownership damage player/enemy terpisah; projectile mengecualikan shooter, friendly fire antarmusuh nonaktif.
- [ ] **P07-06** Terapkan stagger menurut tipe melalui konfigurasi. Jangan menganggap semua hit dapat membatalkan attack heavy atau boss.
- [ ] **P07-07** Uji encounter satu melee dan satu melee + satu ranged pada ruang yang mendukung movement, block, dan dodge. Validasi batas awal dua musuh aktif di rute pendakian.

**Exit:** ketiga archetype dapat dilawan, dibaca, dan diselesaikan; jalankan A09–A10. Jangan menambah tipe musuh lain untuk menutupi masalah tuning.

## P08 — Session Progress, Checkpoints & Retry

Dependensi: P03, P05–P07. Aturan boss mengikuti [snapshot specification](../desain/boss-penjaga-gerbang.md).

- [x] **P08-01** Solved puzzle dan collected artifact memakai dictionary terpisah dengan stable IDs; solved-but-uncollected, pickup sekali dan rebuild modul diuji.
- [x] **P08-02** Checkpoint dan respawn eksplorasi tersedia: jeda 2 s, teleport aman, HP/stamina penuh serta reset transient.
- [x] **P08-03** Potion tersisa dipertahankan; checkpoint tidak memberi heal/potion gratis. Runtime pemakaian 5→4 lalu death/respawn mempertahankan 4 lolos.
- [x] **P08-04** Killed IDs bertahan untuk semua musuh eksplorasi selama sesi, termasuk pendakian. Musuh hidup reset ke spawn saat respawn; pickup tetap satu kali. Baseline ini sengaja berlaku untuk seluruh pulau.
- [x] **P08-05** Snapshot tepat sebelum aktivasi pertama/wake, bukan sesudah regen selama wake. HP70/stamina45/potion5 tidak ditimpa retry.
- [x] **P08-06** Retry menetapkan resource snapshot tepat, boss penuh/fase1, serta membersihkan attack/telegraph. Tiga kegagalan berulang lolos regression.
- [x] **P08-07** Menang mempertahankan resource dan membuang snapshot. Tidak ada keluar sukarela dari arena aktif; Esc hanya pause, quit membuang sesi. Tidak ada pickup resource di arena retry.
- [ ] **P08-08** Uji death saat attack, dodge, potion, interaction, dan projectile aktif; respawn tidak boleh memicu damage lama atau interaksi ganda.

**Exit / M1:** test arena mendukung combat, interaksi, dan retry yang dapat diulang; jalankan A11–A13.

## P09 — Fixed World Blockout

Dependensi: movement/camera dan ukuran karakter terbukti. Belum memasukkan variasi procedural penuh. *Catatan:* bagian ini mencatat blockout baseline historis; layout prosedural saat ini dicatat di P15 dan Start Here.

- [x] **P09-01** Pulau baseline 250 × 250 m, spawn Grassland, cabang Forest/Rocky Highlands, pad gerbang dan dock: `scripts/world/island_terrain.gd`.
- [x] **P09-02** Delapan rute, cabang alternatif, landmark, viewpoint dan koneksi antarpad tersedia; flood fill membuktikan pad artefak tidak membutuhkan pad lain lebih dahulu.
- [x] **P09-03** Pad objective rata, ruang encounter, collision terrain dan clearance tersedia. Traversal internal objective diuji terpisah pada P10–P12.
- [x] **P09-04** Graph rute + flood fill heightfield, slope dan obstacle clearance divalidasi; rute dunia tidak membutuhkan jump. Jump internal summit milik P12.
- [x] **P09-05** Player fisika berjalan seluruh 8 rute dua arah pada baseline dan seed 404/5555: 16/16 per layout, tanpa teleport di tengah rute, jatuh atau stall. Rute terpanjang 150 m sekitar 22,7 s; bukti `evidence/terrain/traversal*.txt`.

**Exit:** seluruh lokasi wajib terjangkau pada map tetap dengan placeholder. Jangan memakai landscape visual sebagai bukti collision dan akses sudah benar.

## P10 — Puzzle 01: Symbol Pillars

Dependensi: P05, P08–P09. Acuan: [Pilar Simbol](../desain/puzzle-01-pilar-simbol.md).

- [x] **P10-01** Empat bentuk pilar, relief permanen, segel collision dan artefak tersedia pada modul reusable.
- [x] **P10-02** Solusi `[2,0,3,1]` dan clue satu sumber; 24 permutasi dan input acak diperiksa melawan model independen.
- [x] **P10-03** Urutan benar melepas segel; salah mereset tanpa HP/potion loss atau cooldown panjang.
- [x] **P10-04** Tidak ada musuh di area puzzle; bentuk/clue diperiksa dari screenshot kamera gameplay 1280 × 720. Penilaian agent, bukan review pengguna.
- [x] **P10-05** Solved-but-uncollected, collected, death/respawn dan rebuild modul mempertahankan state tanpa duplikasi.

**Exit:** A14 lolos dan modul dapat ditempatkan ulang tanpa kehilangan petunjuk atau akses.

## P11 — Puzzle 02: Energy Path

Dependensi: P05, P08–P09. Acuan: [Jalur Energi](../desain/puzzle-02-jalur-energi.md).

- [x] **P11-01** Tiga panel, kristal sumber, altar, segel dan artefak berada di modul terkontrol.
- [x] **P11-02** Port lurus/siku dan orientasi 90° diperiksa dengan trace independen pada seluruh 64 susunan; dua solusi valid.
- [x] **P11-03** Satu putaran per interaksi, input reentry ditolak selama tween, prefix aliran mengikuti konektivitas.
- [x] **P11-04** Koneksi lengkap membuka segel; ukiran/chevron dan cahaya tidak bergantung suara saja. Tidak ada timer/damage/batas percobaan.
- [x] **P11-05** Starting `[0,1,2]` dapat diselesaikan enam press menjadi `[1,3,1]`; 64 kombinasi dan persistence teruji.

**Exit:** A15 lolos; perubahan penempatan/seed tidak membuat modul kehilangan solusi.

## P12 — Exploration Challenge: Summit Route

Dependensi: P07–P09. Acuan: [Jalur Menuju Puncak](../desain/exploration-03-jalur-menuju-puncak.md).

- [x] **P12-01** Kaki bukit/checkpoint, tebing, courtyard, puncak dan viewpoint tersedia; origin modul dipisah dari arena boss ke `(0,0,-50)`.
- [x] **P12-02** Satu melee kaki dan melee+ranged courtyard, cover serta bypass tersedia; foot guard dijauhkan dari kolong jembatan/leash.
- [x] **P12-03** Gap nyata 3 m dengan beda tinggi 0,4 m dilalui player fisika lewat input lompat. Tanpa lompat player jatuh; combat tidak dipaksa di gap.
- [x] **P12-04** Artefak tidak memerlukan solved puzzle atau kill seluruh penjaga; bypass courtyard teruji, full run hanya membunuh satu guard.
- [x] **P12-05** Tuas puncak membuka jembatan collision persisten. Turun/naik dan exit kaki diuji; rel rendah yang menjepit kapsul dihapus.
- [x] **P12-06** Fall/checkpoint, killed IDs, shortcut dan jalur pulang diuji. Lane bawah R4 x=1,5 memiliki clearance >=3,95 m dan terhubung ke boss.

**Exit:** A16 lolos, termasuk run tanpa membunuh semua penjaga.

## P13 — Boss: The Gatekeeper

Dependensi: P06–P09 dan ruang arena. Acuan: [Penjaga Gerbang](../desain/boss-penjaga-gerbang.md).

- [x] **P13-01** Arena rata, checkpoint, tiga socket artefak unik dan aktivasi altar tersedia.
- [x] **P13-02** Wake authored, arena lock, state dan telegraph dengan target lock tersedia; snapshot diambil sebelum wake.
- [x] **P13-03** Sweep/slam/charge memberi damage 24/38/30; block 6/10/8, dodge menghindar dalam uji timing. Pylon memotong telegraph dan damage.
- [x] **P13-04** Threshold 50% tepat masuk fase2; rangkaian tambahan mempertahankan windup/telegraph dasar.
- [x] **P13-05** Recovery slam 2,4 s menyediakan kesempatan combo. Full input run mengalahkan boss tanpa menggunakan potion.
- [x] **P13-06** Snapshot retry berulang mempertahankan socket/progres, boss kembali penuh/fase1 tanpa mengulang wake.
- [x] **P13-07** Boss runtuh, gerbang terbuka dan crossing dock memicu completion sekali; dibuktikan state regression serta full-input run.
- [x] **P13-08 (kontrak baru, 25 Nov 2026)** Boss fase 1 = dua pukulan beruntun, fase 2 (HP ≤ 50%) = dua atau tiga pukulan; windup cepat/tertunda, telegraph baru per pukulan, recovery penuh di akhir, pemilihan serangan sadar-jarak. HP 420, damage 24/38/30, ambang 50% tidak berubah. Terbukti: `boss_pattern` 122/0 + playthrough dirender seed 42 PASS (boss fase 2). Pemeriksaan manual feel/kesulitan terbuka.
- [x] **P06-baru (kontrak baru, 25 Nov 2026)** Blok: tiap hit diblok memakai stamina `max(8, damage × 0,8)`; kurang → guard break; terbayar → 25% omni-arah; kontrol dan UI tidak berubah. Terbukti: `combat_edge` 269/0 (harness). Feel manual terbuka.
- [x] **P07-baru (kontrak baru, 25 Nov 2026)** Standard combo dua pukulan; heavy pendekatan dipercepat + sapuan lebar tertunda; ranged semburan tiga tembakan; telegraph baru, kunci terlambat, recovery terbatas; HP/damage baseline tidak berubah. Terbukti: `enemy_pattern` 72/0 + playthrough dirender PASS. Kesulitan subjektif terbuka.

**Exit:** A17–A19 lolos tanpa musuh tambahan atau pola boss di luar desain.

## P14 — Completable Level Integration

Dependensi: P09–P13.

- [x] **P14-01** Spawn, objective, encounter, checkpoint, gerbang, boss dan ending terhubung di main scene.
- [x] **P14-02** Keenam urutan pickup melalui Interactor asli memberi tiga ID unik dan entitlement gerbang sama.
- [x] **P14-03** Death solved-but-uncollected/collected/shortcut dan retry mempertahankan progres; regression state memakai teleport dan bukan bukti traversal.
- [x] **P14-04** Respawn mempertahankan instance/seed; New Run membuat session kosong dan melepas root lama sebelum root baru.
- [x] **P14-05** Full-input run tanpa noclip/teleport/item injection mencapai ending: renderer nyata 120,6 s simulasi dan executable release 119,8 s simulasi, tanpa death/potion terpakai.

**Exit / M2:** satu level lengkap bisa ditamatkan. Ini menjadi pembanding sebelum P15 mengubah terrain/penempatan.

## P15 — Seeded Procedural Island

Dependensi: traversal P04, route contract P09, dan playable level P14.

- [x] **P15-01** Seed terrain dan dekorasi terpisah; seed sama memberi hash heightfield/rute/obstacle identik, perubahan dekorasi tidak mengubah terrain/rute.
- [x] **P15-02** Mesh vertex-color 201 × 201 dan collision dari triangle sama; coastline, biome, elevasi di luar jalur, pads rata dan rute berkemiringan moderat tersedia.
- [x] **P15-03** Pad summit/boss diperbaiki menjadi rectangular keepout sesuai footprint; overlap lama dan route bawah R4 diperbaiki, seluruh 20 seed data divalidasi ulang.
- [x] **P15-04** Graph/flood fill, slope, footprint, collision dan gap diperiksa. Baseline seluruh rute dilewati player fisika; objective internal dilalui full-input bot.
- [ ] **P15-05** Bangun navigation sesuai terrain/modul, tetapkan perilaku aggro/leash, dan uji melee/ranged pada slope serta cover nyata.
- [x] **P15-06** Maksimum empat kandidat lalu baseline 20261122. Harness forced-invalid benar-benar mencapai fallback valid pada percobaan kelima, tanpa loop tak terbatas.
- [ ] **P15-07** Data/geometry seluruh 20 seed checklist lolos, masing-masing first-attempt; belum full objective/boss run per seed. Bukti `evidence/terrain/data_validation_acceptance.txt`. Matrix tambahan 20 seed lain dicatat terpisah, bukan pengganti matrix acceptance.
- [ ] **P15-08** Uji seed sama setelah reload/respawn, keenam urutan artifact, dan akses shortcut/boss; simpan seed reproduksi setiap kegagalan.

**Exit:** A20–A21 lolos. Generator tidak menyatakan hasil valid jika ada objective wajib yang tidak dapat dicapai.

## P16 — Final Asset Integration

Dependensi: asset lab P02 dan gameplay/world yang sudah terbukti. Pengadaan kebutuhan tersisa berjalan sejak P01.

- [ ] **P16-01** Selesaikan pengadaan/custom modelling seluruh baris `REQUIRED` pada inventaris. Setiap kekurangan punya fallback produksi yang spesifik.
- [ ] **P16-02** Ganti placeholder melalui wrapper scene tanpa mengganti stable ID, collision contract, interaksi, atau state progres.
- [ ] **P16-03** Integrasikan karakter, weapon attachment, semua clip wajib, enemy silhouette, boss, dan feedback hit. Animasi tidak boleh mengubah timing diam-diam.
- [ ] **P16-04** Integrasikan nature, cliffs, ruins, bridge, gate, altar, artifact, potion, checkpoint, dan dermaga. Samakan skala, palette, material, serta lighting.
- [ ] **P16-05** Buat water/sky/lighting dan VFX yang bekerja di renderer Compatibility. Perubahan renderer atau ketergantungan shader baru harus diuji dan didokumentasikan.
- [ ] **P16-06** Uji collision dan kamera setelah visual diganti, termasuk tree canopy, stone walls, panels, boss, dan shortcut.
- [ ] **P16-07** Jalankan pemeriksaan kelengkapan visual akhir: tidak ada asset visual/animasi wajib `MISSING/CANDIDATE/PLACEHOLDER`, missing texture, rig mismatch, atau lisensi yang belum tercatat. UI/audio diselesaikan pada P17 dan Gate C.

**Exit:** Gate B pada inventaris lolos. `DOWNLOADED` dan `IMPORTED` belum cukup untuk menutup tahap ini.

## P17 — UI, Audio & Narrative

Dependensi: session/progression dan gameplay terintegrasi; dapat dikerjakan pada test scenes lebih awal.

- [x] **P17-01** HUD HP/stamina/potion/artefak/prompt mengikuti state nyata; hitung puzzle hanya dua kunci puzzle.
- [x] **P17-02** Menu, seed/New Run, pause/volume, control hints dan completion bekerja; Keluar memakai satu jalur shutdown bersih.
- [x] **P17-03** Intro terdampar, clue lingkungan dan outro dermaga tersedia; compass tidak memaksa urutan artefak.
- [ ] **P17-04** Musik/ambience/SFX terpasang dari sumber berlisensi; mix belum diaudit telinga manusia.
- [ ] **P17-05** Volume tersimpan dan informasi utama memakai bentuk/teks; review mute dan spam SFX oleh manusia belum.
- [x] **P17-06** Label debug musuh dan teks lab tidak tampil di main game; runner QA hanya aktif lewat flag CLI.

**Exit / M3:** A22 lolos dan run dapat dipahami tanpa penjelasan lisan pembuat game.

## P18 — Balancing, Performance & Polish

Dependensi: playable content lengkap.

- [ ] **P18-01** Playtest bersama anggota lain: catat durasi run, waktu perjalanan kosong, kesalahan puzzle, kematian, retry boss, dan bagian kontrol yang membingungkan.
- [ ] **P18-02** Tuning movement, stamina, HP/damage, potion, combo windows, telegraph, recovery, enemy density, dan drop dengan resource konfigurasi. Pertahankan aturan inti desain.
- [ ] **P18-03** Uji keterbacaan puzzle, cover ranged, gap, camera collision, dan boss telegraph pada resolusi target serta volume rendah/mute.
- [ ] **P18-04** Tentukan mesin uji, resolusi, target FPS/frame time, dan anggaran memory/loading sebelum menilai performa. Catat hasil pada seed dan encounter yang sama.
- [ ] **P18-05** Profile terrain, physics, navigation, foliage, transparansi/water, shadows, audio, dan resources. Gunakan optimasi yang didukung hasil pengukuran.
- [ ] **P18-06** Perbaiki bug prioritas: crash, progres macet, objective tidak terjangkau, resource duplikat, input/camera buruk, lalu visual/audio minor. Ulangi acceptance yang terdampak.
- [ ] **P18-07** Polish shader/material, lighting, air dan efek setelah gameplay inti stabil; cocokkan palet pengguna, keterbacaan dan renderer Compatibility. Bandingkan visual serta frame time sebelum/sesudah pada mesin target; hindari efek berat tanpa bukti manfaat.

**Exit:** tidak ada blocker yang diketahui pada alur lengkap; A23 lolos dengan catatan mesin dan build.

## P19 — Full Regression & Standalone Export

Dependensi: P16–P18.

- [ ] **P19-01** Bukti otomatis (historis 22 Nov, kode lama): state regression 36.099/0, combat edge 248/0, 20 seed data, full-input run. **Untuk kode 25 Nov belum ada hasil**; item manusia (controller fisik, audio, komputer lain) juga belum.
- [x] **P19-02** Template 4.7.2 resmi terverifikasi SHA-512; preset Windows `all_resources` mengecualikan addon MCP, docs, tools, tmp dan raw Mixamo. Audit paket 1.393 entri bersih.
- [x] **P19-03** (historis, build `90d2976`) Executable release di luar Editor mencapai ending lewat input QA (119,8 s simulasi), tanpa MCP/server. Tidak berlaku otomatis untuk build 25 Nov.
- [ ] **P19-04** Fresh remote clone di mesin sama: import bersih, full-input, regression 36.099/0, export (buat `exports/windows/` dulu) dan EXE lolos. Satu crash native awal tidak terulang dalam 16 import bersih. Komputer anggota lain belum.
- [ ] **P19-05** Paket offline belum diuji di komputer target lain.

**Exit / M4:** A24–A25 lolos dan semua blocker release ditutup.

## P20 — Release & Handoff

Dependensi: build P19 terbukti.

- [x] **P20-01** ZIP berisi EXE, PLAY, VERSION, notices dan lisensi; isi paket diuji.
- [x] **P20-02** (historis, build `90d2976`) ZIP diekstrak ke path berspasi dan EXE-nya menamatkan level lewat QA input; hash build final lama dicatat di `VERSION.txt` dan README. Build 25 Nov belum punya hash.
- [x] **P20-03** README, inventaris, tracker, acceptance dan handoff diperbarui dengan hasil nyata dan known issues.
- [ ] **P20-04** Lengkapi nama dosen/tahun ajaran laporan, sesuaikan disclaimer AI dan atribusi aktual, lalu export PDF final yang sudah diperiksa.
- [ ] **P20-05** Simpan build/release dan PDF pada tujuan yang dipakai tim; bagikan link kepada pengguna. Pengunggahan tugas ke portal kampus dilakukan jika diminta terpisah.
- [ ] **P20-06** Tandai release selesai setelah anggota lain dapat menjalankan paket dan memahami known issues; arsipkan seed/build reproduksi bug yang belum kritis.

## Prototype Decisions

Bagian ini berisi rincian yang belum final pada desain. Isi hasil eksperimen sebelum menjadikannya kontrak lintas sistem; tidak perlu mengulang brainstorming konsep utama.

| ID | Hal yang harus ditetapkan | Status awal | Bukti/hasil |
|---|---|---|---|
| D01 | Mapping tombol attack/block/dodge/interact; kontrol kamera dan arah melee sudah ditetapkan (mouse-look, WASD relatif kamera, melee menghadap karakter) | PARTIAL | Kontrol kamera: lihat Revisi kontrol kamera; mapping lain OPEN |
| D02 | Angka movement, jump, FOV, damping, pitch, collision margin | OPEN | — |
| D03 | Skeleton utama, model pedang satu tangan, clip mapping, in-place/root motion | PARTIAL | Preferensi KayKit/chibi dengan prioritas kelengkapan ekosistem online; pedang satu tangan tetap. Paket, rig, clip, dan kebutuhan penyesuaian belum diuji |
| D04 | Potion saat block/dodge, hit yang sepenuhnya diblock, dan urutan event hit/completion | OPEN | — |
| D05 | Reset enemy/pickup di luar rute pendakian dan proteksi safe respawn | OPEN | — |
| D06 | Keluar sukarela dari boss, interaksi resource di area retry, dan invalidasi snapshot | OPEN | — |
| D07 | Aggro/leash, stagger, friendly fire, projectile dan navigation pada elevasi | OPEN | — |
| D08 | Angka balancing, ukuran/coverage modul, seed matrix, mesin/target performa | OPEN | — |

Campaign, multiplayer, player ranged/magic, skill tree, miniboss tambahan, serta save lintas level tidak menjadi syarat tracker ini (save lokal Pulau 1 sudah ada; lihat Start Here). Pulau 2/3 belum dibuat. Full gamepad mapping di luar right-stick orbit juga belum menjadi keputusan desain.

## Team Workstreams

Usulan pembagian untuk empat anggota; PIC ditentukan bersama, bukan otomatis menurut urutan nama di cover.

| Stream | Tanggung jawab | Dependency integrasi |
|---|---|---|
| A | Player, camera, aiming, combat, defense | Input/state dan batas traversal disepakati dengan B/C |
| B | Asset pipeline, terrain, biome, navigation, scene dressing | Skala/rig dari P02, route contract P09 |
| C | Puzzle, artifact/session, checkpoint/retry, gate/boss progression | Interaction/damage contract dari A, ruang modul dari B |
| D | Enemy/boss content, UI, audio, QA dan export | Combat primitives A, state C, world B |

Keempat anggota bisa menguji branch anggota lain. Perubahan file pusat seperti `project.godot`, main scene, dan session state dikoordinasikan agar tidak saling menimpa. Pembagian ini tidak mengharuskan empat pekerjaan mengubah scene yang sama sekaligus.

## Work Log

| Tanggal | Task | PIC | Hasil/bukti | Commit | Berikutnya |
|---|---|---|---|---|---|
| 2026-11-17 | B00-01–06, P01-01 | Codex | Audit file repo; inventaris kebutuhan dan kandidat resmi tersedia. Tidak ada download/import asset produksi pada pekerjaan planning ini. | Lihat commit penambahan tracker | P01-02 |
| 2026-11-20 | P01-02 (parsial), D03 (parsial) | OMP | Pengguna menetapkan petualang manusia berpakaian ringan dengan pedang satu tangan, keluarga musuh penjaga kuno, dan boss golem batu berinti energi. [Riset karakter](ASSET_CHARACTER_RESEARCH.md) dan [environment](ASSET_ENVIRONMENT_RESEARCH.md) memuat preview model asli yang sudah dibuka, sumber, lisensi/tier, dan gap; belum ada download paket/import. | — | Tunggu pilihan visual; selesaikan konflik lisensi Quaternius sebelum pengadaan. P01-02 tetap belum selesai |
| 2026-11-20 | P01-02/P01-05 (parsial), D03 (parsial) | OMP | Scan ekosistem selesai sebagai metadata/preview: [audit gabungan](ASSET_ECOSYSTEM_AUDIT.md), register karakter/world/pelengkap, seluruh M01–M28/N01–N12 dipetakan. KayKit Adventurers + Animations + Forest + Dungeon direkomendasikan; legacy/rebrand/tier/bundle dibedakan. Tidak ada download/import/pembelian. | — | Pilih sampel; gap drink, boss/core/clip, guardian identity, glyph/connector/socket dan water/VFX tetap terbuka |
| 2026-11-20 | P01-02 (inti ditetapkan), P01-05/06 (parsial) | OMP | Pengguna menetapkan empat keluarga inti KayKit dan mengizinkan edit basis online. [Rencana sumber](ASSET_SOURCE_PLAN.md) memetakan 54 kebutuhan; exact Drinking/Mixamo dan fallback clip, guardian/golem, rune/track/crystal/water/VFX serta UI/audio ditemukan. Belum download/import/beli; authoring dan retarget belum dilakukan. | — | Pengadaan sampel dengan gate akun/biaya/lisensi eksplisit, lalu proof satu drink dan boss attack; jangan mencentang readiness dari katalog |
| 2026-11-20 | P01-03/P01-04 (parsial) | OMP | 25 file/paket gratis diunduh ke `downloads/` (ignored), ZIP/GLB lolos cek integritas, lisensi dan SHA-256 dicatat di [ASSET_DOWNLOADS](ASSET_DOWNLOADS.md). Mixamo menunggu login pengguna; Frost Golem/Extra menunggu keputusan beli. | — | Login Mixamo; keputusan Frost Golem; P02 ekstrak ke `assets/` + import Godot |
| 2026-11-21 | P01 selesai; P02-02; P02-01/04/06/08 (parsial) | OMP | Rock Golem diunduh via akun BlendSwap pengguna; Blender 4.5.16 LTS portable di `tools/` (hash cocok checksum resmi). Subset asset diekstrak ke `assets/third_party/` (1.681 file, 74 MB; musik WAV→OGG, SFX tidak relevan dibuang). Godot 4.7.2 import 1.281 file tanpa error setelah `.gdignore` folder kerja dan `filesystem/import/blender/enabled=false`. Uji muat: golem GLB 28 bone, Rogue 23 bone, clip Rig_Medium/Large, Drinking.fbx. Nama bone karakter = library animasi. `THIRD_PARTY_NOTICES.md` diisi; inventaris diperbarui ke status per kebutuhan. | — | Scene `asset_lab`, cek visual skala/material (P02-03), set loop clip, retarget Mixamo, rework golem |
| 2026-11-21 | P02-04/06 (parsial), audit kecukupan | OMP | Ambang visual dilonggarkan (model mirip/cukup, recolor diutamakan): tidak ada model/paket baru wajib; M27 opsional; core golem cukup recolor + skala seragam + crystal. Parse statis GLB (satu kali, tanpa Godot): Rogue/Knight/Barbarian/Ranger identik dengan `Rig_Medium_*` (23 joint, nama, parent, rest pose; semua target clip ditemukan) tetapi rest pose berbeda dari `Rig_Large_*` (translasi 1/23 cocok), sehingga klaim Barbarian=Large dikoreksi dan clip Medium dipakai. Kesamaan rest pose bukan bukti visual; loop tidak diverifikasi. Hitungan tetap 31 IMPORTED / 23 MISSING, 0 VERIFIED; angka file mentah (1.681/1.281) bukan kesiapan. Repo GitHub ternyata publik: FBX Mixamo di-gitignore, hanya salinan lokal, clone baru harus mengunduh sendiri. Gameplay belum ada. | — | P02-03 cek visual, wrapper scene, retarget N06/N11, reskin guardian |
| 2026-11-21 | I01; P02-01/03/08 (parsial) | OMP | Scene statis `scenes/tests/asset_lab.tscn`: Rogue, Rogue Hooded, Ranger, Knight, Barbarian, Rock Golem, pohon, batu, pilar; kamera tetap, label, lighting, lantai dan bar tepat 1 m. Palet pengguna disimpan di `docs/desain/palettes/`. Posisi golem/pohon didasarkan pada AABB nyata dan skala seragam; tidak remodel/recolor asset sumber, tidak animasi/Mixamo/gameplay. Run nyata Godot 4.7.2 Compatibility (Radeon RX 5500M), 1280×720, exit 0, capture PNG berhasil tanpa error/warning; [screenshot](evidence/i01-asset-lab.png). Main scene tidak diubah. | Commit I01 (log commit terkait) | Tunggu pilihan pemain serta review warna/skala dari pengguna; I02 diblok sampai disetujui |
| 2026-11-23 | Penyelesaian Pulau 1 (dokumentasi) | DocumentIslandOneCompletion | Dokumen disinkronkan dengan perilaku saat ini: layout prosedural deterministik (akar modul, jalan, 3–5 pack encounter, potion, checkpoint, biome, dermaga; axis-aligned; puzzle internal + boss fixed), save JSON lokal + autosave 5 detik/milestone + simpan manual + Continue (resource persis; snapshot boss asli), konfirmasi New Run, hitmarker/SFX, landmark/sign. Fakta uji saat ini: layout data 16 seed lolos; terrain seed 42/777/20261117 lolos sebelum resume; regresi save 82 check, 4 suite, 0 gagal. Lainnya pending/berjalan. Target build `exports/island-one/the-lost-island.exe` (belum dibuat/diverifikasi). Tidak ada tanda lulus baru. | — | Bukti akhir dan hash dari parent |
| 2026-11-23 | Penyelesaian Pulau 1 (dokumentasi, pembaruan) | DocumentIslandOneCompletion | Ditambahkan: Pilar Simbol/Jalur Energi bertukar barat–timur deterministik (103 bertukar / 97 normal pada 200 seed, tanpa gagal generate, terukur agen); rute/viewpoint/biome mengikuti sisi sebenarnya; checkpoint offset authored puncak +(−4,18), boss +(−10,12,5); X/Alt+F4 jendela = simpan-lalu-keluar seperti menu (uji UI pending). Regresi layout 16 seed dan terrain 42/777/20261117 lolos setelah pembaruan. EXE final belum diklaim. | — | Bukti akhir dan hash dari parent |
| 2026-11-25 | Penyelesaian Pulau 1 (rekonsiliasi dokumen) | FinalizeIslandProgressDocs | "Start Here" ditulis ulang sebagai status 25 Nov; klaim lama "font belum runtime", "layout tetap", "tanpa save" dihapus dari blok aktif (teks lama jadi riwayat bertanggal). Font, ikon, UI Kenney, peta (M), blur dicatat terkirim. Kontrak combat baru dicatat: musuh (standard 2 pukulan, heavy pendekatan cepat + sapuan tertunda, ranged semburan 3 tembakan), boss (fase 1 dua pukulan, fase 2 dua atau tiga), guard `max(8, damage×0,8)`; bukan buff HP. Tidak ada centang baru. | — | Lihat baris bukti parsial di bawah |
| 2026-11-25 | Penyelesaian Pulau 1 (bukti final + EXE) | FinalizeIslandProgressDocs | Dilaporkan parent: save 82/0, layout 16 seed 0 gagal, completion 384/0, `--seeds-full` 37.620/0, enemy_pattern 72/0, boss_pattern 122/0, combat_edge 269/0, traversal all_ok, terrain 20 seed PASS; shutdown pause 43/0, menu 36/0, window 38/0, source `--quit-after 5` exit 0 tanpa leak. Playthrough dirender (sumber) seed 42 PASS 229,9 s sim. **EXE `exports/island-one/the-lost-island.exe` SHA-256 `81ed42e9f85ed5754a575a14b3da407549cddacde5ee07b1ee9f72b382364449`: `--qa-playthrough --seed 42` PASS 200,4 s sim** (3 kill, boss attempt 1, 0 kematian, 3 artefak, dua puzzle + shortcut + gerbang + ending, exit 0, tanpa SCRIPT ERROR/leak). Build/ZIP tidak di-commit. Manual QA tetap terbuka. | commit milestone Pulau 1 pada `main` (lihat riwayat Git) | Manual QA: gamepad, audio/kesulitan, komputer lain |

Template catatan sesi:

```text
Tanggal / PIC:
Task IDs yang dikerjakan:
Scene/script/resource yang berubah:
Asset ID + sumber/lisensi jika ada:
Uji yang dijalankan / seed / hasil:
Bukti (log, screenshot, build, atau catatan reproduksi):
Task yang benar-benar selesai:
Masalah / baseline yang berubah:
Commit:
Task berikutnya yang dependensinya sudah siap:
```

## Hasil I02 — preview animasi

- Implementasi: `scenes/tests/animation_lab.tscn` dan `scripts/tests/animation_lab.gd`. I01, main scene dan asset sumber tidak diubah.
- Rogue memakai empat salinan clip terpilih: `Idle_A`, `Walking_A`, `Running_A` (loop), dan `Melee_1H_Attack_Slice_Horizontal` (sekali). Library impor tidak dimutasi. Pedang `sword_1handed.gltf` mengikuti `handslot.r` melalui BoneAttachment3D.
- Pemeriksaan: run nyata Godot 4.7.2 Compatibility / Radeon RX 5500M pada 1280×720, exit 0, tanpa error/warning. Input klik pada keempat Button memulai clip terkait. Attack selesai kembali idle; attack yang dipotong dengan tombol Run tidak mengubah kembali mode Run. Actor tidak berpindah posisi dunia dan tangan bergerak (23 bone).
- Bukti visual: screenshot idle/lari/serangan pada folder `evidence/`; karakter dan pedang tampak utuh. Kualitas gerak/transisi tetap menunggu penilaian pengguna. Belum ada damage, combo, stamina, WASD, retarget Mixamo atau generator procedural.
- Commit implementasi menggunakan judul `feat(asset-lab): preview selected character animations`; I03 tetap diblok sampai pengguna menerima I02.

## Hasil I03 — gerak darat relatif kamera

- Implementasi baru: `scenes/tests/movement_lab.tscn`, `scripts/player/ground_player.gd`; empat action `move_*` physical WASD di `project.godot`. Main scene, I01/I02 dan asset sumber tidak diubah.
- Arena tertutup 14×14 m, kamera tetap, empat boundary collider dan satu dinding tengah. Capsule pemain radius 0.45 m/tinggi 2.18 m; world layer 1, player layer 2/mask 1. Gerak memakai CharacterBody3D/move_and_slide dan gravitasi kontak lantai, tanpa jump.
- Baseline: kecepatan 4 m/s, akselerasi 20 m/s², perlambatan 25 m/s², turn rate 12/s, blend idle/jalan 0.15 s. Input diproyeksikan ke basis horizontal kamera. Ini angka prototype, bukan balancing final.
- Uji nyata Godot 4.7.2 Compatibility, Radeon RX 5500M, 1280×720, exit 0 tanpa error/warning. Event physical WASD menggerakkan pemain; uji W dan putar arah lolos. Kecepatan lurus/diagonal terukur sama 4.000/4.000 m/s. Pelepasan tombol menghentikan gerak dan kembali idle. Empat boundary menahan pusat capsule sekitar ±6.55 m; dinding tengah menahan posisi z sekitar -0.248 m. Pemain tetap grounded; simulasi notifikasi focus loss menghentikan gerak. Alt-tab fisik dan rasa gerak masih perlu review pengguna.
- [Screenshot arena](evidence/i03-movement.png) diperiksa. Foot sliding/kenyamanan belum dinyatakan final. Belum ada kontrol lompat, aiming, orbit/follow, hitbox/damage, musuh atau pulau procedural.
- I02 diterima pengguna; I03 akan diserahkan lewat commit `feat(player): add camera-relative ground movement`. Tunggu review I03 sebelum I04.

## Hasil I04 — lompat, gravitasi dan landing

- Scene `scenes/tests/jump_lab.tscn` mewarisi arena I03; controller `scripts/player/ground_player.gd` menambahkan `jump_enabled` opt-in. I03 tetap `false`, hanya I04 mengaktifkannya. Input `jump` = physical Space. Main scene dan asset sumber tetap.
- Baseline impulse `5.1 m/s`, gravitasi project (`9.8 m/s²`), puncak teoritis sekitar 1.33 m; pengukuran diskret runtime sekitar 1.37 m. Naik memakai `Jump_Start`, jatuh `Jump_Idle` loop, mendarat `Jump_Land` sekali lalu idle/jalan. Gerak horizontal tidak diblok landing; gerak boleh memotong clip landing setelah 0.25 s. Jump baru yang valid dapat memotong landing.
- Tidak ada double-jump, hold auto-jump, buffer/coyote atau variable jump height. Grounded + press edge wajib untuk takeoff. Gravitasi juga menangani berjalan turun dari tepi.
- Uji Godot 4.7.2 Compatibility pada 1280×720, exit 0 tanpa error/warning: Space meluncurkan pemain, press kedua di udara tidak mereset kecepatan vertikal, menahan Space melewati landing tidak mengulang, press baru setelah landing bekerja. Urutan clip teramati `jump_start → jump_idle → jump_land → idle`.
- Uji traversal: mendarat pada platform rendah (`y≈0.450`) dan platform tinggi (`y≈0.800`) dengan gap 1 m; berjalan dari tepi kembali grounded di lantai. I03 diuji terpisah dan tetap tidak melompat saat Space ditekan.
- Bukti: [arena](evidence/i04-jump-lab.png), [landing platform tinggi](evidence/i04-platform.png). Tinggi/jarak dan rasa landing masih menunggu pengguna. Kamera masih tetap; I05 belum dimulai.

## Hasil I05 — elevated smooth follow

- File baru `scripts/camera/smooth_follow_camera.gd` dan `scenes/tests/follow_lab.tscn`; scene mewarisi I04 dan memasang script pada Camera3D yang sudah dipakai controller. I01–I04, main scene dan controller tidak diubah.
- Baseline kamera Perspective FOV 50°, focus point 1 m di atas pemain, offset dunia `(0, 7, 9)` dari focus point. Posisi awal tepat sesuai target sehingga tidak ada fly-in. Pitch runtime sekitar 37.9° ke bawah, yaw tetap 0.
- Damping eksponensial frame-independent: horizontal `8/s`, vertikal `5/s`. Hanya posisi yang berubah setelah inisialisasi; rotasi pemain tidak memutar kamera.
- Uji nyata Godot 4.7.2 Compatibility/Radeon RX 5500M, 1280×720, exit 0 tanpa error/warning. Event W menggerakkan pemain dan kamera mengikuti horizontal sekitar 2.45 m. Space menyebabkan kamera naik sekitar 1.22 m dengan perubahan vertikal per frame maksimum sekitar 0.139 m pada run uji. Basis kamera tetap saat pemain berputar/lompat. Angka ini hasil run, bukan batas performa atau janji identik tiap mesin.
- Bukti visual [follow](evidence/i05-follow.png) dan [lompat](evidence/i05-jump.png). Kenyamanan damping dan framing menunggu review pengguna. Tembok dapat menutupi pemain karena collision kamera sengaja belum dibuat (I07); orbit I06, aiming dan combat juga belum ditambahkan.
- I04 diterima pengguna; I05 diserahkan dengan judul commit `feat(camera): add elevated smooth follow`. Tunggu review I05 sebelum I06.
