"""Visual A4 project report, authored as positioned graphics rather than a word processor.

Requires PyMuPDF. All gameplay descriptions are design specifications, not completion claims.
"""
from pathlib import Path
import json
import math
import sys
import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'docs/laporan/assets'
OUT = ROOT / 'output/pdf/the-lost-island-laporan-proyek.pdf'
BACKGROUND_ONLY = '--background-only' in sys.argv
if BACKGROUND_ONLY:
    OUT = ROOT / 'tmp/pdfs/background-only.pdf'
META = json.loads((ROOT / 'docs/laporan/identitas.json').read_text(encoding='utf-8'))
W, H = 595.276, 841.89

def rgb(value):
    return tuple(int(value[i:i+2], 16)/255 for i in (0, 2, 4))

CREAM=rgb('F7F3E9'); INK=rgb('20343D'); TEAL=rgb('317B77')
SAGE=rgb('B7CDBD'); PALE=rgb('E4EBDF'); CORAL=rgb('E28F6F')
MUTED=rgb('586B6D'); WHITE=rgb('FFFEF8'); LINE=rgb('CBD6C9')
FONTS = {
    'body': fitz.Font(fontfile='C:/Windows/Fonts/arial.ttf'),
    'bold': fitz.Font(fontfile='C:/Windows/Fonts/arialbd.ttf'),
    'title': fitz.Font(fontfile='C:/Windows/Fonts/bahnschrift.ttf'),
    'serif': fitz.Font(fontfile='C:/Windows/Fonts/georgia.ttf'),
}
FONT_FILES = {'body':'arial.ttf', 'bold':'arialbd.ttf', 'title':'bahnschrift.ttf', 'serif':'georgia.ttf'}
doc=fitz.open()
text_blocks=[]

class Page:
    def __init__(self, section, dark=False, frame=False):
        self.p=doc.new_page(width=W,height=H)
        self.dark=dark
        self.fg=CREAM if dark else INK
        self.muted=SAGE if dark else MUTED
        self.rect(0,0,W,H, INK if dark else CREAM)
        for name, file in FONT_FILES.items():
            self.p.insert_font(fontname=name, fontfile='C:/Windows/Fonts/'+file)
        if frame:
            self.rect(19,19,W-38,H-38,None,SAGE,.7)
            self.line(19,43,43,19,SAGE,1)
            self.line(W-43,H-19,W-19,H-43,SAGE,1)
        self.text(34,H-32,430,'THE LOST ISLAND  /  '+section.upper(),7.3,'bold',self.muted)
        self.text(W-55,H-34,25,f'{len(doc):02}',9,'bold',CORAL)

    def rect(self,x,y,w,h,fill=None,stroke=None,width=1):
        self.p.draw_rect(fitz.Rect(x,y,x+w,y+h),color=stroke,fill=fill,width=width)

    def line(self,x1,y1,x2,y2,color=TEAL,width=1):
        self.p.draw_line((x1,y1),(x2,y2),color=color,width=width)

    def poly(self,points,fill,stroke=None,width=1):
        shape=self.p.new_shape()
        shape.draw_polyline(points+[points[0]])
        shape.finish(color=stroke,fill=fill,width=width,closePath=True)
        shape.commit()

    def circle(self,x,y,r,fill=None,stroke=None,width=1):
        self.p.draw_circle((x,y),r,color=stroke,fill=fill,width=width)

    def text(self,x,y,w,txt,size=11,font='body',color=None,leading=1.4):
        color=self.fg if color is None else color
        f=FONTS[font]
        lines=[]
        for para in str(txt).split('\n'):
            if not para:
                lines.append(''); continue
            line=''
            for word in para.split():
                candidate=(line+' '+word).strip()
                if f.text_length(candidate,fontsize=size)>w and line:
                    lines.append(line); line=word
                else:
                    line=candidate
            lines.append(line)
        for i,line in enumerate(lines):
            if f.text_length(line,fontsize=size)>w+.5:
                raise ValueError(f'Text too wide, page {len(doc)}: {line}')
            if not BACKGROUND_ONLY:
                self.p.insert_text((x,y+size+i*size*leading),line,fontname=font,fontsize=size,color=color)
        end=y+size+(len(lines)-1)*size*leading+size*.25
        if x<0 or x+w>W+.1 or y<0 or end>H-42:
            # Footer itself occupies the otherwise reserved last 42 points.
            if y<H-40:
                raise ValueError(f'Text outside content area, page {len(doc)}: {txt[:70]} / {end}')
        text_blocks.append({'page':len(doc),'rect':[x,y,x+w,end],'text':str(txt),'lines':lines,'size':size,'font':font,'color':color,'leading':leading})
        return end

    def image(self,name,x,y,w,h):
        self.p.insert_image(fitz.Rect(x,y,x+w,y+h),filename=str(ASSETS/name),keep_proportion=True)

    def kicker(self,txt,x=38,y=40):
        return self.text(x,y,510,txt.upper(),9,'bold',SAGE if self.dark else TEAL,1.2)

    def title(self,txt,x=38,y=65,w=515,size=38,font='title'):
        return self.text(x,y,w,txt,size,font,self.fg,1.08)

    def bullet(self,x,y,w,txt,size=11,color=None):
        self.rect(x,y+5,4,4,CORAL)
        return self.text(x+15,y,w-15,txt,size,'body',color)+10

    def card(self,x,y,w,h,label,txt,fill=PALE,size=11):
        self.rect(x,y,w,h,fill)
        self.text(x+16,y+15,w-32,label,12,'bold',TEAL)
        return self.text(x+16,y+42,w-32,txt,size,'body',INK)

    def tag(self,x,y,w,txt,fill=TEAL,color=WHITE):
        self.rect(x,y,w,20,fill)
        self.text(x+7,y+4,w-14,txt,7.7,'bold',color,1.1)

