# Acceptance Checklist

Checklist ini dipakai bersama [Implementation Tracker](IMPLEMENTATION_TRACKER.md) dan [Asset Inventory](ASSET_INVENTORY.md). Semua skenario masih belum dijalankan pada saat dokumen dibuat, 17 November 2026.

## Recording Results

Centang skenario hanya setelah semua pemeriksaan di baris tersebut lolos. Catat commit, scene/build, seed, perangkat/input, hasil aktual, dan bukti pada **Test Runs**. Jika sebagian gagal, biarkan `[ ]` dan tulis langkah reproduksi. Setelah perubahan yang memengaruhi skenario, uji ulang sebelum menganggap hasil lama masih berlaku.

Pure logic yang berisiko, seperti konektivitas panel, progress IDs, damage deduplication, dan snapshot restore, layak diberi automated tests saat sistemnya dibuat. Keterbacaan kamera, timing combat, animasi, dan kualitas audio tetap memerlukan pengujian saat dimainkan.

## Input, Camera & Combat

- [ ] **A01 — Input modes.** Move, jump, attack, block, dodge, interaction, potion, dan pause tidak saling terpicu. Mouse selalu tertangkap dan memutar kamera tanpa MMB; scroll zoom tetap dalam `4–14 m`. Esc menjeda dan menampilkan cursor + Resume; focus loss menjeda tanpa menangkap ulang otomatis dan tidak meninggalkan tombol/cursor tersangkut. Right-stick diuji; bedakan bukti simulasi input dari perangkat fisik. Belum diuji untuk kontrol baru.
- [ ] **A02 — Camera.** Follow, jump/landing damping, mouse-look yaw 360°, pitch clamp `20°–65°` dan zoom scroll `4–14 m` bekerja. Obstacle tidak otomatis memperpendek jarak; occlusion pemain dan clipping kamera diterima sesuai keputusan pengguna. Kamera tidak otomatis berputar karena arah karakter/attack berubah. Framing terrain, slope, canopy, tebing dan boss tetap perlu review.
- [ ] **A03 — Heading & traversal.** WASD relatif kamera; karakter menghadap arah gerak (S berbalik menghadap kamera) tanpa memutar kamera. Arah melee mendatang mengikuti karakter, tanpa mouse-ground aim dan tanpa lock-on; baru dapat diuji setelah combat diizinkan. Karakter dapat melewati slope/tangga/gap yang diterima desain tanpa menembus collision atau jatuh pada sambungan modul.
- [ ] **A04 — Hit & interaction ownership.** Satu swing memberi damage satu kali per target, bukan setiap frame. Death dan artifact pickup diproses sekali. Prompt hanya menunjuk target yang valid dan input interact tidak mengaktifkan beberapa objek sekaligus.
- [ ] **A05 — Combo.** Input tepat waktu meneruskan tiga hit; early/late input dan hold tidak membuat auto-combo. Arah terkunci per hit dan diperbarui pada hit selanjutnya. Attack tidak memakai stamina, movement melambat, serta block/dodge tidak memotong animasi attack yang sudah dimulai.
- [ ] **A06 — Block & stamina.** Block mengurangi damage dari depan/belakang/samping, melee/projectile/boss, dan menguras stamina saat ditahan meski tidak diserang. Dodge memakai biaya tetap; stamina tidak negatif. Regen delay serta penolakan defense pada resource kurang mengikuti konfigurasi; movement/attack tetap tersedia.
- [ ] **A07 — Dodge.** Damage melee, projectile, dan boss dihindari selama i-frames; damage di luar window tetap berlaku. Collision, jarak, biaya, dan state setelah dodge konsisten. Uji saat stamina cukup, tepat ambang biaya, dan kurang.
- [ ] **A08 — Potion.** HP dan quantity berubah sekali pada completion. Hit sebelum completion membatalkan tanpa heal/konsumsi. Attack tidak berjalan bersamaan; movement melambat. Uji hit pada batas completion, death, block/dodge, full HP, stok kosong, dan pemakaian berulang sesuai baseline yang dicatat.
- [ ] **A09 — Enemy roles.** Standard melee memakai satu swing singkat; heavy memiliki telegraph dan recovery panjang; ranged memakai persiapan dan proyektil lurus. Detection, chase/leash, stagger, serta recovery tidak menyebabkan musuh macet atau menyerang terus tanpa celah.
- [ ] **A10 — Projectile & cover.** Proyektil berhenti pada world/cover sesuai desain, mengenai target yang benar satu kali, tidak homing, dan tidak mengenai pemiliknya secara tidak sengaja. Impact/lifetime membersihkan instance; death/retry tidak menyisakan projectile lama.

