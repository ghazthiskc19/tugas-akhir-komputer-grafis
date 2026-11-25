# Third-party notices

## Godot Editor MCP

`addons/godot_mcp/` berasal dari [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp), release **2026.10.20.1**. Plugin didistribusikan dengan lisensi **MIT**. Teks lisensi dan atribusi asli tersedia di [addons/godot_mcp/LICENSE](addons/godot_mcp/LICENSE).

Addon dipakai untuk integrasi editor selama development dan dikecualikan dari preset export game. Server Python dipasang secara terpisah di komputer pengembang.

## Godot Engine

Godot Engine menggunakan [lisensi MIT](https://godotengine.org/license/). Binary engine dan export templates tidak disimpan di repository ini. Ketika mendistribusikan executable game, sertakan atribusi Godot dan lisensi dependensi yang relevan mengikuti ketentuan distribusi engine.

## Project assets

`icon.svg` dibuat untuk fondasi project ini. Asset pihak ketiga di bawah disimpan pada `assets/third_party/` dan diambil 20–21 November 2026. Rincian sumber, hash arsip asli, dan subset yang diambil ada di [docs/implementation/ASSET_DOWNLOADS.md](docs/implementation/ASSET_DOWNLOADS.md). Credit tetap dicantumkan walaupun CC0 tidak mewajibkan atribusi.

| Folder | Asset / pembuat | Lisensi | Bukti lisensi |
|---|---|---|---|
| `kaykit/adventurers` | KayKit Adventurers 2.0 Free — Kay Lousberg | CC0 1.0 | `License.txt` dalam folder |
| `kaykit/character_animations` | KayKit Character Animations 1.1 — Kay Lousberg | CC0 1.0 | `License.txt` dalam folder |
| `kaykit/forest_nature` | KayKit Forest Nature Pack 1.0 Free — Kay Lousberg | CC0 1.0 | `License.txt` dalam folder |
| `kaykit/dungeon` | KayKit Dungeon Pack 1.1 Free — Kay Lousberg | CC0 1.0 | `License.txt` dalam folder |
| `kaykit/medieval_hexagon` | KayKit Medieval Hexagon Pack 1.0 Free (subset jembatan serta tile air/pantai/sungai) — Kay Lousberg | CC0 1.0 | `License.txt` dalam folder |
| `kenney/*` | UI Pack, Input Prompts, Kenney Fonts, Interface Sounds, RPG Audio, Particle Pack, Rune Pack — Kenney (kenney.nl) | CC0 1.0 | `License.txt` tiap folder |
| `kenney/starter_kit_racing` | Model `track-straight`/`track-corner` dari Starter Kit Racing — Kenney | Model CC0; kode repo MIT (tidak disalin) | `LICENSE` dalam folder |
| `kenney/ui_pack_adventure` | UI Pack - Adventure 1.0 — Kenney, [kenney.nl](https://kenney.nl/assets/ui-pack-adventure) (diambil 23 November 2026) | CC0 1.0 | `License.txt` dalam folder |
| `kenney/fantasy_ui_borders` | Fantasy UI Borders — Kenney, [kenney.nl](https://kenney.nl/assets/fantasy-ui-borders) (diambil 23 November 2026) | CC0 1.0 | `License.txt` dalam folder |
| `fonts/cinzel` | Cinzel (variable) — The Cinzel Project Authors, via [Google Fonts](https://github.com/google/fonts/tree/main/ofl/cinzel) | SIL Open Font License 1.1 | `OFL.txt` dalam folder |
| `fonts/nunito` | Nunito (variable) — The Nunito Project Authors, via [Google Fonts](https://github.com/google/fonts/tree/main/ofl/nunito) | SIL Open Font License 1.1 | `OFL.txt` dalam folder |
| `game_icons` | Ikon SVG dari [game-icons.net](https://game-icons.net) ([repo](https://github.com/game-icons/icons)); nama file `<pembuat>_<ikon>.svg`: Lorc, Delapouite, Skoll, Sbed (CC BY 3.0) dan Zeromancer (CC0) | CC BY 3.0 (atribusi wajib) / CC0 | `license.txt` dalam folder; atribusi juga tampil di kredit README |
| `kenney/particle_pack` (subset dipakai runtime: `star_04`, `star_06`, `light_01`, `smoke_04`, `smoke_07`, `dirt_01`) | Particle Pack — Kenney | CC0 1.0 | `License.txt` dalam folder; shader slash/ring di `scripts/vfx/combat_vfx.gd` ditulis tim |
| `polypizza/crystal_ipoly3d.glb` | Crystal — iPoly3D, via [Poly Pizza](https://poly.pizza/m/7iHQpCXTb7) | CC0 1.0 | Halaman sumber |
| `polypizza/flower_a_isa_lousberg.glb` | Flower A — Isa Lousberg, via [Poly Pizza](https://poly.pizza/m/DG7oCt9QYv) | CC0 1.0 | Halaman sumber |
| `audio/tinysized_vehicle` | Fantasy Sound Effects (Tinysized SFX) — Vehicle, [OpenGameArt](https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx) (subset relevan) | CC0 1.0 | File `.txt` dalam folder + halaman sumber |
| `audio/rpg_sfx_rubberduck` | 80 CC0 RPG SFX — rubberduck, [OpenGameArt](https://opengameart.org/content/80-cc0-rpg-sfx) | CC0 1.0 | Halaman sumber |
| `audio/ambience/Forest_Ambience.mp3` | Forest Ambience — TinyWorlds, [OpenGameArt](https://opengameart.org/content/forest-ambience) | CC0 1.0 | Halaman sumber |
| `audio/ambience/VistulaShort.mp3` | Sea and river wave sounds — RandomMind, [OpenGameArt](https://opengameart.org/content/sea-and-river-wave-sounds) | CC0 1.0 | Halaman sumber |
| `audio/music/children_soundtrack_2.ogg` | Children's Game Music 2 - Adventure — heartade, [OpenGameArt](https://opengameart.org/content/childrens-game-music-2-adventure); dikonversi WAV→OGG Vorbis | CC0 1.0 | Halaman sumber |
| `audio/music/CleytonRX-*` | Boss Battle Theme — CleytonKauffman, [OpenGameArt](https://opengameart.org/content/boss-battle-theme) | CC0 1.0 | Halaman sumber |
| `shaders/pixelated_water` | godot-4-pixelated-water-shader — taillight-games (shader + noise saja) | MIT | `LICENSE` dalam folder |
| `shaders/ring_aoe` | Dynamic Ring VFX Shader — priyanshsingh102005 (shader saja) | MIT | `LICENSE` dalam folder |
| `shaders/fiery_slash` | Fiery Slash Shader — priyanshsingh102005 (shader, mesh, `fire_01.png`) | MIT | `LICENSE` dalam folder |
| `blendswap/rock_golem` | Rock Golem — Joseph George, [BlendSwap](https://blendswap.com/blend/8148) | CC0 1.0 | `BLENDSWAP_LICENSE.txt` dalam folder |
| `mixamo/README.md` | Petunjuk pengadaan animasi Adobe Mixamo; FBX tidak disertakan | Adobe Mixamo terms, bukan CC0 | File motion lokal dikecualikan dari Git |

**Perubahan ikon game-icons:** latar hitam SVG dihapus untuk transparansi; ikon ditint dan diskalakan oleh UI. Bentuk ikon dan atribusi pembuat mengikuti sumber. Ikon CC BY 3.0 tetap tunduk pada [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); ikon Zeromancer yang bertanda CC0 mengikuti CC0.

**Mixamo dan repository publik:** GitHub API terautentikasi mengonfirmasi repository ini **public** pada 21 November 2026. Pernyataan sebelumnya bahwa repository private tidak benar. File FBX Mixamo dan sidecar import-nya tetap lokal, diabaikan Git, dan tidak ikut commit/push publik. Credit tidak memberikan izin redistribusi asset mentah. [Penjelasan distribusi Adobe](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) membedakan kolaborasi anggota tim dari distribusi raw files ke publik/non-anggota tim; anggota tim dapat memperoleh motion dari akun Mixamo masing-masing. Distribusi build game dibedakan dari distribusi file animasi reusable. README folder Mixamo berisi daftar motion yang perlu diperoleh, bukan animasinya.

## Konten yang ditulis sendiri oleh project

Berikut dibuat untuk project ini dan tidak menyalin kode, mesh, atau tekstur pihak ketiga. Asset pihak ketiga hanya dimuat apa adanya sebagai model/audio.

| Konten | Lokasi | Catatan |
|---|---|---|
| Shader laut | `shaders/island/island_water.gdshader` | Ditulis lokal untuk renderer Compatibility (tanpa depth/screen texture); warna dari palet pengguna. Tidak mengambil kode dari `assets/third_party/shaders/pixelated_water` atau shader pihak ketiga lain. |
| Shader health bar boss (inline) | `scripts/boss/gatekeeper_encounter.gd` (`_build_bar`) | Billboard unshaded sederhana, ditulis lokal. |
| Telegraf boss, partikel `CPUParticles3D`, segel/penghalang energi, material objektif | `scripts/boss/`, `scripts/objectives/objective_kit.gd` | Poligon/mesh primitif dan partikel buatan sendiri; tidak memakai shader `ring_aoe` atau `fiery_slash`. |
| Penampilan penjaga kuno (shader batu per-instance, material inti/pauldron/cincin rune, bone attachment) | `scripts/enemies/guard_appearance.gd` | Shader dan material ditulis lokal; menimpa material per instance, tidak mengubah resource KayKit yang diimpor. |
| Clip animasi golem (wake, roar, walk, sweep, slam, charge, recovery, death) | `scripts/boss/golem_animations.gd` | Keyframe tulang dibuat dalam kode pada rig `rock_golem.glb` (28 bone, tanpa clip bawaan). Bukan retarget dan bukan motion Mixamo. |
| Clip minum potion pemain | `scripts/player/drink_animation.gd` | Keyframe tulang untuk rig KayKit Rig_Medium; bukan motion Mixamo `Drinking`. |
| Terrain prosedural, layout, dermaga, tiga objektif, encounter boss, HUD/menu/intro/outro, mixer audio | `scripts/world/`, `scripts/objectives/`, `scenes/objectives/`, `scripts/boss/`, `scenes/boss/`, `scripts/ui/` | Kode dan scene project; teks intro/outro ditulis tim. HUD/menu memakai font Cinzel/Nunito (OFL), frame Kenney (CC0), serta ikon game-icons sesuai atribusi di atas. |
| Blur latar UI dan transisi | `shaders/ui_backdrop_blur.gdshader`, `scripts/ui/ui_theme.gd` | Shader canvas Compatibility dan pengaturan tween ditulis project; bukan shader pihak ketiga. |
| Attachment senjata dan efek combat | `scripts/combat/weapon_mount.gd`, `scripts/vfx/combat_vfx.gd` | Attachment, mesh arc/ring dan shader ditulis project; model senjata KayKit serta tekstur partikel Kenney tetap mengikuti lisensi sumber di atas. |

**Tidak ada dependency runtime pada Mixamo mentah.** Tidak ada script atau scene gameplay yang me-load `assets/third_party/mixamo/*.fbx`; clip minum dan golem dibuat dari kode. Clone baru dapat menjalankan dan mengekspor game tanpa mengunduh FBX Mixamo. Folder `assets/third_party/mixamo/README.md` hanya mencatat motion referensi lokal.

**Status runtime (25 November 2026):** UI memuat Cinzel/Nunito, `game_icons`, Kenney `ui_pack_adventure`, `fantasy_ui_borders` dan `input_prompts`; efek combat memuat subset `particle_pack` yang disebut di tabel. Asset runtime lain mencakup KayKit Adventurers, Character Animations, Forest Nature dan Dungeon; `polypizza/crystal_ipoly3d.glb`; `blendswap/rock_golem`; Kenney `interface_sounds`/`rpg_audio`; serta `audio/*`. Shader pihak ketiga `pixelated_water`, `ring_aoe` dan `fiery_slash` tidak digunakan oleh shader laut/arc/ring buatan project. Daftar kredit pemain ada pada [README](README.md#kredit); status bukti per kebutuhan ada di [Asset Inventory](docs/implementation/ASSET_INVENTORY.md).
