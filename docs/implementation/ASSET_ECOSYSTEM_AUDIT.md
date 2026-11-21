# Audit Ekosistem Asset Online — The Lost Island

Tanggal: **20 November 2026**. Preferensi pengguna: **KayKit/chibi**, tetapi keputusan utama mengikuti kelengkapan ekosistem model, animasi, dan props yang serasi. Model produksi bersumber online; agent menangani penyesuaian. **Tidak ada pembelian, download paket model, atau import pada audit ini.** Temuan katalog bukan asset `VERIFIED` dan bukan bukti kompatibilitas Godot 4.7.2.

## Prinsip pemilihan

1. Pilih keluarga visual dan skeleton utama, bukan satu gambar karakter yang menarik. Gunakan paket pelengkap hanya untuk kebutuhan yang belum tertutup.
2. Bedakan **banyak paket tersedia**, **model yang sesuai tema tersedia**, dan **model/clip yang sudah diuji bekerja**. Ketiganya bukan klaim yang sama.
3. **LOW:** recolor/material, skala konsisten, aksesori/attachment, perakitan ulang prop statis. **MEDIUM:** kitbash geometri, pemisahan bagian, UV/material baru, penyusunan ulang clip yang sudah cocok. **HIGH:** mengganti anatomi/silhouette, remodel besar, skin weights/re-rig, atau animasi baru/retarget lintas keluarga tanpa bukti. Tingkat tersebut adalah perkiraan risiko, bukan hasil uji file.
4. Tidak mengganti penjaga kuno menjadi undead atau boss batu menjadi golem tulang hanya karena suatu paket tersedia. Perubahan desain tersebut membutuhkan keputusan tersendiri.
5. Tidak ada paket online yang otomatis menyediakan aturan khusus Pilar Simbol, Jalur Energi, snapshot boss, collision, atau keterjangkauan generator. Model dasar dapat diambil online; perakitan modul dan perilaku gameplay tetap diimplementasikan.

## Sumber katalog dan cara menghitung

