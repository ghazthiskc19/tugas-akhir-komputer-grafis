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

# 01 - Cover restores the original island illustration.
p=Page('Game Project Report',frame=True)
p.image('original-island-cover.png',24,22,547,398)
p.kicker('Komputer Grafis / Game Project Report',38,426)
p.title('THE LOST\nISLAND',38,449,350,43)
p.image('the-lost-island-logo.png',395,452,162,105)
p.line(38,568,557,568,SAGE,1)
p.text(38,583,218,META['nama_tim'],13,'bold',TEAL)
p.text(38,620,214,'Lecturer',8.7,'bold',MUTED)
p.text(38,637,214,META['dosen'],10)
p.text(38,674,214,'Academic Year',8.7,'bold',MUTED)
p.text(38,691,214,META['tahun_ajaran'],10)
p.image('logo-filkom.png',38,730,201,49)
p.text(274,584,283,'TEAM MEMBERS',9,'bold',TEAL)
y=608
for name,nim in META['anggota']:
    p.text(274,y,283,name,9.7,'bold')
    p.text(274,y+15,283,nim,9.5,'body',MUTED)
    y+=37
p.text(274,764,283,'Fakultas Ilmu Komputer\nUniversitas Brawijaya',9.3,'body',MUTED)

# 02 - Disclosure with an illustrated identity mark.
p=Page('AI Usage Disclosure',frame=True)
p.kicker('Project documentation')
p.title('AI Usage\nDisclosure',y=72,size=42,w=360)
p.image('the-lost-island-logo.png',399,77,158,99)
p.text(38,190,519,'AI digunakan untuk membantu perencanaan, persiapan development, dan penyusunan materi visual. Kontribusinya dicatat berdasarkan pekerjaan yang telah dilakukan.',12)
p.rect(38,275,313,444,WHITE)
y=296
for title,body in [
    ('Planning & Documentation','ChatGPT membantu pembahasan konsep dan alternatif desain. Codex membantu merangkum keputusan serta menyusun dokumen dan layout laporan.'),
    ('Development Setup','Codex membantu setup project, migrasi dari Unity ke Godot, konfigurasi MCP, dan pengelolaan Git. Sistem gameplay dalam laporan ini masih berupa rancangan.'),
    ('Visual Development','Canva AI digunakan pada draft awal, termasuk ilustrasi cover yang dipertahankan. Imagegen menghasilkan logo gim dan ilustrasi tambahan. Seluruh gambar merupakan concept art, bukan screenshot gameplay.'),
]:
    y=p.text(55,y,278,title,12,'bold',TEAL)+9
    y=p.text(55,y,278,body,10.8)+24
p.rect(372,275,185,444,TEAL)
p.text(389,296,151,'Team Responsibility',18,'title',WHITE)
p.text(389,365,151,'Tim bertanggung jawab atas keputusan desain, pemahaman kode, pemeriksaan hasil, pengujian, dan materi yang dikumpulkan.',11,'body',WHITE)
p.text(389,514,151,'Sources & Licenses',13,'bold',WHITE)
p.text(389,551,151,'Sumber serta lisensi asset pihak ketiga dicatat sesuai penggunaan aktual. Hasil AI ditinjau dan disesuaikan sebelum digunakan pada produk akhir.',10.8,'body',WHITE)
p.text(38,751,519,'Logo FILKOM disediakan oleh anggota tim. Atribusi visual dan teknologi tercantum pada bagian Sources & Project Status.',9,'body',MUTED)

# 03 - Overview pairs the premise with a full environment illustration.
p=Page('Game Overview')
p.kicker('Concept / Level 1')
p.title('Game Overview',size=43)
p.text(38,145,235,'The Lost Island adalah gim petualangan 3D tentang awak kapal yang terdampar, tiga artefak kuno, dan penjaga gerbang menuju dermaga.',13,'serif',INK,1.5)
p.image('island-concept.jpg',303,142,254,174)
p.text(303,321,254,'Environment concept',8.3,'body',MUTED)
for x,label,value in [(38,'PLATFORM','PC'),(214,'MODE','Single-player'),(390,'CONNECTION','Fully offline')]:
    p.rect(x,365,167,66,PALE)
    p.text(x+13,377,140,label,8,'bold',TEAL)
    p.text(x+13,395,140,value,15,'title')