def tree(p,x,y,s=1):
    p.line(x,y,x,y+20*s,TEAL,2*s)
    p.poly([(x,y-10*s),(x-12*s,y+12*s),(x+12*s,y+12*s)],TEAL)
    p.poly([(x,y-19*s),(x-9*s,y+1*s),(x+9*s,y+1*s)],SAGE)

def diamond(p,x,y,r=12,color=TEAL):
    p.poly([(x,y-r),(x+r*.72,y),(x,y+r),(x-r*.72,y)],color)
    p.line(x,y-r,x,y+r,WHITE,.6)

def arrow(p,x1,y1,x2,y2,color=TEAL,width=1.5):
    p.line(x1,y1,x2,y2,color,width)
    a=math.atan2(y2-y1,x2-x1)
    p.poly([(x2,y2),(x2-7*math.cos(a-.5),y2-7*math.sin(a-.5)),(x2-7*math.cos(a+.5),y2-7*math.sin(a+.5))],color)

# 01 - Cover: landscape art, large title, two-column identity block.
p=Page('Dokumen proyek',frame=True)
p.image('island-concept.jpg',25,25,545,307)
p.tag(415,39,137,'ILUSTRASI KONSEP',CREAM,INK)
p.kicker('Komputer Grafis / Dokumen proyek gim',38,350)
p.title('THE LOST\nISLAND',38,376,350,48)
p.image('the-lost-island-logo.png',365,376,190,110)
p.line(38,505,557,505,SAGE,1)
p.text(38,524,205,META['nama_tim'],14,'bold',TEAL)
p.text(38,558,205,'Dosen pengampu',8.7,'bold',MUTED)
p.text(38,574,205,META['dosen'],10)
p.text(38,609,205,'Tahun ajaran',8.7,'bold',MUTED)
p.text(38,625,205,META['tahun_ajaran'],10)
p.text(274,524,283,'ANGGOTA TIM',9,'bold',TEAL)
y=550
for name,nim in META['anggota']:
    p.text(274,y,283,name,9.7,'bold')
    p.text(274,y+16,283,nim,9.5,'body',MUTED)
    y+=47
p.image('logo-filkom.png',38,700,205,52)
p.text(274,755,280,'Fakultas Ilmu Komputer\nUniversitas Brawijaya',9.5,'body',MUTED)

# 02 - AI disclaimer: editorial column and separate tool ledger.
p=Page('Disclaimer penggunaan AI',frame=True)
p.kicker('Pernyataan penggunaan alat')
p.title('Disclaimer\npenggunaan AI',y=72,size=39)
p.text(38,177,468,'Proyek ini menggunakan AI dalam perencanaan, persiapan development, dan penyusunan materi visual. Kontribusi setiap alat dicatat sesuai pekerjaan yang telah dilakukan.',12)
p.rect(38,272,313,449,WHITE)
y=294
for title,body in [
    ('Perencanaan dan dokumen','ChatGPT membantu brainstorming konsep, membahas alternatif desain, dan menyusun draft dokumen. Codex membantu konsolidasi spesifikasi dan penyusunan laporan visual.'),
    ('Persiapan development','Codex membantu setup project, migrasi dari Unity ke Godot, konfigurasi MCP, serta pengelolaan repository Git. Sistem gameplay yang dijelaskan masih merupakan rancangan.'),
    ('Visual berbantuan AI','Canva AI digunakan pada draft visual awal. Imagegen digunakan untuk menghasilkan logo gim dan ilustrasi pulau pada laporan ini. Ilustrasi bukan screenshot gameplay.'),
]:
    y=p.text(55,y,278,title,12,'bold',TEAL)+9
    y=p.text(55,y,278,body,10.8)+21
p.rect(372,272,185,449,TEAL)
p.text(389,293,151,'Tanggung jawab tim',17,'title',WHITE)
p.text(389,357,151,'Tim bertanggung jawab atas keputusan desain, pemahaman kode, pemeriksaan hasil, pengujian, serta materi yang dikumpulkan.',11,'body',WHITE)
p.text(389,508,151,'Sumber dan lisensi',13,'bold',WHITE)
p.text(389,544,151,'Asset pihak ketiga dicatat sesuai penggunaan aktual. Hasil AI harus diperiksa dan disesuaikan sebelum dipakai dalam produk akhir.',10.8,'body',WHITE)
p.text(38,747,510,'Logo FILKOM disediakan oleh anggota tim. Rincian asset dan teknologi tercantum pada halaman sumber.',9,'body',MUTED)

