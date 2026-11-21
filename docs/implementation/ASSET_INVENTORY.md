# Asset Inventory

Audit awal: **17 November 2026**. Acuan: [konsep game](../konsep-game.md) dan [Implementation Tracker](IMPLEMENTATION_TRACKER.md).

Inventaris mencatat kebutuhan logis, bukan jumlah file yang wajib diunduh. Satu paket dapat memenuhi beberapa baris; satu model dapat dipakai ulang melalui scene/material variant. Status baris di bawah mengikuti kondisi terkini (lihat audit kecukupan 21 November 2026 di bawah); status `MISSING` pada audit awal 17 November sudah diperbarui. Daftar kandidat di bawah belum membuktikan file tersedia atau bekerja pada project.

## Status Definitions

| Status | Arti dan bukti minimum |
|---|---|
| MISSING | Belum ada file produksi untuk kebutuhan tersebut |
| CANDIDATE | Kandidat spesifik dipilih, tetapi file belum diunduh/diperiksa |
| DOWNLOADED | File lokal, sumber, versi/tanggal, hash, dan lisensi tercatat |
| IMPORTED | Resource dapat dibuka di Godot, tetapi belum lolos pemeriksaan gameplay |
| VERIFIED | File/scene terpetakan dan lisensi, visual, material, rig/clip bila relevan, collision, serta perilakunya sudah diuji |
| PLACEHOLDER | Pengganti sementara untuk prototype; bukan final asset readiness |
| REJECTED | Ditolak dengan alasan yang tercatat; kebutuhan harus dipetakan ke pengganti |
| REFERENCE_ONLY | Gambar acuan atau asset laporan, bukan asset runtime 3D/audio |

`REQUIRED` berarti kebutuhan fungsional untuk release. `POLISH` berarti variasi tambahan yang dapat ditunda. Label ini adalah prioritas pengadaan, bukan jumlah encounter atau keputusan artistik baru.

## Existing Material

| Materi | Path yang tersedia | Status | Penggunaan |
|---|---|---|---|
| Concept art pulau, puzzle, route, karakter, boss | `docs/laporan/assets/` | REFERENCE_ONLY | Acuan palette, bentuk, framing dan silhouette; tidak menggantikan mesh, rig, animasi, atau collision |
| Logo game dan FILKOM | `docs/laporan/assets/` | REFERENCE_ONLY | Branding/laporan; pemakaian pada UI memerlukan import dan pemeriksaan tersendiri |
| Icon project sementara | `icon.svg` | PLACEHOLDER | Icon fondasi, bukan icon game final yang sudah diverifikasi |
| Preview ground | `scenes/main.tscn` | PLACEHOLDER | Permukaan uji awal; bukan pulau 250 × 250 meter |

## Candidate Sources

Halaman resmi diperiksa melalui web pada 17 November 2026. Lisensi yang dicantumkan adalah keterangan halaman sumber; file lisensi arsip dan cakupan tier yang diunduh tetap harus diperiksa. Belum ada download pada pekerjaan planning ini.