p.text(38,470,519,'Design Pillars',23,'title')
for i,(title,body) in enumerate([
    ('Guided Exploration','Landmark, jalur alternatif, dan shortcut membantu pemain menemukan objektif dalam urutan yang fleksibel.'),
    ('Readable Challenges','Puzzle memiliki petunjuk visual. Musuh dan boss memberi tanda sebelum serangan agar pemain dapat menentukan respons.'),
    ('Stylized Island','Bentuk low-poly, elevasi moderat, dan tiga biome memberi karakter pada ruang eksplorasi Level 1.'),
]):
    y=518+i*73
    p.text(38,y,42,f'0{i+1}',22,'title',CORAL)
    p.text(93,y,454,title,13,'bold',TEAL)
    p.text(93,y+24,454,body,10.8)
p.text(38,759,519,'Target pengalaman: eksplorasi, puzzle ringan, dan pertarungan melee dalam satu level yang dapat ditamatkan.',9,'body',MUTED)

# 04 - Story uses a large image and a different, dark editorial composition.
p=Page('Story & Setting',dark=True)
p.kicker('Narrative / Level 1')
p.title('Story & Setting',size=39,font='serif')
p.text(38,146,519,'Badai merusak kapal dan membawa seorang awak ke bekas pulau penjagaan jalur pelayaran. Dermaga terlindung berada di sisi lain pulau, tetapi jalan menuju ke sana ditutup oleh gerbang kuno.',12.5,'body',CREAM,1.5)
p.image('original-island-cover.png',57,268,481,350)
p.text(57,625,481,'Original island concept',8.4,'body',SAGE)
p.text(38,662,242,'Energy Keys',15,'bold',SAGE)
p.text(38,692,242,'Tiga artefak mengaktifkan kembali sistem gerbang dan golem yang masih menjalankan perintah lama untuk menolak penyusup.',10.6,'body',CREAM)
p.text(314,662,243,'Environmental Storytelling',15,'bold',SAGE)
p.text(314,692,243,'Pembukaan singkat, relief lingkungan, dan penutup menyampaikan cerita tanpa kebutuhan NPC atau dialog panjang.',10.6,'body',CREAM)

# 05 - Parallel goals retain the flexible objective order.
p=Page('Core Gameplay Loop',frame=True)
p.kicker('Player progression')
p.title('Core Gameplay\nLoop',size=40)
p.text(38,176,519,'Pemain memilih tujuan, membaca lingkungan, menyelesaikan tantangan, lalu kembali ke jalur utama. Ketiga artefak diperlukan untuk memulai pertarungan akhir.',12)
p.circle(298,294,29,TEAL);p.text(278,283,55,'START',9,'bold',WHITE)
for x,title,body in [(38,'Symbol Pillars','Grassland\nPuzzle urutan simbol'),(216,'Energy Path','Forest\nPuzzle sambungan energi'),(394,'Summit Route','Rocky Highlands\nTraversal dan penjaga')]:
    arrow(p,298,327,x+80,376,SAGE)
    p.card(x,382,163,125,title,body,size=10.6)
    diamond(p,x+81,534,13,CORAL)
    p.line(x+81,554,x+81,581,SAGE,1.5)
p.line(119,581,475,581,SAGE,1.5);arrow(p,298,581,298,616,TEAL)
p.rect(139,622,318,45,TEAL)
p.text(156,634,285,'Pasang artefak dan aktifkan penjaga',11,'bold',WHITE)
arrow(p,298,668,298,697,TEAL)
p.text(137,705,325,'Defeat the Gatekeeper',20,'title',TEAL)
p.text(137,741,325,'Kemenangan membuka gerbang. Melewatinya menyelesaikan Level 1.',10.5)