[Katalog situs pembuat KayKit](https://kaylousberg.com/game-assets) menampilkan **18 entri**, termasuk satu bundle; ini **bukan 18 paket yang semuanya relevan** untuk game. Situs mencantumkan Character Animations, Forest Nature, Adventurers, Skeletons, Dungeon Remastered, Medieval Hexagon, Resource Bits, RPG Tools, Platformer, Block Bits, Prototype Bits, Furniture Bits, Halloween Bits, Holiday Bits, Restaurant Bits, Space Base Bits, dan City Builder Bits. [Halaman Complete Collection](https://kaylousberg.com/game-assets/complete-kaykit-collection) juga menautkan Mystery Monthly Series 4 dan 5. Identitas pembuat didukung [profil GitHub resmi](https://github.com/KayKit-Game-Assets) yang menautkan situs dan akun itch yang sama.

Nama lama, URL alias/rebrand, tier Free/Extra/Source, dan bundle tidak dihitung sebagai paket konten baru yang independen. Dungeon Remastered dan Dungeon Pack saat ini merupakan satu keluarga rilis, bukan dua solusi terpisah. Pack urban, restaurant, atau space tidak menjadi rekomendasi pulau hanya untuk menambah jumlah hasil.

Akses root itch dan sebagian halaman sempat HTTP 429 melalui reader/browser. Jalur alternatif yang digunakan adalah situs/GitHub pembuat, halaman publik yang dapat diakses, dan indeks pencarian yang diberi label bila isinya belum dibaca penuh. Tidak melewati login, paywall, atau pembatasan download.

## Harga dan lisensi

[Complete Collection](https://kaylousberg.com/game-assets/complete-kaykit-collection) menyebut isi **SOURCE tier** paket yang dirilis dan paket mendatang; situs menampilkan **USD 150**, sedangkan indeks itch saat audit menampilkan promosi **USD 99**. Ini bukan harga checkout yang dijamin. Bundle bukan syarat: pembuat menyatakan paket individual tetap tersedia gratis atau dengan harga terpisah. Jangan membeli seluruh koleksi sebelum gap kebutuhan dan tier yang benar-benar diperlukan jelas.

Lisensi setiap file/rilis tetap harus disimpan ketika pengadaan dilakukan. Label CC0 pada katalog tidak menghapus kebutuhan memeriksa tier dan file yang benar-benar diperoleh. Khusus [LOWPO Golem](https://standout7.itch.io/lowpo-golem), metadata itch menampilkan CC0 tetapi teks ketentuan halaman melarang redistribusi asset mentah; konflik harus diselesaikan sebelum file dibagikan lewat repository. Larangan training/dataset pada halaman itu bukan otomatis larangan menggunakan tool AI untuk mengerjakan game.

## Pelengkap non-model — tidak dihitung sebagai paket 3D

Bagian ini memperlihatkan jalur asset online untuk kebutuhan pendukung, bukan audit UI/audio lengkap atau bukti isi file telah diuji.

| Paket | Bukti halaman resmi | Peran dan batas |
|---|---|---|
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | Gratis, CC0, 80 file, sprite 512 × 512 | Kandidat texture particle hit/collect/dust; bukan shader air, sistem VFX Godot, atau telegraph gameplay siap pasang. |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | Gratis, CC0, 430 file | Kandidat panel/button/slider; tidak menyediakan logika HUD HP/stamina atau font/ikon spesifik yang sudah diperiksa. |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Gratis, CC0, 50 file; tag foley/footstep/weapon | Kandidat SFX; pemetaan tiap SFX, musik eksplorasi/boss, ambience, loop dan mix tetap belum dibuktikan. |

## Bukti tambahan langsung

[RPG Tools pada situs pembuat](https://kaylousberg.com/game-assets/rpg-tools) menyebut 45+ model, CC0, OBJ/FBX/glTF, termasuk hammer, axe, mallet dan lantern, serta penambahan 28 tool animations pada Character Animations. Ini memberi kandidat senjata/prop dan kegiatan bertema sama; bukan alasan menambah crafting/survival atau bukti clip heavy combat tertentu tersedia.

[LOWPO Golem](https://standout7.itch.io/lowpo-golem) menawarkan Free Rock/Earth/Iron dalam FBX, HEX USD 3.99 dengan empat golem tambahan dan format ekstra, Full USD 9.99 dengan source Blend/quad topology menurut halaman. Pembuat menyatakan humanoid rig/Mixamo compatible dan **no animations included**. [Preview Free yang dibuka](https://img.itch.zone/aW1nLzI2MzM3MzMzLnBuZw==/original/evXvUy.png) menunjukkan bentuk golem stylized, tetapi tidak membuktikan rig serasi KayKit, tiga pola boss, atau core turquoise. Kandidat ini hanya pelengkap dengan gap teknis/lisensi, bukan pilihan final.

## Cakupan karakter dan animasi

Rincian, seluruh sumber paket/manifest/chart, dan tier tersedia pada [audit karakter KayKit](ASSET_ECOSYSTEM_CHARACTERS.md) serta [12 paket pelengkap](ASSET_ECOSYSTEM_COMPLEMENTS.md). Kode `KC` dan `C` di bawah merujuk register kedua dokumen tersebut. Kata **ada** berarti ada bukti katalog/label publik, bukan file sudah diperoleh atau integrasi sudah lolos.

### Model pemain, cast, dan senjata

| Asset ID | Kandidat berbasis sumber online | Cakupan yang didukung dan gap | Risiko |
|---|---|---|---|
| M01 | KC01 Adventurers Free: Rogue atau Ranger; sword dari paket sama | Manusia chibi berpakaian tersedia. Pilihan pemain spesifik tetap mengikuti preview; outfit/palette/attachment belum diuji. | LOW–MEDIUM |
| M02 | KC01 Knight; KC04 Paladin atau KC05 Black Knight sebagai premium | Basis penjaga berzirah tersedia, **bukan** guardian batu siap pakai. Palette/glyph attachment lebih kecil pekerjaannya daripada membentuk anatomi patung baru. Skeleton bukan pengganti lore otomatis. | MEDIUM untuk armor; HIGH bila remodel stone construct |
| M03 | KC01 Barbarian Free + heavy weapon; Extra memberi Barbarian besar | Ada bentuk/calon senjata heavy; varian besar premium USD 7.95. Heavy kuno dari batu dan motion tepat belum terpilih. | MEDIUM–HIGH |
| M04 | KC01 Ranger/bow atau humanoid KayKit + crossbow; C02/C03 fallback non-undead | Calon ranged dan projectile tersedia, tetapi family armor/guardian serta pose/grip harus dipadankan. LOWPO bukan satu rig yang terbukti sama dengan KayKit. | MEDIUM–HIGH |
| M05 | KC05 Frost Golem premium; C01 LOWPO Rock/Earth/Iron Free | **Bentuk golem online ditemukan.** Frost→stone belum terbukti cukup recolor; LOWPO tanpa animasi dan lisensi konflik. Core dada, sweep/slam/charge, serta fase belum dipenuhi. | MEDIUM–HIGH / UNKNOWN |
| M06 | KC01 one-handed sword | Kategori sword tersedia; manifest resmi lama menyebut `sword_1handed`. Nama file 2.0, grip, arah depan, collision belum diperiksa. | LOW–MEDIUM |
| M07 | KC01 sword/axe | Ada basis weapon standard; ukuran/attachment/material mengikuti guardian yang dipilih. | LOW–MEDIUM |
| M08 | KC01 two-handed sword/axe; KC07 hammer/mallet | Ada sumber weapon/tool, tidak wajib membuat senjata dari nol. Two-hand grip dan silhouette heavy belum diuji; tool swing bukan otomatis combat slam. | LOW–MEDIUM |
| M09 | KC01 bow/crossbow/arrow | Model dan kandidat label ranged tersedia. Bow blendshape pada preview Ranger bukan projectile/attack system yang sudah diimplementasikan. | MEDIUM |

### Seluruh kebutuhan animasi N01–N12

Sumber label: [chart Rig_Medium](https://kaylousberg.com/content/3-game-assets/4-character-animations/rig_medium_overview.png), [chart Rig_Large](https://kaylousberg.com/content/3-game-assets/4-character-animations/rig_large_overview.png), [Character Animations](https://kaylousberg.itch.io/kaykit-character-animations). Chart telah dibuka pada audit karakter; ini nama publik chart, bukan pemeriksaan nama resource di FBX/glTF.

| Asset ID | Kandidat yang benar-benar bernama pada publikasi | Gap yang tidak boleh disembunyikan |
|---|---|---|
| N01 idle/walk/run | Medium/Large `IDLE_A/B`, `WALKING_A`, `RUNNING_A`; Medium punya variasi tambahan | Loop, blend, root motion, skala dan foot sliding belum diuji. |
| N02 jump/fall/land | Medium `JUMP_START`, `JUMP_IDLE`, `JUMP_LAND`, `JUMP_FULL_SHORT/LONG` | Fall terpisah belum terkonfirmasi; Large jump tidak terlihat pada chart. Tidak mengklaim file pasti tidak mempunyai clip lain. |
| N03 combo tiga hit | Medium `MELEE_1H_ATTACK_SLICE_HORIZONTAL`, `...SLICE_DIAGONAL`, `...CHOP` | **Tiga gerak berbeda tersedia sebagai kandidat**. Urutan, finisher feel, transition, active window dan no-buffer adalah implementasi/tuning. |
| N04 block | Medium/Large `MELEE_BLOCK`, `MELEE_BLOCKING`, `MELEE_BLOCK_HIT` | Enter/exit terpisah belum terbukti. Omni-block, reduction dan stamina bukan fitur model. |
| N05 dodge | Medium/Large `DODGE_FORWARD/BACKWARD/LEFT/RIGHT` | Bentuk dash/roll, durasi, root displacement belum diperiksa; i-frames dan stamina di gameplay. |
| N06 drink/completion/interrupt | `USE_ITEM` hanya lead, bukan bukti minum | **GAP PRIORITAS.** Halaman masih menyebut eating/drinking pada rencana. Perlu gerak nyata atau custom animation; membeli Source tidak otomatis memberi clip minum. |
| N07 hurt/death/respawn | Medium `HIT_A/B`, `DEATH_A/B`, `SPAWN_AIR/GROUND`; Large hit/death | Spawn Large belum terbukti. Respawn checkpoint/reset bukan clip. |
| N08 standard enemy | Medium locomotion + 1H attack + hit/death | Wind-up/recovery harus diperiksa dari timeline aktual; identitas guardian bukan diselesaikan oleh animasi. |
| N09 heavy enemy | Large `MELEE_2H_ATTACK`, `MELEE_2H_SLAM`, `MELEE_UNARMED_SMASH`; Medium 2H chop | Gerak heavy bernama ada. Daftar Large lebih sempit daripada Medium; tidak semua 161 animasi diasumsikan ada untuk kedua rig. |
| N10 ranged enemy | Medium `RANGED_BOW_DRAW`, `...AIMING_IDLE`, `...RELEASE`; 1H/2H aim/shoot/reload | Grip, drawstring, timing tembak dan projectile event perlu integrasi; Large ranged belum terkonfirmasi. |
| N11 boss | Large slam/smash sebagai bahan jika rig tepat; C01 LOWPO hanya basis humanoid tanpa animasi | **GAP PRIORITAS.** Wake, sweep, slam, charge, recovery/death khas boss dan transisi fase belum terbukti satu paket. Retarget lintas keluarga perlu diuji. |
| N12 props | Transform node/AnimationPlayer untuk panel, pilar, seal, artifact, checkpoint, bridge, gate | Dapat memakai model online, tetapi pivot, bagian terpisah, collision dan state/animasi masih perlu disusun agent; bukan skeletal clip humanoid. |

**Koreksi cakupan:** library current menyebut 161 animasi, mirror lama 133; penambahan 28 tool clips tidak membuktikan 161 gerak tersedia pada setiap rig. Library legacy untuk karakter tanpa kaki tidak dihitung sebagai solusi current. Tidak menjumlah tier, versi lama, chart lama, dan bundle untuk memperbesar angka.

## Biaya karakter: opsi, bukan izin belanja

| Jalur | Harga minimum katalog USD | Keputusan |
|---|---:|---|
| Adventurers Free + Character Animations Free | 0 | Kandidat awal paling rasional untuk pemain/weapon/motion; belum ancient trio/potion/boss lengkap. |
| Adventurers Extra | 7.95 | Opsional untuk Barbarian besar; tidak membeli animasi minum atau guardian batu. |
| Adventurers Source, termasuk Extra | 11.95 | Alternatif terhadap Extra, **bukan** tambahan 7.95 + 11.95 untuk pack sama. Source memudahkan edit; FBX/glTF Free tetap dapat diedit dengan workflow yang sesuai. |
| Character Animations Source | 14.99 | Source/control rig, bukan animasi eksklusif tambahan. |
| Satu Mystery Series 4, 5, atau 6 | 19.99 | Hanya jika karakter tertentu benar-benar menutup gap; jangan beli ketiganya demi jumlah. |

Harga tersebut tidak termasuk world packs, pajak/fee, atau biaya pengerjaan; bukan biaya total game. Tidak ada budget/pembelian yang diotorisasi pengguna.

## Cakupan world dan props M10–M28

Rincian 15 produk, tiga bundle yang tidak dihitung ganda, nama mesh publik, tier dan preview: [audit world KayKit](ASSET_ECOSYSTEM_WORLD.md). Kode `W` merujuk register di sana.

| Asset ID | Kandidat online / tier | Yang masih menjadi pekerjaan atau gap |
|---|---|---|
| M10 | W01 Forest Extra modular terrain; W03 Medieval Free tiles sebagai alternatif | Pulau 250×250, seeded mesh/layout, biome, slope, collision dan navigation bukan model siap main. |
| M11 | W01 Forest Free trees/bushes/grass | Kategori foliage tersedia; pemilihan model, skala, collision dan instancing perlu integrasi. |
| M12 | W01 Free rocks; modular cliff/terrain **Extra USD 9.99** | Cover dan rute highlands belum terbukti dapat dilalui; cliff layout bukan otomatis bagian Free. |
| M13 | W01 Free grass/bushes | Bunga belum eksplisit terkonfirmasi; wind/shader Compatibility belum ditutup. |
| M14 | W02 Dungeon Free floors/walls/stairs/arch/rubble | Public manifest versi lama mendukung base; perakitan ruin outdoor, weathering dan collision tetap perlu. |
| M15 | W02 Free pillar/column; W06 Prototype Free alternatif | Bisa memakai satu mesh empat kali. Glyph/interaksi/light feedback/collider perlu perakitan. |
| M16 | W02 backing stone; W10 Board Game tokens hanya alternatif | **GAP:** empat glyph berbeda dan relief urutan yang tepat belum ditemukan. Perlu sumber motif spesifik atau mesh/decal/texturing baru dari base online; bukan sekadar recolor. |
| M17 | W02 floor atau W06 Primitive_Floor sebagai backing | **GAP:** konektor energi flat lurus/siku dan visual routing belum terbukti tersedia. Kitbash/mesh edit serta pivot 90° dan script koneksi diperlukan. |
| M18 | W04 Resource **Extra USD 4.99** gems + W02 stone pedestal; W12 fountain alternatif | Crystal base online ada di tier berbayar. Altar/seal/source node khusus belum siap; kitbash dan material/feedback tetap perlu. |
| M19 | W04 Extra gems; W10 tokens/W11 props alternatif | Pilih tiga bentuk terbaca, bukan asal tiga recolor. Stable ID/pickup/state adalah implementasi. |
| M20 | W02 Free bottle_A/B/C dari public manifest | Bottle mesh base tersedia; grip/material/potion identity belum diuji dan N06 minum tetap gap. |
| M21 | W02 pillar/torch; W09 lantern alternatif | Base marker online tersedia, bukan model checkpoint spesifik yang sudah terkonfirmasi; active/inactive effect dan state dikerjakan project. |
| M22 | W02 stairs + W01 terrain/modules | Jalur naik, lompatan, altar summit dan collision dirakit sesuai batas traversal; belum runtime-proven. |
| M23 | W03 Free `building_bridge_A/B` | Bridge statis tersedia. Bagian terpisah, pivot, ukuran dan opening shortcut belum dibuktikan; split/edit mungkin perlu. |
| M24 | W02 wall_arched/gated/pillars + W03 gate | **GAP:** tiga sockets artefak dan gerbang kuno final. Base ada, tetapi tidak otomatis matching lock/socket atau animasi buka. |
| M25 | W02 modular ruins; W03 tower_A/B | Base landmark tersedia; miniatur RTS belum tentu enterable/berskala pemain tanpa adaptasi. |
| M26 | W03 water/coast/cloud geometry | **GAP runtime:** ocean material, shoreline, sky/environment/lighting Compatibility belum ditutup oleh model tiles. |
| M27 | W03 Medieval **Extra USD 9.99** dock/ships, kebutuhan POLISH | Dock/boat muncul di preview Extra; exact file/skala belum diperiksa. Intact ship menjadi shipwreck dapat memerlukan remodel besar. |
| M28 | W04 gems/W05 pickups sebagai anchor; Kenney Particle Pack untuk sprite | **GAP runtime:** telegraph, energy flow, hit/collect dan phase feedback tetap perlu material/mesh/particle logic, bukan paket model statis. |

## Rekomendasi ekosistem

**KayKit layak menjadi keluarga utama berdasarkan luas katalog, props, dan library gerak yang dipublikasikan; belum terbukti lengkap end-to-end atau lolos import.** Jalur paling konservatif:

1. **Inti ditetapkan pengguna:** Adventurers + Character Animations + Forest Nature + Dungeon Pack. Berikutnya cari sumber konkret bagi sisa kebutuhan dan modifikasi basis online yang sedikit berbeda bila perlu; ini bukan otorisasi pembelian atau bukti asset sudah siap.
2. **Pelengkap satu style:** Resource Bits untuk gems/artefak, Medieval Hexagon untuk bridge/dock/tower, Fantasy Weapons/RPG Tools hanya jika senjata inti tidak cukup. Extra dibeli hanya bila model yang dibutuhkan berada di sana.
3. **Musuh:** evaluasi Knight/Barbarian/Ranger atau humanoid KayKit berarmor dengan palette/glyph serasi lebih dahulu agar tidak memperbanyak family rig. Ini basis adaptasi, bukan trio ancient stone guardian yang sudah jadi. Skeletons hanya alternatif jika lore diubah secara eksplisit.
4. **Boss:** bandingkan Frost Golem Series 5 (family KayKit, premium) dengan LOWPO Golem (basis Free, beda rig/style dan lisensi konflik). Tidak membeli premium atau mengganti keluarga cast hanya untuk menutupi satu gambar boss. Bentuk, core dan animasi harus dinilai terpisah.
5. **Gap prioritas:** minum potion; tiga pola/transisi boss; guardian identity; glyph/relief; connector panel; seal/gate sockets; water/VFX runtime. Tetap mempertahankan fitur yang sudah disepakati, bukan menghapusnya agar asset terlihat lengkap.

### Remedy berbayar world — bukan biaya total game

| Tambahan opsional | Harga minimum USD teramati | Nilai yang benar-benar ditambah |
|---|---:|---|
| Forest Extra | 9.99 | Modular terrain/cliffs, tambahan model dan delapan palette. |
| Resource Extra | 4.99 | Gems, money/containers/food; hanya ambil kebutuhan crystal/artefak. |
| Medieval Extra | 9.99 | Termasuk dock/ships yang terlihat di preview Extra; bukan shipwreck siap main. |
| Dungeon Extra | 7.95 | Prop/texture tambahan; tidak wajib hanya untuk membuktikan base walls/pillars/stairs tersedia. |

**Tweak yang realistis dikerjakan agent:** palette/material, attachment senjata/crystal, perakitan pilar/altar, pivot dan transform props, UV/mesh edit terarah, serta integrasi clip/timing. **Bukan janji tweak ringan:** mengganti anatomi, membuat stone construct dari skeleton, skin weights/re-rig, atau animasi khusus minum/boss. Bagian berat tetap dapat ditangani sebagai pekerjaan tersendiri setelah file dan tooling diperiksa, tetapi belum dibuktikan dalam audit ini.

## Batas selesai audit

- Register karakter, world dan pelengkap menyimpan sumber resmi serta membedakan current, legacy, alias/rebrand, tier dan bundle.
- Matriks di dokumen ini mencakup **M01–M28 dan N01–N12** tanpa menyatakan semua kebutuhan telah tertutup.
- Preview resmi dan chart gerak diperiksa; metadata/path public manifest bukan inspeksi mesh/rig/clip di dalam paket.
- Tidak menjalankan Godot, download model, import, pembelian, retarget, atau tes gameplay. Status produksi inventaris tidak dinaikkan hanya karena katalog luas.
- Langkah berikutnya setelah pengguna menetapkan inti: tutup gap melalui sumber konkret dan rencana modifikasi yang dapat diperiksa, lalu lakukan pengadaan sampel dan uji import/rig/clip pada tahap yang diotorisasi. Jangan membeli bundle sebagai pengganti pembuktian gap.

## Luas scan yang dihitung tanpa duplikasi

| Jenis hasil | Jumlah | Makna |
|---|---:|---|
| Listing produk individual non-legacy | 31 | Termasuk alternatif dan kandidat yang ditolak/tidak direkomendasikan; bukan 31 paket yang cocok atau wajib diunduh. |
| Listing legacy pembanding | 3 | Dungeon legacy, Medieval Builder legacy, dan Character Animations legacy; bukan coverage pipeline current tambahan. |
| Bundle terpisah | 3 | Bits Bundle 1, Bits Bundle 2, Complete KayKit; tidak dihitung lagi sebagai produk individual baru. |

Total produk individual yang dibandingkan **34**, setelah dua overlap karakter/world dan alias Dungeon Remastered/current dideduplikasi. Tiga paket pendukung non-3D Kenney UI/Particle/Audio pada bagian terpisah tidak ditambahkan ke angka itu. Nama mesh/clip dan coverage tidak disimpulkan dari jumlah pemasaran.

Harga Complete KayKit **USD 150 juga terlihat lewat browser pada audit world**; indeks promosi USD 99 bukan harga checkout saat audit. Harga tetap perlu dilihat lagi jika kelak ada otorisasi pembelian.

## Hasil pencarian gap setelah keluarga inti disetujui

[Rencana Sumber Asset](ASSET_SOURCE_PLAN.md) adalah acuan terbaru: seluruh 54 kebutuhan inventaris dipetakan ke bahan konkret/jalur turunan, dengan rincian [karakter](ASSET_GAP_CHARACTERS.md), [world](ASSET_GAP_WORLD.md), dan [UI/audio](ASSET_GAP_UI_AUDIO.md). Sumber minum spesifik, crystal gratis, motif rune, geometry lurus/siku, shader/VFX, musik dan ambience kini ditemukan. Gap produksi tidak dianggap selesai: akun/pengadaan motion, budget primary boss/heavy, retarget, authoring khusus, mesh turunan dan renderer belum dibuktikan. Inventaris tetap MISSING untuk file yang belum diperoleh.