# 03 - Overview: logo on a field, compact product attributes, three pillars.
p=Page('Gambaran game')
p.kicker('Game overview')
p.title('Petualangan\ndi pulau kuno',size=38)
p.image('the-lost-island-logo.png',305,167,250,151)
p.text(38,183,242,'Petualangan 3D single-player tentang awak kapal yang terdampar, tiga artefak kuno, dan golem yang menjaga gerbang menuju dermaga.',13,'serif',INK,1.5)
for x,label,value in [(38,'PLATFORM','PC'),(214,'MODE','Single-player'),(390,'KONEKSI','Fully offline')]:
    p.rect(x,354,167,69,PALE)
    p.text(x+13,366,140,label,8,'bold',TEAL)
    p.text(x+13,385,140,value,15,'title')
p.text(38,458,515,'Pilar desain',23,'title')
for i,(title,body) in enumerate([
    ('Eksplorasi terarah','Landmark, percabangan jalur, dan shortcut membantu pemain menemukan objektif dengan urutan fleksibel.'),
    ('Tantangan yang terbaca','Puzzle memakai petunjuk visual; musuh dan boss memiliki telegraph sebelum serangan.'),
    ('Dunia stylized','Pulau low-poly dengan elevasi moderat dan tiga biome menjadi ruang eksplorasi Level 1.'),
]):
    y=506+i*76
    p.text(38,y,42,f'0{i+1}',23,'title',CORAL)
    p.text(93,y,454,title,13,'bold',TEAL)
    p.text(93,y+24,454,body,10.8)
p.text(38,752,515,'Target pengalaman: pemain yang menikmati eksplorasi, puzzle ringan, dan pertarungan melee.',9.3,'body',MUTED)

# 04 - Narrative: dark opening, large prose, panoramic art, story beats.
p=Page('Cerita dan dunia',dark=True)
p.kicker('Story / Level 1')
p.title('Pulau penjagaan\nyang terlupakan',size=37,font='serif')
p.text(38,189,510,'Setelah badai merusak kapalnya, seorang awak terdampar di bekas pulau penjagaan jalur pelayaran. Sebuah dermaga terlindung berada di sisi lain pulau, tetapi jalan menuju ke sana tertutup gerbang kuno.',12.5,'body',CREAM,1.5)
p.image('island-concept.jpg',38,300,519,292)
p.tag(390,565,151,'ILUSTRASI KONSEP',CREAM,INK)
p.text(38,626,242,'Tiga kunci energi',15,'bold',SAGE)
p.text(38,656,242,'Artefak tersebar di reruntuhan, instalasi energi, dan menara pengamatan. Ketiganya mengaktifkan kembali sistem gerbang.',10.7,'body',CREAM)
p.text(314,626,243,'Penjaga yang terbangun',15,'bold',SAGE)
p.text(314,656,243,'Golem masih menolak penyusup sesuai perintah lama. Pemain harus mengalahkannya untuk mencapai dermaga.',10.7,'body',CREAM)
p.text(38,759,519,'Penyampaian: pembukaan singkat, relief lingkungan, dan penutup; tanpa kebutuhan dialog panjang.',8.7,'body',SAGE)

# 05 - Core loop: parallel objectives rather than a forced sequence.
p=Page('Core loop',frame=True)
p.kicker('Gameplay flow')
p.title('Progres artefak\ndan gerbang akhir',size=39)
p.text(38,179,510,'Pemain membaca lingkungan, memilih tujuan, menyelesaikan tantangan, lalu kembali ke jalur utama. Ketiga artefak diperlukan untuk memulai pertarungan akhir.',12)
p.circle(298,294,29,TEAL)
p.text(274,283,55,'MULAI',9,'bold',WHITE)
for x,title,body in [
    (38,'Pilar Simbol','Grassland\nPuzzle urutan simbol'),
    (216,'Jalur Energi','Forest\nPuzzle sambungan energi'),
    (394,'Menuju Puncak','Rocky Highlands\nTraversal dan penjaga'),
]:
    arrow(p,298,327,x+80,376,SAGE)
    p.card(x,382,163,125,title,body,size=10.6)
    diamond(p,x+81,534,13,CORAL)
    p.line(x+81,554,x+81,581,SAGE,1.5)
p.line(119,581,475,581,SAGE,1.5)
arrow(p,298,581,298,616,TEAL)
p.rect(139,622,318,45,TEAL)
p.text(156,634,285,'Pasang artefak dan bangunkan penjaga',11,'bold',WHITE)
arrow(p,298,668,298,697,TEAL)
p.text(137,705,325,'Kalahkan boss, lewati gerbang',16,'title',TEAL)
p.text(137,736,325,'Level 1 selesai setelah pemain menuju dermaga.',10.5)

# 06 - Conceptual map: no claim of an implemented playable level.
p=Page('Dunia dan level design')
p.kicker('World / Baseline blockout')
p.title('Pulau dan\ntiga biome',size=41)
p.tag(392,68,165,'BASELINE 250 × 250 M')
p.rect(38,185,519,367,rgb('DCEBE6'))
island=[(85,437),(68,359),(117,281),(191,253),(235,218),(334,229),(395,271),(470,293),(512,372),(478,466),(372,511),(252,495),(153,510)]
p.poly(island,SAGE)
p.poly([(85,437),(130,349),(253,335),(333,393),(372,511),(252,495),(153,510)],rgb('D6D4A9'))
p.poly([(117,281),(191,253),(248,296),(253,335),(130,349)],rgb('6F9D7C'))
p.poly([(235,218),(334,229),(395,271),(352,345),(248,296)],rgb('98A49A'))
for x,y in [(134,288),(164,301),(193,282),(205,316),(160,330)]: tree(p,x,y,.7)
for x,y in [(274,253),(310,270),(341,249)]:
    p.poly([(x,y-18),(x-18,y+18),(x+18,y+18)],rgb('788B86'))
