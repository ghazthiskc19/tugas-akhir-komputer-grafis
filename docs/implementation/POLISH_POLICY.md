# Polish policy — Pulau 1 jadi standar untuk pulau berikutnya

Dokumen ini mendefinisikan kapan sebuah area dianggap "dipoles". Pulau 2/3 baru dimulai setelah Pulau 1 memenuhi semua baris di bawah (atau baris yang belum terpenuhi ditulis sebagai batas yang diketahui). Pulau berikutnya wajib mengikuti aturan yang sama.

## Prinsip
1. **Setiap aksi pemain/musuh punya umpan balik yang terlihat, terdengar, dan terasa** (gerak kamera/waktu), bukan hanya angka HP.
2. **Efek harus terbaca, bukan sekadar ada.** Tidak menutupi telegraph serangan musuh.
3. **Semua intensitas bisa diatur** (guncangan kamera, volume) dan punya nilai awal yang nyaman.
4. **Tidak mengubah balance** (HP, damage, timing) kecuali diminta; polish = presentasi.
5. **Bukti nyata:** tiap perubahan diuji di jendela render (screenshot/rekaman) dan regresi relevan, bukan klaim.
6. **Navigasi dan puzzle jelas:** landmark/rute keluar terbaca; petunjuk relasional dapat ditemukan dan dipahami, puzzle memberi umpan balik progres tanpa menyamarkan solusi.
7. **Gate performa:** ukur frame time dan draw call pada resolusi/mesin acuan setelah batch; angka lama bukan bukti performa batch baru.

## Standar umpan balik combat
| Kejadian | Visual | Kamera / waktu | Audio |
|---|---|---|---|
| Pukulan combo kena | percikan + flash musuh | guncangan ringan, hit-stop pendek | impact berlapis |
| Finisher kena | percikan besar + ring | guncangan sedang, hit-stop lebih panjang | impact berat |
| Musuh kena (reaksi) | flash putih singkat + flinch terlihat | — | grunt/impact |
| Blok berhasil | percikan baja + ring | guncangan kecil | clang |
| Guard pecah | efek berbeda dari blok | guncangan kuat | suara pecah |
| Pemain kena | vignette merah singkat + flash | guncangan kuat | hurt |
| Dodge | jejak/debu | — | whoosh |
| Slam boss / heavy | ground impact + debu | guncangan jauh-dekat | boom |
| Musuh mati | poof | guncangan ringan | death |

Catatan komitmen serangan: musuh standar dan ranged tidak ter-stagger oleh pukulan non-fatal selama seluruh rantai serangan (windup, active, jeda antar-hit, recovery); flash/flinch, suara, dan damage HP tetap berlaku, kematian tetap membatalkan serangan. Heavy tidak berubah (windup/active kebal, recovery tetap ter-stagger).

## Standar area (per pulau)
- **Visual dunia:** pencahayaan konsisten, tidak ada objek melayang/tembus, landmark terbaca dari jauh, tiap biome punya identitas. Fog membantu menyatukan horizon dan jarak tanpa mengaburkan rute, landmark, telegraph, atau clue.
- **Navigasi/puzzle:** arah ke objektif dan jalur keluar dapat ditemukan; clue puzzle terbaca dari sudut pandang normal; indikator progres menjelaskan apa yang sudah terhubung/aktif.
- **Shortcut:** akses lintas cabang harus punya syarat objektif yang terlihat dan pulih dari progres save; jalan pulang tidak boleh menjebak pemain. Bukan kewajiban membunuh semua penjaga.
- **Vegetasi:** pohon dekat pemain selalu terlihat; jangan memakai visibility range pada pusat satu MultiMesh se-pulau untuk menghilangkan tiap pohon. Kanopi tambahan harus mengikuti transform asset dan tidak menghalangi telegraph.
- **Encounter:** tingkatkan tekanan lewat komposisi dan posisi, bukan buff HP/damage. Pack pembuka mengajarkan melee; pack campuran punya maksimal satu ranged dan cover yang benar-benar memutus tembakan. Jarak aggro/leash harus memberi ruang mundur tanpa otomatis menarik pack berikutnya; formasi mengikuti arah rute.
- **Audio:** musik per konteks, mixer seimbang, tidak ada klik/pop saat transisi.
- **UI:** semua layar terbaca di 1280×720, tidak ada teks terpotong/tumpang tindih.
- **Performa:** target median frame ≤ 16,7 ms di 1280×720; baseline historis Pulau 1 16,65 ms dan 584 draw call. Gate perf untuk batch saat ini belum diukur; jangan menganggap baseline lama sebagai hasil baru.
- **Aksesibilitas:** pengaturan intensitas guncangan; efek flash tidak berkedip cepat berulang.

## Bukti wajib sebelum "selesai"
Screenshot render per area, regresi combat/boss/enemy/shutdown, playthrough input penuh, dan catatan batas yang belum diuji manusia (rasa, audio subjektif, mesin lain).