# 06 - Conceptual world diagram rather than a claimed implemented map.
p=Page('World Design')
p.kicker('Island / Baseline blockout')
p.title('World Design',size=43)
p.tag(392,132,165,'BASELINE 250 × 250 M')
p.rect(38,185,519,367,rgb('DCEBE6'))
island=[(85,437),(68,359),(117,281),(191,253),(235,218),(334,229),(395,271),(470,293),(512,372),(478,466),(372,511),(252,495),(153,510)]
p.poly(island,SAGE)
p.poly([(85,437),(130,349),(253,335),(333,393),(372,511),(252,495),(153,510)],rgb('D6D4A9'))
p.poly([(117,281),(191,253),(248,296),(253,335),(130,349)],rgb('6F9D7C'))
p.poly([(235,218),(334,229),(395,271),(352,345),(248,296)],rgb('98A49A'))
for x,y in [(134,288),(164,301),(193,282),(205,316),(160,330)]:tree(p,x,y,.7)
for x,y in [(274,253),(310,270),(341,249)]:p.poly([(x,y-18),(x-18,y+18),(x+18,y+18)],rgb('788B86'))
route=[(179,454),(210,394),(284,373),(349,332),(391,388),(438,433)]
for a,b in zip(route,route[1:]):p.line(*a,*b,CREAM,5)
for x,y in [(179,454),(284,373),(438,433)]:p.circle(x,y,6,CORAL)
for x,y in [(178,306),(314,270),(249,442)]:diamond(p,x,y,11,CORAL)
p.tag(81,370,104,'FOREST');p.tag(302,205,176,'ROCKY HIGHLANDS',INK);p.tag(176,479,119,'GRASSLAND')
p.text(57,523,483,'Skema hubungan area. Posisi, proporsi biome, dan jalur belum menjadi map final.',8.3,'body',MUTED)
p.card(38,578,249,126,'Navigation','Grassland mengenalkan kontrol. Forest dan Rocky Highlands bercabang dari jalur penghubung. Gerbang menjadi landmark.',size=10.7)
p.card(307,578,250,126,'Return Routes','Shortcut mengurangi pengulangan perjalanan. Lokasi objektif dan ruang traversal harus tetap valid pada setiap seed.',size=10.7)
p.text(38,735,519,'Durasi dapat melebihi usulan 15–20 menit. Target akhirnya ditentukan melalui playtest terhadap rute dan aktivitas pemain.',10.3,'body',MUTED)

# 07 - Camera combines a geometry diagram with clearly separated mouse modes.
p=Page('Camera & Controls')
p.kicker('Perspective / Elevated follow')
p.title('Camera & Controls',size=39)
p.rect(38,180,519,247,PALE);p.line(67,383,529,383,SAGE,2)
p.circle(359,322,14,TEAL);p.line(359,336,359,374,TEAL,5)
p.line(359,351,340,366,TEAL,3);p.line(359,351,378,366,TEAL,3)
p.rect(100,236,48,32,INK);p.poly([(148,241),(168,232),(168,272),(148,263)],INK)
p.line(163,252,358,336,CORAL,1.5);p.line(163,252,464,375,SAGE,1);p.line(163,252,297,375,SAGE,1)
p.text(64,198,190,'Perspective Camera',10,'bold',TEAL);p.text(377,302,151,'Player',10,'bold',TEAL)
p.text(67,393,460,'Skema posisi kamera. Jarak, FOV, dan sudut ditentukan melalui prototype.',8.5,'body',MUTED)
p.card(38,455,249,134,'Aiming Mode','Mouse mengarahkan serangan ke posisi di dunia permainan. Perubahan arah serangan tidak otomatis memutar kamera.',size=11)
p.card(307,455,250,134,'Orbit Mode','Tahan tombol tengah mouse untuk orbit horizontal 360°. Sudut vertikal dibatasi. Lepaskan tombol untuk kembali aiming.',size=11)
y=620
for txt in ['Smooth damping mengikuti movement dan lompatan tanpa hentakan.', 'Camera collision mendekatkan kamera saat terhalang dan mengembalikannya secara mulus.', 'Analog kanan mengatur orbit. Mapping gamepad lainnya belum dirinci.']:y=p.bullet(38,y,519,txt,10.8)
p.text(38,758,519,'Framing harus menjaga keterbacaan simbol, jarak lompatan, musuh, dan telegraph boss.',9,'body',MUTED)