route=[(179,454),(210,394),(284,373),(349,332),(391,388),(438,433)]
for a,b in zip(route,route[1:]):p.line(*a,*b,CREAM,5)
for x,y in [(179,454),(284,373),(438,433)]:p.circle(x,y,6,CORAL)
diamond(p,178,306,11,CORAL); diamond(p,314,270,11,CORAL); diamond(p,249,442,11,CORAL)
p.tag(81,370,104,'FOREST',TEAL)
p.tag(302,205,176,'ROCKY HIGHLANDS',INK)
p.tag(176,479,119,'GRASSLAND',TEAL)
p.text(57,523,483,'Skema hubungan area; posisi, proporsi biome, dan jalur belum merupakan map final.',8,'body',MUTED)
p.card(38,578,249,126,'Orientasi','Grassland mengenalkan kontrol. Forest dan Rocky Highlands bercabang dari jalur penghubung. Gerbang menjadi landmark.',size=10.7)
p.card(307,578,250,126,'Perjalanan kembali','Shortcut mengurangi pengulangan rute. Lokasi objektif dan ruang traversal dipertahankan valid pada setiap seed.',size=10.7)
p.text(38,733,519,'Durasi boleh lebih panjang dari usulan 15–20 menit. Target akhir ditentukan melalui playtest, bukan luas map saja.',10.3,'body',MUTED)

# 07 - Camera: geometric explanation with two mouse modes.
p=Page('Kamera dan input')
p.kicker('Perspective / Elevated follow')
p.title('Kamera mengikuti\nperjalanan pemain',size=36)
p.rect(38,180,519,247,PALE)
p.line(67,383,529,383,SAGE,2)
p.circle(359,322,14,TEAL);p.line(359,336,359,374,TEAL,5)
p.line(359,351,340,366,TEAL,3);p.line(359,351,378,366,TEAL,3)
p.rect(100,236,48,32,INK);p.poly([(148,241),(168,232),(168,272),(148,263)],INK)
p.line(163,252,358,336,CORAL,1.5)
p.line(163,252,464,375,SAGE,1)
p.line(163,252,297,375,SAGE,1)
p.text(64,198,190,'Perspective camera',10,'bold',TEAL)
p.text(377,302,151,'Karakter',10,'bold',TEAL)
p.text(67,393,460,'Skema posisi kamera; jarak, FOV, dan sudut ditentukan lewat prototype.',8.5,'body',MUTED)
p.card(38,455,249,134,'Mouse bebas','Posisi mouse di dunia menentukan arah serangan. Kamera tidak otomatis mengikuti arah karakter menyerang.',size=11)
p.card(307,455,250,134,'Tahan tombol tengah','Mouse mengatur orbit 360° horizontal. Orbit vertikal dibatasi. Lepaskan tombol untuk kembali aiming.',size=11)
y=620
for txt in ['Smooth damping mengikuti movement dan lompatan tanpa hentakan.',
            'Camera collision mendekatkan kamera ketika terhalang, lalu kembali secara mulus.',
            'Analog kanan mengatur orbit; mapping gamepad lainnya belum dirinci.']:
    y=p.bullet(38,y,519,txt,10.8)
p.text(38,757,519,'Keterbacaan puzzle, lompatan, dan telegraph boss menjadi kriteria framing.',9,'body',MUTED)

# 08 - Symbol puzzle: four distinct glyphs and an always-visible clue.
p=Page('Puzzle / Pilar Simbol',frame=True)
p.kicker('Artefak / Grassland')
p.title('Pilar Simbol',size=46)
p.text(38,131,510,'Baca relief, lalu aktifkan empat pilar dalam urutan yang ditunjukkan.',14,'serif')
p.rect(38,200,519,232,PALE)
for i,x in enumerate([104,233,362,491]):
    p.rect(x-36,287,72,106,rgb('A8B9A7'))
    p.rect(x-41,277,82,20,rgb('8DA69A'))
    if i==0:p.poly([(x,226),(x-15,254),(x+15,254)],TEAL)
    elif i==1:p.circle(x,242,14,None,TEAL,3)
    elif i==2:diamond(p,x,242,18,TEAL)
    else:
        p.line(x-14,242,x+14,242,TEAL,4);p.line(x,228,x,256,TEAL,4)
    p.text(x-5,330,16,str(i+1),13,'bold',CREAM)
p.text(57,406,480,'Skema mekanik; bentuk simbol dan urutan contoh belum menjadi pilihan visual final.',8.2,'body',MUTED)
y=470
for txt in [
    'Relief urutan tetap terlihat selama puzzle dikerjakan.',
    'Pemain mendekati pilar lalu berinteraksi. Cahaya dan audio pendek memberi feedback.',
    'Urutan benar membuka segel artefak. Urutan salah mereset rangkaian tanpa damage atau kehilangan item.',
    'Simbol dapat dibedakan melalui bentuk; warna hanya membantu keterbacaan.',
    'Musuh tidak mengganggu puzzle pertama. Status selesai bertahan setelah respawn selama sesi.'
]: y=p.bullet(38,y,519,txt,11)
p.tag(38,745,226,'MODUL TERKONTROL, SOLUSI VALID')

