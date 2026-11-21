# Implementation Tracker

Proyek: **The Lost Island** · Tim: **Aku Suka Embegeh** · Dibuat: **17 November 2026**.

Dokumen ini menjadi checklist pelaksanaan Level 1, dari pencarian asset hingga distribusi build. Scope mengikuti [konsep aktif](../konsep-game.md). Rencana ini belum menyatakan gameplay sudah dibuat.

## Start Here

| Informasi | Status |
|---|---|
| Tahap aktif | Melee satu hit ke dummy teruji runtime; menunggu review pengguna |
| Pekerjaan berikutnya | Review iterasi kecil melee di `scenes/tests/melee_lab.tscn`; belum lanjut combo/stamina atau enemy AI |
| Fondasi yang tersedia | Project Godot, scene preview, Git, konfigurasi MCP, dokumen desain, asset pihak ketiga di `assets/third_party/` (ter-import tanpa error) |
| Gameplay | Gerak/lompat dan kamera diterima; melee satu hit, dummy HP dan death tersedia di lab. Combo, defense, AI, puzzle, boss dan generator belum dibuat |
| Asset produksi 3D dan audio | Bahan awal cukup, tidak perlu download model wajib lagi. Salinan lokal: 31 dari 54 kebutuhan `IMPORTED`, 23 sisanya perlu perakitan/edit/retarget (clone baru tanpa FBX Mixamo memiliki lebih sedikit). Belum ada yang `VERIFIED`; lihat inventaris |
| Hambatan yang diketahui | Gap nyata: retarget/aplikasi N06 dan N11 serta authoring wake/charge boss (FBX Mixamo hanya salinan lokal, repo publik); kode terrain procedural, puzzle, UI dan perakitan scene; reskin guardian/golem (recolor cukup); loop clip harus di-set manual. Tidak ada model/paket wajib baru |

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

## Iterasi kecil dan persetujuan pengguna

Keputusan pengguna, 21 November 2026: urutan utama dipertahankan, tetapi implementasi dipecah menjadi hasil kecil yang dapat diperiksa pengguna. Tabel berikut adalah **rencana**, bukan pekerjaan yang sudah selesai.

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

**Gate saat ini:** pengguna menerima kontrol kamera third-person tanpa auto-zoom obstacle dan mengizinkan melanjutkan. Iterasi berikutnya dibatasi **satu serangan melee ke dummy**, HP/damage, deduplikasi per swing dan death sekali; setelah selesai review lagi. Combo, stamina, block/dodge, potion dan AI belum bagian iterasi ini.

Polish shader dikerjakan **setelah gameplay inti stabil**, sebelum regresi/export akhir. Pertahankan palet pengguna dan Compatibility; nilai visual serta frame time diuji bersama, bukan menambah efek berat di tengah prototype.

### Iterasi melee satu hit

Scene `scenes/tests/melee_lab.tscn`: klik kiri satu swing arah karakter, arah terkunci, movement ×0,3, mulai hanya grounded dan tidak lompat saat swing. Klip `Melee_1H_Attack_Slice_Horizontal` sepanjang `1,3667 s`; window aktif rasio `0,15–0,30` (~`0,205–0,410 s`). Dummy 60 HP menerima 20 damage, tiga swing menjadi KO; R memuat ulang lab.

Runtime Godot 4.7.2 Compatibility membuktikan hold tidak mengulang; dua hurtbox satu pemilik tidak menggandakan damage; target belakang/di luar jangkauan dan di balik world wall tidak kena; HP `60→40→20→0`, death sekali dan label KO. Klik GUI Lanjutkan tidak menyerang. [Bukti](evidence/melee-review.png). Belum combo/stamina/AI; arah visual dan timing masih perlu review pengguna.

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

## Baseline Audit

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

- [ ] **P05-01** Buat deteksi objek interactable, prioritas satu target, jarak/range, prompt, dan penolakan interaksi ketika state pemain tidak mengizinkan.
- [ ] **P05-02** Buat health/damage dan event death yang hanya diproses sekali. Hindari beberapa sistem mengubah HP tanpa jalur yang sama.
- [ ] **P05-03** Buat hitbox/hurtbox dengan attack ID dan daftar target yang sudah terkena, agar satu swing tidak memberi damage berulang per physics frame.
- [ ] **P05-04** Definisikan state minimum player: locomotion, attack, block, dodge, potion, hurt/dead. Tetapkan prioritas serta pembatalan berdasarkan desain, bukan urutan callback kebetulan.
- [ ] **P05-05** Siapkan debug HP/stamina, hitbox, state, dan target interaksi yang dapat dimatikan untuk build pemain.