## State, Objective & Boss

- [ ] **A11 — Exploration respawn.** HP kembali penuh pada checkpoint aman; healing tersisa tetap dimiliki, healing yang sudah dipakai tidak dipulihkan. Artifact/puzzle/shortcut sesuai progres sesi. Musuh pendakian yang kalah tetap mati. Area lain mengikuti reset rule yang dicatat, tanpa free pickup farming yang tidak disengaja.
- [ ] **A12 — Snapshot integrity.** Contoh input uji: HP 70, stamina 45, potion 5 sebelum boss; pakai potion dan mati. Tepat setelah restore, nilainya kembali 70/45/5, bukan HP/stamina maksimum atau penambahan 5 ke sisa stok. Ulangi beberapa kegagalan; snapshot awal tidak berubah dan item tidak berlipat. Angka contoh bukan balancing final.
- [ ] **A13 — Transient cleanup.** Mati saat attack, potion, dodge, interaction, atau telegraph tidak membawa timer/hitbox/damage/callback lama ke respawn. Boss kembali penuh/fase pertama; progres pulau bertahan. Aturan keluar sukarela, quit, dan resource di area retry mengikuti baseline D06.
- [ ] **A14 — Symbol Pillars.** Empat bentuk terbaca dan relief cocok dengan solusi. Salah urutan mereset rangkaian tanpa damage/item loss; benar membuka segel. Clue tetap bisa dibaca dan musuh tidak mengganggu. Uji death saat belum selesai, solved-but-uncollected, dan artifact sudah diambil.
- [ ] **A15 — Energy Path.** Tiga panel berputar 90° per interaksi dengan connector yang benar. Periksa seluruh 4³ = 64 kombinasi orientasi pada layout yang dipakai: partial flow dan completion harus cocok dengan konektivitas data. Starting arrangement dapat diselesaikan; spam input tidak merusak orientasi. Tidak ada damage/timer/attempt limit, dan solved/collected bertahan setelah respawn.
- [ ] **A16 — Summit Route.** Kaki bukit, satu/dua jump pendek, courtyard melee+ranged, altar, dan shortcut dapat dijangkau. Area combat cukup luas dan cover bekerja. Run bypass musuh tetap dapat mengambil artifact sebelum kedua puzzle; death mempertahankan musuh rute yang telah kalah dan shortcut yang sudah dibuka.
- [ ] **A17 — Artifact gate.** Nol/satu/dua artifact tidak dapat mengaktifkan boss. Tiga artifact unik dapat dipasang dan memulai boss melalui interaksi. Uji keenam urutan pengambilan; interaction spam tidak menggandakan item, menghitung artifact dua kali, atau memulai beberapa boss instance.
- [ ] **A18 — Boss patterns.** Arm sweep, slam, dan charge memiliki telegraph yang cocok area damage. Target tidak mengikuti pemain setelah lock. HP tepat 50% masuk fase kedua; dua serangan berurutan mempertahankan tanda dasar. Slam recovery memungkinkan combo tiga hit dengan timing/posisi tepat; block dan i-frames tetap berlaku. Uji kemenangan tanpa potion.
- [ ] **A19 — Ending & restart.** Boss mati membuka gerbang; melewatinya memicu completion sekali. Resource dari attempt menang dipertahankan dan snapshot tidak di-restore lagi. Retry tidak mengulang pemasangan artifact/opening. New Run memulai session baru tanpa membawa progress/seed state yang seharusnya direset.

## World, Presentation & Distribution

