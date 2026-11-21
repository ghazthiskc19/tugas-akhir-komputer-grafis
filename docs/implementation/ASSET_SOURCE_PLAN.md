# Rencana Sumber Asset — The Lost Island

20 November 2026. **Keputusan pengguna: KayKit Adventurers + Character Animations + Forest Nature + Dungeon sebagai inti.** Asset pelengkap boleh berbeda sedikit dan diedit agent. Model produksi bersumber online; pengguna tidak perlu modelling manual. Tidak ada pembelian, login, download model atau import pada pekerjaan pencarian ini.

## Kesimpulan yang tidak menyamakan pencarian dengan produksi

**Kebijakan terkini, 21 November 2026:** dengan ambang visual yang dilonggarkan, bahan awal cukup dan tidak ada model/paket wajib baru. Gap yang nyata adalah retarget/aplikasi N06 dan N11 serta authoring wake/charge, plus kode dan perakitan (terrain procedural, logika, UI, scene), bukan unduhan geometri. Baris di bawah ini adalah catatan historis 20 November yang menyebut opsi berbayar/reproportion; opsi itu tidak lagi wajib. Seluruh **54 baris kebutuhan inventaris** punya sumber bahan konkret atau jalur authoring, tetapi **itu bukan 54 asset siap pakai**: belum ada hasil mesh/clip turunan atau runtime yang diuji. Jangan menandai asset terpenuhi/VERIFIED hanya dari tabel ini.

### Bukti sumber dan lisensi

- **K** = [audit karakter KayKit](ASSET_ECOSYSTEM_CHARACTERS.md): roster, tier, manifest lama dan exact chart clip Medium/Large. Free CC0 untuk inti yang disebut; Extra/Source tidak otomatis gratis.
- **W** = [audit world KayKit](ASSET_ECOSYSTEM_WORLD.md): exact column/pillar/bottle/bridge paths pada snapshot maker, current/legacy dibedakan.
- **CG** = [gap karakter/motion](ASSET_GAP_CHARACTERS.md): Mixamo Drinking dan motion mutant dipreview publik; Frost Golem ditinjau; budget/account/licence dan rencana retarget/authoring eksplisit.
- **WG** = [gap world/puzzle/renderer](ASSET_GAP_WORLD.md): Rune Pack Kenney CC0, track-straight/corner GLB CC0 dari Kenney, iPoly3D Crystal CC0, source shader MIT/CC0; rencana edit terarah dan caveat Compatibility.
- **UA** = [UI/audio](ASSET_GAP_UI_AUDIO.md): exact publikasi font, prompts, sound banks, musik/ambience; belum audisi atau file assignment final.

Status tabel: **SUMBER** = bahan/model/clip spesifik ditemukan, **TURUNAN** = sumber ditemukan tetapi perlu assembly/mesh/animation authoring, **AKUN** = pengadaan perlu akun, **BIAYA** = primary berbayar belum diotorisasi, **RUNTIME** = bahan online tidak menggantikan kode/renderer/integrasi. Semuanya tetap belum diunduh/diuji. Primary bersyarat berbayar bukan keputusan membeli.

## Model dan world: M01–M28