# 08 - Illustrated puzzle, concise rules beneath the environment.
p=Page('Symbol Pillars',frame=True)
p.kicker('Puzzle 01 / Grassland')
p.title('Symbol Pillars',size=44)
p.text(38,133,519,'Pada puzzle Pilar Simbol, pemain membaca relief dan mengaktifkan empat pilar sesuai urutan petunjuk.',12)
p.image('symbol-ruins.jpg',38,197,519,346)
p.text(38,551,519,'Concept art; bentuk simbol, urutan, dan layout merupakan ilustrasi mekanik.',8.6,'body',MUTED)
y=582
for txt in ['Relief tetap terlihat. Simbol dibedakan melalui bentuk, dengan warna sebagai pendukung.', 'Interaksi pada pilar memberi feedback cahaya dan audio. Urutan benar membuka segel artefak.', 'Urutan salah mereset rangkaian tanpa damage atau kehilangan item.', 'Musuh tidak mengganggu puzzle. Status selesai bertahan setelah respawn selama sesi.']:y=p.bullet(38,y,519,txt,10.8)

# 09 - Illustrated energy puzzle; exact solution remains in controlled modules.
p=Page('Energy Path')
p.kicker('Puzzle 02 / Forest')
p.title('Energy Path',size=46)
p.text(38,133,519,'Pada puzzle Jalur Energi, tiga panel diputar untuk menyambungkan kristal sumber ke altar artefak.',12)
p.image('energy-ruins.jpg',38,193,519,292)
p.text(38,495,519,'Concept art; susunan dan orientasi panel belum menjadi layout final.',8.6,'body',MUTED)
p.text(38,540,249,'Interaction',17,'title',TEAL)
p.text(38,578,249,'Setiap interaksi memutar panel 90°. Ukiran jalur lurus atau siku menunjukkan sambungan, sedangkan energi mengikuti jalur dari sumber.',11)
p.text(307,540,250,'Completion',17,'title',TEAL)
p.text(307,578,250,'Sambungan lengkap membuka segel artefak. Pemain bebas mencoba tanpa damage, timer, atau batas percobaan.',11)
p.line(38,686,557,686,SAGE,1)
p.text(38,710,519,'Status selesai bertahan setelah respawn selama sesi. Sistem menggunakan konektivitas jalur; simulasi cahaya fisik tidak diperlukan.',11)

# 10 - Summit illustration and a four-stage route, in two columns.
p=Page('Summit Route',frame=True)
p.kicker('Exploration challenge / Rocky Highlands')
p.title('Summit Route',size=44)
p.text(38,133,519,'Jalur Menuju Puncak menggabungkan pencarian rute, traversal, dan encounter menuju altar di dataran tinggi.',12)
p.image('summit-route.jpg',38,191,519,292)
p.text(38,491,519,'Environment concept; bentuk menara, jalur, dan jembatan belum final.',8.6,'body',MUTED)
for x,y,n,title,body in [
    (38,532,'01','Trailhead','Checkpoint sebelum pendakian dan satu musuh melee di area combat yang cukup luas.'),
    (307,532,'02','Cliff Path','Jalur berkelok dengan satu atau dua lompatan pendek dan ruang untuk membaca jarak.'),
    (38,636,'03','Guard Courtyard','Satu melee dan satu ranged. Batu memberi perlindungan, dengan jalur pendekatan samping.'),
    (307,636,'04','Summit Altar','Artefak, viewpoint, dan jembatan shortcut yang dibuka dari sisi puncak.'),
]:
    p.text(x,y,27,n,13,'bold',CORAL);p.text(x+34,y,215,title,15,'title',TEAL)
    p.text(x,y+30,249,body,10.6)
p.text(38,754,519,'Pemain boleh melewati penjaga. Musuh rute yang sudah dikalahkan tetap mati selama sesi.',9.5,'body',MUTED)