| Source ID | Kandidat resmi | Potensi pemakaian | Keterangan sumber dan batas pemeriksaan |
|---|---|---|---|
| S01 | [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | Pohon, batu, foliage | Halaman resmi terindeks mencantumkan CC0. Akses langsung dibatasi robots; daftar file/format/tier arsip belum diverifikasi. |
| S02 | [Kenney Castle Kit](https://kenney.nl/assets/castle-kit) | Modul batu, stairs, gate/tower sebagai bahan adaptasi | Halaman resmi terindeks mencantumkan CC0. Bentuk reruntuhan, sockets, dan ukuran gameplay perlu adaptasi serta uji. |
| S03 | [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | Karakter rigged dan weapon/accessory candidates | Halaman pembuat mencantumkan tier Free, CC0, FBX/glTF, dan aksesori senjata. Jangan menganggap isi EXTRA/SOURCE termasuk tier Free. |
| S04 | [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | Animasi karakter KayKit | Halaman pembuat mencantumkan CC0 dan FBX/glTF. Cocokkan clip nyata; ketersediaan animasi minum tidak diasumsikan. |
| S05 | [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) | Alternatif karakter/skeleton | Halaman pembuat mencantumkan CC0, FBX/glTF, dan humanoid rig. Versi/tier yang dipilih dan hasil retargeting belum diuji. |
| S06 | [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) | Alternatif locomotion/combat clips | Halaman pembuat mencantumkan CC0 dan FBX/GLB. Bukan bukti semua clip game tersedia atau semua rig langsung cocok. |
| S07 | [Quaternius Ultimate Nature](https://quaternius.com/packs/ultimatenature.html) | Alternatif nature kit | Halaman pembuat mencantumkan CC0 dan FBX/OBJ/Blend. Konversi ke glTF/GLB mungkin diperlukan; jangan menyatakan tersedia GLB sebelum arsip diperiksa. |
| S08 | [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) | Modul batu, stairs, gate bases, bottles dan props | Current 1.1 adalah rebrand Dungeon Remastered, bukan legacy `/kaykit-dungeon`. Free 200 model, Extra/Source terpisah; FBX/glTF/OBJ, CC0 menurut halaman. Manifest repo 1.0 bukan daftar file arsip 1.1. |
| S10 | [Quaternius Ultimate Modular Men / Adventurer](https://quaternius.com/packs/ultimatemodularcharacters.html) | Alternatif pemain berpakaian, proporsi non-chibi | Model Adventurer dipublikasikan pada [akun pembuat](https://poly.pizza/m/5EGWBMpuXq). Paket mengklaim 11 karakter/24 animasi; clip, rig, dan attachment pedang belum diperiksa. Label CC0 bertentangan dengan lisensi global QAL; belum dipilih/diunduh. |
| S09 | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Kandidat footsteps/weapon/foley | Halaman resmi terindeks mencantumkan CC0. Nama clip, format, dan kecukupan SFX harus diperiksa dari file. |
| S11 | [KayKit Forest Nature](https://kaylousberg.itch.io/kaykit-forest) | Nature utama satu style | Free 100+ trees/rocks/bush/grass; modular terrain/cliffs Extra USD 9.99. CC0 dan FBX/glTF/OBJ menurut halaman; belum diunduh. |
| S12 | [KayKit Medieval Hexagon](https://kaylousberg.itch.io/kaykit-medieval-hexagon) | Bridge, tower, coast; dock/ship optional | Free bridge/tower/coast candidates; dock/ship terlihat pada Extra USD 9.99. Skala RTS/hex dan gameplay collision belum diuji. |
| S13 | [KayKit Resource Bits](https://kaylousberg.itch.io/resource-bits) | Gems/crystal/artefak base | Gems berada pada Extra USD 4.99 menurut halaman/preview; bukan crystal Free yang sudah terbukti. |
| S14 | [KayKit Fantasy Weapons Bits](https://kaylousberg.itch.io/fantasy-weapons-bits) | Pelengkap senjata | Free 25+ model, Extra elemental USD 4.99; tidak perlu dipakai jika Adventurers sudah mencukupi. |
| S15 | [KayKit RPG Tools Bits](https://kaylousberg.itch.io/rpg-tools-bits) | Hammer/mallet/lantern alternatif | Free 45+ model; clip tool berada pada Character Animations. Tidak menambah crafting/fishing ke scope. |
| S16 | [KayKit Mystery Monthly Series 5](https://kaylousberg.itch.io/kaykit-series-5) | Frost Golem/Black Knight dan karakter alternatif | USD 19.99 per series menurut halaman, source termasuk. Frost Golem adalah lead boss, bukan bukti batu/core/semua serangan sudah siap. Series 4/6 dicatat pada audit karakter. |
| S17 | [LOWPO Golem](https://standout7.itch.io/lowpo-golem) | Pelengkap boss batu | Free Rock/Earth/Iron FBX, humanoid rig, eksplisit tanpa animasi. Beda family KayKit; terms non-redistribution vs metadata CC0 bertentangan, belum aman diputuskan untuk pengadaan/repo. |

Mulai dari satu family karakter dan satu environment kit. S05–S07/S08 adalah alternatif atau pengisi kekurangan, bukan kewajiban mengunduh semua paket. Uji sampel berdampingan sebelum mencampurkan kit dengan proporsi/material berbeda. Sumber musik, ambience, font, dan SFX yang belum tertutup tetap dicari; belum ada klaim lisensi untuk file yang belum dipilih.

**Pemeriksaan ulang lisensi, 20 November 2026:** beberapa halaman paket Quaternius masih menyebut CC0, sedangkan [halaman lisensi resmi](https://quaternius.com/license.html) menampilkan Quaternius Asset License v1.0, diperbarui 28 Agustus 2026. QAL mengizinkan penggunaan dalam produk dan pekerjaan kolaborator, tetapi membatasi redistribusi sebagai asset mandiri. Jangan menyimpulkan izin redistribusi file mentah pada repo dari label CC0 lama saja; cakupan lisensi paket yang benar-benar diperoleh perlu dipastikan sebelum pengadaan/integrasi. Preview visual tidak menyelesaikan konflik ini.

### Arah visual dan persetujuan sampel — 20 November 2026

Pengguna menetapkan pemain manusia awak kapal/petualang berpakaian ringan dengan pedang satu tangan; musuh penjaga kuno satu keluarga visual dengan pembeda standard/heavy/ranged; boss tetap golem batu berinti energi. Detail ada pada [konsep aktif](../konsep-game.md#arah-karakter-dan-musuh--ditetapkan-20-november-2026).

Pengguna lebih menyukai KayKit/chibi, tetapi memprioritaskan **kelengkapan ekosistem asset online yang serasi** daripada satu model. Lakukan scan luas karakter, senjata, animasi, musuh/boss, nature, reruntuhan, dan props; map ke Asset ID serta pisahkan gratis/berbayar, lisensi, dan biaya penyesuaian. Model produksi bersumber online dan agent menangani penyesuaian; jangan menyamakan recolor/attachment/kitbash dengan remodel/re-rig/animasi baru. Scan dan preview saat ini bukan izin pembelian, download paket model, atau import. Semua status produksi tetap mengikuti bukti file dan pengujian, bukan preferensi visual.

Riset gambar environment tersedia pada [Riset Asset Environment](ASSET_ENVIRONMENT_RESEARCH.md): Kenney Nature Kit, Quaternius Ultimate Nature, dan Ultimate Modular Ruins. Ini shortlist perbandingan, bukan pilihan final atau bukti ketersediaan file produksi.

Riset karakter tersedia pada [Riset Kandidat Karakter 3D](ASSET_CHARACTER_RESEARCH.md): Adventurer Quaternius sebagai opsi non-chibi dan Rogue KayKit sebagai alternatif chibi. Rock Golem Joseph George hanya basis adaptasi yang jauh dari acuan; penjaga kuno standard/heavy/ranged dan boss siap pakai tetap belum tertutup. Gambar sudah diperiksa, bukan file model/rig/animasi.

Shortlist awal di dua dokumen di atas merupakan **riset historis yang lebih sempit**, bukan hasil audit kelengkapan ekosistem. Preferensi terbaru KayKit/chibi menggantikan prioritas Adventurer non-chibi pada riset karakter tersebut; keluarga musuh batu dan boss tetap perlu dicari atau dinilai biaya adaptasinya tanpa mengubah lore diam-diam.

**Audit aktif yang lebih luas:** [Audit Ekosistem Asset Online](ASSET_ECOSYSTEM_AUDIT.md), dengan register [karakter/animasi](ASSET_ECOSYSTEM_CHARACTERS.md), [world/props](ASSET_ECOSYSTEM_WORLD.md), dan [pelengkap/boss](ASSET_ECOSYSTEM_COMPLEMENTS.md). Rekomendasi utama sekarang KayKit Adventurers + Character Animations + Forest + Dungeon, bukan wajib mencampur Quaternius Nature/Ruins. Seluruh M01–M28 dan N01–N12 dipetakan; banyak kandidat belum berarti semua kebutuhan tertutup. Harga adalah minimum katalog pada tanggal audit, bukan otorisasi pembelian atau harga checkout permanen.

**Inti kini ditetapkan pengguna**, bukan sekadar preferensi: KayKit Adventurers + Character Animations + Forest Nature + Dungeon. Sisa model boleh sedikit berbeda dan dimodifikasi agent. Sumber gap spesifik serta edit turunannya dicatat pada [world/puzzle/water/VFX](ASSET_GAP_WORLD.md) dan [UI/audio](ASSET_GAP_UI_AUDIO.md). File produksi tetap `MISSING` sampai benar-benar diperoleh; sumber yang ditemukan tidak sama dengan model/clip yang sudah cocok dan teruji.

**Acuan pengadaan terbaru:** [Rencana Sumber Asset](ASSET_SOURCE_PLAN.md) memetakan seluruh 54 kebutuhan ke sumber bahan atau authoring turunan. [Gap karakter](ASSET_GAP_CHARACTERS.md) memuat exact motion Mixamo dan basis guardian/golem; sumber world/UI/audio di atas melengkapinya. Tahap ini memilih bahan, bukan menyatakan semua model/clip final sudah terpenuhi. Akun Mixamo, biaya primary boss/heavy, retarget, authoring wake/charge dan pengujian tetap gate.

**Unduhan 20 November 2026:** 25 file/paket gratis (lima paket KayKit inti+Medieval, Kenney, rune, track, crystal, flower, audio, shader) sudah diunduh ke `downloads/` lokal dan diverifikasi integritas/lisensinya; lihat [Catatan Unduhan Asset](ASSET_DOWNLOADS.md).

**Ekstraksi dan import 21 November 2026 (P02-01/02):** subset yang dipakai ada di `assets/third_party/` (1.681 file, 74 MB; path di bawah relatif terhadap folder itu). Godot 4.7.2 mengimpor seluruh 1.281 file yang bisa diimpor tanpa error/warning. Uji muat headless: Rock Golem GLB (28 bone), Rogue (23 bone), Rig_Medium/Rig_Large CombatMelee (22/16 clip), pilar Dungeon, dan `Drinking.fbx` (37 bone) berhasil di-instantiate. Rogue, Knight, dan Barbarian memiliki 23 nama bone yang sama dengan library Rig_Medium/Rig_Large; track animasi Godot merujuk nama bone. Koreksi pada audit kecukupan di bawah: rest pose karakter identik dengan Rig_Medium tetapi **tidak** dengan Rig_Large, dan kesamaan nama bukan jaminan kompatibilitas pose. Kecocokan visual belum dilihat.

`IMPORTED` dipakai hanya bila file yang ter-import langsung memenuhi kebutuhan. Kebutuhan yang masih memerlukan perakitan, edit mesh, atau retarget tetap `MISSING`, dengan basis yang sudah ter-import dicatat di kolom file. Belum ada baris `VERIFIED`.

### Audit kecukupan asset — 21 November 2026 (ambang visual dilonggarkan)

Pengguna menyatakan model yang mirip/cukup sudah memadai (tidak harus bagus atau persis concept art) dan recolor diutamakan daripada ubah bentuk. Dengan ambang itu: **bahan awal cukup; tidak ada model, paket berbayar, atau pencarian sumber baru yang wajib.** Shipwreck/dock (M27) opsional. Yang tersisa bukan unduhan: (a) retarget/aplikasi N06 dan N11 serta authoring wake/charge boss; (b) kode dan perakitan (terrain procedural, logika puzzle/UI/state, wrapper scene, collision, reskin guardian, material golem, socket crystal); (c) verifikasi visual/gameplay. Tidak ada gameplay dan tidak ada baris `VERIFIED`.

**Angka mentah bukan kesiapan.** 1.681 file di `assets/third_party/` (1.281 bisa diimpor) adalah jumlah berkas, bukan jumlah kebutuhan. Dari 54 baris: 31 `IMPORTED` dan 23 `MISSING` (perlu perakitan/edit/retarget). Angka ini tidak dinaikkan oleh audit ini. Catatan clone baru: FBX Mixamo (N06/N11) di-gitignore karena repo GitHub ternyata publik; salinan lokal ada, tetapi clone baru tidak memilikinya dan tim harus mengunduh sendiri dari Mixamo, sehingga hitungan di atas berlaku untuk salinan kerja lokal ini, bukan fresh clone.

**Bukti satu kali (parse statis GLB, tanpa Godot; skrip sementara sudah dihapus):** Rogue, Knight, Barbarian, dan Ranger dibandingkan dengan `Rig_Medium_General` dan `Rig_Medium_CombatMelee`: 23 joint, nama dan parent sama, translasi dan rotasi rest pose identik (23/23), seluruh target channel animasi (15 dan 22 clip) menemukan joint di karakter. Terhadap `Rig_Large_CombatMelee`: nama sama dan seluruh 16 clip menemukan target, tetapi rest translasi hanya 1/23 cocok (selisih hingga ±0,76 pada head/upperarm/hips) dan clip membawa track translation/rotation/scale; pada karakter Free (berproporsi Medium) clip Large berpotensi mendistorsi, sehingga clip Medium dipakai untuk semua karakter KayKit. Koreksi: klaim lama bahwa Barbarian "sama dengan Rig_Large" hanya benar untuk nama bone. Kesamaan nama/rest pose belum menjamin hasil visual; pose tidak dilihat, dan flag loop tetap tidak ada pada import (tidak ada klaim semantik loop). Rock Golem: 28 joint bernama generik `Bone*`, tanpa clip dan tanpa image; tidak ada kecocokan dengan rig KayKit atau Mixamo, jadi N11 tetap kerja retarget/authoring.

## Models & World Resources

Kolom file/scene diisi setelah pengadaan. Basis model diprioritaskan dari sumber online; perakitan, modifikasi mesh/material, procedural terrain dan animasi/gameplay yang belum tercakup adalah pekerjaan agent yang tetap harus dibuktikan, bukan asset yang sudah selesai.

| Asset ID | Kebutuhan logis | Prioritas | Kandidat/fallback awal | Status | File/scene aktual |
|---|---|---|---|---|---|
| M01 | Satu karakter pemain rigged | REQUIRED | S03 Rogue/Ranger Free sebagai kandidat utama; model spesifik belum dipilih | IMPORTED | `kaykit/adventurers/characters/Rogue.glb`, `Rogue_Hooded.glb`, `Ranger.glb` — pilihan final belum ditetapkan |
| M02 | Standard melee penjaga kuno, silhouette ramping terbaca | REQUIRED | S03 Knight Free sebagai model dasar cukup; recolor batu/metal tua + accent; Paladin/Black Knight premium tidak wajib | MISSING | Basis ter-import: `kaykit/adventurers/characters/Knight.glb`; reskin guardian belum dibuat, belum siap penuh |
| M03 | Heavy melee penjaga kuno, tubuh lebih besar/weapon berat | REQUIRED | S03 Barbarian Free cukup sebagai model dasar (Extra USD 7.95 tidak wajib). Heavy lewat skala seragam + senjata 2H + recolor | MISSING | Basis ter-import: `kaykit/adventurers/characters/Barbarian.glb` (rest pose sama dengan Rig_Medium, bukan Rig_Large); reskin belum dibuat, belum siap penuh |
| M04 | Ranged penjaga kuno, weapon silhouette terbaca | REQUIRED | S03 Ranger/bow atau humanoid + crossbow; model dasar cukup, perlu recolor/attachment | MISSING | Basis ter-import: `Knight.glb`/`Ranger.glb` + `crossbow_2handed.gltf`; reskin/attachment belum dibuat, belum siap penuh |
| M05 | Golem Penjaga Gerbang, inti energi dan bagian yang dapat dianimasikan | REQUIRED | **Dipilih pengguna 20 Nov 2026:** Rock Golem Joseph George (BlendSwap, CC0, gratis). Frost Golem tidak dibeli. Titik awal cukup: recolor + skala seragam + attachment crystal iPoly3D; reproportion/re-rig anatomis tidak wajib kecuali pengujian visual nanti membuktikan perlu | MISSING | Basis ter-import: `blendswap/rock_golem/rock_golem.glb` — konversi mentah Blender 4.5.16 (2 primitive mesh, armature 28 bone, tanpa animasi, tanpa image eksternal; bounding ±20,2 × 11,6 × 4,6 unit sehingga perlu skala seragam). Sumber `.blend` di `source/`. Sisa: material, skala, socket core, animasi (N11) |
| M06 | Pedang satu tangan pemain dan attachment | REQUIRED | S03 sword Free; attachment/clip mapping belum diuji | IMPORTED | `kaykit/adventurers/props/sword_1handed.gltf` |
| M07 | Weapon standard melee | REQUIRED | S03 sword/axe; S14 hanya bila kurang | IMPORTED | `kaykit/adventurers/props/sword_1handed.gltf`, `axe_1handed.gltf`, `dagger.gltf` |
| M08 | Weapon heavy melee | REQUIRED | S03 two-handed weapon; S14/S15 hammer alternatif | IMPORTED | `kaykit/adventurers/props/axe_2handed.gltf`, `sword_2handed.gltf` |
| M09 | Weapon ranged dan projectile | REQUIRED | S03 bow/crossbow/arrow; spawn origin, grip dan string belum diuji | IMPORTED | `kaykit/adventurers/props/crossbow_2handed.gltf`, `arrow_crossbow.gltf`, `bow_withString.gltf`, `arrow_bow.gltf` |
| M10 | Terrain mesh, biome material, collision | REQUIRED | S11 Extra modular base atau S12 tiles; procedural seeded mesh/layout tetap implementasi project | MISSING | — |
| M11 | Pohon dan foliage untuk Grassland/Forest | REQUIRED | S11 Free utama; S01/S07 alternatif, bukan wajib dicampur | IMPORTED | `kaykit/forest_nature/Tree_1..4_*`, `Tree_Bare_1..2_*`, `Bush_1..4_*` (17 pohon, 22 semak) |
| M12 | Batu, cliffs, cover, dan variasi elevasi | REQUIRED | S11 Free rocks; modular cliff/terrain Extra; traversal/collision belum diuji | IMPORTED | `kaykit/forest_nature/Rock_1..3_*` (43 batu); cliff modular tidak ada di tier Free |
| M13 | Rumput, semak, bunga, variasi dekorasi | POLISH | S11 grass/bush Free + Flower A Isa Lousberg CC0 dari Poly Pizza; scale/palette belum diuji | IMPORTED | `kaykit/forest_nature/Grass_1..2_*`, `polypizza/flower_a_isa_lousberg.glb` |
| M14 | Ruin floor, wall, steps, arch | REQUIRED | S08 Free stone modules utama; S02 alternatif | IMPORTED | `kaykit/dungeon/` — `floor_tile_large*.gltf`, `wall_arched.gltf`, `wall_doorway.gltf`, `stairs*.gltf`, `rubble_*.gltf`, dll. |
| M15 | Empat pilar interaktif | REQUIRED | S08 column/pillar base diulang; glyph/trigger/state perlu perakitan agent | MISSING | Basis ter-import: `kaykit/dungeon/pillar.gltf`, `pillar_decorated.gltf`, `column.gltf` |
| M16 | Empat glyph berbeda bentuk dan relief urutan | REQUIRED | Kenney Rune Pack CC0/vector: cross, arrow, fork, diamond dari preview; backing S08. Extrusi/relief edit agent belum dibuat | MISSING | Basis ter-import: `kenney/rune_pack/vector/*.svg`, `grey_tile/*.png` |
| M17 | Tiga panel energi putar dan connector lurus/siku | REQUIRED | Kenney Starter Kit Racing `track-straight`/`track-corner` CC0 + floor S08; trimming/UV/endpoints perlu edit | MISSING | Basis ter-import: `kenney/starter_kit_racing/track-straight.glb`, `track-corner.glb` |
| M18 | Source crystal, altar tujuan, seal feedback | REQUIRED | iPoly3D Crystal CC0 gratis + S08 pedestal + Rune Pack/ring VFX; assembly belum dibuat | MISSING | Basis ter-import: `polypizza/crystal_ipoly3d.glb`, pilar Dungeon, `shaders/ring_aoe/` |
| M19 | Representasi tiga artifact dengan stable ID | REQUIRED | Rune Pack cross/fork/diamond + S08 stone fragments + crystal CC0; mesh turunan/matching socket belum dibuat | MISSING | Basis ter-import: rune pack, `polypizza/crystal_ipoly3d.glb` |
| M20 | Potion world pickup dan prop animasi minum | REQUIRED | S08 Free bottle base; material/hand grip dan N06 tetap perlu pemeriksaan | IMPORTED | `kaykit/dungeon/bottle_A_green.gltf` (+ varian `bottle_A/B/C_*`); hand grip belum diuji |
| M21 | Checkpoint marker | REQUIRED | S08 pillar/torch atau S15 lantern; active/inactive feedback dan state di project | MISSING | Basis ter-import: `kaykit/dungeon/torch.gltf`, `torch_lit.gltf`, pilar |
| M22 | Jalur naik, steps/ledges, dan puncak altar | REQUIRED | S08 stairs + S11 modules; rute, altar, collision dan jump gap dirakit/diuji agent | MISSING | Basis ter-import: `kaykit/dungeon/stairs*.gltf` |
| M23 | Bridge shortcut dengan state/collision terbuka | REQUIRED | S12 Free bridge_A/B; bagian terpisah/pivot/open state belum diketahui | IMPORTED | `kaykit/medieval_hexagon/buildings/neutral/building_bridge_A.gltf`, `_B.gltf`; open state belum diperiksa |
| M24 | Ancient gate, tiga sockets, arena boundary | REQUIRED | S08 gate + plate floor; recess dari motif artefak Rune Pack yang sama; Boolean/topology dan opening perlu edit agent | MISSING | Basis ter-import: `kaykit/dungeon/wall_archedwindow_gated.gltf`, `wall_doorway.gltf` |
| M25 | Landmark menara/reruntuhan puncak | REQUIRED | S08 stacked ruins utama; menara Medieval tidak diambil (tidak ada varian warna netral) | MISSING | Basis ter-import: modul Dungeon; susunan landmark belum dibuat |
| M26 | Ocean/water surface, sky dan lighting setup | REQUIRED | taillight-games Pixelated Water MIT, turunan opaque konservatif + S12 geometry; full depth formula perlu port Compatibility, belum render-tested | MISSING | Basis ter-import: `shaders/pixelated_water/`, `kaykit/medieval_hexagon/tiles/base/hex_water.gltf`, `tiles/coast/*` |
| M27 | Dock/shipwreck untuk konteks cerita | POLISH | **Opsional, tanpa art wajib.** Konteks cerita cukup lewat opening/outro teks dan dermaga/gerbang; dock/ship Extra tidak dibeli, tidak ada remodel shipwreck | MISSING | — (tidak ada pekerjaan wajib) |
| M28 | Bentuk/material telegraph, energy flow, hit/collect feedback | REQUIRED | Ring/slash shader MIT, cone port, Kenney particle textures; material/timing/CPU particles perlu integrasi | MISSING | Basis ter-import: `shaders/ring_aoe/`, `shaders/fiery_slash/`, `kenney/particle_pack/` |

Variasi pohon/batu dapat memakai instancing. Jumlah variasi final mengikuti kebutuhan visual dan profiling, tidak ditentukan dari jumlah file dalam paket.

## Animation Coverage

Catat nama clip asli, target skeleton, retarget mapping, durasi/loop, dan resource animation yang dipakai. Animasi yang terlihat di preview paket belum dianggap tersedia dalam tier yang diunduh.

Nama clip dan durasi di bawah dibaca dari file yang sudah di-import Godot (21 November 2026), bukan dari gambar katalog. Path relatif terhadap `assets/third_party/kaykit/character_animations/animations/`. **Tidak ada clip yang membawa flag loop setelah import** (glTF tidak menyimpannya); loop idle/locomotion/hold harus di-set lewat import settings. Integrasi dan timing gameplay belum diuji.

| Animation ID | Aksi wajib | Kandidat/metode | Status | Clip/resource aktual |
|---|---|---|---|---|
| N01 | Player idle, walk/run | S04 Medium idle/walk/run; loop di-set saat integrasi | IMPORTED | `Rig_Medium_General`: `Idle_A` 1,07 s, `Idle_B` 2,13 s; `Rig_Medium_MovementBasic`: `Walking_A/B/C`, `Running_A/B` 0,80 s |
| N02 | Jump, fall, landing | S04 Medium; `Jump_Idle` dipakai sebagai loop jatuh | IMPORTED | `Rig_Medium_MovementBasic`: `Jump_Start` 0,60 s, `Jump_Idle` 1,07 s, `Jump_Land` 0,67 s |
| N03 | Attack 1, attack 2, finisher | S04 Medium; event window dan no-buffer di game | IMPORTED | `Rig_Medium_CombatMelee`: `Melee_1H_Attack_Slice_Horizontal` 1,37 s → `Melee_1H_Attack_Slice_Diagonal` 1,00 s → `Melee_1H_Attack_Chop` 1,07 s |
| N04 | Block enter/hold/exit | S04; enter = `Melee_Block`, hold = `Melee_Blocking`, exit via blend; omni-block di game | IMPORTED | `Rig_Medium_CombatMelee`: `Melee_Block`, `Melee_Blocking`, `Melee_Block_Hit` (masing-masing 1,07 s) |
| N05 | Dodge | S04 empat arah; i-frames/collision/stamina di game | IMPORTED | `Rig_Medium_MovementAdvanced`: `Dodge_Forward/Backward/Left/Right` 0,40 s |
| N06 | Potion drink, completion, interrupt transition | Mixamo Drinking perlu retarget ke rig KayKit (HIGH); fallback `Use_Item` 1,60 s; completion/interrupt di game | MISSING | Basis ter-import **hanya di salinan lokal** (FBX Mixamo di-gitignore, tidak ikut push publik; clone baru tidak memilikinya, tim harus mengunduh sendiri dari Mixamo): `assets/third_party/mixamo/Drinking.fbx` (skeleton Mixamo 37 bone, clip `mixamo_com`). **Gap nyata:** retarget/aplikasi; fallback `Use_Item` KayKit ada di repo |
| N07 | Player hurt/death/respawn transition | S04 Medium; checkpoint/reset tetap script | IMPORTED | `Rig_Medium_General`: `Hit_A` 0,67 s, `Hit_B` 0,87 s, `Death_A` 0,80 s, `Death_B` 2,63 s, `Spawn_Ground`/`Spawn_Air` 1,30 s |
| N08 | Standard melee movement, wind-up, attack, recovery, hurt/death | S04 Medium; wind-up/recovery dibaca dari timeline saat integrasi | IMPORTED | Locomotion + `Melee_1H_Attack_*` + `Hit_*`/`Death_*` dari `Rig_Medium_*` |
| N09 | Heavy movement, wind-up, slam, recovery, hurt/death | Pakai clip `Rig_Medium_*` pada Barbarian (rest pose identik, lihat audit kecukupan); clip `Rig_Large_*` punya rest pose berbeda sehingga tidak dipasang langsung pada Barbarian Free. Skala heavy lewat scale node seragam | IMPORTED | Jalur yang cocok untuk Barbarian: `Rig_Medium_CombatMelee`: `Melee_2H_Attack_Chop`, `Melee_2H_Attack_Slice`, `Melee_2H_Idle`; locomotion/hit/death dari `Rig_Medium_*`. Referensi Large (hanya bila memakai model Large): `Rig_Large_CombatMelee` `Melee_2H_Slam` 2,83 s, `Melee_Unarmed_Smash` 3,47 s, `Melee_2H_Attack` 1,33 s; `Rig_Large_MovementBasic`; `Rig_Large_General` |
| N10 | Ranged preparation, fire, recovery, movement/hurt/death | S04 Medium; projectile event di game | IMPORTED | `Rig_Medium_CombatRanged`: `Ranged_2H_Aiming` 1,60 s, `Ranged_2H_Shoot` 1,07 s, `Ranged_2H_Reload` 1,60 s; alternatif `Ranged_Bow_Draw`/`Ranged_Bow_Aiming_Idle`/`Ranged_Bow_Release` |
| N11 | Boss wake/idle, arm sweep, ground slam, charge, recovery, death | Mixamo Mutant clips perlu retarget ke rig golem 28 bone non-humanoid; wake/charge anticipation-brake masih authoring | MISSING | Basis ter-import **hanya di salinan lokal** (FBX Mixamo di-gitignore, tidak ikut push publik): `assets/third_party/mixamo/Mutant_Swiping.fbx`, `Mutant_Run.fbx` (in place), `Mutant_Roaring.fbx`, `Mutant_Dying.fbx`; golem belum punya animasi. **Gap nyata:** retarget/aplikasi + authoring wake/charge; bukan kekurangan model |
| N12 | Panel rotation, seal unlock, artifact, checkpoint, bridge/gate opening | Godot AnimationPlayer/tween/state-driven transforms | MISSING | — |

Animasi prop tidak memerlukan skeletal rig bila transform node sudah memadai. Source `.blend` berbayar tidak diasumsikan menjadi kebutuhan; pastikan workflow dapat dilakukan dengan file yang benar-benar diperoleh.

## UI, Audio & Narrative Resources

| Resource ID | Kebutuhan | Prioritas | Status | File/resource aktual |
|---|---|---|---|---|
| U01 | HP bar + angka, stamina, potion count, artifact progress | REQUIRED | IMPORTED | Gambar dasar: `kenney/ui_pack/grey/`, `extra/`; layout HUD dan binding state belum dibuat |
| U02 | Prompt interaksi, control hints, input glyphs/cursor | REQUIRED | IMPORTED | `kenney/input_prompts/keyboard_mouse/`, `generic/`; pemetaan ke input final belum dibuat |
| U03 | Main/pause/settings/completion screens | REQUIRED | IMPORTED | Gambar dasar: `kenney/ui_pack/`; layar belum dibuat |
| U04 | Font yang terbaca dan lisensinya, icon/logo runtime | REQUIRED | IMPORTED | `kenney/fonts/*.ttf`, `kenney/ui_pack/font/`; pilihan font dan import logo belum ditetapkan |
| U05 | Opening/outro dan environmental clues sesuai lore | REQUIRED | MISSING | — |
| SFX01 | Footsteps/jump/landing | REQUIRED | IMPORTED | `audio/tinysized_vehicle/`: `mud-steps-*`, `soil-steps-*`, `boots-leather-step-*`, `boots-leather-jump-*`; `kenney/rpg_audio/`; belum diaudisi |
| SFX02 | Melee swing/hit, heavy hit, ranged fire/impact | REQUIRED | IMPORTED | `audio/tinysized_vehicle/`: `sword-clash-*`, `metal-hammer-hit-*`, `arrow-*`; `audio/rpg_sfx_rubberduck/`; belum diaudisi |
| SFX03 | Block, dodge, hurt/death | REQUIRED | IMPORTED | `audio/tinysized_vehicle/`: `metal-*`, `*-whoosh-*`; `audio/rpg_sfx_rubberduck/` (creature hurt/die); belum diaudisi |
| SFX04 | Potion/pickup/collect | REQUIRED | IMPORTED | `audio/tinysized_vehicle/`: `vial-glass-*`, `bottle-glass-cork*`, `water-pour-*`; `audio/rpg_sfx_rubberduck/` (item/gem); belum diaudisi |
| SFX05 | Pilar activation/error/solved dan panel/energy/solved | REQUIRED | MISSING | Bahan ter-import: `audio/rpg_sfx_rubberduck/` (stone/spell/lock/gem), `kenney/interface_sounds/`; perlu layering/edit |
| SFX06 | Checkpoint, shortcut, gate, boss wake/attacks/death | REQUIRED | MISSING | Bahan ter-import: `audio/rpg_sfx_rubberduck/` (stone/chain/lock/roar), `audio/tinysized_vehicle/` (`floor-creak-*`, `keyhole-lockbox-*`); perlu layering/edit |
| SFX07 | UI confirm/cancel/pause | REQUIRED | IMPORTED | `kenney/interface_sounds/`; clip spesifik belum dipilih |
| AUD01 | Ambience pulau | REQUIRED | IMPORTED | `audio/ambience/Forest_Ambience.mp3`, `VistulaShort.mp3`; loop/crossfade/mix belum diuji |
| AUD02 | Musik eksplorasi dan boss | REQUIRED | IMPORTED | `audio/music/children_soundtrack_2.ogg` (konversi WAV→OGG), `CleytonRX-Battle-RPG-Theme.mp3` / `-Var.ogg`; loop/transisi belum diuji |

Satu clip dapat memenuhi beberapa konteks jika hasilnya sesuai dan tidak membingungkan feedback. Track sementara boleh digunakan untuk prototype tetapi tetap `PLACEHOLDER` sampai sumber, lisensi, loop, mix, dan import tervalidasi.

## Collection & Validation Procedure

1. Pilih kebutuhan yang belum terpenuhi berdasarkan Asset ID. Cari pada sumber utama terlebih dahulu, lalu fallback bila memang kurang.
2. Periksa halaman resmi, lisensi, tier dan format, lalu unduh sampel. Jika membuat scraper, simpan metadata katalog dan lakukan deduplikasi URL/hash; jangan otomatis mengimpor seluruh katalog.
3. Simpan arsip kerja di luar resource game; ekstrak hanya dependency yang diperlukan ke struktur asset produksi. Simpan lisensi asli dan sumbernya bersama paket yang dipakai.
4. Catat file serta versi. Ubah status menjadi `DOWNLOADED` setelah file lokal terverifikasi; thumbnail atau link saja tetap `CANDIDATE`.
5. Import ke asset lab, bandingkan skala/palette, dan uji rig, clips, material, attachment serta collision sesuai peran. Ubah menjadi `IMPORTED`, lalu `VERIFIED` setelah pemeriksaan lolos.
6. Petakan baris kebutuhan ke file dan wrapper scene yang benar-benar dipakai. Catat hasil custom modelling/animation dengan cara yang sama.
7. Hitung kekurangan dari baris kebutuhan wajib, bukan jumlah folder/file. Jika satu baris wajib belum `VERIFIED`, asset set belum final-ready.

Format record per paket/asset yang diambil:

```text
Asset IDs:
Pembuat / nama paket / versi atau tanggal unduh:
Halaman sumber dan URL download resmi:
Lisensi / URL lisensi / path file lisensi lokal:
Tier yang diunduh / isi yang benar-benar tersedia:
SHA-256 arsip atau file sumber:
Format asli / alat dan versi konversi bila dipakai:
Path file runtime dan dependency texture/bin:
Wrapper scene / skeleton / clip mapping:
Modifikasi (scale, material, collision, animasi):
Bukti uji (scene, screenshot/log, tanggal, PIC):
Status / kekurangan / pengganti:
```

## Gate A — Prototype Sample Ready

- [ ] Karakter/skeleton sampel dan set locomotion/attack minimum lolos asset lab, atau fallback placeholder dicatat secara eksplisit.
- [ ] Attachment weapon dan satu dummy/enemy bisa dipakai pada test arena tanpa missing resource.
- [ ] Pohon, batu, dan modul stone dibandingkan dalam satu scene untuk memutuskan arah kit; collision/skala dasarnya dapat dipakai.
- [ ] Semua animasi yang belum tersedia punya rencana custom/fallback. Potion dan boss tidak diasumsikan lengkap karena ada library humanoid.
- [ ] Sumber/lisensi sampel tersimpan. P02 mencatat hasil dan kandidat yang ditolak.

Gate A membuka prototype. Gate ini tidak menyatakan seluruh kebutuhan asset sudah lengkap.

## Gate B — Final Visual Asset Ready

- [ ] Semua model/world resource dan animasi `REQUIRED` sudah `VERIFIED`, dengan file/scene aktual serta modifikasi tercatat.
- [ ] Tidak ada missing texture/bin, material rusak, rig mismatch, clip wajib kosong, atau weapon attachment terlepas.
- [ ] Seluruh visual wajib sudah dipasang pada gameplay scene; collision, interaksi, camera probe, dan telegraph diuji kembali setelah pergantian asset.
- [ ] Tidak ada asset visual wajib yang diam-diam masih placeholder. Asset custom lolos pemeriksaan yang sama dengan asset unduhan.
- [ ] Atribusi/lisensi yang diperlukan tercatat pada notices/credits dan dependency source dapat dipulihkan dari repo/paket yang sah dibagikan.

## Gate C — Release Resource Ready

- [ ] Gate B tetap valid pada release candidate.
- [ ] UI, audio, dan resource narasi `REQUIRED` telah `VERIFIED` pada build, termasuk font/glyph, audio loop/mix, dan credits.
- [ ] Tidak ada file runtime yang hanya tersedia pada komputer pembuat atau hanya di folder laporan/cache.
- [ ] Paket export memakai asset yang diperlukan dan tidak membawa arsip download, tooling MCP, dokumen kerja, atau credential lokal.
- [ ] [Acceptance Checklist](ACCEPTANCE_CHECKLIST.md) yang terkait asset/UI/audio/export lolos.

## Open Gaps

Kondisi awal: seluruh model/world resource produksi, animasi, UI runtime, dan audio di atas masih perlu dipenuhi. Boss, puzzle props, potion animation, dan source/tier clip menjadi risiko pengadaan yang diperiksa lebih awal. Concept art tidak menjadi jaminan ada paket 3D dengan bentuk yang sama.

| Tanggal | Asset ID | Kekurangan/temuan | Fallback atau tindakan berikutnya | PIC |
|---|---|---|---|---|
| 2026-11-17 | Semua baris produksi | Belum ada file 3D/audio/gameplay script pada audit awal | Ambil sampel P01-02–04, lalu uji pada P02 | Belum ditetapkan |

## Bukti review statis I01 — 21 November 2026

Scene `scenes/tests/asset_lab.tscn` menampilkan sembilan sampel: Rogue, Rogue Hooded, Ranger, Knight, Barbarian, Rock Golem, `Tree_2_C_Color1`, `Rock_1_A_Color1`, dan pilar Dungeon. [Screenshot runtime](evidence/i01-asset-lab.png) berasal dari render nyata Godot 4.7.2 Compatibility, 1280×720 (Radeon RX 5500M), exit 0 tanpa error/warning. Referensi warna ada di [palet pengguna](../desain/palettes/README.md).

- Material/tekstur model asal dipertahankan; lantai/display/background memakai warna acuan. Kesesuaian akhir warna dan pilihan pemain **menunggu review pengguna**.
- Bar pembanding panjangnya tepat 1 unit/meter. Karakter memakai skala sumber yang sama (`1.0`); perbedaan tinggi termasuk helm/hood tidak dinormalisasi per mesh.
- Golem memakai skala seragam `0.32` (tinggi AABB sekitar `3.695 m`), posisi vertikal `2.8983` agar titik terendah mesh berada pada lantai. Pohon memakai skala `0.70` dan offset dasar `0.2753`; batu `1.50`. Ini baseline showroom, bukan balancing atau ukuran final dunia.
- Tidak ada animasi, collision gameplay, attachment senjata, retarget, atau generator procedural pada I01. Status `IMPORTED` tidak dinaikkan menjadi `VERIFIED` hanya karena sampel terlihat di showroom; Gate A/B/C tetap memerlukan pemeriksaan yang belum dilakukan.
