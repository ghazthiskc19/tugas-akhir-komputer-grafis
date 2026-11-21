# Audit Ekosistem KayKit — Karakter, Senjata, dan Animasi

Tanggal pemeriksaan: **20 November 2026**. Lingkup: **8 paket aktif berbeda**, satu library animasi legacy sebagai pembanding yang ditolak untuk pipeline baru, dan satu jalur bundle. Tier Free/Extra/Source tidak dihitung sebagai paket terpisah. Hanya metadata, preview resmi, daftar path repository, dan teks lisensi; **tidak mengunduh model/arsip, mengimpor, membeli, atau menguji rig**. Semua kandidat tetap mengikuti status produksi di [Asset Inventory](ASSET_INVENTORY.md); audit ini bukan perubahan menjadi `VERIFIED`.

## Kesimpulan yang dapat dipakai

- **KayKit kuat sebagai ekosistem humanoid serasi**, bukan hanya satu Rogue: manusia ringan, Knight, Barbarian, Ranger, senjata, library gerak/combat, serta alternatif karakter berbayar memakai standar baru. Ranger Free 2.0 adalah kandidat manusia berpakaian ringan baru untuk dipreview dengan pedang satu tangan dari paket yang sama; bukan keputusan mengganti pemain menjadi pemanah.
- **N01–N05, N07–N10 mempunyai kandidat clip bernama**, tetapi tidak berarti seluruh kebutuhan tiap baris sudah tertutup. N02 belum mempunyai label jatuh bebas terpisah yang terbukti; N04 belum membuktikan tiga clip enter/hold/exit; N06 minum potion tetap gap penting. `USE_ITEM` bukan bukti gerak minum.
- **Rig_Large bukan salinan lengkap Rig_Medium.** Ada slam dan gerak heavy yang menjanjikan, tetapi chart publiknya tidak menawarkan seluruh jump/ranged/potion set. Jangan membeli karakter besar karena menganggap semua 161 animasi tersedia pada kedua rig.
- **Penjaga kuno standard/heavy/ranged belum memiliki trio final yang tematik.** Manusia bersenjata KayKit bisa menjadi basis bila penjaga berbaju zirah/manusia diterima; Skeletons mengubah spesies/lore, bukan sekadar material variant. Skeleton Golem bukan golem batu. Frost Golem berbayar menjanjikan basis lain, bukan bukti boss batu berinti energi dengan tiga serangan/dua fase.
- Free-first benar-benar memungkinkan kandidat pemain + sword + standard/heavy/ranged secara mekanis. **Tidak ada klaim bahwa recolor otomatis menyelesaikan lore, anatomi, potion animation, atau boss.**

## Metode dan tingkat bukti

| Label | Makna pada dokumen ini |
|---|---|
| `CATALOG` | Halaman maker terbaca dan menyatakan isi/tier/format/lisensi. Bukan inspeksi file. |
| `PREVIEW` | Gambar resmi dibuka; bentuk/teks chart dapat dinilai. Bukan bukti isi arsip atau hasil animasi bergerak. |
| `TEXT_MANIFEST` | Daftar path atau teks lisensi repository maker dibaca, tanpa mengambil model. Berlaku pada versi repository itu saja. |
| `INDEX_ONLY` | Hanya indeks pencarian karena akses halaman gagal; tidak dipakai untuk mengunci isi/tier final. |
| `UNCONFIRMED` | Halaman/chart tidak cukup memastikan kebutuhan tertentu. Tidak berarti file pasti tidak ada. |

Sebagian `read` itch menghasilkan HTTP429. Browser riset kemudian berhasil membaca Adventurers, Skeletons, Series 5, legacy animations, devlog, dan Dungeon; halaman maker `.com` memberi mirror metadata tambahan. Jadi fakta pada baris tersebut bukan semata snippet indeks. Semua harga di bawah ialah **USD minimum yang terlihat pada bagian tier/Download/Purchase**, bukan angka donasi, nilai total bundle, ataupun otorisasi belanja. Tanggal observasi tidak menjamin harga checkout nanti.