| ID | Primary / fallback konkret | Status dan pekerjaan agent yang tersisa | Bukti |
|---|---|---|---|
| M01 | Rogue Adventurers Free; Ranger Free alternatif | SUMBER; one-handed sword attachment, skala/material/rig diperiksa | K |
| M02 | Knight Free, visor tertutup + sword | TURUNAN; palette batu/metal tua, rune/energy accent; bukan undead | CG |
| M03 | Barbarian Free + axe/sword 2H; Extra tidak wajib | TURUNAN; heavy lewat skala seragam + recolor + senjata; reskin belum dibuat, belum siap penuh | CG |
| M04 | Knight Free kedua + crossbow/arrow; Ranger bow fallback | TURUNAN; rig/grip/reload/projectile socket dan pembeda siluet | CG |
| M05 | Rock Golem Joseph George (Free CC0, ter-import); Frost Golem tidak dibeli | TURUNAN; cukup recolor + skala seragam + crystal attachment sebagai titik awal; reproportion/re-rig tidak wajib kecuali bukti visual nanti. LOWPO tidak default karena lisensi konflik | CG |
| M06 | Adventurers one-handed sword | SUMBER; orientasi/grip/collision/attack attachment | K |
| M07 | Adventurers sword/axe | SUMBER; penyesuaian guardian dan collider | K |
| M08 | Adventurers two-handed axe/sword; RPG Tools hammer/mallet fallback | SUMBER; heavy grip dan ukuran belum diuji | K |
| M09 | Adventurers crossbow/bow/arrow | SUMBER/RUNTIME; string pose, projectile origin/flight/impact di game | K/CG |
| M10 | Forest Extra modular terrain; Medieval Free tiles sebagai base alternatif | TURUNAN/RUNTIME; pulau seeded250×250, biome, route/collision/nav tetap project | W |
| M11 | Forest Free trees/bushes/grass | SUMBER; seleksi variasi, scale, collision dan instancing | W |
| M12 | Forest Free rocks; cliff modular Extra USD 9.99 | SUMBER/BIAYA; bila memakai terrain procedural sendiri, Extra tidak otomatis wajib; route/cover tetap diuji | W |
| M13 | Forest grass/bush Free + [Flower A — Isa Lousberg](https://poly.pizza/m/DG7oCt9QYv), Free CC0 FBX/glTF | SUMBER; publikasi maker dibaca, file/scale/palette belum diuji. Flower tidak diasumsikan berasal dari Forest Free | W + sumber langsung |
| M14 | Dungeon Free wall_arched/wall_broken/floor/stairs/rubble | SUMBER; susun ruin outdoor, ukuran, weathering dan collision | W |
| M15 | Dungeon pillar/column, empat instance | TURUNAN; mount glyph, trigger/light dan interaksi | W/WG |
| M16 | Kenney Rune Pack vector: cross, arrow, fork, diamond + Dungeon backing | TURUNAN; extrude relief dan susun clue dari motif sama, belum dibuat | WG |
| M17 | Kenney models/track-straight.glb + track-corner.glb, floor Dungeon | TURUNAN; isolasi/pipihkan strip, UV, endpoints, rim stone, pivot90°; bukan track balap dalam game | WG |
| M18 | Crystal iPoly3D Free CC0 + Dungeon column/floor pedestal; Rune Pack/ring shader seal | TURUNAN; komposisi/energy material. Resource Extra tidak diperlukan untuk mendapat crystal | WG |
| M19 | Cross/fork/diamond Rune Pack pada stone fragments + Crystal iPoly3D | TURUNAN; tiga key-head/artefak cocok recess, stable ID/pickup script | WG |
| M20 | Dungeon bottle_A/B/C | SUMBER; potion material/cork/hand grip. Prop bukan animation drink | K/W |
| M21 | Dungeon pillar/torch; RPG Tools lantern fallback | TURUNAN/RUNTIME; active/inactive feedback dan checkpoint state | W/WG |
| M22 | Dungeon stairs + Forest terrain/rocks | TURUNAN; summit route, ledges, altar, collision dan jump gap | W |
| M23 | Medieval Free building_bridge_A/B | SUMBER/TURUNAN; separasi mesh/pivot/open collision belum diperiksa | W |
| M24 | Dungeon arch/gate/pillar + tiga floor plates; cutters dari motif M19 | TURUNAN; matching recess/Boolean/topology, door split/pivot dan opening | WG |
| M25 | Dungeon stacked ruins atau Medieval Free tower_A/B | SUMBER/TURUNAN; landmark dan gameplay scale/access | W |
| M26 | taillight-games Pixelated Water MIT: 64-water-imposter + wave source; Medieval geometry | TURUNAN/RUNTIME; opaque conservative port, sky/light/horizon, shoreline. Full depth formula upstream tidak langsung benar di Compatibility | WG |
| M27 | Dock/ships Medieval Extra tidak dibeli; kebutuhan POLISH | OPSIONAL; tanpa art wajib dan tanpa remodel shipwreck; lore cukup lewat teks dan gerbang/dermaga | W |
| M28 | Dev Quest ring/slash, GOSIjnr cone port, Kenney Particle Pack | TURUNAN/RUNTIME; shader/mesh/mask provenance, CPU particle adaptation, event/timing/readability | WG |

## Animasi: N01–N12

| ID | Primary / fallback konkret | Status dan pekerjaan agent yang tersisa | Bukti |
|---|---|---|---|
| N01 | KayKit Medium IDLE_A/B, WALKING_A/B/C, RUNNING_A/B | SUMBER; blend, loop, speed/root-motion policy | K |
| N02 | JUMP_START/JUMP_IDLE/JUMP_LAND/FULL_SHORT/LONG | SUMBER; fall pose terpisah belum terbukti, evaluasi airborne JUMP_IDLE | K |
| N03 | 1H SLICE_HORIZONTAL → SLICE_DIAGONAL → CHOP | SUMBER; retiming/transitions/finisher dan combo windows di game | K |
| N04 | MELEE_BLOCK/MELEE_BLOCKING/MELEE_BLOCK_HIT | SUMBER/TURUNAN; enter/exit blend atau authoring, omni reduction/stamina di game | K |
| N05 | DODGE_FORWARD/BACKWARD/LEFT/RIGHT | SUMBER; i-frames, biaya, root displacement/collision diuji | K |
| N06 | Mixamo Drinking / Male Drinking; nikoff Bottle_In/Loop/Out paid fallback | AKUN/TURUNAN; AdobeID untuk file, HIGH retarget/head/hand-mouth/upperbody mask; completion/interrupt script. Tidak menaruh raw reusable motion di repo publik | CG |
| N07 | HIT_A/B, DEATH_A/B/POSE, SPAWN_AIR/GROUND | SUMBER; respawn state dan transitions bukan clip | K |
| N08 | Medium 1H attacks + locomotion/hit/death | SUMBER; guardian fitting dan attack wind-up/recovery aktual | K/CG |
| N09 | Medium 2H chop/slice pada Barbarian (rest pose identik dengan Rig_Medium); Large clips hanya bila model Large | SUMBER; rest pose Large berbeda sehingga tidak dipasang pada Barbarian Free. Wind-up/contact/recovery perlu tuning | K/CG |
| N10 | Medium RANGED_2H_AIMING/SHOOT/RELOAD; bow draw/aim/release fallback | SUMBER/TURUNAN; gun-style reload belum pasti cocok crossbow, bow fallback lebih spesifik | CG |
| N11 | Native slash/smash/run/death; Mixamo Mutant Swiping/Run/Roaring/Dying fallback | TURUNAN; **gap nyata:** retarget/aplikasi ke rig golem 28 bone dan authoring wake/anticipation-brake charge. Mutant FBX hanya lokal (gitignore). Tiga attacks/dua fase tetap | CG |
| N12 | Transform node panel/seal/artifact/checkpoint/bridge/gate pada mesh online | TURUNAN/RUNTIME; bagian terpisah/pivot/state/collision/timing dikerjakan agent | W/WG |

## UI, narasi dan audio: U01–U05, SFX01–SFX07, AUD01–AUD02

Semua sumber audio/font di UA dibaca pada publikasi maker dan berlabel CC0; belum audisi/hasil edit. Tidak memilih clip berdasarkan filename yang dikarang.

| ID | Sumber konkret | Status dan pekerjaan tersisa |
|---|---|---|
| U01 | Kenney UI Pack; ikon dari props/model yang dipilih | SUMBER/RUNTIME; HUD bar/angka/stamina/potion/artifact sesuai state |
| U02 | Kenney Input Prompts non-pixel 64×64, keyboard/mouse/generic | SUMBER; pilih tombol dan integrasi prompt |
| U03 | Kenney UI Pack | SUMBER/RUNTIME; main/pause/settings/completion layout dan navigasi |
| U04 | Kenney Fonts + logo game lokal | SUMBER; file font/glyph/legibility dan import logo belum diperiksa |
| U05 | Lore konsep aktif + rune/model pilihan | TURUNAN; teks opening/outro dan clue ditulis agent/tim, bukan NPC/dialog baru |
| SFX01 | Vehicle Tinysized boots/steps; Weapons and Apparel leather boots | SUMBER/TURUNAN; audisi, pilih/trim footsteps dan layer jump/landing |
| SFX02 | Vehicle sword/arrows/metal hits; rubberduck blade/metal | SUMBER/TURUNAN; swing/impact/heavy/fire berdasarkan event |
| SFX03 | Vehicle metal/whooshes + rubberduck creature hurt/die | SUMBER/TURUNAN; block/dodge/hurt/death layers, jangan mengklaim voice manusia spesifik sudah cocok |
| SFX04 | Vehicle bottles/vials/cork/water + rubberduck item/gem | SUMBER/TURUNAN; potion/pickup/collect audisi dan layering |
| SFX05 | rubberduck stone/lock/spell/gem + Vehicle metal/creaks | SUMBER/TURUNAN; bedakan activation/error/solved dan energy feedback lewat hasil edit |
| SFX06 | rubberduck chain/stone/lock/wood/roar + Vehicle creaks/metal | SUMBER/TURUNAN; checkpoint/shortcut/gate/boss layers dan event timing |
| SFX07 | Kenney Interface Sounds | SUMBER; confirm/cancel/pause clip belum ditetapkan/diaudisi |
| AUD01 | TinyWorlds Forest Ambience + RandomMind Vistula waves | SUMBER; belum audisi/crossfade/loop/mix; Vistula rekaman sungai bukan klaim rekaman laut |
| AUD02 | heartade Children's Game Music2 Adventure + CleytonKauffman Boss Battle Theme | SUMBER; kandidat eksplorasi/boss, belum audisi atau uji loop/transisi |

## Gate pengadaan dan kualitas

1. **Belum semuanya fulfilled.** Source coverage, edit turunan, dan produksi terverifikasi adalah tiga tahap berbeda. Baris yang masih memerlukan reskin/perakitan/retarget tetap MISSING pada inventaris; yang sudah ter-import dan langsung memenuhi kebutuhan IMPORTED.
2. **Akun/repo:** file Mixamo sudah diekspor ke salinan lokal, tetapi repo GitHub publik sehingga FBX Mixamo di-gitignore dan tidak ikut push; clone baru harus mengunduh ulang dari Mixamo dengan akun Adobe sendiri. Bila tidak tersedia, fallback `Use_Item` KayKit untuk potion (kualitas rendah, tetap clip nyata) atau authoring pada rig KayKit; bukan fake clip.
3. **Biaya (kebijakan terkini, 21 Nov 2026):** tidak ada pembelian. Frost Golem, Barbarian besar Extra, dan Medieval Extra tidak diperlukan; basis gratis yang sudah ter-import cukup untuk memulai (lihat [audit kecukupan](ASSET_INVENTORY.md#audit-kecukupan-asset--21-november-2026-ambang-visual-dilonggarkan)). LOWPO tidak dipilih karena licence conflict.
4. **Repo:** KayKit/Kenney CC0 dan source MIT dapat disimpan sesuai lisensinya setelah file lisensi diperiksa. Mixamo/Fab motion bukan CC0; jangan commit raw reusable asset ke repository publik. Private collaboration terms dan compiled-game use dibedakan.
5. **Bukti sesudah file diperoleh:** lisensi/hash/versi → model/material/pivot/skeleton → satu drink retarget dan satu boss attack → fixture glyph/panel/socket → Compatibility water/VFX → gameplay integration. Tidak mencentang ready asset berdasarkan katalog.

Tidak ada fitur yang dihapus untuk menyesuaikan ketersediaan asset. Semua modifikasi adalah pekerjaan agent; pengguna tidak diminta membuat model/animasi manual. Riset ini memilih jalur yang dapat ditelusuri, bukan menjanjikan pekerjaan HIGH selalu dapat diselesaikan dengan edit kecil.