# 09 - Energy puzzle: connected panels with readable engraving.
p=Page('Puzzle / Jalur Energi')
p.kicker('Artefak / Forest')
p.title('Jalur Energi',size=46)
p.text(38,133,510,'Putar tiga panel batu untuk menyambungkan kristal sumber ke altar artefak.',14,'serif')
p.rect(38,204,519,220,TEAL)
diamond(p,77,307,18,CREAM)
for x in [178,298,418]:
    p.rect(x-38,267,76,76,PALE)
    p.line(x-38,305,x+38,305,INK,12)
    p.line(x-38,305,x+38,305,CORAL,5)
    p.text(x-19,356,58,'90°',16,'bold',WHITE)
for x1,x2 in [(94,140),(216,260),(336,380),(456,500)]:arrow(p,x1,305,x2,305,CORAL,3)
p.rect(500,281,30,49,SAGE)
p.text(55,220,468,'SUMBER',8,'bold',CREAM)
p.text(475,220,65,'ALTAR',8,'bold',CREAM)
p.text(55,393,480,'Skema kondisi tersambung; layout dan orientasi awal akan dirinci saat produksi.',8.2,'body',WHITE)
p.card(38,461,249,138,'Interaksi','Setiap interaksi memutar panel 90°. Panel menggunakan ukiran jalur lurus atau siku. Energi mengikuti sambungan dari sumber.',size=10.9)
p.card(307,461,250,138,'Solusi','Hubungan lengkap ke altar membuka segel artefak. Cahaya, ukiran, arah aliran, dan audio membantu membaca sambungan.',size=10.9)
y=633
for txt in ['Tanpa timer, damage, atau batas percobaan.',
            'Status selesai bertahan setelah respawn selama sesi.',
            'Sistem menggunakan konektivitas jalur, bukan simulasi cahaya fisik.']:
    y=p.bullet(38,y,519,txt,11)
p.text(38,757,519,'Generator menempatkan modul puzzle pada lokasi yang dapat diakses dan tetap dapat diselesaikan.',9,'body',MUTED)

# 10 - Ascent: vertical expedition itinerary with an optional fight route.
p=Page('Exploration challenge',frame=True)
p.kicker('Artefak / Rocky Highlands')
p.title('Jalur Menuju\nPuncak',size=43)
p.text(38,178,510,'Cari rute naik, lewati penjaga, lalu capai altar di reruntuhan dataran tinggi.',12.5)
p.line(65,263,65,632,SAGE,3)
for i,(title,body) in enumerate([
    ('Kaki bukit','Checkpoint sebelum pendakian. Satu musuh melee menjaga area combat yang cukup luas.'),
    ('Jalur tebing','Jalur berkelok dengan satu atau dua lompatan pendek. Area lompatan memberi ruang membaca jarak.'),
    ('Pelataran penjaga','Satu melee dan satu ranged. Batu menjadi perlindungan, dengan jalur pendekatan dari samping.'),
    ('Altar puncak','Ambil artefak, nikmati viewpoint, dan aktifkan jembatan shortcut dari sisi puncak.'),
]):
    y=252+i*108
    p.circle(65,y+13,15,TEAL)
    p.text(61,y+5,20,str(i+1),11,'bold',WHITE)
    p.text(99,y,448,title,17,'title',TEAL)
    p.text(99,y+30,445,body,11)
p.rect(38,709,519,66,INK)
p.text(54,721,487,'Pemain boleh melawan atau melewati musuh. Artefak tidak mensyaratkan semua penjaga dikalahkan. Musuh rute yang sudah kalah tetap mati selama sesi.',10.6,'body',CREAM)

# 11 - Combat: strong graphic and resource economy on a dark field.
p=Page('Combat pemain',dark=True)
p.kicker('Melee / Mouse-world aiming')
p.title('Sistem combat\nmelee',size=43)
for i,(x,label,sub) in enumerate([(38,'01','Hit cepat'),(216,'02','Hit cepat'),(394,'03','Finisher')]):
    p.rect(x,214,163,140,TEAL if i<2 else CORAL)
    p.text(x+17,227,130,label,44,'title',CREAM if i<2 else INK)
    p.text(x+17,300,130,sub,14,'bold',CREAM if i<2 else INK)
p.text(38,387,519,'Satu tombol attack mengatur combo tiga hit. Input berikutnya harus masuk pada timing window; early input tidak disimpan dan menahan tombol tidak menjalankan combo otomatis.',12,'body',CREAM)
y=489
for txt in [
    'Animasi attack yang sudah dimulai diselesaikan sebelum block atau dodge.',
    'Pemain tetap dapat bergerak dengan kecepatan berkurang saat menyerang.',
    'Arah dikunci selama satu hit. Aiming dibaca kembali saat hit berikutnya dimulai.',
    'Attack dan combo tidak menghabiskan stamina.'
]:y=p.bullet(38,y,519,txt,11.4,CREAM)
p.line(38,710,557,710,TEAL,1)
p.text(38,733,519,'Timing window, hitbox, damage, dan recovery disusun sebagai baseline lalu diuji melalui prototype.',10,'body',SAGE)

