# Pelengkap konkret UI, font, musik, dan ambience

Diperiksa 20 November 2026. Keluarga model utama KayKit telah ditetapkan pengguna; dokumen ini menutup pencarian sumber pendukung, **bukan menyatakan file sudah diunduh, didengarkan, diimpor, atau VERIFIED**. Semua sumber di bawah adalah halaman pembuat/publikasi pembuat yang benar-benar dibaca. Tidak ada pembelian.

| Kebutuhan | Sumber yang dipilih untuk sampel | Lisensi/format/bukti | Edit dan batas |
|---|---|---|---|
| U01/U03 panel, bar, menu | [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | Halaman resmi CC0, gratis, 430 file pada audit sebelumnya | Base visual saja; layout, angka HP/stamina, pause/settings/completion dan binding state tetap implementasi. Jenis bar tepat diperiksa saat sampel. |
| U02 control prompts | [Kenney Input Prompts](https://kenney.nl/assets/input-prompts) | Gratis CC0, 1500 file, 64×64; keyboard/mouse serta generic/gamepad. Halaman menyebut spritesheets/fonts pada changelog | Prioritaskan varian non-pixel agar lebih serasi KayKit. Set tombol mengikuti input final; glyph/icon masing-masing belum dipetakan ke file aktual. |
| U04 font | [Kenney Fonts](https://kenney.nl/assets/kenney-fonts) | Gratis CC0, 11 file; halaman tidak menetapkan exact family/file format | Pilih font non-pixel yang terbaca setelah melihat file; glyph Indonesia/tanda baca dan lisensi lokal perlu diperiksa. Logo game lokal adalah branding, bukan mengklaim Kenney membuatnya. |
| SFX07 UI | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Gratis CC0, 100 file, preview audio resmi tersedia | Pilih confirm/cancel/hover/pause setelah audisi; tidak menyatakan seluruh file terdengar sesuai. |
| SFX01–SFX06 kandidat foley/combat | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Gratis CC0, 50 file; kategori footstep/weapon/foley pada halaman | Pemetaan spesifik jump/landing/block/dodge/potion/puzzle/boss belum terkonfirmasi pada tingkat file. Pitch/layering/edit boleh, tetapi tidak otomatis menutup seluruh SFX. |
| AUD01 forest | [Forest Ambience — TinyWorlds](https://opengameart.org/content/forest-ambience) | Publikasi pembuat, CC0; file `Forest_Ambience.mp3`, halaman mengklaim seamless loop | Kandidat ambience/mood hutan, dikategorikan Music oleh pembuat; belum didengarkan sehingga jangan menyebut pure field recording atau final mix. |
| AUD01 shoreline | [Sea and river wave sounds — RandomMind](https://opengameart.org/content/sea-and-river-wave-sounds) | Publikasi pembuat, CC0; rekaman ombak sungai Vistula, `VistulaShort_0.mp3` dan arsip versi panjang | Bukan klaim rekaman pantai laut. Trim/crossfade/loop dan volume distance perlu diuji; jangan memasukkan arsip 180 MB tanpa kebutuhan. |
| AUD02 eksplorasi | [Children's Game Music 2 - Adventure — heartade](https://opengameart.org/content/childrens-game-music-2-adventure) | Publikasi pembuat, CC0; `children_soundtrack_2.wav`, 24.4 MB; electronic synth untuk adventure menurut deskripsi | Kandidat awal, belum audisi kecocokan/loop. Jika kurang cocok cari pengganti, bukan menganggap pilihan final karena lisensinya jelas. |
| AUD02 boss | [Boss Battle Theme — CleytonKauffman](https://opengameart.org/content/boss-battle-theme) | Publikasi pembuat, CC0; halaman menyebut looped; MP3 + variasi OGG. File variasi `CleytonRX - Battle RPG Theme Var_0.ogg` | Kandidat battle orchestral/rock menurut tag; belum didengarkan atau diuji transisi. Simpan credit pembuat walaupun CC0 tidak mewajibkan atribusi. |
| M28 sprite VFX | [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | Gratis CC0, 80 sprite 512×512 pada audit sebelumnya | Sprite bukan sistem particle/telegraph. Material, particle node, timing dan readability tetap pekerjaan agent. |

U05 opening/outro dan environmental clue mengikuti lore dalam `docs/konsep-game.md`; teks ditulis tim/agent dan memakai model/ilustrasi yang sudah mendapat izin, bukan alasan mencari NPC/dialog baru. Narasi bukan asset 3D yang harus dibeli.

## Status yang jujur

Sumber konkret font, input, UI, musik dan ambience **ditemukan pada katalog**, bukan produksi selesai. SFX01–SFX06 masih perlu daftar clip spesifik dan audisi; music/ambience belum diperiksa dengan telinga. Saat pengadaan: simpan pembuat, URL, lisensi, tanggal/hash file; audisi, trim/loop, import dan uji volume/transisi sebelum status VERIFIED. Tidak mengisi nama clip yang tidak dipublikasikan oleh sumber.

## SFX yang lebih spesifik daripada satu paket RPG generik

| Bank resmi pembuat | Isi yang dinyatakan | Penggunaan terarah |
|---|---|---|
| [Fantasy Sound Effects (Tinysized SFX) — Vehicle](https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx) | CC0; 96 file, 44.1kHz/16bit; boots/steps, arrows/quiver, bottles/vials/cork, keys/lockbox, sword, metal hits/scrapes, whooshes, water drops/pouring | SFX01 langkah/landing dari boots; SFX02 sword/arrow/metal; SFX03 block/dodge dari metal/whoosh; SFX04 potion dari vial/cork/water. Ini pemetaan editing, bukan nama file final atau audisi. |
| [Fantasy Weapons and Apparel — Vehicle](https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library) | CC0; 126 file, 44.1kHz/16bit; arrows/quiver/belt/leather boots/knife/seax/sword | Fallback footsteps, clothing movement dan weapon handling yang konsisten dengan bank Vehicle sebelumnya. Tidak harus mengunduh kedua bank jika pertama mencukupi. |
| [80 CC0 RPG SFX — rubberduck](https://opengameart.org/content/80-cc0-rpg-sfx) | CC0; blade, chain, creature die/hurt/roar, item gem/stone/wood, lock, metal, spell, stones, wood | SFX03 hurt/death dan SFX05–06 puzzle/checkpoint/gate/boss: layer stone/chain/lock/spell/gem dan pitch/gain/trim sesuai interaksi. Bukan klaim ada file bernama Gatekeeper atau EnergyPanel. |

Dengan tiga bank ini seluruh kategori SFX01–SFX07 mempunyai sumber bahan katalog yang konkret, tetapi **file-level assignment, hasil edit dan kualitas audio belum terpenuhi**. Misalnya lompat/landing memakai foley dan roar golem memakai editing/layering: itu pekerjaan agent, bukan asset gameplay yang sudah jadi. Tidak menyimpulkan loop/mix cocok tanpa audisi. Tidak ada arsip bank diunduh dalam pekerjaan ini.