# 11 - A large action illustration precedes the compact combat specification.
p=Page('Combat System',dark=True)
p.kicker('Melee / Mouse-world aiming')
p.title('Combat System',size=43)
p.image('combat-scene.jpg',38,155,519,292)
p.text(38,457,519,'Combat concept; penampilan karakter dan jenis senjata masih berupa eksplorasi visual.',8.5,'body',SAGE)
for i,(x,label,sub) in enumerate([(38,'01','Quick Hit'),(216,'02','Quick Hit'),(394,'03','Finisher')]):
    p.rect(x,497,163,61,TEAL if i<2 else CORAL)
    p.text(x+13,507,39,label,24,'title',CREAM if i<2 else INK)
    p.text(x+59,519,95,sub,11,'bold',CREAM if i<2 else INK)
p.text(38,590,519,'Satu tombol attack menjalankan combo tiga hit. Input lanjutan harus masuk pada timing window; early input tidak disimpan dan menahan tombol tidak menjalankan combo otomatis.',11.2,'body',CREAM)
y=669
for txt in ['Attack yang dimulai diselesaikan sebelum block atau dodge. Movement tetap tersedia dengan kecepatan berkurang.', 'Arah dikunci selama satu hit dan dibaca kembali pada hit berikutnya. Attack tidak memakai stamina.']:y=p.bullet(38,y,519,txt,11,CREAM)

# 12 - Enemy appearance exploration is explicitly separated from locked behaviors.
p=Page('Enemy Archetypes')
p.kicker('Encounter design / Three roles')
p.title('Enemy Archetypes',size=40)
p.image('enemy-lineup.jpg',38,160,519,292)
p.text(38,465,519,'Character exploration; penampilan dan jenis senjata spesifik belum ditetapkan.',8.6,'body',MUTED)
for x,n,title,body in [
    (38,'01','Standard Melee','Mendekati pemain lalu melakukan satu swing singkat dengan recovery pendek.'),
    (216,'02','Heavy Melee','Bergerak lebih lambat, memberi tanda sebelum hantaman kuat, lalu recovery panjang.'),
    (394,'03','Ranged','Menembakkan proyektil lurus setelah persiapan yang terbaca. Pemain dapat menghindar atau memakai perlindungan.'),
]:
    p.text(x,514,150,n,17,'title',CORAL);p.text(x,548,153,title,12.3,'bold',TEAL)
    p.text(x,581,151,body,10.7)
p.line(38,709,557,709,SAGE,1)
p.text(38,733,519,'Rancangan awal tidak memakai proyektil homing atau combo heavy yang panjang. Detection, chase/leash, stagger, dan distribusi encounter dirinci melalui prototype.',10.4,'body',MUTED)

# 13 - Resource rules with an observable retry diagram.
p=Page('Resources & Retry')
p.kicker('HP / Stamina / Potion')
p.title('Resources & Retry',size=40)
p.card(38,161,249,153,'Block & Dodge','Block mengurangi damage dari semua arah dan menguras stamina selama ditahan. Dodge memakai biaya tetap dan memberi i-frames singkat.',size=10.8)
p.card(307,161,250,153,'Stamina Recovery','Stamina pulih setelah jeda sejak block atau dodge berhenti. Jika stamina kurang, defense ditolak; movement dan attack tetap tersedia.',size=10.8)
p.text(38,347,519,'Potion Use',22,'title',TEAL)
p.text(38,387,519,'Saat minum, pemain berjalan lebih lambat dan tidak dapat menyerang. Terkena serangan membatalkan animasi. Healing dan konsumsi potion terjadi setelah animasi selesai; pembatalan tidak menghabiskan item.',11.2)
p.text(38,480,249,'Exploration Respawn',15,'bold',TEAL)
p.text(38,514,249,'HP kembali penuh di checkpoint. Healing terpakai tidak dikembalikan. Artefak dan puzzle selesai tetap tercatat selama sesi.',10.8)
p.text(307,480,250,'Boss Snapshot',15,'bold',TEAL)
p.text(307,514,250,'HP, stamina, dan jumlah potion kembali ke kondisi sebelum pertarungan pertama. Boss direset; progres pulau tetap tersimpan.',10.8)
for x,count,label in [(38,'5','Before Fight'),(233,'2','After Use'),(428,'5','After Retry')]:
    p.circle(x+61,661,29,TEAL);p.text(x+52,640,40,count,29,'title',CREAM)
    p.text(x+14,710,132,label,10.3,'bold',TEAL)
