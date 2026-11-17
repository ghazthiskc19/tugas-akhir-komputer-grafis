# Asset Inventory

Audit awal: **17 November 2026**. Acuan: [konsep game](../konsep-game.md) dan [Implementation Tracker](IMPLEMENTATION_TRACKER.md).

Inventaris mencatat kebutuhan logis, bukan jumlah file yang wajib diunduh. Satu paket dapat memenuhi beberapa baris; satu model dapat dipakai ulang melalui scene/material variant. Semua baris produksi masih `MISSING` pada audit awal. Daftar kandidat di bawah belum membuktikan file tersedia atau bekerja pada project.

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
| S08 | [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) | Alternatif modular floor, stairs, wall, dan door | Halaman pembuat mencantumkan CC0, tier Free, serta FBX/glTF/OBJ. Bukan jaminan puzzle props atau boss sudah tersedia. |
| S09 | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Kandidat footsteps/weapon/foley | Halaman resmi terindeks mencantumkan CC0. Nama clip, format, dan kecukupan SFX harus diperiksa dari file. |

Mulai dari satu family karakter dan satu environment kit. S05–S07/S08 adalah alternatif atau pengisi kekurangan, bukan kewajiban mengunduh semua paket. Uji sampel berdampingan sebelum mencampurkan kit dengan proporsi/material berbeda. Sumber musik, ambience, font, dan SFX yang belum tertutup tetap dicari; belum ada klaim lisensi untuk file yang belum dipilih.

## Models & World Resources

Kolom file/scene diisi dengan path yang benar-benar ada setelah pengadaan. `Custom` adalah rencana pembuatan, bukan asset yang sudah selesai.

| Asset ID | Kebutuhan logis | Prioritas | Kandidat/fallback awal | Status | File/scene aktual |
|---|---|---|---|---|---|
| M01 | Satu karakter pemain rigged | REQUIRED | S03 atau S05; capsule sementara | MISSING | — |
| M02 | Standard melee, silhouette terbaca | REQUIRED | Variant rig family terpilih; penampilan belum final | MISSING | — |
| M03 | Heavy melee, silhouette/weapon berbeda | REQUIRED | Variant rig family atau custom | MISSING | — |
| M04 | Ranged enemy | REQUIRED | Variant rig family atau custom | MISSING | — |
| M05 | Golem Penjaga Gerbang, inti energi dan bagian yang dapat dianimasikan | REQUIRED | Cari kandidat spesifik atau custom batu modular | MISSING | — |
| M06 | Satu weapon melee pemain dan attachment | REQUIRED | S03 atau custom; jenis visual belum dipilih | MISSING | — |
| M07 | Weapon standard melee | REQUIRED | S03 atau custom | MISSING | — |
| M08 | Weapon heavy melee | REQUIRED | S03 atau custom | MISSING | — |
| M09 | Weapon ranged dan projectile | REQUIRED | S03 atau custom; jenis visual belum dipilih | MISSING | — |
| M10 | Terrain mesh, biome material, collision | REQUIRED | Custom procedural mesh; bukan landscape dari screenshot | MISSING | — |
| M11 | Pohon dan foliage untuk Grassland/Forest | REQUIRED | S01 atau S07 | MISSING | — |
| M12 | Batu, cliffs, cover, dan variasi elevasi | REQUIRED | S01/S07 dan custom modul | MISSING | — |
| M13 | Rumput, semak, bunga, variasi dekorasi | POLISH | Kit nature terpilih | MISSING | — |
| M14 | Ruin floor, wall, steps, arch | REQUIRED | S02 atau S08; adaptasi ukuran/material | MISSING | — |
| M15 | Empat pilar interaktif | REQUIRED | Custom dari base stone; pivot/interaksi disiapkan | MISSING | — |
| M16 | Empat glyph berbeda bentuk dan relief urutan | REQUIRED | Custom mesh/decal/texture yang terbaca kamera | MISSING | — |
| M17 | Tiga panel energi putar dan connector lurus/siku | REQUIRED | Custom modul dengan orientasi 90° | MISSING | — |
| M18 | Source crystal, altar tujuan, seal feedback | REQUIRED | Adaptasi crystal/stone atau custom | MISSING | — |
| M19 | Representasi tiga artifact dengan stable ID | REQUIRED | Base custom + variant visual yang dapat dibedakan | MISSING | — |
| M20 | Potion world pickup dan prop animasi minum | REQUIRED | Kandidat item pack atau custom | MISSING | — |
| M21 | Checkpoint marker | REQUIRED | Custom; active/inactive dapat dibedakan | MISSING | — |
| M22 | Jalur naik, steps/ledges, dan puncak altar | REQUIRED | Modul custom + kit stone terpilih | MISSING | — |
| M23 | Bridge shortcut dengan state/collision terbuka | REQUIRED | Custom/adaptasi bridge kit | MISSING | — |
| M24 | Ancient gate, tiga sockets, arena boundary | REQUIRED | S02/S08 + custom sockets dan animasi | MISSING | — |
| M25 | Landmark menara/reruntuhan puncak | REQUIRED | S02/S08 atau custom sederhana | MISSING | — |
| M26 | Ocean/water surface, sky dan lighting setup | REQUIRED | Mesh/material/world environment custom yang bekerja di Compatibility | MISSING | — |
| M27 | Dock/shipwreck untuk konteks cerita | POLISH | Model custom/kit jika dibutuhkan; opening/outro visual dapat menyampaikan konteks tanpa kapal 3D penuh | MISSING | — |
| M28 | Bentuk/material telegraph, energy flow, hit/collect feedback | REQUIRED | Custom shader/material/mesh/particles yang didukung renderer | MISSING | — |

