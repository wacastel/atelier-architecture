from pathlib import Path
import argparse, re, html, json, hashlib, posixpath
from reportlab.pdfgen import canvas
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs'
SCRATCH = ROOT / 'output/city-building-guide-review'
SCRATCH.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser(description='Generate offline HTML and PDF from the shared guide Markdown.')
parser.add_argument('--font-dir',type=Path,default=Path.home()/'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/fonts',help='Directory containing Ubuntu R/B/RI/BI and UbuntuMono-R TTF files')
args=parser.parse_args()
FONT=args.font_dir
if not all((FONT/name).is_file() for name in ['Ubuntu-R.ttf','Ubuntu-B.ttf','Ubuntu-RI.ttf','Ubuntu-BI.ttf','UbuntuMono-R.ttf']):
    parser.error('Pass --font-dir with the five Ubuntu TTF files described in scripts/docs/README.md.')
for name, filename in [('Body','Ubuntu-R.ttf'),('BodyBold','Ubuntu-B.ttf'),('BodyItalic','Ubuntu-RI.ttf'),('BodyBoldItalic','Ubuntu-BI.ttf'),('Mono','UbuntuMono-R.ttf')]:
    pdfmetrics.registerFont(TTFont(name, str(FONT / filename)))
pdfmetrics.registerFontFamily('Body', normal='Body', bold='BodyBold', italic='BodyItalic', boldItalic='BodyBoldItalic')
source = (OUT / 'CITY-BUILDING-GUIDE.md').read_text()

def repo_url(url):
    if url.startswith(('https:','http:','#')):
        return url
    return 'https://github.com/wacastel/atelier-architecture/blob/main/' + posixpath.normpath('docs/' + url)

def inline(text, pdf=False):
    tokens=[]
    def save(s):
        tokens.append(s)
        return f'ZZTOKEN{len(tokens)-1}ZZ'
    text=re.sub(r'`([^`]+)`',lambda m:save('<font name="Mono">'+html.escape(m[1])+'</font>' if pdf else '<code>'+html.escape(m[1])+'</code>'),text)
    def link(m):
        label=html.escape(m[1]); url=repo_url(m[2])
        return save(('<link href="'+html.escape(url,quote=True)+'" color="#176A73">'+label+'</link>') if pdf else '<a href="'+html.escape(url,quote=True)+'">'+label+'</a>')
    text=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',link,text)
    text=html.escape(text)
    text=re.sub(r'\*\*([^*]+)\*\*',r'<b>\1</b>',text)
    for i,t in enumerate(tokens):text=text.replace(f'ZZTOKEN{i}ZZ',t)
    return text

def parse(md):
    blocks=[];lines=md.splitlines();i=0
    while i<len(lines):
        line=lines[i].strip()
        if not line:i+=1;continue
        if line=='<!-- page -->':blocks.append(('page',''));i+=1;continue
        if line.startswith('<a id='):blocks.append(('anchor',re.search(r'id="([^"]+)"',line)[1]));i+=1;continue
        if line.startswith('```'):
            buf=[];i+=1
            while i<len(lines) and not lines[i].startswith('```'):buf.append(lines[i]);i+=1
            blocks.append(('code','\n'.join(buf)));i+=1;continue
        m=re.match(r'^(#{1,3}) (.+)',line)
        if m:blocks.append(('h'+str(len(m[1])),m[2]));i+=1;continue
        m=re.match(r'^(-|\d+\.) (.+)',line)
        if m:blocks.append(('bullet' if m[1]=='-' else 'number',(m[1],m[2])));i+=1;continue
        buf=[line];i+=1
        while i<len(lines) and lines[i].strip() and not lines[i].startswith(('#','```','<!--','<a id=')):
            buf.append(lines[i].strip());i+=1
        blocks.append(('p',' '.join(buf)))
    return blocks