arrow(p,143,661,214,661,SAGE,2);arrow(p,338,661,409,661,SAGE,2)
p.text(38,752,519,'Jumlah pada skema merupakan contoh. Snapshot tidak menggandakan item; setelah menang, resource yang tersisa dipertahankan.',9.3,'body',MUTED)

# 14 - Boss concept and readable pattern descriptions.
p=Page('The Gatekeeper',frame=True)
p.kicker('Final encounter / Level 1')
p.title('The Gatekeeper',size=42)
p.text(38,129,519,'Penjaga Gerbang aktif setelah tiga artefak dipasang dan pemain memulai pertarungan.',11.5)
p.image('gatekeeper-boss.jpg',38,177,519,292)
p.text(38,479,519,'Boss concept; arena rata dan luas, tanpa musuh tambahan.',8.6,'body',MUTED)
for y,title,body in [
    (516,'Arm Sweep','Lengan ditarik ke belakang sebelum sapuan. Pemain mundur atau dodge keluar jangkauan.'),
    (570,'Ground Slam','Kedua tangan diangkat; lingkaran menandai area damage. Recovery memberi celah combo tiga hit.'),
    (624,'Straight Charge','Badan direndahkan dan garis menunjukkan arah terjangan. Target dikunci menjelang serangan dilepas.'),
]:
    p.text(38,y,151,title,12,'bold',TEAL);p.text(205,y,352,body,10.5)
p.line(38,685,557,685,SAGE,1)
p.text(38,706,249,'Phase 1 / HP > 50%',12,'bold',TEAL)
p.text(38,735,249,'Satu serangan lalu recovery. Telegraph memberi kesempatan membaca pola.',10.1)
p.text(307,706,250,'Phase 2 / HP ≤ 50%',12,'bold',TEAL)
p.text(307,735,250,'Sesekali dua serangan berurutan. Telegraph dan timing dasar tetap dipertahankan.',10.1)

# 15 - Art direction includes image, palette, HUD schematic and audio notes.
p=Page('Art Audio & Interface')
p.kicker('Visual direction / Player feedback')
p.title('Art, Audio\n& Interface',size=39)
p.image('island-concept.jpg',38,185,320,180)
for i,(c,label) in enumerate([(INK,'Ink'),(TEAL,'Sea Teal'),(SAGE,'Sage'),(CREAM,'Cream'),(CORAL,'Coral')]):
    y=185+i*37;p.rect(383,y,34,24,c,LINE,.5);p.text(428,y+4,123,label,9.8,'bold',MUTED)
p.text(38,388,519,'Stylized Low-Poly',20,'title',TEAL)
p.text(38,426,519,'Bentuk medan, landmark, simbol, dan telegraph menyampaikan informasi permainan. Bentuk serta arah tetap terbaca tanpa bergantung pada warna saja.',11.4)
p.rect(38,501,249,194,INK)
p.text(54,517,216,'HUD Elements',15,'bold',WHITE)
p.rect(54,554,145,9,CORAL);p.text(210,549,58,'HP',9,'bold',WHITE)
p.rect(54,578,110,7,SAGE);p.text(180,572,81,'Stamina',9,'body',WHITE)
p.text(54,608,216,'Potion count / Artifact progress',10,'body',WHITE)
p.text(54,643,216,'Skema elemen UI; bukan screenshot atau nilai balancing final.',9,'body',SAGE)
p.text(311,509,246,'Audio Production',15,'bold',TEAL)
p.text(311,545,246,'Rencana audio mencakup ambience pulau, musik eksplorasi dan boss, serta SFX untuk combat, potion, puzzle, dan gerbang.',11)
p.text(311,636,246,'Audio memperkuat feedback visual. Track dan asset final belum dipilih.',10.5,'body',MUTED)
p.text(38,735,519,'Menu utama, pause, pengaturan audio, dan layar selesai menjadi baseline UX untuk tahap prototype.',10.7,'body',MUTED)

