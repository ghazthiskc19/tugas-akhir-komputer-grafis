# Mixamo animations — local files, not included in Git

Lima motion berikut diekspor lokal pada 20 November 2026 dari [Mixamo](https://www.mixamo.com/) memakai akun Adobe anggota tim. Format FBX binary 2019, tanpa skin, 30 fps, tanpa keyframe reduction. Karakter ekspor: karakter primary akun (**Mutant**). Repository dikonfirmasi **public** pada 21 November 2026; file FBX dan sidecar import-nya diabaikan Git sehingga tidak tersedia dari clone.

| File | Motion Mixamo | Dipakai untuk |
|---|---|---|
| `Drinking.fbx` | Drinking — Male Drinking | Pemain minum potion (perlu retarget ke rig KayKit) |
| `Mutant_Swiping.fbx` | Mutant Swiping — Attacking With Left Hand | Sapuan lengan boss |
| `Mutant_Run.fbx` | Mutant Run — Running, **in place** | Terjangan boss; perpindahan diatur controller |
| `Mutant_Roaring.fbx` | Mutant Roaring | Bahan animasi bangun boss |
| `Mutant_Dying.fbx` | Mutant Dying — Falling Onto Back | Kematian boss |

**Pengadaan anggota tim:** login sendiri ke Mixamo, cari motion sesuai nama/deskripsi di atas, lalu simpan di folder ini. File lokal pemilik project belum di-retarget ke KayKit/golem; mengunduhnya tidak langsung membuat animasi siap gameplay. Tidak ada scene gameplay saat ini yang bergantung pada file lokal tersebut.

**Lisensi:** Adobe Mixamo terms, bukan CC0; lihat [FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) dan [penjelasan distribusi Adobe](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400). Jangan memasukkan FBX mentah atau asset animasi reusable ke repo publik. Credit tidak menggantikan izin distribusi. Kebijakan akses kolaborator proyek privat tidak mengubah larangan distribusi publik. Folder ini membagikan instruksi, bukan motion.