# 12 - Enemy comparison: three roles, three distinct weapon symbols.
p=Page('Musuh biasa')
p.kicker('Encounter / Tiga tipe')
p.title('Musuh dan\nperan encounter',size=42)
rows=[('01','Melee biasa','Mendekat dan melakukan satu swing singkat. Recovery pendek memberi tekanan jarak dekat.'),
      ('02','Heavy melee','Bergerak lebih lambat, mengangkat senjata sebelum hantaman kuat, lalu recovery panjang.'),
      ('03','Ranged','Menembakkan proyektil lurus setelah persiapan yang terbaca. Pemain dapat menghindar atau memakai perlindungan.')]
for i,(n,title,body) in enumerate(rows):
    y=224+i*153
    p.rect(38,y,519,132,PALE if i!=1 else rgb('EAE0CE'))
    p.circle(99,y+63,40,TEAL if i!=1 else INK)
    if i==0:
        p.line(82,y+84,116,y+40,CREAM,5);p.line(80,y+63,103,y+80,CORAL,4)
    elif i==1:
        p.line(90,y+88,109,y+43,CREAM,6);p.rect(91,y+35,37,18,CORAL)
    else:
        p.line(82,y+76,116,y+47,CREAM,3);arrow(p,84,y+51,119,y+77,CORAL,2)
    p.text(162,y+18,371,n+'  '+title,19,'title',TEAL)
    p.text(162,y+54,371,body,11.3)
p.text(38,714,519,'Rancangan awal tidak memakai proyektil homing atau combo heavy yang panjang. Detection, chase/leash, stagger, dan distribusi encounter dirinci saat prototype.',10.8,'body',MUTED)
p.text(38,765,519,'Simbol senjata menunjukkan peran; penampilan karakter dan jenis senjata spesifik belum final.',8.6,'body',MUTED)

# 13 - Defense, potion and retry: distinct general and boss rules.
p=Page('Resource dan retry')
p.kicker('HP / Stamina / Potion')
p.title('Resource dan\nkesempatan mencoba lagi.',size=35)
p.card(38,182,249,157,'Block dan dodge','Keduanya memakai satu pool stamina. Block mengurangi damage dari semua arah dan menguras stamina selama ditahan. Dodge memakai biaya tetap dan memberi i-frames singkat.',size=10.7)
p.card(307,182,250,157,'Regenerasi','Stamina pulih setelah jeda singkat sejak block atau dodge berhenti. Jika stamina kurang, defense ditolak; movement dan attack tetap tersedia.',size=10.7)
p.text(38,372,519,'Potion dipakai setelah animasi selesai',22,'title',TEAL)
p.text(38,414,519,'Saat minum, pemain berjalan lebih lambat dan tidak dapat menyerang. Terkena serangan membatalkan animasi. HP baru pulih dan potion baru berkurang setelah animasi selesai; pembatalan tidak menghabiskan item.',11.6)
p.line(38,504,557,504,SAGE,1)
p.text(38,528,249,'Respawn eksplorasi',16,'bold',TEAL)
p.text(38,565,249,'HP kembali penuh di checkpoint. Healing terpakai tidak dikembalikan. Artefak dan puzzle selesai tetap tercatat selama sesi.',11)
p.text(307,528,250,'Retry boss: snapshot',16,'bold',TEAL)
p.text(307,565,250,'HP, stamina, dan jumlah potion kembali ke kondisi sebelum pertarungan pertama. Boss direset; progres pulau tetap tersimpan.',11)
p.rect(38,673,519,70,INK)
p.text(54,685,487,'Contoh jumlah item: masuk boss dengan 5 potion, memakai 3 lalu mati, retry kembali membawa 5. Setelah menang, resource yang tersisa dipertahankan.',10.8,'body',CREAM)
p.text(38,758,519,'Angka pada contoh bukan kapasitas inventory final. Snapshot tidak menggandakan potion.',8.8,'body',MUTED)

# 14 - Boss: telegraph panels and phase bar.
p=Page('Boss / Penjaga Gerbang',frame=True)
p.kicker('Pertarungan akhir Level 1')
p.title('Penjaga Gerbang',size=40)
p.text(38,131,519,'Golem batu dengan inti energi. Aktif setelah tiga artefak dipasang dan pemain memulai pertarungan.',12.5)
for i,(x,title,body) in enumerate([
    (38,'Sapuan lengan','Lengan ditarik ke belakang. Pemain mundur atau dodge keluar jangkauan.'),
    (216,'Hantaman tanah','Kedua tangan diangkat. Lingkaran tanah menandai area damage.'),
    (394,'Terjangan lurus','Badan direndahkan. Garis menandai arah terjangan sebelum target dikunci.'),
]):
    p.rect(x,214,163,268,PALE)
    cx=x+81
    if i==0:
        p.circle(cx,269,32,None,TEAL,2);p.poly([(cx,269),(cx-34,300),(cx+34,300)],CORAL)
    elif i==1:
        p.circle(cx,275,35,None,TEAL,2);p.circle(cx,275,20,CORAL)
    else:
        p.rect(cx-15,242,30,67,SAGE);arrow(p,cx,303,cx,247,CORAL,4)
    p.text(x+13,330,137,title,13,'bold',TEAL)
    p.text(x+13,375,137,body,10.5)
