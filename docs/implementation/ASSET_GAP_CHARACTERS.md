# Penutupan Gap Karakter — Sumber Motion dan Basis Guardian

Tanggal riset: **20 November 2026**. Lingkup: **N06, N11, M02–M05**. Inti tetap KayKit Adventurers + Character Animations + Forest + Dungeon. Pendamping [audit karakter](ASSET_ECOSYSTEM_CHARACTERS.md), [audit utama](ASSET_ECOSYSTEM_AUDIT.md), dan [inventaris](ASSET_INVENTORY.md); tidak mengubah status produksi di sana.

**Batas pekerjaan:** membaca halaman/publikasi maker, manifest teks, gambar resmi, dan preview Mixamo publik. Tidak login, mengunduh model/arsip/FBX, membeli, mengimpor, meretarget, menjalankan engine, atau menguji file. Gambar di bawah ditautkan ke sumber, bukan file model lokal. Tidak ada klaim persentase terpenuhi atau `VERIFIED`.

## Keputusan yang lebih spesifik

1. **N06 punya motion minum bernama yang benar-benar dapat dipreview publik: Mixamo `Drinking`, deskripsi `Male Drinking`.** Ini bukan tebakan dari `USE_ITEM`. Preview dimuat pada default character dan menampilkan gerak tangan ke mulut; belum diuji pada KayKit, belum memiliki FBX lokal, dan belum memiliki completion/interrupt gameplay.
2. **Fallback N06 lebih tepat daripada pack NPC generik:** nikoff **Survival Eating & Drinking Animations**, dengan manifest resmi `AS_Surv_Stand_Drink_Bottle_In`, `_Loop`, `_Out`. Berbayar, FBX tercantum, tetapi belum dibeli atau diuji. MoCap Online Bar **bukan fallback default** karena ketentuan AI-processing/retargeting dan konteks bar yang harus diedit.
3. **M05 utama bersyarat: Frost Golem Series 5**, bukan LOWPO otomatis. Preview resmi kini diperiksa: torso/anggota batu-berbidang sudah terbentuk, tetapi berwarna es dan punya duri kristal. Recolor/roughness + core attachment masuk akal sebagai rencana; spike removal/pemisahan material belum terbukti ringan. Identitas rig Frost Golem **belum dinyatakan per karakter**: jangan menyebut `Rig_Large` confirmed hanya dari ukuran gambar.
4. **N11 tidak mempunyai satu paket yang terbukti lengkap.** Pilih basis KayKit dan exact motion di tabel berikut; sweep/charge/wake masih memerlukan adaptasi atau authoring agent. Alternatif Mixamo mempunyai nama dan preview nyata, tetapi retarget ke KayKit bukan plug-and-play. Tiga serangan dan aturan dua fase tidak dihapus.
5. **M02–M04 dapat memakai satu keluarga guardian dari basis KayKit**, tanpa mengganti ke undead: Knight closed-visor untuk standard/ranged, Barbarian besar dengan fitting armor untuk heavy. Ini keputusan basis adaptasi, bukan trio ancient guardian siap pakai. Tidak ada kewajiban pengguna melakukan modelling manual.

### Tingkat bukti dan biaya edit

- **PUBLIC_CLIP_PREVIEW:** clip dipilih dan dimuat di viewer maker pada default character. Lebih kuat daripada judul katalog, tetapi bukan bukti file/tier hasil unduhan atau retarget target.
- **PUBLISHED_LABEL:** nama clip ada pada chart/manifest maker; tidak mengklaim sudah melihat semua gerak atau mengekstrak clip.
- **MODEL_PREVIEW / CATALOG:** gambar/model ditampilkan atau isi diklaim halaman produk; tidak membuktikan mesh terpisah, weights, skeleton, dan material slots.
- **LOW:** palette/scale/rigid attachment tanpa mengubah anatomi. **MEDIUM:** fitting/kitbash terarah, trim/retiming/pose correction pada rig yang cocok. **HIGH:** animasi baru, retarget lintas proporsi/rig, perubahan skin weights atau remodel. **UNKNOWN:** file belum cukup terbukti. Level adalah perkiraan risiko, bukan estimasi hasil uji.

## N06 — minum potion

### Primary: Adobe Mixamo `Drinking`