**Exit:** dummy dapat menerima satu hit yang benar, mati sekali, dan interaksi tidak terpicu ganda; jalankan A04.

## P06 — Player Combat, Defense & Potion

Dependensi: P05 dan mapping animasi minimum P02. Acuan: bagian combat/resource pada [konsep](../konsep-game.md).

- [ ] **P06-01** Implementasikan satu tombol combo tiga hit: dua hit cepat dan finisher. Input hanya diterima pada timing window; early input tidak dibuffer dan hold tidak menjalankan auto-combo.
- [ ] **P06-02** Kunci arah karakter per hit, baca ulang arah pada hit berikutnya, dan kurangi movement saat attack; tanpa mouse-ground aim atau lock-on. Animasi attack yang dimulai selesai sebelum block/dodge.
- [ ] **P06-03** Sinkronkan animasi dan active hit window; attack tidak memakai stamina. Uji seluruh rangkaian terhadap dummy bergerak.
- [ ] **P06-04** Implementasikan satu pool stamina, held-block drain, dodge fixed cost, regen delay, penolakan aksi saat tidak cukup, dan clamp tanpa nilai negatif.
- [ ] **P06-05** Implementasikan block yang mengurangi damage semua arah dan dodge i-frames untuk melee, projectile, serta boss. Pisahkan collision fisik dari invulnerability.
- [ ] **P06-06** Implementasikan inventory potion terbatas, pickup/drop, HUD quantity, dan penggunaan manual. Angka kapasitas/heal/drop merupakan baseline playtest.
- [ ] **P06-07** Implementasikan animasi minum dengan slow movement dan larangan attack bersamaan. Heal dan konsumsi item hanya pada completion; hit membatalkan tanpa menghabiskan item.
- [ ] **P06-08** Uji interaksi potion dengan block/dodge, death, damage pada frame completion, pause, dan pemakaian berturut-turut sesuai baseline yang dicatat.

**Exit:** combat bisa dimainkan dengan resource yang konsisten, bukan hanya animasi yang terlihat; jalankan A05–A08.

## P07 — Enemy Archetypes

Dependensi: P05–P06. Model dapat berbagi rig/fondasi AI, tetapi perilaku harus berbeda.

- [ ] **P07-01** Buat state idle/patrol bila diperlukan, detect, approach, wind-up, attack, recovery, hurt, dan dead. Tetapkan detection, chase/leash, dan obstacle handling sebagai baseline.
- [ ] **P07-02** Implementasikan standard melee: approach, satu swing singkat, recovery pendek.
- [ ] **P07-03** Implementasikan heavy melee: movement lebih lambat, telegraph hantaman kuat, recovery lebih panjang; tanpa combo panjang pada rancangan awal.
- [ ] **P07-04** Implementasikan ranged: persiapan terbaca dan projectile lurus tanpa homing. Uji hit world/cover, player, dan cleanup setelah impact/lifetime.
- [ ] **P07-05** Bedakan player/enemy damage ownership; projectile tidak mengenai pemiliknya secara tidak sengaja. Tentukan friendly-fire baseline.
- [ ] **P07-06** Terapkan stagger menurut tipe melalui konfigurasi. Jangan menganggap semua hit dapat membatalkan attack heavy atau boss.
- [ ] **P07-07** Uji encounter satu melee dan satu melee + satu ranged pada ruang yang mendukung movement, block, dan dodge. Validasi batas awal dua musuh aktif di rute pendakian.

**Exit:** ketiga archetype dapat dilawan, dibaca, dan diselesaikan; jalankan A09–A10. Jangan menambah tipe musuh lain untuk menutupi masalah tuning.

## P08 — Session Progress, Checkpoints & Retry

Dependensi: P03, P05–P07. Aturan boss mengikuti [snapshot specification](../desain/boss-penjaga-gerbang.md).