# 16 - Technical diagram on a dark background.
p=Page('Technology & Generation',dark=True)
p.kicker('Development / Toolchain')
p.title('Technology\n& Generation',size=40)
for x,title,body in [(38,'GODOT 4.7.2','Standard / GDScript'),(303,'OFFLINE PC','Single-player / Level 1')]:
    p.rect(x,194,254,76,TEAL);p.text(x+15,207,224,title,19,'title',CREAM);p.text(x+15,242,224,body,10.5,'body',CREAM)
for x,title in [(38,'Seed'),(216,'Terrain Mesh'),(394,'Valid Modules')]:
    p.rect(x,311,163,72,None,TEAL,1)
    if x==38:diamond(p,x+81,333,12,CORAL)
    elif x==216:
        for a in range(3):p.line(x+35+a*32,320,x+24+a*32,348,SAGE,1)
        p.line(x+29,334,x+117,334,SAGE,1)
    else:
        for a in range(3):p.rect(x+43+a*28,324,19,22,SAGE)
    p.text(x+15,356,133,title,10,'bold',CREAM)
arrow(p,202,346,215,346,CORAL);arrow(p,380,346,393,346,CORAL)
y=426
for txt in ['Procedural mesh memakai variasi berdasarkan seed yang dapat digunakan ulang untuk debugging.', 'Puzzle, traversal, checkpoint, dan arena boss ditempatkan melalui aturan atau modul terkontrol.', 'Generation menjaga akses, slope, jarak lompatan, ruang combat, dan solusi puzzle.', 'AI/MCP digunakan saat development. Game pemain berjalan tanpa API atau layanan online.']:y=p.bullet(38,y,519,txt,11.1,CREAM)
p.line(38,664,557,664,TEAL,1)
p.text(38,686,247,'Collaboration',15,'bold',SAGE)
p.text(38,718,247,'Scene, script, resource, dan dokumen disimpan di Git. Cache .godot dan hasil export dikecualikan.',10.5,'body',CREAM)
p.text(313,686,244,'Windows Export',15,'bold',SAGE)
p.text(313,718,244,'Export templates 4.7.2 dan build akhir perlu diverifikasi sebelum distribusi.',10.5,'body',CREAM)

# 17 - Requirements paired with contextual image thumbnails.
p=Page('Product Requirements')
p.kicker('PRD / Acceptance criteria')
p.title('Product\nRequirements',size=40)
requirements=[
    ('R01','Movement & Camera','Movement, jump, aiming, orbit, dan collision bekerja bersama; rute wajib dapat dilewati.','combat-scene.jpg'),
    ('R02','Three Objectives','Dua puzzle dan Jalur Menuju Puncak dapat diselesaikan dalam urutan bebas.','symbol-ruins.jpg'),
    ('R03','Combat & Resources','Combo, tiga tipe musuh, block, dodge, stamina, dan potion mengikuti aturan desain.','enemy-lineup.jpg'),
    ('R04','Progress & Retry','Progres sesi bertahan. Snapshot boss memulihkan resource tanpa mengurangi stok awal atau menggandakan item.','energy-ruins.jpg'),
    ('R05','Boss & Completion','Tiga artefak membuka aktivasi boss. Kemenangan membuka gerbang dan penyelesaian Level 1.','gatekeeper-boss.jpg'),
    ('R06','Offline Build','Build Windows berjalan tanpa Editor, MCP, akun, backend, atau koneksi internet saat bermain.','summit-route.jpg'),
]
for i,(rid,title,body,art) in enumerate(requirements):
    y=198+i*83
    p.image(art,38,y,91,58)
    p.text(146,y,35,rid,10,'bold',CORAL)
    p.text(194,y-1,363,title,12.8,'bold',TEAL)
    p.text(146,y+25,411,body,10.5)
p.text(38,731,519,'Seluruh kebutuhan merupakan target implementasi. Angka performa, balancing, durasi sesi, dan daftar seed pengujian ditentukan setelah prototype.',10.4,'body',MUTED)