- [ ] **A20 — Seed validity.** Setiap seed yang diterima memiliki akses spawn ke semua objective, checkpoint, shortcut, boss, dan completion route. Uji slope, clearance, collision, jump gaps, interaction range, clue visibility, ruang combat, serta navigation; graph connectivity saja belum cukup. Seed sama menghasilkan layout yang dapat direproduksi.
- [ ] **A21 — Generation failure.** Forced invalid placement atau batas regeneration menghasilkan fallback yang sudah valid, bukan loop/loading tanpa akhir atau artifact hilang. Death tidak meregenerasi pulau dengan IDs/seed lain. Uji pembersihan instance jika generation dijalankan ulang untuk New Run.
- [ ] **A22 — UI, narrative & audio.** HUD cocok dengan HP/stamina/potion/artifact aktual; prompt dan control hints sesuai input. Menu/pause/settings/completion bekerja. Opening/outro mengikuti lore. Musik/SFX/ambience tidak hilang, clipping, atau spam; puzzle dan combat tetap dapat dibaca saat mute dan tanpa mengandalkan warna saja.
- [ ] **A23 — Performance & stability.** Hasil dicatat pada mesin, resolusi, seed, serta encounter yang ditentukan. Bandingkan frame time/FPS, loading, dan memory dengan target yang sudah disepakati. Beberapa run/retry/pause tidak menambah instance, audio, atau memory secara terus-menerus. Tidak ada crash, error aktif, atau progres macet yang diketahui.
- [ ] **A24 — Standalone offline.** Executable Windows dijalankan di luar Editor tanpa Godot/MCP/Python/server/akun/internet. Resource, font, audio, shader, input, save/session behavior yang dirancang, serta run hingga ending tetap bekerja. Build tidak bergantung pada path absolut mesin pembuat.
- [ ] **A25 — Fresh clone & release package.** Anggota lain dapat membuka project hasil clone dengan versi yang dipin. Paket ZIP diekstrak ke lokasi baru/path berspasi dan dijalankan beserta file pendampingnya. Versi/commit/hash, kontrol, credits/lisensi, serta known issues tersedia; Gate C inventaris lolos.

## Seed Matrix

Usulan baseline QA: 20 seed berikut. Ini daftar kasus uji baru, bukan hasil pengujian atau jaminan semua seed valid. Catat rejected → fallback sebagai hasil tersendiri; jangan menyembunyikannya sebagai keberhasilan seed asli.

| Seed | Status | Akses/collision/modul | Objective/respawn/boss | Bukti/bug |
|---|---|---|---|---|
| 0 | NOT_RUN | — | — | — |
| 1 | NOT_RUN | — | — | — |
| 2 | NOT_RUN | — | — | — |
| 3 | NOT_RUN | — | — | — |
| 4 | NOT_RUN | — | — | — |
| 5 | NOT_RUN | — | — | — |
| 11 | NOT_RUN | — | — | — |
| 17 | NOT_RUN | — | — | — |
| 23 | NOT_RUN | — | — | — |
| 42 | NOT_RUN | — | — | — |
| 64 | NOT_RUN | — | — | — |
| 99 | NOT_RUN | — | — | — |
| 123 | NOT_RUN | — | — | — |
| 256 | NOT_RUN | — | — | — |
| 512 | NOT_RUN | — | — | — |
| 777 | NOT_RUN | — | — | — |
| 1024 | NOT_RUN | — | — | — |
| 2048 | NOT_RUN | — | — | — |
| 4096 | NOT_RUN | — | — | — |
| 20261117 | NOT_RUN | — | — | — |

## Test Runs

Belum ada test run implementasi pada checklist ini.

| Tanggal | Case IDs | Commit/build | Scene/seed | Mesin/input/resolusi | Hasil aktual/bukti | Bug/PIC |
|---|---|---|---|---|---|---|
| — | — | — | — | — | NOT_RUN | — |

Template bug:

```text
Case ID / judul:
Commit/build / seed / perangkat:
Langkah reproduksi:
Hasil yang diharapkan:
Hasil aktual:
Frekuensi / severity / apakah menghambat progres:
Log atau screenshot:
PIC / perbaikan / hasil retest:
```