blocks=parse(source)
css='''
:root{--ink:#19313c;--muted:#536975;--accent:#176a73;--paper:#fff;--rule:#d9e2e5}
*{box-sizing:border-box}body{margin:0;background:#edf1f2;color:var(--ink);font:17px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif}
main{max-width:920px;margin:40px auto;background:var(--paper);box-shadow:0 8px 34px #17313b15;padding:48px 68px}
.brand{color:var(--accent);font-size:13px;font-weight:700;letter-spacing:.2em;border-top:5px solid var(--accent);padding-top:18px}
h1{font-size:46px;line-height:1.13;letter-spacing:-.035em;margin:25px 0}h2{font-size:29px;line-height:1.24;margin:35px 0 20px;letter-spacing:-.025em}h3{font-size:19px;margin:26px 0 10px}
p{margin:0 0 17px}a{color:var(--accent);text-underline-offset:3px}a:hover{color:#0b4850}code{font: .88em/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;background:#f0f5f6;border-radius:3px;padding:.08em .2em;overflow-wrap:anywhere}
pre{background:#f0f5f6;border-left:3px solid var(--accent);padding:16px 18px;overflow-x:auto;border-radius:0 5px 5px 0;line-height:1.45}pre code{font-size:13px;padding:0;background:none;overflow-wrap:normal}
ul,ol{padding-left:25px;margin:10px 0 20px}li{margin:0 0 10px}.chapter{border-top:1px solid var(--rule);padding-top:22px;margin-top:42px;scroll-margin-top:22px}.footer{border-top:1px solid var(--rule);font-size:13px;color:var(--muted);padding-top:18px;margin-top:32px}
@media(max-width:650px){main{margin:0;padding:28px 24px;box-shadow:none}h1{font-size:35px}h2{font-size:25px}body{font-size:16px}}
@media print{@page{size:letter;margin:17mm}body{background:white;font-size:10pt;line-height:1.45}main{max-width:none;margin:0;padding:0;box-shadow:none}h1{font-size:29pt}h2{font-size:19pt}h3{font-size:12pt}a{color:inherit}pre{white-space:pre-wrap}pre code{font-size:8pt}.chapter{break-before:page;border:0;padding:0;margin:0}h2,h3{break-after:avoid}li,pre{break-inside:avoid}.brand{padding-top:10px}li{margin-bottom:6px}}
'''
parts=['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Building a city section in Atelier</title><style>'+css+'</style></head><body><main><div class="brand">ATELIER / CITY BUILDING GUIDE</div><section>']
list_mode=None
for kind,value in blocks:
    desired='ul' if kind=='bullet' else 'ol' if kind=='number' else None
    if desired!=list_mode:
        if list_mode:parts.append('</'+list_mode+'>')
        if desired:parts.append('<'+desired+'>')
        list_mode=desired
    if desired:parts.append('<li>'+inline(value[1])+'</li>')
    elif kind=='page':parts.append('</section><section class="chapter">')
    elif kind=='anchor':parts.append('<a id="'+value+'"></a>')
    elif kind=='code':parts.append('<pre><code>'+html.escape(value)+'</code></pre>')
    elif kind.startswith('h'):parts.append('<'+kind+'>'+inline(value)+'</'+kind+'>')
    else:parts.append('<p>'+inline(value)+'</p>')
if list_mode:parts.append('</'+list_mode+'>')
parts.append('</section><div class="footer">Prepared 9 September 2026 · Offline document; external source links require a connection. Repository links open the current project documentation.</div></main></body></html>')
(OUT/'city-building-guide.html').write_text('\n'.join(parts))