Sumber katalog: [koleksi karakter resmi](https://itch.io/c/6033067/kaykit-character-packs), [game assets maker](https://kaylousberg.com/game-assets), dan [profil GitHub maker](https://github.com/KayKit-Game-Assets). Profil GitHub menautkan `kaylousberg.com` dan akun itch yang sama. Tidak menggunakan mirror pihak ketiga untuk membuktikan isi.

## Katalog relevan dan tier — 8 paket aktif

Lisensi `CC0` pada tabel adalah klaim halaman resmi. Secara CC0 penggunaan komersial, perubahan, dan redistribusi diizinkan tanpa atribusi wajib; halaman maker sekaligus meminta agar salinan tidak dimodifikasi tidak dijual ulang/diklaim sebagai karya sendiri. Jangan menafsirkan permintaan etika itu sebagai lisensi proprietary baru. **File lisensi tier/versi yang benar-benar diperoleh tetap diperiksa sebelum publikasi file mentah.**

| ID | Nama persis / sumber resmi | Coverage kandidat | Tier dan harga yang diamati | Format / rig / lisensi yang dinyatakan | Kekurangan persis; risiko edit |
|---|---|---|---|---|---|
| KC01 | **KayKit - Character Pack : Adventurers** — [itch](https://kaylousberg.itch.io/kaykit-adventurers), [maker](https://kaylousberg.com/game-assets/characters-adventurers) | M01–M04, M06–M09; N01–N05/N07–N10 bersama KC02; potion prop KC01 Extra hanya kandidat | Free **2.0 $0**, 5 karakter; Extra **2.0 $7.95**, 3 tambahan + accessories + 3 alternative textures untuk masing-masing 8 adventurer; Source **2.0 $11.95**, `.blend` dan seluruh Extra | FBX/glTF, fully textured/rigged/animated, basic movement; compatible dengan KC02. Gradient atlas 1024², boleh downsample. CC0. `CATALOG` + Ranger `PREVIEW` | Free: Knight, Barbarian, Rogue, Mage, Ranger tampak pada halaman. Extra: Engineer + Turret, Druid, **Barbarian besar**. Tidak ada janji ancient guardian, drink clip, atau 3-hit game logic. Pedang/attachment **LOW–MEDIUM**; guardian construct/stone conversion **HIGH**. |
| KC02 | **KayKit - Character Animations** — [itch](https://kaylousberg.itch.io/kaykit-character-animations), [maker](https://kaylousberg.com/game-assets/character-animations), [devlog 1.1](https://kaylousberg.itch.io/kaykit-character-animations/devlog/1139588/character-animations-update-11) | N01–N10; N11 hanya bahan gerak humanoid, bukan boss lengkap | Free **1.1 $0**, semua animasi gratis; Source **1.1 $14.99**, satu `.blend` per animation set dengan basic control rig. Tidak ada tier Extra/animasi premium eksklusif yang dinyatakan | FBX/glTF; Rig_Medium + Rig_Large terpisah. Halaman itch menyebut **161**, maker mirror **133**; 28 tool clips pada update 1.1 menjelaskan selisih secara aritmetis tetapi tidak membuktikan jumlah per rig. CC0. `CATALOG`/chart `PREVIEW` | Fall terpisah, block enter/exit, dan drink spesifik belum terbukti; eating/drinking masih tercantum pada rencana halaman. Integration timing **MEDIUM**, custom drink **HIGH** dibanding sekadar attachment. Source tidak menambah clip siap pakai. |
| KC03 | **KayKit - Character Pack : Skeletons** — [itch](https://kaylousberg.itch.io/kaykit-skeletons), [repo maker 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | M02–M04/M07–M09; N08–N10 melalui KC02; M05 hanya alternatif bentuk yang tidak sesuai tema batu | Free **1.1 $0**, 4 skeleton + 10+ accessories; Extra **1.1 $7.95**, Skeleton Golem + Necromancer + alternative texture; Source **1.1 $11.95**, `.blend` dan Extra | FBX/glTF; basic movement, updated KC02 compatibility; CC0. `CATALOG`; path repo `TEXT_MANIFEST` versi **1.0** | Warrior/Minion/Rogue/Mage jelas ada di manifest lama. Bone anatomy bukan batu: menutup lubang tulang/mengubah silhouette/core adalah **remodel**, mungkin reweight/re-rig. Lore swap **belum disetujui**. Pemakaian skeleton apa adanya **LOW**, sebagai guardian kuno non-undead **HIGH**. |
| KC04 | **KayKit - Character Pack : Mystery Monthly Series 4** — [itch](https://kaylousberg.itch.io/kaykit-series-4) | M01–M04/M06–M09 alternatif; N01–N10 lewat KC02 sesuai rig | **$19.99** minimum; bundle versi **1.1**; `.blend` termasuk; tidak ada Free/Extra yang dinyatakan | 15 karakter (halaman juga menulis 15+), assets + alternative textures, FBX/glTF/.blend; fully rigged/textured/animated, basic movement; new style/compatible standard Adventurers; CC0. `CATALOG`; Paladin `PREVIEW` | **Paladin, Ninja, Orc Raider, Werewolf (human + wolf)** relevan sebagai armor/weapon/human/monster alternatives. Paladin masih manusia berzirah, bukan guardian batu. Exact rig per karakter/clip custom belum terdaftar. Recolor/weapon swap **LOW–MEDIUM**; menjadi stone construct **HIGH**. |
| KC05 | **KayKit - Character Pack : Mystery Monthly Series 5** — [itch](https://kaylousberg.itch.io/kaykit-series-5) | M01–M05 alternatif; N01–N11 hanya basis rig/movement | **$19.99** minimum; versi **1.1**, `.blend` termasuk; tidak ada Free/Extra yang dinyatakan | 14 karakter (deskripsi juga 14+), FBX/glTF/.blend; fully rigged/textured/animated, new standard + KC02; CC0. `CATALOG` | **Black Knight, Frost Golem, Caveman, Clanker, Protagonists, Hiker, Tiefling** membuka bentuk lain. Frost Golem belum membuktikan chest core, arm sweep/charge, rig per karakter, atau batu bukan es. Armor adaptation **MEDIUM**, elemental/core/remodel dan custom boss animation **HIGH/UNKNOWN**. |
| KC06 | **KayKit - Character Pack : Mystery Monthly Series 6** — [itch](https://kaylousberg.itch.io/kaykit-series-6) | M02–M04/M08–M09 alternatif; M05 hanya bahan eksplorasi monster/mechanical | **$19.99** minimum; versi **1.1**, `.blend` termasuk; tidak ada Free/Extra yang dinyatakan | 14 karakter menurut halaman; FBX/glTF/.blend, basic movement, current standard + KC02, CC0. Changelog menetapkan **Monstrosity `Rig_Large`**. `CATALOG` | **Orc Brute, Plant Warrior, 4-GTN (dua karakter), Avian Swordsman, Marksman** relevan. 4-GTN mekanik bukan otomatis kuno-batu; Marksman belum memastikan jenis projectile/weapon di teks. Plant/monster menjadi stone trio **HIGH**; cast+weapon attachment **MEDIUM/UNKNOWN**. |
| KC07 | **KayKit : RPG Tools Bits** — [itch](https://kaylousberg.itch.io/rpg-tools-bits), [maker](https://kaylousberg.com/game-assets/rpg-tools) | M08 alternatif hammer/axe/mallet; N09 tool swing hanya bahan, bukan slam siap gameplay | Free **$0**, 45+ models; Extra **$4.99**, 20 extra assets untuk fishing/lockpicking; Source **$7.49**, `.blend` + Extra | OBJ/FBX/glTF; gradient atlas 1024²; prop pack bukan character rig. CC0. 28 tool animasi berada di **KC02**, bukan alasan membeli Extra tools. `CATALOG` | Tidak perlu menambah crafting/fishing scope. Hammer/mallet tool belum tentu silhouette weapon heavy memadai. Scale/attachment **LOW–MEDIUM**; tidak menyelesaikan ancient heavy body atau attack telegraph. |
| KC08 | **KayKit - Dungeon Pack** (sebelumnya **Dungeon Remastered**) — [halaman lama resmi yang menuju paket kini](https://kaylousberg.itch.io/kaykit-dungeon-remastered), [halaman kini](https://kaylousberg.itch.io/kaykit-dungeon-pack), [maker mirror](https://kaylousberg.com/game-assets/dungeon-remastered), [repo maker](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) | **M20 bottle/potion base**; world coverage dibahas terpisah, bukan karakter tambahan | Free **1.1 $0**, 200 assets; Extra **1.1 $7.95**, 275+ total + 6 textures; Source **1.1 $11.95**, `.blend` + Extra | FBX/glTF/OBJ; CC0, static prop pack. `CATALOG` + bottle path `TEXT_MANIFEST` pada repo **1.0** | Changelog **16-7-2026** menyebut rebrand Remastered1.1 → Dungeon Pack1.1: **jangan dihitung dua paket current**. Bottle_A/B/C cocok sebagai sumber online bentuk botol, belum potion final/rig/drink animation. Recolor/scale/hand attachment **LOW–MEDIUM**, N06 tetap gap. |

### Isi cast premium lengkap yang tertulis di katalog

Daftar ini menjaga scan tidak terbatas pada satu karakter yang terlihat cocok. Bukan rekomendasi membeli semua karakter.

- **KC04 Series 4:** Orc Raider; Driver + Car; Monster Costume; Werewolf (Human + Wolf); Animatronic (Normal + Creepy); Action Figure; Space Ranger; Ninja; Survivalist; Paladin; Clown; Robots (dua karakter). Bentuk modern/sci-fi/costume bukan prioritas pulau kuno.
- **KC05 Series 5:** Combat Mech; Superhero; Black Knight; Vampire; Witch; Helpers (dua); Frost Golem; Caveman; Clanker; Protagonists (dua); Hiker; Tiefling. Nama karakter tidak membuktikan tipe rig atau seluruh accessories.
- **KC06 Series 6:** Lorekeeper; Orc Brute; Cleric; Monstrosity; Plant Warrior; Toy Soldier; 4-GTN (dua); Hoarder; Avian Swordsman; Marksman; Magical Girls; Farmers (dua). Angka total pada halaman tidak direkonsiliasi dari judul kelompok; tidak menghitung satu judul kelompok sebagai satu mesh.
- Halaman Series 4–6 menyatakan Series 1–3 adalah karakter legacy tanpa standar baru, tidak tersedia lagi/tidak menerima update. **Bukan tiga paket online siap diadakan sekarang.**

## Bukti manifest resmi, dengan batas versi

[Repository Adventurers **1.0**](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) menyebut **4 (+2 Extra), 75 animasi**, sedangkan halaman produk kini **2.0 = 5 (+3 Extra)** dan memisahkan library KC02. Jangan membawa angka/clip versi lama ke tier baru. Path yang benar-benar terlihat di daftar resmi lama:

```text
Assets/fbx/sword_1handed.fbx
Assets/fbx/sword_2handed.fbx
Assets/fbx/axe_1handed.fbx
Assets/fbx/axe_2handed.fbx
Assets/fbx/crossbow_1handed.fbx
Assets/fbx/crossbow_2handed.fbx
Assets/fbx/arrow.fbx
Assets/fbx/arrow_bundle.fbx
Assets/fbx/quiver.fbx
Assets/fbx/mug_empty.fbx
Assets/fbx/mug_full.fbx
```

Prefiks penuhnya `addons/kaykit_character_pack_adventures/`. Versi glTF dan `.bin` juga terdaftar. Ini bukti nama model lama, **bukan download/inspeksi model ataupun jaminan nama path 2.0**. Versi kini sendiri menyatakan swords/axes/bow/crossbows/arrows, sehingga kandidat fungsi senjata tidak bergantung pada asumsi arsip lama. [Teks LICENSE.txt 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/main/LICENSE.txt) dibaca: CC0; atribusi tidak wajib.

[Repository Skeletons **1.0**](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) mendaftarkan `Skeleton_Mage`, `Skeleton_Minion`, `Skeleton_Rogue`, `Skeleton_Warrior` pada FBX/GLB; aksesori `Skeleton_Arrow`, `Skeleton_Arrow_Half`, `Skeleton_Arrow_Broken`, `Skeleton_Arrow_Broken_Half`, `Skeleton_Axe`, `Skeleton_Blade`, `Skeleton_Crossbow`, `Skeleton_Quiver`, `Skeleton_Staff`, dan shields. README lama menyebut 90+ animasi; produk **1.1** kini basic movement + library KC02, jadi angka itu tidak digunakan untuk klaim coverage baru.

[Repository Dungeon Remastered **1.0**](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) mencantumkan `Assets/fbx/bottle_A_brown.fbx`, `bottle_A_green.fbx`, `bottle_A_labeled_brown.fbx`, `bottle_A_labeled_green.fbx`, `bottle_B_brown.fbx`, `bottle_B_green.fbx`, `bottle_C_brown.fbx`, `bottle_C_green.fbx` di bawah `addons/kaykit_dungeon_remastered/`. Online bottle base ada; warna/scale/cap/hand grip/potion identity dan tier 1.1 tetap diperiksa saat pengadaan.

Tidak ditemukan repository animasi current terpisah pada daftar repository maker yang diperiksa. Tidak membuka GLB/glTF model untuk mengambil animasinya. **Bukti clip current berikut berasal dari chart dan devlog resmi**, bukan parsing file model.

## Daftar label animasi publik current

**Penting:** ini transkripsi label pada chart resmi, dengan huruf kapital seperti chart; kapitalisasi/nama internal animation resource pada FBX/glTF belum diperiksa. Chart tidak menjamin durasi, root motion, loop, pose attachment, atau urutan event. Nama seperti `JUMP_FULL_LONG` adalah satu clip bernama, bukan tiga file start/fall/land otomatis.

Sumber **AM**: [Rig_Medium chart resmi](https://kaylousberg.com/content/3-game-assets/4-character-animations/rig_medium_overview.png), dibuka sebagai gambar. Sumber **AL**: [Rig_Large chart resmi](https://kaylousberg.com/content/3-game-assets/4-character-animations/rig_large_overview.png), dibuka sebagai gambar. Keduanya tertaut dari [halaman maker](https://kaylousberg.com/game-assets/character-animations). Chart situs menampilkan Large **29 total**, sedangkan galeri itch memakai chart lama **23 total**; versi arsip menentukan daftar sebenarnya. Jangan menjumlah chart lama+baru sebagai animasi berbeda.

### AM — Rig_Medium

```text
MOVEMENT BASIC
RUNNING_A
RUNNING_B
JUMP_FULL_LONG
JUMP_FULL_SHORT
JUMP_IDLE
JUMP_LAND
JUMP_START
WALKING_A
WALKING_B
WALKING_C

MOVEMENT ADVANCED
CRAWLING
CROUCHING
SNEAKING
DODGE_BACKWARD
DODGE_FORWARD
DODGE_LEFT
DODGE_RIGHT
RUNNING_HOLDINGBOW
RUNNING_HOLDINGRIFLE
RUNNING_STRAFE_LEFT
RUNNING_STRAFE_RIGHT
WALKING_BACKWARDS

COMBAT MELEE
MELEE_BLOCK
MELEE_BLOCK_ATTACK
MELEE_BLOCK_HIT
MELEE_BLOCKING
MELEE_1H_ATTACK_CHOP
MELEE_1H_ATTACK_JUMP_CHOP
MELEE_1H_ATTACK_SLICE_DIAGONAL
MELEE_1H_ATTACK_SLICE_HORIZONTAL
MELEE_1H_ATTACK_STAB
MELEE_2H_ATTACK_CHOP
MELEE_2H_ATTACK_SLICE
MELEE_2H_ATTACK_SPIN
MELEE_2H_ATTACK_SPINNING
MELEE_2H_ATTACK_STAB
MELEE_2H_IDLE
MELEE_DUALWIELD_ATTACK_CHOP
MELEE_DUALWIELD_ATTACK_SLICE
MELEE_DUALWIELD_ATTACK_STAB
MELEE_UNARMED_IDLE
MELEE_UNARMED_ATTACK_PUNCH_A
MELEE_UNARMED_ATTACK_KICK

COMBAT RANGED
RANGED_1H_AIMING
RANGED_1H_RELOAD
RANGED_1H_SHOOT
RANGED_1H_SHOOTING
RANGED_2H_AIMING
RANGED_2H_RELOAD
RANGED_2H_SHOOT
RANGED_2H_SHOOTING
RANGED_BOW_AIMING_IDLE
RANGED_BOW_DRAW
RANGED_BOW_DRAW_UP
RANGED_BOW_IDLE
RANGED_BOW_RELEASE
RANGED_BOW_RELEASE_UP
RANGED_MAGIC_RAISE
RANGED_MAGIC_SHOOT
RANGED_MAGIC_SUMMON
RANGED_MAGIC_SPELLCASTING
RANGED_MAGIC_SPELLCASTING_LONG

GENERAL
T-POSE
IDLE_A
IDLE_B
HIT_A
HIT_B
DEATH_A
DEATH_A_POSE
DEATH_B
DEATH_B_POSE
INTERACT
PICKUP
THROW
USE_ITEM
SPAWN_AIR
SPAWN_GROUND

SIMULATION
CHEERING
PUSH_UPS
LIE_DOWN
LIE_IDLE
LIE_STANDUP
SIT_CHAIR_DOWN
SIT_CHAIR_IDLE
SIT_CHAIR_STANDUP
SIT_CHAIR_FLOOR_DOWN
SIT_CHAIR_FLOOR_IDLE
SIT_CHAIR_FLOOR_STANDUP
SIT_UPS
WAVING

SPECIAL
SKELETONS_AWAKEN_FLOOR
SKELETONS_AWAKEN_FLOOR_LONG
SKELETONS_AWAKEN_STANDING
SKELETONS_IDLE
SKELETONS_TAUNT
SKELETONS_TAUNT_LONGER
SKELETONS_DEATH
SKELETONS_DEATH_POSE
SKELETONS_DEATH_RESURRECT
SKELETONS_INACTIVE_FLOOR_POSE
SKELETONS_INACTIVE_STANDING_POSE
SKELETONS_SPAWN_GROUND
SKELETONS_WALKING
EXPERIMENTAL_MEDIUM_TRANSFORM
```

### AL — Rig_Large

```text
MOVEMENT BASIC
RUNNING_A
WALKING_A

MOVEMENT ADVANCED
DODGE_BACKWARD
DODGE_FORWARD
DODGE_LEFT
DODGE_RIGHT

COMBAT MELEE
MELEE_BLOCK
MELEE_BLOCK_ATTACK
MELEE_BLOCK_HIT
MELEE_BLOCKING
MELEE_1H_SLASH
MELEE_1H_STAB
MELEE_2H_IDLE
MELEE_2H_ATTACK
MELEE_2H_SLAM
MELEE_DUALWIELD_SLASH
MELEE_DUALWIELD_SLASHCOMBO
MELEE_UNARMED_IDLE
MELEE_UNARMED_KICK
MELEE_UNARMED_PUNCH
MELEE_UNARMED_SMASH

GENERAL
T-POSE
IDLE_A
IDLE_B
HIT_A
DEATH_A
DEATH_A_POSE

SIMULATION
FLEXING

SPECIAL
EXPERIMENTAL_LARGE_TRANSFORM
```

### AT — tambahan 1.1, Rig_Medium saja menurut devlog

[Devlog resmi, 10 Desember 2025](https://kaylousberg.itch.io/kaykit-character-animations/devlog/1139588/character-animations-update-11), teks browser terbaca. Ejaan/case di bawah mengikuti teks devlog, bukan chart:

```text
Chop
Chopping
Dig
Digging
Fishing_Bite
Fishing_Cast
Fishing_Catch
Fishing_Idle
Fishing_Reeling
Fishing_Struggling
Fishing_Tug
Hammer
Hammering
Holding_A
Holding_B
Holding_C
Lockpick
Lockpicking
Pickaxe
Pickaxing
Saw
Sawing
Work_A
Work_B
Work_C
Working_A
Working_B
Working_C
```

Ini memperluas kecocokan prop KC07; bukan permintaan menambah gameplay tool/survival. `Hammer` bisa ditinjau sebagai bahan heavy motion, tetapi tidak otomatis menjadi combat slam dengan telegraph/recovery yang diperlukan.

## Matriks N01–N10 — kebutuhan vs bukti clip

Semua label current mengacu AM/AL/AT di atas dan KC02 Free. `Kandidat` berarti clip bernama ada di publikasi, **bukan aksi game selesai**.

| ID | Kandidat label dan rig | Yang terbukti / yang masih harus dibuat atau dicocokkan | Risiko |
|---|---|---|---|
| N01 idle/walk/run | Medium `IDLE_A/B`, `WALKING_A/B/C`, `RUNNING_A/B`; Large `IDLE_A/B`, `WALKING_A`, `RUNNING_A` | Kandidat lengkap untuk locomotion dasar kedua rig; blend tree, playback speed, root motion/foot sliding belum diuji. | MEDIUM |
| N02 jump/fall/landing | Medium `JUMP_START`, `JUMP_IDLE`, `JUMP_LAND`, `JUMP_FULL_SHORT/LONG` | Jump dan landing bernama. **Tidak ada label `FALL` terpisah pada chart yang dibaca**; `JUMP_IDLE` mungkin bahan airborne tetapi pose jatuh bebas harus dilihat nanti. Large chart tidak menunjukkan jump. Tidak menyatakan archive pasti tidak punya. | MEDIUM; Large UNKNOWN/HIGH bila wajib |
| N03 tiga distinct hits | Medium pilihan konkret **`MELEE_1H_ATTACK_SLICE_HORIZONTAL` → `MELEE_1H_ATTACK_SLICE_DIAGONAL` → `MELEE_1H_ATTACK_CHOP`**; alternatif `...STAB`/`...JUMP_CHOP` | Tiga gerak satu tangan berbeda bernama, bukan mengulang satu clip untuk tiga hit. Finisher feel, urutan, transition/weapon grip harus dinilai. **Event damage, cancel windows, no early-buffer/no hold** adalah implementasi gameplay, bukan fitur paket. Large chart hanya dua label 1H; jangan menganggap tiga 1H tersedia di Large. | MEDIUM |
| N04 block enter/hold/exit | Medium/Large `MELEE_BLOCK`, `MELEE_BLOCKING`, `MELEE_BLOCK_HIT`, `MELEE_BLOCK_ATTACK` | Block/hold/hit reaction kandidat kuat. Label saja tidak memastikan `MELEE_BLOCK` berisi enter+exit atau clip exit tersendiri. Blend/custom transition mungkin perlu; block omni, stamina dan arah damage di kode, bukan animasi. | MEDIUM; custom enter/exit UNKNOWN |
| N05 dodge | Medium/Large `DODGE_FORWARD/BACKWARD/LEFT/RIGHT` | Empat arah bernama. Tidak menjanjikan roll vs dash tertentu, root translation, durasi, atau collision fit. **I-frames dan stamina** ditetapkan gameplay. | MEDIUM |
| N06 minum potion/completion/interrupt | Medium `USE_ITEM` hanya lead; bottle KC08 / Druid accessories KC01 Extra sebagai prop candidate | **Drink spesifik belum terbukti**. Halaman KC02 masih menyebut eating/drinking pada future plans. Tidak menyimpulkan pasti nihil di archive; juga tidak menamakan `USE_ITEM` sebagai drink tanpa preview gerak. Hand-to-mouth, tilt bottle, prop visibility, completion event, interrupted transition kemungkinan animasi/edit baru. Membeli Source bukan membeli clip drink. | HIGH/UNKNOWN |
| N07 hurt/death/respawn | Medium `HIT_A/B`, `DEATH_A/B`, pose akhir, `SPAWN_AIR/GROUND`; Large `HIT_A`, `DEATH_A`, `DEATH_A_POSE` | Hurt/death bernama. Spawn untuk Medium adalah kandidat respawn visual, bukan checkpoint/reset state. Large spawn tidak terdaftar pada chart. Hurt interruption/respawn control tetap di game. | MEDIUM |
| N08 standard enemy | Medium locomotion/hit/death + salah satu `MELEE_1H_ATTACK_*`; skeleton-specific idle/walk/death opsional untuk KC03 saja | Basis lengkap secara kategori; wind-up/recovery bisa bagian serangan, **belum ada durasi/timeline terbukti**. Bukan izin mengganti ancient guardian menjadi skeleton. | MEDIUM; tema/remodel HIGH bila construct |
| N09 heavy enemy | Large `MELEE_2H_IDLE`, `MELEE_2H_ATTACK`, **`MELEE_2H_SLAM`**, `MELEE_UNARMED_SMASH`, locomotion/hit/death; Medium `MELEE_2H_ATTACK_CHOP`, tool `Hammer` | Slam eksplisit tersedia pada chart Large. Medium normal Barbarian bisa heavy weapon, Extra Barbarian besar memberi silhouette lebih kuat; jenis rig/clip exact per model tetap dicocokkan. Wind-up/recovery, hit pause, ground effect belum supplied proof. | MEDIUM; body/theme HIGH bila remodel |
| N10 ranged enemy | Medium `RANGED_BOW_DRAW`, `RANGED_BOW_AIMING_IDLE`, `RANGED_BOW_RELEASE`, `RANGED_BOW_IDLE`; atau `RANGED_1H/2H_AIMING`, `...SHOOT`, `...RELOAD`; locomotion/hit/death | Preparation/fire/recovery punya bahan bernama. Bow+arrow/crossbow ada di KC01, crossbow+arrow KC03. Projectile spawn socket, flight/impact, attack event dan string synchronization harus dibuat. Large ranged set **belum terbukti**. | MEDIUM |

**N11 bukan terselesaikan oleh tabel ini:** Large slam/smash + locomotion hanyalah kandidat gerak dasar; boss wake, sweep, charge, core expose, phase transitions, recovery dan death khas golem masih perlu audit sumber boss dan mungkin custom animasi. N12 animasi prop berada di audit world/integrasi, bukan humanoid library.

## Matriks cast dan senjata — tidak mencampur fungsi dengan lore

| Kebutuhan | Free-first online base | Remedy berbayar yang nyata | Gap dan kelas perubahan |
|---|---|---|---|
| M01 pemain manusia ringan | **Ranger KC01 Free2.0** untuk light clothing; Rogue tetap opsi lama, bukan satu-satunya. Ranger memegang sword dari kit yang sama | Series5 Hiker/Protagonists, Series4 Ninja/Werewolf-human sebagai alternatif, **$19.99 per series** | Ranger preview masih cape/quiver/bow identity; melepas aksesori jika terpisah adalah attachment change, bukan jaminan mesh cape bisa dihapus tanpa edit. Recolor **LOW**, detach/regrip **MEDIUM**, silhouette tubuh/pakaian baru **HIGH**. |
| M02 standard ancient guardian | KC01 Knight berzirah; KC03 Warrior/Minion hanya **alternatif undead yang belum disetujui** | Series4 Paladin; Series5 Black Knight | Knight/Paladin bisa menjadi penjaga bersenjata secara fungsi. Ancient glyph attachment/emissive/palette **LOW–MEDIUM**; mengubah manusia/bones menjadi stone construct **HIGH**, bukan recolor. |
| M03 heavy ancient guardian | KC01 Barbarian + axe_2handed candidate; ukuran dan armor perlu dibandingkan | KC01 Extra **$7.95** Barbarian besar; KC03 Extra Skeleton Golem **$7.95** dengan mismatch bones; Series6 Orc Brute **$19.99** | Extra besar mengurangi kebutuhan membuat body besar, tidak menghapus masalah lore/anatomi. Mereskalakan manusia saja belum menjamin heavy silhouette; changing skin/armor to stone may need remodel/reweight. |
| M04 ranged ancient guardian | KC01 Ranger/bow+arrow, atau Knight dengan crossbow attachment jika rig/grip cocok; KC03 Rogue/crossbow sebagai alternatif undead | Series6 Marksman / 4-GTN; Series5 Clanker, masing-masing series **$19.99** | Type of Marksman projectile dan mechanical weapon detail **UNCONFIRMED** dari teks. Menjaga satu ancient family memerlukan pilihan helmet/armor/glyph serasi, bukan tiga karakter acak. |
| M06 player one-handed sword | KC01 sword, public old manifest `sword_1handed` | Tidak perlu membeli tier premium untuk membuktikan kategori sword tersedia | Attach hand socket, orientation, scale, grip/clipping belum diuji. **LOW–MEDIUM**, bukan custom sword wajib. |
| M07 standard weapon | KC01 1H sword/axe, KC03 blade/axe | Paladin hammer atau Black Knight equipment bila bentuk disukai | Skeleton ornament atau terlalu besar dapat butuh mesh edit **MEDIUM**. |
| M08 heavy weapon | KC01 two-handed axe/sword candidate; KC07 hammer/mallet | Paladin hammer KC04 / Extra giant Barbarian accessories | Heavy read + reach + two-hand grip belum diperiksa. Scale/recolor **LOW**, handle/grip kitbash **MEDIUM**, body+weapon new silhouette **HIGH**. |
| M09 ranged + projectile | KC01 bow/crossbow + arrow; KC03 crossbow + `Skeleton_Arrow` | Series6 Marksman sebagai opsi cast, bukan bukti projectile gratis tambahan | Ranger preview memberi fakta **`BOW_WITHSTRING` blendshape untuk string**. Ini masih preview claim; driver blendshape/animation resource, spawn socket, collision/flight/trail bukan ready gameplay. |
| M20 potion prop | KC08 bottle_A/B/C dari manifest resmi lama; recolor/label ke potion | KC01 Extra Druid page menunjukkan potion bottles pada deskripsi gambar, tetapi tier/file model exact masih perlu diperiksa | Bottle source online tidak sama dengan N06 drink. Jangan membeli Druid hanya karena mengira ia membawa animation drink. |
| M05 stone-core boss | **Belum ada basis gratis KayKit yang terbukti memenuhi bentuk** | Series5 **Frost Golem $19.99** sebagai lead; KC03 Extra Skeleton Golem bukan batu | Frost→stone mungkin material-only **hanya bila silhouette/mesh cocok**; core opening/emissive insert/limb layout dapat memerlukan kitbash/remodel. Three attacks+two phases bukan klaim katalog. **HIGH/UNKNOWN**. |

## Dua preview karakter baru yang benar-benar dibuka

Dua gambar representatif berikut menggantikan fokus pada Rogue lama. Diagram daftar animasi AM/AL di atas dibuka hanya sebagai bukti teknis label, bukan tambahan shortlist gambar karakter.

1. **Ranger — KC01 Free 2.0**, sumber [halaman Adventurers](https://kaylousberg.itch.io/kaykit-adventurers). [Gambar resmi resolusi asli](https://img.itch.zone/aW1hZ2UvMjE2OTQ0MC8yMzgwODI0My5wbmc=/original/Suziuu.png). `PREVIEW`: manusia chibi berpakaian ringan cream/cokelat dengan scarf/cape biru; bow, arrow, quiver ditampilkan. Caption secara eksplisit menyebut `BOW_WITHSTRING` mempunyai blendshape untuk animasi tali. **Pedang tidak terlihat pada gambar ini**, tetapi kategori sword ada di paket; grip pedang belum dilihat. Ranger ini bukan Extra Engineer/Druid/Barbarian besar.
2. **The Paladin — KC04 Series4 paid $19.99**, sumber [halaman Series4](https://kaylousberg.itch.io/kaykit-series-4). [Gambar resmi resolusi asli](https://img.itch.zone/aW1hZ2UvMzcxMjE3NC8yMjEzODI2OC5wbmc=/original/2AqorH.png). `PREVIEW`: manusia berzirah emas/biru, helmet penuh, hammer, shield, book, dan statue; alternatif warna ditampilkan. Berguna menilai family silhouette guardian/heavy, **bukan bukti stone guardian atau free content**. Statue adalah prop pada preview, bukan klaim model hidup golem rigged.

Tidak ada gambar yang menyatakan semua aksesori/variasi di luar tier tersebut gratis. Tidak ada screenshot engine project atau bukti import dibuat.

## Cart riset free-first dan alternatif biaya

Ini daftar kandidat pengadaan **nanti**, bukan instruksi download atau izin belanja sekarang.

| Opsi | Isi yang dituju | Biaya minimum halaman | Yang masih belum ditutup |
|---|---|---|---|
| **Free-first inti** | KC01 Free2.0 + KC02 Free1.1; KC08 Free1.1 untuk bottle; KC07 Free bila hammer cocok | **$0** | Ancient guardian trio final, drink, block exit/fall confirmation, Godot import/rig mapping dan event timing. Semua source model tetap online. |
| Free skeleton alternative | Tambah KC03 Free1.1 | **$0 tambahan** | Tidak dipilih otomatis: perubahan lore undead; tidak menyelesaikan stone boss. |
| Heavy silhouette remedy | KC01 **Extra2.0**, selain free-first | **$7.95** | Memberi big Barbarian dan variasi warna, **tidak** memberi ancient skin/stone body atau clip drink. |
| Editable Adventurers remedy | KC01 **Source2.0** menggantikan pembelian Extra terpisah | **$11.95**, termasuk Extra | Membeli control/source editability; bukan hasil remodel yang sudah selesai. Jangan menjumlah $7.95 + $11.95 untuk paket yang sama. |
| Animated-source remedy | Tambah KC02 Source1.1 pada KC01 Source | **$14.99 tambahan; $26.94 total** | Memudahkan authoring dengan control rig; drink/custom transitions tetap pekerjaan animasi. Free FBX/glTF tetap dapat diedit/di-retarget dengan workflow yang sesuai, `.blend` paid bukan syarat mutlak recolor. |
| Premium family candidates | KC04/05/06 sesuai pilihan | **$19.99 per series**; ketiganya **$59.97** bila semua memang dibutuhkan | Tidak ada alasan membeli semua tanpa keputusan visual. Series5 memberi Frost Golem lead; tidak memastikan boss move set. |
| Skeleton large alternative | KC03 Extra atau Source | **$7.95** atau **$11.95** | Bentuk bones/lore mismatch tetap ada; **bukan** remedy yang dianjurkan untuk boss batu. |
| Tool alternative | KC07 Free; Extra/Source hanya jika isi tambahannya dibutuhkan | **$0 / $4.99 / $7.49** | Tool animations sudah Free KC02; tidak perlu membayar fishing/lockpicking untuk combat. |
| Bundle alternatif | [Complete KayKit Collection resmi](https://kaylousberg.com/game-assets/complete-kaykit-collection), [itch](https://kaylousberg.itch.io/kaykit-complete) | Maker site menampilkan **$150**; indeks itch pernah menampilkan promo berbeda, **bukan harga checkout yang dipastikan di audit ini** | Situs mengklaim seluruh SOURCE current+future; daftar eksplisit situs masih hanya sampai Series5. **Konfirmasi Series6/deliverables aktual sebelum membandingkan pembelian.** Tidak ada isi eksklusif menurut maker; bukan kewajiban membeli bundle untuk memakai free assets. |

Tidak ada asumsi budget user. Harga-harga di atas bukan pajak/fee/currency conversion. Harga minimum produk dan hak mengedit tidak membuktikan suatu customisation cepat atau hasil final dijamin.

## Jalur legacy yang diperiksa tetapi tidak dipakai untuk menambal gap current

**KC-L01 — (Legacy) KayKit - Character Animations**: [halaman resmi](https://kaylousberg.itch.io/kaykit-animations), `CATALOG` melalui browser. Free, CC0, animasi FBX/glTF; model contoh FBX/OBJ/DAE/glTF menurut FAQ. Halaman secara eksplisit menyatakan ini untuk **karakter lama tanpa kaki**, tidak akan diperbarui. Versi tersedia **1.2**. Tidak dihitung sebagai paket aktif kesembilan atau solusi drop-in Rig_Medium/Large.

Daftar publik persis dari teks halaman:

```text
Idle
Walk
Run
Hop
Jump
Defeat
Cheer
Wave
Laying Down Idle
Climbing
Attack (1h)
Heavy Attack
Block
Shoot (1h) (For pistols etc.)
Continuous Shooting (1h)
Shoot (2h) (For rifles, shotgun etc.)
Continuous Shooting (2h)

Update 1.2:
Attack - Spinning
Attack - Combo
Shoot (2h) Bow
Pick up
Throw
Interact
Dance
Roll
Dash Front
Dash Back
Dash Right
Dash Left
```

`Roll`, `Attack - Combo`, dan `Climbing` legacy tidak boleh dipindahkan ke matriks current hanya untuk membuat coverage tampak lengkap. Retarget/re-author legacy merupakan pekerjaan berbeda dengan risiko **HIGH**, dan tidak diperlukan untuk gap dodge karena library current sudah menyediakan empat dodge.

## Batas keputusan berikutnya

1. Pilih visual kandidat pemain Ranger+1H sword serta guardian family **tanpa** mengasumsikan undead disetujui. Kandidat biaya nol dapat ditinjau dulu; pilihan premium tidak diotorisasi oleh audit.
2. Saat user mengizinkan pengadaan: catat tier/versi/lisensi arsip aktual; cocokkan rig exact per model, nama resource clip, skeleton mapping, scale/material, hand sockets, bow blendshape dan projectile. Preview/catalog tidak memberi hasil uji Godot4.7.2 Compatibility.
3. N06 drink adalah gap prioritas: cari motion online yang cocok atau tentukan authoring **dengan menyebut custom animation**, bukan attachment/recolor. N02 fall dan N04 enter/exit diperiksa pada gerak/file actual sebelum menyatakan perlu clip baru.
4. Boss batu/core/3 attacks/2 phases dan ancient trio tetap keputusan asset/design lintas audit; jangan menyembunyikan remodel/re-rig/animasi custom di bawah istilah tweaking.