Variasi pohon/batu dapat memakai instancing. Jumlah variasi final mengikuti kebutuhan visual dan profiling, tidak ditentukan dari jumlah file dalam paket.

## Animation Coverage

Catat nama clip asli, target skeleton, retarget mapping, durasi/loop, dan resource animation yang dipakai. Animasi yang terlihat di preview paket belum dianggap tersedia dalam tier yang diunduh.

| Animation ID | Aksi wajib | Kandidat/metode | Status | Clip/resource aktual |
|---|---|---|---|---|
| N01 | Player idle, walk/run | S04 atau S06 sesuai rig | MISSING | — |
| N02 | Jump, fall, landing | Library terpilih atau custom | MISSING | — |
| N03 | Attack 1, attack 2, finisher | Library/custom; tiga hit punya event window sendiri | MISSING | — |
| N04 | Block enter/hold/exit | Library/custom; arah visual tidak membatasi block semua arah | MISSING | — |
| N05 | Dodge | Library/custom; frame i-frames ditetapkan terpisah | MISSING | — |
| N06 | Potion drink, completion, interrupt transition | Custom jika library tidak memuatnya | MISSING | — |
| N07 | Player hurt/death/respawn transition | Library/custom | MISSING | — |
| N08 | Standard melee movement, wind-up, attack, recovery, hurt/death | Family rig terpilih + custom timing | MISSING | — |
| N09 | Heavy movement, wind-up, slam, recovery, hurt/death | Family rig terpilih + custom timing | MISSING | — |
| N10 | Ranged preparation, fire, recovery, movement/hurt/death | Family rig terpilih + projectile event | MISSING | — |
| N11 | Boss wake/idle, arm sweep, ground slam, charge, recovery, death | Custom rig atau animation per bagian mesh | MISSING | — |
| N12 | Panel rotation, seal unlock, artifact, checkpoint, bridge/gate opening | Godot AnimationPlayer/tween/state-driven transforms | MISSING | — |

Animasi prop tidak memerlukan skeletal rig bila transform node sudah memadai. Source `.blend` berbayar tidak diasumsikan menjadi kebutuhan; pastikan workflow dapat dilakukan dengan file yang benar-benar diperoleh.

## UI, Audio & Narrative Resources

| Resource ID | Kebutuhan | Prioritas | Status | File/resource aktual |
|---|---|---|---|---|
| U01 | HP bar + angka, stamina, potion count, artifact progress | REQUIRED | MISSING | — |
| U02 | Prompt interaksi, control hints, input glyphs/cursor | REQUIRED | MISSING | — |
| U03 | Main/pause/settings/completion screens | REQUIRED | MISSING | — |
| U04 | Font yang terbaca dan lisensinya, icon/logo runtime | REQUIRED | MISSING | — |
| U05 | Opening/outro dan environmental clues sesuai lore | REQUIRED | MISSING | — |
| SFX01 | Footsteps/jump/landing | REQUIRED | MISSING | — |
| SFX02 | Melee swing/hit, heavy hit, ranged fire/impact | REQUIRED | MISSING | — |
| SFX03 | Block, dodge, hurt/death | REQUIRED | MISSING | — |
| SFX04 | Potion/pickup/collect | REQUIRED | MISSING | — |
| SFX05 | Pilar activation/error/solved dan panel/energy/solved | REQUIRED | MISSING | — |
| SFX06 | Checkpoint, shortcut, gate, boss wake/attacks/death | REQUIRED | MISSING | — |
| SFX07 | UI confirm/cancel/pause | REQUIRED | MISSING | — |
| AUD01 | Ambience pulau | REQUIRED | MISSING | — |
| AUD02 | Musik eksplorasi dan boss | REQUIRED | MISSING | — |

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