# 18 - Production stages pair work items with content previews.
p=Page('Production Roadmap',frame=True)
p.kicker('Proposed schedule / Four-person team')
p.title('Production\nRoadmap',size=40)
weeks=[('01','Interaction Prototype','Kamera, movement, aiming, satu enemy, dan combat dasar. Uji konflik input dan keterbacaan.','combat-scene.jpg'),('02','Playable Slice','Tiga objektif, progres artefak, checkpoint, boss, dan ending dalam satu alur yang dapat ditamatkan.','symbol-ruins.jpg'),('03','Content & Balancing','Blockout pulau, biome, encounter, potion, snapshot retry, dan validasi generation.','summit-route.jpg'),('04','Polish & Delivery','Feedback visual/audio, perbaikan bug, playtest anggota, export Windows, dan dokumentasi final.','gatekeeper-boss.jpg')]
for i,(n,title,body,art) in enumerate(weeks):
    y=196+i*111
    p.text(38,y,35,n,19,'title',CORAL)
    p.image(art,84,y,107,65)
    p.text(211,y,346,title,15,'title',TEAL)
    p.text(211,y+31,346,body,10.7)
p.line(38,653,557,653,SAGE,1)
p.text(38,673,519,'Proposed Responsibilities',16,'bold',TEAL)
p.text(38,709,519,'Player/combat, world/generation, puzzle/progression, serta UI/audio/QA. Penanggung jawab ditentukan bersama; pembagian ini belum menjadi penugasan nama anggota.',10.8)
p.text(38,767,519,'Usulan empat minggu; urutan dan tanggal milestone dapat disesuaikan.',9,'body',MUTED)

# 19 - Provenance and status, with project mark.
p=Page('Sources & Project Status')
p.kicker('Document revision / 17 November 2026')
p.title('Sources &\nProject Status',size=39,w=370)
p.image('the-lost-island-logo.png',407,69,150,96)
p.card(38,192,249,130,'Available Foundation','Project Godot, scene preview, Git, konfigurasi MCP, dan dokumen keputusan desain telah tersedia.',size=10.9)
p.card(307,192,250,130,'Next Production Stage','Gameplay, playtest, integrasi visual/audio, serta verifikasi build akhir belum dinyatakan selesai.',size=10.9)
p.text(38,357,519,'Sources & Attribution',23,'title',TEAL)
y=405
for title,body in [('Design Decisions','Isi mengacu pada brainstorming tim dan dokumen konsep repository. Keputusan terbaru menggantikan catatan Unity serta kamera top-down historis.'),('Visual Assets','Logo FILKOM disediakan pengguna. Cover menggunakan kembali ilustrasi dari draft awal Canva. Logo gim dan enam ilustrasi tambahan dibuat melalui imagegen; semuanya merupakan concept art.'),('Development Tools','Godot 4.7.2 Standard dan GDScript. Godot Editor MCP dari hybridindie/godot-mcp versi 2026.10.20.1 berlisensi MIT; lihat THIRD_PARTY_NOTICES.md.'),('Production Assets','Model, musik, dan SFX final belum dipilih. Sumber dan lisensi setiap asset yang digunakan pada implementasi perlu dicatat.')]:
    y=p.text(38,y,519,title,12,'bold',TEAL)+8
    y=p.text(38,y,519,body,10.5)+19
p.text(38,756,519,'Repository: github.com/ghazthiskc19/tugas-akhir-komputer-grafis',9.1,'body',MUTED)
p.p.insert_link({'kind':fitz.LINK_URI,'from':fitz.Rect(38,753,557,776),'uri':'https://github.com/ghazthiskc19/tugas-akhir-komputer-grafis'})

doc.set_metadata({'title':'The Lost Island - Game Project Report','author':'; '.join(a[0] for a in META['anggota']),'subject':'Level 1 game design, product requirements, and production roadmap','keywords':'Godot, Komputer Grafis, GDD, PRD, The Lost Island'})
if not BACKGROUND_ONLY:doc.subset_fonts()
OUT.parent.mkdir(parents=True,exist_ok=True)
doc.save(OUT,garbage=4,deflate=True)
manifest={'pdf':OUT.relative_to(ROOT).as_posix(),'pages':len(doc),'text_blocks':text_blocks}
if not BACKGROUND_ONLY:(ROOT/'docs/laporan/layout-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pdf':str(OUT),'pages':len(doc),'bytes':OUT.stat().st_size}))