- [ ] **P08-01** Simpan solved puzzle dan collected artifact sebagai state terpisah dengan stable IDs. Artifact hanya dapat dikoleksi sekali.
- [ ] **P08-02** Implementasikan aktivasi checkpoint, safe respawn point, reset state transient player, dan respawn eksplorasi dengan HP penuh.
- [ ] **P08-03** Pertahankan jumlah healing tersisa saat respawn eksplorasi; item yang sudah dipakai tidak kembali. Aktivasi checkpoint tidak otomatis memberi healing tambahan.
- [ ] **P08-04** Simpan killed-enemy state pada Jalur Menuju Puncak. Putuskan dan dokumentasikan reset musuh/pickup area lain; jangan memperluas aturan rute itu tanpa catatan baseline.
- [ ] **P08-05** Buat snapshot HP, stamina, dan potion sebelum boss attempt pertama. Snapshot tidak memberi heal gratis dan tidak ditimpa oleh retry gagal.
- [ ] **P08-06** Pada kegagalan boss, tetapkan resource ke nilai snapshot; reset HP/fase boss, projectile, hitbox aktif, timer, target, dan event tertunda. Progres pulau tetap tersimpan.
- [ ] **P08-07** Pada kemenangan, pertahankan resource tersisa dan hentikan restore snapshot. Catat aturan keluar sukarela/quit serta resource/pickup di area retry sebelum mengimplementasikannya.
- [ ] **P08-08** Uji death saat attack, dodge, potion, interaction, dan projectile aktif; respawn tidak boleh memicu damage lama atau interaksi ganda.

**Exit / M1:** test arena mendukung combat, interaksi, dan retry yang dapat diulang; jalankan A11–A13.

## P09 — Fixed World Blockout

Dependensi: movement/camera dan ukuran karakter terbukti. Belum memasukkan variasi procedural penuh.

- [ ] **P09-01** Blockout area sekitar 250 × 250 meter sebagai baseline, dengan Grassland spawn, cabang Forest/Rocky Highlands, gerbang, dan akses dermaga.
- [ ] **P09-02** Tetapkan main path, jalur alternatif, landmark, hidden viewpoint, dan shortcut. Ketiga lokasi artifact dapat dijangkau tanpa urutan wajib.
- [ ] **P09-03** Sediakan ruang/sockets untuk modul dua puzzle, ascent, checkpoint, encounter, dan arena boss. Tentukan slope, clearance, dan jump gap dari hasil P04.
- [ ] **P09-04** Tentukan graph/route contract untuk terrain generation dan navigation, termasuk koneksi jump yang memang diizinkan.
- [ ] **P09-05** Uji perjalanan dari kamera permainan dan catat waktu antarobjektif. Kurangi ruang kosong sebelum menambah luas atau konten baru.

**Exit:** seluruh lokasi wajib terjangkau pada map tetap dengan placeholder. Jangan memakai landscape visual sebagai bukti collision dan akses sudah benar.

## P10 — Puzzle 01: Symbol Pillars

Dependensi: P05, P08–P09. Acuan: [Pilar Simbol](../desain/puzzle-01-pilar-simbol.md).

- [ ] **P10-01** Buat modul empat pilar, empat simbol berbeda bentuk, relief yang selalu dapat diperiksa, segel, dan artifact.
- [ ] **P10-02** Simpan solusi dan clue dalam data modul yang sama. Implementasikan urutan interaksi, reset pada input salah, serta feedback cahaya/audio.
- [ ] **P10-03** Buka segel pada urutan benar tanpa damage, kehilangan item, atau cooldown panjang akibat kesalahan.
- [ ] **P10-04** Lindungi area dari gangguan musuh dan uji keterbacaan dari kamera Perspective.
- [ ] **P10-05** Uji solved-but-uncollected, collected, death, dan respawn. Terapkan kembali state tanpa menduplikasi artifact.

**Exit:** A14 lolos dan modul dapat ditempatkan ulang tanpa kehilangan petunjuk atau akses.

## P11 — Puzzle 02: Energy Path

Dependensi: P05, P08–P09. Acuan: [Jalur Energi](../desain/puzzle-02-jalur-energi.md).

- [ ] **P11-01** Buat modul tiga panel, source crystal, altar, segel, dan artifact. Source serta tujuan tetap di dalam modul.
- [ ] **P11-02** Representasikan connector jalur lurus/siku dan orientasi 90° dalam data. Validasi satu jalur source-to-altar yang dapat dicapai.
- [ ] **P11-03** Implementasikan rotasi panel per interaksi, cegah input ganda saat rotasi, dan tampilkan aliran hanya sejauh sambungan valid.
- [ ] **P11-04** Buka segel pada koneksi lengkap. Gunakan ukiran/arah, cahaya, dan audio; tanpa timer, damage, atau batas percobaan.
- [ ] **P11-05** Uji seluruh kombinasi orientasi panel serta persistence solved/collected. Simulasi sinar, mirror, atau ray tracing tidak diperlukan.