p.text(38,516,519,'Dua fase, telegraph tetap terbaca',22,'title',TEAL)
p.rect(38,561,519,13,TEAL);p.rect(298,561,259,13,CORAL)
p.text(38,591,244,'HP di atas 50%',13,'bold',TEAL)
p.text(38,620,244,'Satu serangan lalu recovery. Pemain mempelajari tanda dan celah serangan.',11)
p.text(313,591,244,'HP 50% atau kurang',13,'bold',TEAL)
p.text(313,620,244,'Sesekali dua serangan berurutan sebelum recovery panjang. Timing dasar dipertahankan.',11)
p.text(38,698,519,'Recovery hantaman memungkinkan combo tiga hit dengan posisi dan timing yang sesuai. Arena rata, tanpa musuh tambahan; semua serangan mengikuti aturan block dan i-frames.',11)
p.text(38,764,519,'Setelah menang, gerbang terbuka. Pemain melewatinya untuk menyelesaikan Level 1.',9,'body',MUTED)

# 15 - Art, HUD and audio: varied moodboard-style blocks.
p=Page('Visual audio dan interface')
p.kicker('Art direction / UX')
p.title('Arah visual,\naudio, dan UI',size=41)
p.image('island-concept.jpg',38,177,320,180)
p.tag(193,329,150,'ILUSTRASI KONSEP',CREAM,INK)
for i,(c,label) in enumerate([(INK,'Ink'),(TEAL,'Sea teal'),(SAGE,'Sage'),(CREAM,'Cream'),(CORAL,'Coral')]):
    y=177+i*37
    p.rect(383,y,34,24,c,LINE,.5);p.text(428,y+4,123,label,9.8,'bold',MUTED)
p.text(38,390,519,'Stylized low-poly dengan warna cerah',20,'title',TEAL)
p.text(38,429,519,'Bentuk medan, landmark, simbol puzzle, dan telegraph menjadi sumber informasi utama. Bentuk serta arah tetap terbaca tanpa bergantung pada warna saja.',11.5)
p.rect(38,501,249,194,INK)
p.text(54,517,216,'Rancangan HUD',15,'bold',WHITE)
p.rect(54,554,145,9,CORAL);p.text(210,549,58,'HP',9,'bold',WHITE)
p.rect(54,578,110,7,SAGE);p.text(180,572,81,'Stamina',9,'body',WHITE)
p.text(54,608,216,'Jumlah potion / progres artefak',10,'body',WHITE)
p.text(54,643,216,'Skema elemen, bukan screenshot atau nilai balancing final.',9,'body',SAGE)
p.text(311,509,246,'Usulan produksi audio',15,'bold',TEAL)
p.text(311,545,246,'Ambience pulau, musik eksplorasi, musik boss, serta SFX attack, block, dodge, potion, puzzle, dan gerbang.',11)
p.text(311,634,246,'Audio memperkuat feedback visual. Pilihan track dan asset belum final.',10.5,'body',MUTED)
p.text(38,735,519,'Menu utama, pause, pengaturan audio, dan layar selesai disiapkan sebagai baseline UX untuk tahap prototype.',10.8,'body',MUTED)

# 16 - Technology: dark technical ledger and procedural constraints.
p=Page('Teknologi dan procedural generation',dark=True)
p.kicker('Development / Toolchain')
p.title('Teknologi\ndan procedural terrain',size=37)
for x,title,body in [
    (38,'GODOT 4.7.2','Standard / GDScript'),
    (303,'PC OFFLINE','Single-player / Level 1'),
]:
    p.rect(x,214,254,82,TEAL)
    p.text(x+15,228,224,title,19,'title',CREAM)
    p.text(x+15,264,224,body,10.5,'body',CREAM)
p.text(38,335,519,'Terrain bervariasi, objektif tetap valid',23,'title',SAGE)
y=385
for txt in [
    'Procedural mesh memakai variasi berdasarkan seed; seed dapat dipakai ulang untuk debugging.',
    'Puzzle, traversal, checkpoint, dan arena boss memakai penempatan atau modul terkontrol.',
    'Generation harus menjaga akses, slope, jarak lompatan, ruang combat, dan solusi puzzle.',
    'AI/MCP digunakan selama development. Game pemain tetap berjalan tanpa API atau layanan online.'
]:y=p.bullet(38,y,519,txt,11.3,CREAM)
p.line(38,644,557,644,TEAL,1)
p.text(38,668,247,'Kolaborasi',16,'bold',SAGE)
p.text(38,701,247,'Git menyimpan scene, script, resource, dan dokumen. Cache .godot dan hasil export dikecualikan.',10.8,'body',CREAM)
p.text(313,668,244,'Export',16,'bold',SAGE)
p.text(313,701,244,'Target Windows Desktop. Export templates 4.7.2 dan build akhir masih harus diverifikasi.',10.8,'body',CREAM)

# 17 - PRD: concise observable requirements, design vs implementation clearly separated.
p=Page('Kebutuhan produk / PRD')
p.kicker('Product requirements')
p.title('Kebutuhan produk\ndan penerimaan',size=38)
requirements=[
    ('R01','Eksplorasi dan kamera','Movement, jump, aiming, orbit, dan camera collision bekerja bersama; rute wajib dapat dilewati.'),
    ('R02','Tiga objektif','Pilar Simbol, Jalur Energi, dan Jalur Menuju Puncak dapat diselesaikan dengan urutan bebas.'),
    ('R03','Combat dan resource','Combo tiga hit, tiga tipe musuh, block, dodge, stamina, serta potion mengikuti aturan desain.'),
    ('R04','Progres dan retry','Artefak/puzzle bertahan selama sesi. Retry boss memulihkan snapshot tanpa mengurangi atau menggandakan stok awal.'),
    ('R05','Boss dan kemenangan','Tiga artefak membuka aktivasi boss. Kemenangan membuka gerbang dan memungkinkan Level 1 selesai.'),
    ('R06','Build offline','Build Windows berjalan tanpa Editor, MCP, akun, backend, atau koneksi internet saat bermain.'),
]
for i,(rid,title,body) in enumerate(requirements):
    y=198+i*83
    p.rect(38,y,47,27,TEAL)
    p.text(45,y+6,35,rid,10,'bold',WHITE)
    p.text(101,y-1,456,title,13,'bold',TEAL)
    p.text(101,y+25,456,body,10.7)