INK=colors.HexColor('#19313c');ACCENT=colors.HexColor('#176a73');MUTED=colors.HexColor('#536975')
styles={
 'h1':ParagraphStyle('title',fontName='BodyBold',fontSize=30,leading=34,textColor=INK,spaceBefore=18,spaceAfter=16),
 'h2':ParagraphStyle('section',fontName='BodyBold',fontSize=21,leading=25,textColor=INK,spaceAfter=13,keepWithNext=True),
 'h3':ParagraphStyle('subsection',fontName='BodyBold',fontSize=12,leading=16,textColor=ACCENT,spaceBefore=7,spaceAfter=7,keepWithNext=True),
 'p':ParagraphStyle('body',fontName='Body',fontSize=10.3,leading=14.2,textColor=INK,spaceAfter=9,splitLongWords=True),
 'bullet':ParagraphStyle('bullet',fontName='Body',fontSize=10.3,leading=14.2,textColor=INK,leftIndent=12,firstLineIndent=0,bulletIndent=0,spaceAfter=6),
 'code':ParagraphStyle('code',fontName='Mono',fontSize=8.8,leading=11.4,textColor=INK,backColor=colors.HexColor('#eff4f5'),borderPadding=10,spaceBefore=3,spaceAfter=12),
 'brand':ParagraphStyle('brand',fontName='BodyBold',fontSize=10,leading=13,textColor=ACCENT,spaceAfter=10),
}
PAGE_W,PAGE_H=612,792
class GuideDoc(SimpleDocTemplate):
    def afterFlowable(self,flowable):
        if isinstance(flowable,Paragraph) and hasattr(flowable,'guide_anchor'):
            self.canv.bookmarkPage(flowable.guide_anchor)
            self.canv.addOutlineEntry(flowable.getPlainText(),flowable.guide_anchor,0,False)

def page_decoration(canv,doc):
    canv.saveState()
    if doc.page==1:
        canv.setFillColor(ACCENT);canv.rect(48,746,516,5,fill=1,stroke=0)
    else:
        canv.setFont('BodyBold',8);canv.setFillColor(MUTED)
        canv.drawString(48,759,'ATELIER / CITY BUILDING GUIDE')
        canv.setStrokeColor(colors.HexColor('#d9e2e5'));canv.line(48,751,564,751)
    canv.setStrokeColor(colors.HexColor('#d9e2e5'));canv.line(48,40,564,40)
    canv.setFont('Body',8);canv.setFillColor(MUTED)
    canv.drawString(48,26,'REPOSITORY FIELD GUIDE  /  9 SEPTEMBER 2026')
    canv.drawRightString(564,26,str(doc.page))
    canv.restoreState()

story=[Paragraph('ATELIER / CITY BUILDING GUIDE',styles['brand'])]
anchor=None
for kind,value in blocks:
    if kind=='page':story.append(PageBreak());continue
    if kind=='anchor':anchor=value;continue
    if kind=='code':story.append(Preformatted(value,styles['code'],maxLineLength=96,splitChars=' '));continue
    if kind in ('bullet','number'):
        bullet='•' if kind=='bullet' else value[0]
        story.append(Paragraph(inline(value[1],True),styles['bullet'],bulletText=bullet));continue
    text=inline(value,True)
    if anchor and kind=='h2':text='<a name="'+anchor+'"/>'+text
    p=Paragraph(text,styles.get(kind,styles['p']))
    if anchor and kind=='h2':p.guide_anchor=anchor;anchor=None
    story.append(p)

pdf_path=OUT/'City-Building-Guide.pdf'
doc=GuideDoc(str(pdf_path),pagesize=(PAGE_W,PAGE_H),leftMargin=48,rightMargin=48,topMargin=58,bottomMargin=52,title='Building a city section in Atelier',author='Atelier project',subject='Repository-based workflow for mapped architectural city sections',pageCompression=1,invariant=1)
doc.build(story,onFirstPage=page_decoration,onLaterPages=page_decoration)
reader=PdfReader(str(pdf_path))
pages=[p.extract_text() for p in reader.pages]
report={
 'pages':len(pages),'markdownWords':len(source.split()),
 'pageStarts':[{ 'page':i+1,'start':t[:150]} for i,t in enumerate(pages)],
 'internalLinks':sum(1 for p in reader.pages for a in p.get('/Annots',[]) if '/Dest' in a.get_object()),
 'externalLinks':sum(1 for p in reader.pages for a in p.get('/Annots',[]) if '/A' in a.get_object()),
 'outputs':{str(p.relative_to(ROOT)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [OUT/'CITY-BUILDING-GUIDE.md',OUT/'city-building-guide.html',pdf_path]},
 'fontSHA256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [FONT/name for name in ['Ubuntu-R.ttf','Ubuntu-B.ttf','Ubuntu-RI.ttf','Ubuntu-BI.ttf','UbuntuMono-R.ttf']]},
}
(SCRATCH/'build-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