**Exit:** A15 lolos; perubahan penempatan/seed tidak membuat modul kehilangan solusi.

## P12 — Exploration Challenge: Summit Route

Dependensi: P07–P09. Acuan: [Jalur Menuju Puncak](../desain/exploration-03-jalur-menuju-puncak.md).

- [ ] **P12-01** Buat modul kaki bukit, jalur tebing, guard courtyard, dan altar puncak dengan checkpoint sebelum rute.
- [ ] **P12-02** Tempatkan satu melee awal, lalu satu melee + satu ranged pada pelataran lebar dengan cover dan pendekatan samping.
- [ ] **P12-03** Buat satu atau dua lompatan pendek yang lolos batas traversal. Jangan memaksa combat saat pemain berada pada gap sempit.
- [ ] **P12-04** Pastikan artifact dapat diambil dengan melewati penjaga dan tanpa menyelesaikan kedua puzzle terlebih dahulu.
- [ ] **P12-05** Implementasikan bridge shortcut dari sisi puncak, status terbuka, dan collision yang sesuai. Uji shortcut setelah death/respawn.
- [ ] **P12-06** Uji jatuh, respawn checkpoint, killed-enemy persistence, viewpoint, dan jalur pulang.

**Exit:** A16 lolos, termasuk run tanpa membunuh semua penjaga.

## P13 — Boss: The Gatekeeper

Dependensi: P06–P09 dan ruang arena. Acuan: [Penjaga Gerbang](../desain/boss-penjaga-gerbang.md).

- [ ] **P13-01** Buat arena rata, checkpoint sebelum arena, gerbang tiga socket, dan interaksi aktivasi setelah ketiga artifact tersedia.
- [ ] **P13-02** Implementasikan wake animation singkat, arena lock, state boss, telegraph, dan waktu penguncian target serangan.
- [ ] **P13-03** Implementasikan arm sweep, ground slam, dan straight charge dengan area damage yang sesuai telegraph. Semua mengikuti block/i-frames umum.
- [ ] **P13-04** Implementasikan fase pertama di atas 50% HP dan fase kedua pada 50% atau kurang; rangkaian dua serangan tidak menghilangkan telegraph dasar.
- [ ] **P13-05** Tuning recovery ground slam agar combo tiga hit mungkin dilakukan dengan posisi/timing tepat. Uji boss tanpa potion.
- [ ] **P13-06** Hubungkan snapshot P08. Retry tidak memasang ulang artifact atau mengulang opening; boss kembali penuh/fase pertama dan tidak membawa attack transient lama.
- [ ] **P13-07** Implementasikan death boss, energi gerbang padam, gate open, dan satu completion trigger ketika pemain melewati gerbang.

**Exit:** A17–A19 lolos tanpa musuh tambahan atau pola boss di luar desain.

## P14 — Completable Level Integration

Dependensi: P09–P13.

- [ ] **P14-01** Hubungkan spawn, ketiga objective, encounter, checkpoint, gerbang, boss, dan ending pada blockout tetap.
- [ ] **P14-02** Uji keenam urutan pengambilan ketiga artifact. Semua memberikan tiga artifact unik dan akses boss yang sama.
- [ ] **P14-03** Uji death setelah puzzle selesai tetapi artifact belum diambil, setelah artifact terkumpul, setelah shortcut dibuka, dan saat menuju boss.
- [ ] **P14-04** Pastikan death tidak membuat world baru dengan seed/ID berbeda. `New Run` sengaja memulai session baru dengan progres kosong.
- [ ] **P14-05** Mainkan dari awal hingga ending tanpa debug unlock, noclip, pemberian item, atau perubahan scene manual.

**Exit / M2:** satu level lengkap bisa ditamatkan. Ini menjadi pembanding sebelum P15 mengubah terrain/penempatan.

## P15 — Seeded Procedural Island

Dependensi: traversal P04, route contract P09, dan playable level P14.

