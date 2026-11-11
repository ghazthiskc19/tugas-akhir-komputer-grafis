"""A4 Canva import with individually positioned text over visual backgrounds.

Avoids PDF text grouping/reflow in Canva. The report remains a visual-layout artifact.
"""
from pathlib import Path
import base64
import html
import json
import pymupdf as fitz

ROOT=Path(__file__).resolve().parents[2]
layout=json.loads((ROOT/'docs/laporan/layout-manifest.json').read_text(encoding='utf-8'))
background=fitz.open(ROOT/'tmp/pdfs/background-only.pdf')
scale=794/595.276
parts=['<!doctype html><html lang="id"><head><meta charset="utf-8"><title>The Lost Island - Dokumen Proyek</title>',
       '<style>html,body{margin:0;padding:0;background:#ddd;font-family:Arial,sans-serif} .page{position:relative;width:794px;height:1123px;overflow:hidden;page-break-after:always} .bg{position:absolute;left:0;top:0;width:794px;height:1123px} .copy{position:absolute;margin:0;padding:0;white-space:pre;letter-spacing:0}</style></head><body>']
for i,page in enumerate(background):
    pix=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
    image=base64.b64encode(pix.tobytes('jpeg',jpg_quality=94)).decode('ascii')
    parts.append(f'<section class="page" data-document-role="page" data-label="Halaman {i+1:02}">')
    parts.append(f'<img class="bg" alt="Elemen visual halaman {i+1}" src="data:image/jpeg;base64,{image}">')
    for t in layout['text_blocks']:
        if t['page']!=i+1: continue
        x,y,x2,y2=t['rect']; font=t['font']
        family='Georgia,serif' if font=='serif' else 'Arial,sans-serif'
        weight='700' if font=='bold' else '400'
        color='rgb('+','.join(str(round(v*255)) for v in t['color'])+')'
        styles=f'left:{x*scale:.3f}px;top:{y*scale:.3f}px;width:{(x2-x)*scale+4:.3f}px;font-family:{family};font-size:{t["size"]*scale:.3f}px;font-weight:{weight};font-style:normal;line-height:{t["size"]*t["leading"]*scale:.3f}px;color:{color}'
        value=html.escape('\n'.join(t['lines']))
        parts.append(f'<div class="copy" style="{styles}">{value}</div>')
    parts.append('</section>')
parts.append('</body></html>')
out=ROOT/'docs/laporan/the-lost-island-canva.html'
out.write_text('\n'.join(parts),encoding='utf-8')
print(json.dumps({'html':str(out),'pages':len(background),'bytes':out.stat().st_size}))