**Sumber exact:** [pencarian motion resmi Drinking](https://www.mixamo.com/#/?page=1&query=drinking&type=Motion%2CMotionPack). Pada sesi publik tanpa login, muncul **3 hasil**:

| Nama hasil persis | Deskripsi persis pada kartu | Keputusan |
|---|---|---|
| `Drinking` | `Male Drinking` | **Primary N06.** Dipilih; viewer `DRINKING ON DEFAULT CHARACTER` berhasil dimuat. Panel menunjukkan **267 total frames** pada setelan saat diamati, bukan durasi final game. Thumbnail/preview memperlihatkan tangan dinaikkan ke mulut. |
| `Drinking Fountain` | `Stopping To Drink From Drinking Fountain` | Ditolak untuk potion berdiri; geraknya membungkuk ke sumber air. |
| `Sitting Drinking` | `Having A Seat And Drinking A Canned Beverage` | Ditolak sebagai primary; memerlukan duduk dan konteks kaleng. |

**Akses/tier:** [FAQ Adobe](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) menyatakan gratis dengan **Adobe ID**, tanpa Creative Cloud subscription; Enterprise/Federated IDs tidak didukung dan ada pembatasan country-code China. Search dan preview di atas berhasil tanpa login; **pengadaan file berada di jalur akun**, bukan public direct-download yang sudah diperoleh. Tidak meminta kredensial, tidak menekan Download, tidak memulai login. Target pengadaan ialah motion **FBX**; pilihan/preset export dan isi FBX aktual **belum diperiksa** pada sesi tanpa pengadaan ini. Jangan menyamakan format FBX yang didukung untuk *upload* dengan bukti preset *download* tertentu.

**Lisensi:** FAQ Adobe mengizinkan penggunaan royalty-free pada game personal/commercial/non-profit. [Panduan distribusi pada domain Adobe Community](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) membedakan penggunaan dalam game dari redistribusi raw animation/character: raw tidak boleh dibagikan umum; anggota project team dapat mengakses untuk kolaborasi. Ini penjelasan komunitas di domain Adobe, bukan lisensi CC0 atau pengganti terms saat memperoleh file. **Jangan commit FBX/hasil motion yang dapat digunakan ulang ke repo publik**. Retarget/modify untuk game tidak membuat motion menjadi CC0. Penggunaan untuk training ML juga dilarang menurut penjelasan tersebut.

**Rencana edit agent, bukan hasil yang sudah selesai — HIGH:**

- Ambil motion pada skeleton sumber yang sah di tahap pengadaan; pertahankan skeleton KayKit produksi. Retarget motion ke rig pemain, bukan mengganti seluruh cast dengan auto-rig Mixamo.
- Cocokkan rest pose, clavicle/upper arm/forearm/wrist dan kepala; proporsi kepala/tangan chibi memerlukan koreksi hand-to-mouth. [Adobe menjelaskan mapping rigged FBX](https://helpx.adobe.com/creative-cloud/help/mixamo-rigging-animation.html), tetapi tidak menjamin mapping KayKit berhasil. FAQ juga memperingatkan proporsi terlalu terdeformasi dapat gagal auto-rig; karena itu auto-rig ulang bukan jalan pintas yang dijanjikan.
- Gunakan bottle Dungeon sebagai prop tangan; sesuaikan grip dan kemiringan bottle. `Drinking` preview tidak membuktikan prop bottle terpisah ikut disertakan.
- Trim menjadi satu penggunaan yang terbaca; mask upper body agar kaki tetap bisa berjalan pelan. Koreksi torso/hand path agar tidak menembus kepala atau sword. Masking dan koreksi ini **belum diuji**.
- Pada integrasi nanti, satu completion event setelah gerak minum selesai yang mengurangi potion dan memulihkan HP. Hit sebelum completion membatalkan, menyembunyikan prop dan beralih ke hurt tanpa konsumsi/heal. Ini tetap pekerjaan gameplay, **bukan fitur clip Mixamo**. Tidak menambah animasi dummy atau event heal di awal demi mengklaim N06 selesai.

**Jika motion gagal fitting:** authoring agent pada rig KayKit berdasarkan pose intake → bottle di mulut/tilt → return, memakai locomotion kaki asli; ini **animasi baru HIGH**, bukan asset online yang sudah ditemukan. Model tubuh dan bottle tetap online, pengguna tidak diminta memodel manual. `USE_ITEM` tetap tidak dianggap drink tanpa pemeriksaan gerak.

### Fallback konkret: nikoff — Survival Eating & Drinking Animations

[Listing publisher Fab](https://www.fab.com/listings/b8288eab-2944-47d9-9d0b-d187151cc2c7) menautkan [manifest resmi yang terbaca publik](https://docs.google.com/spreadsheets/d/1U9q5yPx3dO_8FaeGy2VIcCw9424x0O8Do4GlqMThTQ8/edit?usp=sharing) dan [video preview publisher](https://youtu.be/zHbJjIFC3Vo). Video tertaut, **bukan diklaim sudah ditonton pada riset ini**. Nama berikut benar-benar ada di manifest:

| Clip persis | Deskripsi maker | Pemakaian N06 |
|---|---|---|
| `AS_Surv_Stand_Drink_Bottle_In` | Pulling out a bottle and unscrewing the cap | Bahan enter; gerak screw-cap mungkin perlu dihilangkan/disesuaikan bottle potion. |
| `AS_Surv_Stand_Drink_Bottle_Loop` | Drinking from a bottle: looping gulp | Pilih satu jumlah gulp terbatas, **bukan loop gameplay tanpa selesai**. |
| `AS_Surv_Stand_Drink_Bottle_Out` | Finishing drinking, screwing the cap back on, storing in inventory | Bahan return; completion tetap ditentukan game setelah keseluruhan aksi. |
| `AS_Surv_Stand_Drink_Bottle_Drop` | Finishing drinking (finishing the rest) and discarding the empty bottle | Tidak dipilih: tidak perlu menambah mekanik buang bottle. |

**Tier/format:** berbayar; listing menyebut **Unreal Engine dan FBX**, serta converted GLB/glTF/USDZ. Harga mesin halaman saat riset **IDR 191,553.48**, tetapi pemilih Personal/Professional belum dipilih; itu **bukan harga checkout/tier yang dijamin**, belum ada izin membeli. Skeleton/bone naming dan file bottle prop tidak terkonfirmasi di manifest. **PUBLISHED_LABEL**, bukan file/gerak yang diuji.

**Lisensi:** [Fab Standard License](https://www.fab.com/eula) mengizinkan penggunaan/modifikasi dalam proyek dan tools selain Unreal; sharing dengan kolaborator di private repository diizinkan, redistribusi standalone tidak. Pastikan lisensi/tier source-format yang benar saat pengadaan; Reference-Only bukan source download. Listing nikoff menandai **Allows usage with AI: Yes**, bukan dibuat AI. Ini lebih cocok sebagai calon workflow agent daripada MoCap Online yang membatasi AI processing. **Retarget ke KayKit HIGH**, penyesuaian grip/cap dan trim **MEDIUM**, bukan direct Godot-ready.

### Kandidat yang tidak menjadi fallback default

- **[MoCap Online Bar](https://mocaponline.com/products/bar)**: source **FBX** memang didokumentasikan (MotusMan_v55; 112 file, 16 standing), bukan semata UASSET. Namun dominan interaksi meja/bar, loop sekitar 30 detik. [Daftar maker](https://mocaponline.com/pages/animlist-BAR) menautkan spreadsheet yang mengembalikan HTTP 400 pada kedua jalur baca; tidak berhasil membuktikan exact standalone potion clip. Yang lebih penting, [lisensi maker sekarang](https://mocaponline.com/pages/licensing) mensyaratkan **AI Usage Permit untuk AI retargeting/processing**, melarang raw redistribution, serta punya threshold pengguna/revenue. **Tolak sebagai fallback default agent**, bukan menyuruh membeli permit. Retarget deterministik biasa tidak otomatis sama dengan AI retargeting, tetapi wording luas ini harus diselesaikan sebelum data diproses workflow agent.
- **[Eating and Drinking — animasterstudio di CGTrader](https://www.cgtrader.com/3d-models/character/other/eating-and-drinking-animation-pack)**: deskripsi eksplisit bottle x2/standing, tetapi **native format hanya UASSET 5.3**, Epic Manny/Quinn, `Royalty Free License (no AI)`; bukan bukti source FBX. Harga tampak USD 35 diskon dari 50. Tidak dipilih.
- **[Eating and Drinking — Unity Asset Store](https://assetstore.unity.com/packages/3d/animations/eating-and-drinking-animation-pack-325036)**: **publisher berbeda, The Mighty Cat Games**, USD 19.99, Standard Unity EULA, Extension Asset. Bagian description/technical detail tidak terbaca isinya pada reader. Jangan menyamakan ini dengan pack animasterstudio atau menjamin format/clip hanya karena judul sama.

## M05 — boss batu berinti energi

### Primary bersyarat: KayKit Series 5 Frost Golem

[Sumber produk/tier](https://kaylousberg.itch.io/kaykit-series-5) · [mirror maker](https://kaylousberg.com/patreon-characters/series-5).

![Preview resmi Frost Golem KayKit Series 5](https://img.itch.zone/aW1hZ2UvMzcxMjE3NS8yMjEzODQ5Ny5wbmc=/original/M4r0IB.png)

**Yang benar-benar terlihat:** humanoid besar, tangan tebal, kepala dan badan berupa bidang-bidang tersegmentasi dengan batas seperti retakan, permukaan biru/putih, duri kristal di bahu/lengan/punggung/kepala. Torso depan cukup lebar untuk calon attachment crystal; **tidak terlihat chest cavity/core terpisah yang sudah siap**. Ini penilaian gambar resmi, bukan inspeksi geometry.

**Tier:** **USD 19.99 minimum** seluruh Series 5 **1.1**; FBX/glTF + `.blend` source untuk karakter/accessories termasuk. Halaman menyatakan rigged/textured/animated, basic movement dan kompatibel standar KayKit kini; **CC0**, tanpa atribusi wajib. Source tidak perlu dibeli terpisah. Tidak ada Free Frost Golem yang terbukti. Tidak membeli/menganggap budget sudah ada.

**Mengapa lebih diprioritaskan daripada external:** proporsi dan atlas shading berada di keluarga maker yang sama; `.blend` memberi jalur edit yang lebih langsung bila kelak pembelian diotorisasi. Namun klaim “technically identical to Adventurers” pada katalog **bukan chart per-character yang menyebut Frost Golem memakai `Rig_Large`**. Ukuran tubuh pada gambar bukan bukti rig. Pemeriksaan hierarchy/rest pose dan pemilihan library Medium/Large tetap gate pertama sebelum animasi boss.

**Rencana agent:**

| Perubahan terhadap model online | Risiko | Batas klaim |
|---|---|---|
| Biru/putih es → stone-grey/warm-grey, matte; kurangi efek material es bila ada | LOW–MEDIUM | Preview tidak membuktikan shader/material source. Duri tetap kristal energi bila silhouette cocok, tidak mengganti lore menjadi ice boss. |
| Tambah **crystal di permukaan dada**, pada chest bone/attachment | LOW–MEDIUM | Tidak mensyaratkan melubangi torso. Core energi tetap hadir dan terbaca; bukan mekanik baru weakpoint/breakable armor. |
| Kurangi duri panjang atau kitbash shoulder agar stone silhouette lebih tenang | MEDIUM; HIGH bila weights menyatu | `.blend` ada secara katalog, tetapi belum diketahui apakah spikes mesh terpisah atau weighted bersama. Recolor saja tidak dijanjikan menutup seluruh perubahan. |
| Atur pose, collision dan grip animasi boss pada tubuh ini | HIGH/UNKNOWN | Belum ada skin/clip yang diuji. |

**Sumber core konkret:** [KayKit Resource Bits](https://kaylousberg.com/game-assets/resource-bits), [preview resmi Extra](https://kaylousberg.com/content/3-game-assets/7-resource-bits/resource_bits_overview_extra.png) benar-benar menampilkan gem lepas di kiri. **Extra USD 4.99** menurut [audit world](ASSET_ECOSYSTEM_WORLD.md), bukan Free; FBX/glTF/OBJ dan CC0 dinyatakan maker. Ambil satu gem lepas, scale/rotate ke dada dan ubah material menjadi cyan/energy. Exact filename/material slot belum diperiksa. Alternatif tanpa pack tambahan ialah memakai ulang salah satu crystal spike **dari source Frost Golem jika geometri dapat dipisahkan**; ini rencana mesh edit MEDIUM, bukan klaim mesh crystal lepas sudah ada. Tidak memerlukan cavity atau perubahan mekanik/lore. Cahaya inti Compatibility dan fase tetap integrasi material, tidak dijanjikan glow/bloom otomatis.

### Fallback bersyarat: LOWPO Rock / Earth Golem Free

[Listing resmi](https://standout7.itch.io/lowpo-golem).

![Preview resmi Free LOWPO Golems](https://img.itch.zone/aW1nLzI2MzM3MzMzLnBuZw==/original/evXvUy.png)

**Model:** Rock, Earth, Iron **Free**, FBX triangulated. HEX USD 3.99 menambah Crystal/Bone/Ice/Arcane dan GLB/OBJ/glTF; Full USD 9.99 menambah source Blend/quad topology. Free Rock/Earth lebih langsung stone daripada Frost; tidak perlu membeli HEX hanya karena butuh core attachment. Preview berlabel Free memperlihatkan anggota batu tebal, tetapi core terpisah tidak terbukti. Pembuat eksplisit **humanoid rig, no animations included**; “Mixamo ready” bukan bukti retarget KayKit.

**Lisensi menghalangi pengadaan yang aman untuk repo publik:** teks mengizinkan personal/commercial game use tetapi melarang redistribution asset files, metadata itch menyebut CC0. Konflik belum terselesaikan. **Fallback bukan aman-download otomatis**, terlebih bukan izin commit raw. Material/core attachment MEDIUM; lintas rig/style dan seluruh N11 HIGH. Bila lisensi tidak dapat dipastikan, jangan berpindah ke LOWPO demi menghindari harga Frost; gunakan jalur KayKit authoring yang jelas atau nyatakan M05 belum terselesaikan.

### Fallback tanpa harga premium/konflik LOWPO: Joseph George Rock Golem

[Publikasi pembuat di BlendSwap](https://blendswap.com/blend/8148) berhasil dibaca lagi: **free, CC0**, `.blend`, **Blender 2.6x / Blender Internal**, 151 KB menurut halaman. Pembuat eksplisit menyebut **floating body parts**, mudah di-pose/edit, boleh dipakai untuk scene/game. Tidak ada klaim FBX/glTF, rig humanoid, atau clip siap pakai. Link Download tersedia, tetapi tidak ditekan; kebutuhan akun/limit pengunduhan belum diuji. Preview pernah dibuka pada [riset karakter sebelumnya](ASSET_CHARACTER_RESEARCH.md#3-boss--rock-golem-oleh-joseph-george): anggota batu terpisah, tubuh ramping/gelap, bukan boss KayKit/core turquoise yang selesai.

**Keputusan:** fallback legal metadata yang lebih jelas bila Frost belum boleh dibeli dan LOWPO terms belum terselesaikan; **bukan pilihan visual/teknis yang lebih ringan**. Model tetap berasal online. Agent dapat memperlebar batu torso/bahu/forearm melalui scale/edit bagian yang sudah ada, memendekkan proporsi agar mendekati keluarga KayKit, menyusun ulang material batu modern, memasang core, lalu memasang rigid body-part meshes pada bone target yang relevan. Karena bagian mengambang, jalur rigid attachment berpotensi menghindari skin weight halus, tetapi separability/hierarchy aktual tetap belum diperiksa. **HIGH** untuk reproportion/rig setup/konversi Blender lama, **MEDIUM** untuk material/core setelah struktur cocok.

N11 tetap memakai exact source-motion plan di bawah hanya setelah skeleton tersedia; asset ini tidak menawarkan shortcut retarget yang telah terbukti. Jika bagian ternyata tidak dapat dipakai melalui rigid attachment, rig/weights adalah pekerjaan agent HIGH yang masih terbuka, bukan kewajiban pengguna memodel manual. CC0 di halaman memperjelas hak modifikasi/redistribusi dibanding konflik LOWPO, tetapi file/dependency license tetap dicatat pada tahap pengadaan. Ini **fallback basis authoring**, tidak menutup M05/N11 end-to-end.

## N11 — exact motion plan, bukan “ada 161 animasi”

Sumber native: [halaman maker Character Animations](https://kaylousberg.com/game-assets/character-animations), [chart Rig_Large resmi yang dibuka](https://kaylousberg.com/content/3-game-assets/4-character-animations/rig_large_overview.png). Free, **CC0**, FBX/glTF. Source/control rig `.blend` **USD 14.99 opsional**, bukan membeli clip eksklusif; tidak dibeli. Chart Large memuat **29 label**, bukan semua gerak Medium. Seluruh penggunaan Large pada Frost Golem **bersyarat setelah rig exact diketahui**.

| Kebutuhan | Primary pada keluarga KayKit | Fallback exact online | Modifikasi dan status |
|---|---|---|---|
| **Idle** | Large `IDLE_A` / `IDLE_B` | Mixamo `Mutant Breathing Idle`, deskripsi `Mutant Breathing Idle`, [search mutant](https://www.mixamo.com/#/?page=1&query=mutant&type=Motion%2CMotionPack) | Native label terbukti chart; Mixamo label terlihat hasil publik tetapi idle ini tidak dipilih untuk preview. MEDIUM native, HIGH retarget. Tidak menambah napas biologis sebagai lore wajib. |
| **Wake** | Tidak ada Large clip `WAKE` terbukti. **Authoring agent**: inactive standing pose berangkat dari `IDLE_B`, kepala/lengan turun → naik → settle `IDLE_A`; tanpa mengubah skeleton dasar | Mixamo **`Mutant Roaring`**, deskripsi sama, [search roar](https://www.mixamo.com/#/?page=1&query=roar&type=Motion%2CMotionPack). Dipilih dan viewer dimuat, **163 total frames** saat diamati | Roaring adalah bahan aktivasi torso/lengan, **bukan clip bangun batu**; hilangkan gestur vokal berlebihan/retime. Wake native belum fulfilled: animasi baru HIGH. Fallback HIGH retarget. Jika pose awal perlu tidur, `Getting Up` dengan deskripsi **`Getting Up From Back`** pada [search getting up](https://www.mixamo.com/#/?page=1&query=getting%20up&type=Motion%2CMotionPack) dipilih dan viewer dimuat; ini bukan alasan mengubah pose awal/desain secara otomatis. |
| **Sapuan lengan** | Large **`MELEE_1H_SLASH`**, atau `MELEE_DUALWIELD_SLASH`; chart membuktikan slash, **tidak membuktikan bare-arm horizontal sweep** | Mixamo **`Mutant Swiping`**, deskripsi **`Mutant Attacking With Left Hand`**, [search swiping](https://www.mixamo.com/#/?page=1&query=swiping&type=Motion%2CMotionPack). Dipilih, viewer dimuat **81 total frames** | Native: buang ketergantungan weapon grip, koreksi lintasan shoulder/elbow/wrist agar sapuan lengan nyata, wind-up dan recovery jelas. MEDIUM jika pose cukup; **HIGH** jika perlu keyframing baru. Mixamo HIGH retarget, bukan sekadar rename slash. |
| **Hantaman tanah** | Large **`MELEE_UNARMED_SMASH`** primary; **`MELEE_2H_SLAM`** fallback native | Jika native tidak sesuai setelah preview file, authoring agent dari raise-pose → kedua tangan turun menyentuh tanah → hold impact → recover pada rig KayKit. Tidak mengklaim external slam yang tidak dibuktikan | Chart memberikan **exact smash/slam labels**, bukan bukti tangan mencapai tanah pada golem. Grip/ground contact dan telegraph perlu koreksi MEDIUM–HIGH. Search Mixamo `Slam` menampilkan `Grab And Slam` (membanting orang) dan pasangan `Hell Slammer A/B`; **ditolak**, bukan ground slam otomatis. |
| **Terjangan lurus** | Large **`RUNNING_A`** sebagai bagian travel, dengan **charge anticipation dan braking pose hasil edit agent** | Mixamo **`Mutant Run`**, deskripsi **`Mutant Running`**, [search mutant](https://www.mixamo.com/#/?page=1&query=mutant&type=Motion%2CMotionPack), dipilih dan viewer dimuat | Running **bukan charge siap pakai**. Tambahkan lean/shoulder lead, start brace dan stop/recovery; translation lurus, target lock dan hitbox berasal dari controller, bukan animasi root yang belum diketahui. Native MEDIUM–HIGH; retarget HIGH. Hasil Mixamo **`Charge` / `Pointing Onward Charge` ditolak**: itu gesture memberi komando, bukan menerjang. |
| **Recovery** | Bagian akhir `MELEE_UNARMED_SMASH` / `MELEE_1H_SLASH` → settle `IDLE_A`; charge perlu braking yang diauthor | End pose motion Mixamo pilihan setelah retarget → KayKit idle | Nama chart tidak membuktikan recovery cukup panjang. Ekstensi hold/settle MEDIUM; custom balance/footplant HIGH. Recovery tidak diganti idle instan agar terlihat lengkap. |
| **Death** | Large **`DEATH_A`** → **`DEATH_A_POSE`** | Mixamo **`Mutant Dying`**, deskripsi **`Mutant Dying Falling Onto Back`**, [search dying](https://www.mixamo.com/#/?page=1&query=dying&type=Motion%2CMotionPack). Dipilih dan viewer dimuat **139 total frames** | Native label terbukti. Ground clearance/stone mass/pose core diperiksa nanti; MEDIUM native, HIGH fallback. Tidak perlu memecahkan golem menjadi batu terpisah atau membuat ragdoll baru. |

**Bukti preview Mixamo di atas bukan angka durasi kontrak:** frame count berasal dari panel pada default settings saat diamati; FPS, hasil trim/overdrive, root motion dan frame data FBX belum diperiksa. Search URL + nama + deskripsi dipakai karena beberapa judul Mixamo tidak unik. `Drinking`, `Mutant Swiping`, `Mutant Roaring`, `Mutant Dying`, `Mutant Run`, dan `Getting Up / Getting Up From Back` benar-benar dipilih di viewer; tidak mengklaim seluruh hasil pencarian ditonton.

**Fallback tanpa lintas rig jika motion tidak cocok:** agent mengedit/author sweep, wake, anticipation/brake charge pada skeleton KayKit yang diperoleh; preserve native idle/death dan smash/slam yang lolos pemeriksaan. Ini rencana produksi **HIGH**, bukan mengatakan “custom” lalu menghitung N11 terpenuhi. Pengguna tidak perlu membuat model/animasi manual. No-op, mengulang satu swing untuk tiga serangan, dan mengganti charge dengan pointing gesture bukan solusi.

**Dua fase tetap sama:** >50% satu serangan lalu recovery; ≤50% kadang dua serangan dengan telegraph/timing dasar tetap. Tidak ada kebutuhan lore untuk transformasi tubuh; **`EXPERIMENTAL_LARGE_TRANSFORM` tidak diperlukan dan tidak dihitung sebagai phase solution**. Penjadwalan serangan, telegraph, damage/event dan snapshot retry tetap implementasi, tidak dibeli bersama model.

## M02–M04 — trio guardian yang mempertahankan keluarga

[Adventurers current](https://kaylousberg.itch.io/kaykit-adventurers) / [mirror maker](https://kaylousberg.com/game-assets/characters-adventurers): Free 2.0 Knight/Barbarian/Rogue/Mage/Ranger; Extra USD 7.95 termasuk Barbarian besar; Source USD 11.95 termasuk Extra dan `.blend`. FBX/glTF, CC0; tier/roster dirinci di [audit karakter](ASSET_ECOSYSTEM_CHARACTERS.md). Preview [Knight resmi yang dibuka](https://kaylousberg.com/content/3-game-assets/11-characters-adventurers/knight.png) secara eksplisit mengatakan **visor can close** dan memperlihatkan helm tertutup. Ini dasar konkret menghindari wajah manusia, bukan asumsi butuh sculpt kepala baru.

**Aturan adaptasi:** gunakan palette stone/aged metal yang sama, glyph/energy accent yang sama, visor tertutup dan weapon silhouette berbeda. Jangan memperkenalkan ras undead atau mengganti penjaga sistem pulau menjadi faksi tentara manusia. Bila tubuh perlu terlihat sepenuhnya stone construct, material saja bukan bukti selesai; fitting/penutupan bagian tubuh tetap dicatat per file. Ordinary guardians tidak dipaksa identik dengan boss atau diberi mekanik weakpoint baru.

| Gap | Primary konkret | Fallback konkret | Pekerjaan agent / bukti tersisa |
|---|---|---|---|
| **M02 standard ramping** | **Knight Free**, visor tertutup + `sword_1handed`/one-handed sword dari Adventurers; Medium `MELEE_1H_ATTACK_SLICE_HORIZONTAL`, idle/walk/hit/death | **Series 5 Black Knight** USD 19.99 (paket yang sama dengan calon boss), FBX/glTF/.blend, CC0; roster terbukti tetapi detail rig/mesh tidak | Palette/visor/weapon **LOW–MEDIUM**. Glyph attachment dan cape/material fitting **MEDIUM**; pemisahan cape belum diperiksa. Tidak perlu merombak anatomi atau mengganti species. Black Knight tidak otomatis gratis karena satu seri dengan boss. |
| **M03 heavy tubuh lebih besar** | **Barbarian besar — Adventurers Extra USD 7.95**, two-handed axe dari Adventurers; helm tertutup/armor rigid dari Knight dipasang ke head/shoulder, palette sama. Native Large `MELEE_2H_SLAM` bila exact rig cocok | **LOWPO Army Knight** Free / armored variant yang terbukti cocok setelah inspeksi; weapon berat dari Adventurers, bukan mengklaim Free Army punya hammer. Atau **LOWPO Mercenary Tank HEX USD 3.99** bila silhouette Army tidak memadai, lihat [audit pelengkap](ASSET_ECOSYSTEM_COMPLEMENTS.md) | Bukan membesarkan Knight seragam lalu menyebut selesai. Large Barbarian memberi basis massa berbeda, tetapi matching helm/shoulder dan mengatasi area exposed skin adalah **MEDIUM–HIGH**; rigid fitting mungkin cukup, reweight jika mesh menyatu **HIGH**. Source Adventurers USD 11.95 alternatif Extra, bukan ditambah 7.95 lagi. Fallback external menambah rig/style/license gate; tidak dipilih diam-diam. |
| **M04 ranged satu keluarga** | **Knight Free kedua dengan visor tertutup + crossbow/arrow Adventurers**, tanpa sword/shield aktif; Medium `RANGED_2H_AIMING`, `RANGED_2H_SHOOT`, `RANGED_2H_RELOAD` sebagai exact candidates | **Ranger Free + bow/arrow Adventurers**, gunakan armor/helm Knight fitting dan palette guardian; `RANGED_BOW_DRAW`, `RANGED_BOW_AIMING_IDLE`, `RANGED_BOW_RELEASE` | Primary sengaja memakai body Knight supaya family benar-benar sama, pembeda role dari silhouette crossbow/posture, bukan hanya warna. Crossbow grip/two-hand fit, socket dan projectile direction **MEDIUM**. Chart gun-style 2H belum membuktikan crossbow reload cocok; bila tidak, bow fallback punya label draw/release lebih spesifik. Fitting Ranger ke closed-visor guardian **MEDIUM–HIGH**, bukan rename manusia berhood jadi construct. |

**Fallback lintas keluarga hanya bila basis KayKit benar-benar gagal:** [LOWPO Army](https://standout7.itch.io/fantasy-army) Footman/Knight/Captain Free; Archer **Premium USD 3.99**, bow/arrow Free. [LOWPO Mercenary](https://standout7.itch.io/lowpo-mercenary) Swordsman/Archer Free, Tank HEX USD 3.99; eksplisit tanpa animasi. Keterangan tier/format tersebut sudah didokumentasikan dari halaman publisher pada [audit pelengkap](ASSET_ECOSYSTEM_COMPLEMENTS.md); pembacaan ulang Army pada riset ini mendapat HTTP 429, jadi tidak mengklaim ada update file baru. Family LOWPO berbeda dari KayKit dan legal gate tetap: Army grant lisensi spesifik belum cukup terbukti; Mercenary terms non-redistribution bertentangan dengan metadata CC0. **Tidak menjanjikan fallback ini siap dipakai sampai hak penggunaan/share dan retarget jelas.**

## Apa yang ditemukan, apa yang tetap unresolved

| Gap | Kemajuan bukti | Masih belum selesai |
|---|---|---|
| N06 | Exact drinking motion Mixamo dengan preview publik; fallback publisher mempunyai exact bottle In/Loop/Out manifest + FBX listing | Akun/pengadaan FBX belum dilakukan; skeleton/hand-mouth, bottle, walking mask, completion/interrupt belum diuji. Tidak ada minum asli KayKit yang terbukti. |
| M02–M04 | Basis role konkret, visor close terbukti preview, same-family kitbash plan dan exact clip candidates | Tidak ada file guardian hasil modifikasi; armor parts separability/rig/role readability belum diuji. Heavy fitting bisa HIGH. |
| M05 | Frost Golem preview benar-benar diperiksa; family-preserving source tersedia berbayar; Rock/Earth LOWPO sudah stone; Joseph George Rock Golem memberi basis Free CC0 | Budget belum diotorisasi, Frost exact rig belum diketahui, material/spike/core edit belum dikerjakan; LOWPO legal conflict belum selesai; Joseph George membutuhkan reproportion/rig/format conversion HIGH. |
| N11 | Exact native smash/slam/slash/run/death labels + exact Mixamo sweep/run/roar/death preview | Tidak ada boss rig/clip yang diuji; native wake dan charge anticipation/brake belum ada sebagai clip siap pakai; sweep horizontal bare-arm belum terbukti. Custom authoring agent tetap pekerjaan nyata, bukan coverage yang sudah terpenuhi. |

**Urutan pembuktian ketika tahap pengadaan diotorisasi:** periksa source license/tier dan exact skeleton → nilai satu motion minum pada pemain → bandingkan Frost/stone material/core attachment → nilai native slash/smash/run/death pada rig boss → tentukan clip yang cukup diedit versus authoring baru. Tidak membeli bundle, tidak memulai login/pembelian, dan tidak memindahkan pekerjaan modelling manual kepada pengguna sebagai syarat riset ini dianggap selesai.