- [ ] **P15-01** Implementasikan seed dan random stream yang terkontrol; pisahkan variasi dekorasi dari penempatan objective agar perubahan dekorasi tidak merusak solusi.
- [ ] **P15-02** Bangun procedural terrain mesh, collision, coastline, biome, dan elevasi moderat. Bentuk jalur dan pads modul mengikuti batas traversal.
- [ ] **P15-03** Tempatkan modul objective/arena/checkpoint/shortcut pada lokasi valid dan pertahankan koneksinya. Bersihkan obstacle yang menutup interaksi, clue, atau ruang dodge.
- [ ] **P15-04** Validasi graph reachability disertai pemeriksaan slope, clearance, collision, serta jump gap. Graph yang tersambung saja belum membuktikan player dapat lewat.
- [ ] **P15-05** Bangun navigation sesuai terrain/modul, tetapkan perilaku aggro/leash, dan uji melee/ranged pada slope serta cover nyata.
- [ ] **P15-06** Tambahkan batas percobaan regeneration dan fallback seed/layout yang sudah terbukti valid. Hindari loading yang mengulang tanpa batas.
- [ ] **P15-07** Jalankan seed matrix yang dicatat pada acceptance. Usulan awal: 20 seed yang dipin; jumlah ini baseline QA baru, bukan bukti bahwa generation sudah valid.
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

- [ ] **P17-01** Buat HUD HP bar + angka, stamina, potion quantity, progres artifact, dan interaction prompt yang mengikuti state sebenarnya.
- [ ] **P17-02** Buat main menu/New Run, pause/resume, pengaturan audio, control hints, serta completion screen sebagai baseline UX. Pause/focus loss tidak memicu attack atau konsumsi potion tanpa sengaja.
- [ ] **P17-03** Masukkan pembukaan awak kapal terdampar, environmental clues, dan penutup menuju dermaga sesuai lore. Hint tidak memaksakan urutan artifact.
- [ ] **P17-04** Integrasikan ambience, musik eksplorasi/boss, dan SFX movement, melee, projectile, block, dodge, potion, puzzle, gate, serta UI; catat sumber/lisensi.
- [ ] **P17-05** Uji volume, transisi musik, spam SFX, dan keterbacaan saat audio dimute. Informasi penting tetap terlihat melalui bentuk, arah, atau animasi.
- [ ] **P17-06** Pastikan debug UI, concept-art label laporan, dan instruksi tooling developer tidak muncul dalam alur game pemain.

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

- [ ] **P19-01** Lengkapi seluruh [Acceptance Checklist](ACCEPTANCE_CHECKLIST.md) dengan bukti yang dapat direproduksi. Pengujian otomatis difokuskan pada state/progression, konektivitas puzzle, damage, snapshot, dan validation seed.
- [ ] **P19-02** Pasang export templates sesuai **4.7.2**, periksa preset Windows, exclusion addon MCP/dokumen/source kerja, serta resource gameplay yang memang diperlukan build.
- [ ] **P19-03** Export ke `exports/windows/`; jalankan executable di luar Editor tanpa MCP/server, lalu ulangi run hingga ending dan retry boss.
- [ ] **P19-04** Uji fresh clone pada komputer anggota: import/run/export menggunakan file yang dilacak Git, tanpa mengandalkan cache atau path mesin pembuat.
- [ ] **P19-05** Uji paket offline pada komputer target lain bila tersedia. Pastikan tidak perlu Godot, Python, akun, API, atau internet; periksa log/missing resources.

**Exit / M4:** A24–A25 lolos dan semua blocker release ditutup.

## P20 — Release & Handoff

Dependensi: build P19 terbukti.

- [ ] **P20-01** Siapkan paket ZIP executable beserta file pendamping yang diperlukan, credits/lisensi, versi, dan petunjuk kontrol/jalankan. Jangan menganggap satu `.exe` cukup sebelum isi paket diuji.
- [ ] **P20-02** Uji ZIP yang sudah diekstrak ke lokasi baru, termasuk path dengan spasi. Catat commit dan hash paket release.
- [ ] **P20-03** Perbarui README, inventaris, tracker, known issues, serta status implementasi pada konsep/laporan berdasarkan hasil nyata.
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

Campaign, multiplayer, player ranged/magic, skill tree, miniboss tambahan, serta save permanen lintas sesi tidak menjadi syarat tracker ini. Full gamepad mapping di luar right-stick orbit juga belum menjadi keputusan desain.

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
