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

**Mixamo dan repository publik:** GitHub API terautentikasi mengonfirmasi repository ini **public** pada 21 November 2026. Pernyataan sebelumnya bahwa repository private tidak benar. File FBX Mixamo dan sidecar import-nya tetap lokal, diabaikan Git, dan tidak ikut commit/push publik. Credit tidak memberikan izin redistribusi asset mentah. [Penjelasan distribusi Adobe](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) membedakan kolaborasi anggota tim dari distribusi raw files ke publik/non-anggota tim; anggota tim dapat memperoleh motion dari akun Mixamo masing-masing. Distribusi build game dibedakan dari distribusi file animasi reusable. README folder Mixamo berisi daftar motion yang perlu diperoleh, bukan animasinya.