p.rect(38,721,519,56,PALE)
p.text(52,733,491,'Semua kebutuhan di atas adalah target implementasi. Angka performa, balancing, durasi sesi, dan daftar seed pengujian ditetapkan setelah prototype.',10.4)

# 18 - Production: four weeks, explicitly an adjustable proposal, unassigned work streams.
p=Page('Rencana produksi',frame=True)
p.kicker('Usulan kerja / Tim empat orang')
p.title('Rencana produksi\nempat minggu',size=39)
weeks=[
    ('01','Fondasi interaksi','Kamera, movement, aiming, satu enemy, dan combat dasar. Uji konflik input dan keterbacaan.'),
    ('02','Alur yang bisa ditamatkan','Tiga objektif, progres artefak, checkpoint, boss, serta ending dalam satu playable slice.'),
    ('03','Konten dan balancing','Blockout pulau, variasi biome, encounter, potion, snapshot retry, dan validasi generation.'),
    ('04','Polish dan pengumpulan','Visual/audio feedback, perbaikan bug, playtest anggota, export Windows, dan dokumentasi final.'),
]
for i,(n,title,body) in enumerate(weeks):
    y=195+i*111
    p.text(38,y,61,n,35,'title',CORAL)
    p.text(115,y,442,title,16,'title',TEAL)
    p.text(115,y+32,442,body,10.9)
p.line(38,653,557,653,SAGE,1)
p.text(38,673,519,'Usulan pembagian tanggung jawab',16,'bold',TEAL)
p.text(38,709,519,'Player/combat • world/generation • puzzle/progression • UI/audio/QA. Penanggung jawab ditentukan bersama; pembagian ini bukan penugasan nama anggota.',10.8)
p.text(38,766,519,'Urutan kerja dapat disesuaikan. Tanggal milestone belum ditetapkan.',9,'body',MUTED)

# 19 - Status and provenance: no fictional implementation results or asset claims.
p=Page('Status dan sumber')
p.kicker('Versi konsep / 11 November 2026')
p.title('Status proyek\ndan sumber',size=40)
p.card(38,183,249,130,'Sudah tersedia','Fondasi project Godot, scene preview, Git, konfigurasi MCP, serta dokumen keputusan desain.',size=11)
p.card(307,183,250,130,'Tahap berikutnya','Implementasi gameplay, playtest, integrasi visual/audio, dan verifikasi build akhir. Laporan ini belum menyatakan tahap tersebut selesai.',size=11)
p.text(38,335,519,'Sumber dan atribusi',23,'title',TEAL)
y=383
for title,body in [
    ('Keputusan desain','Bersumber dari brainstorming tim dan dokumen konsep repository The Lost Island. Keputusan terbaru menggantikan catatan Unity dan kamera top-down historis.'),
    ('Identitas visual','Logo FILKOM disediakan pengguna. Logo gim dan ilustrasi pulau dihasilkan melalui imagegen. Semua ilustrasi merupakan konsep, bukan screenshot gameplay.'),
    ('Teknologi','Godot 4.7.2 Standard dan GDScript. Godot Editor MCP dari hybridindie/godot-mcp, versi 2026.10.20.1, berlisensi MIT; lihat THIRD_PARTY_NOTICES.md.'),
    ('Asset produksi','Model, musik, dan SFX final belum dipilih. Asset yang digunakan pada implementasi wajib dicatat sumber serta lisensinya.'),
]:
    y=p.text(38,y,519,title,12,'bold',TEAL)+8
    y=p.text(38,y,519,body,10.6)+20
p.text(38,745,519,'Repository: github.com/ghazthiskc19/tugas-akhir-komputer-grafis',9.2,'body',MUTED)
p.p.insert_link({'kind':fitz.LINK_URI,'from':fitz.Rect(38,743,557,765),'uri':'https://github.com/ghazthiskc19/tugas-akhir-komputer-grafis'})

doc.set_metadata({'title':'The Lost Island - Dokumen Proyek Komputer Grafis','author':'; '.join(a[0] for a in META['anggota']),'subject':'GDD ringkas, kebutuhan produk, dan rencana produksi Level 1','keywords':'Godot, Komputer Grafis, GDD, PRD, The Lost Island'})
if not BACKGROUND_ONLY:
    doc.subset_fonts()
OUT.parent.mkdir(parents=True,exist_ok=True)
doc.save(OUT,garbage=4,deflate=True)
manifest={'pdf':OUT.relative_to(ROOT).as_posix(),'pages':len(doc),'text_blocks':text_blocks}
if not BACKGROUND_ONLY:
    (ROOT/'docs/laporan/layout-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pdf':str(OUT),'pages':len(doc),'bytes':OUT.stat().st_size}))
