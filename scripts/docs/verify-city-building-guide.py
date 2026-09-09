from pathlib import Path
import ast, hashlib, html, json, re, runpy, subprocess
from html.parser import HTMLParser
import pdfplumber
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs'
SCRATCH=ROOT/'output/city-building-guide-review'
SCRATCH.mkdir(parents=True,exist_ok=True)
md=(OUT/'CITY-BUILDING-GUIDE.md').read_text()
html_text=(OUT/'city-building-guide.html').read_text()
reader=PdfReader(str(OUT/'City-Building-Guide.pdf'))

class Text(HTMLParser):
    def __init__(self):super().__init__();self.text=[];self.ids=[];self.hrefs=[];self.external_assets=[];self.ignore=False
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag=='style':self.ignore=True
        if 'id' in attrs:self.ids.append(attrs['id'])
        if tag=='a' and 'href' in attrs:self.hrefs.append(attrs['href'])
        if tag in ['script','img','link','iframe','video','audio']:self.external_assets.append((tag,attrs))
    def handle_endtag(self,tag):
        if tag=='style':self.ignore=False
    def handle_data(self,data):
        if not self.ignore:self.text.append(data)

def clean(s):return re.sub(r'\s+','',s)
def plain(s):
    s=re.sub(r'`([^`]+)`',r'\1',s)
    s=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',r'\1',s)
    return s.replace('**','')

h=Text();h.feed(html_text)
html_clean=clean(''.join(h.text))
pdf_clean=clean(''.join(p.extract_text() for p in reader.pages))
failures=[];checked=0
code_values=[]
def protect_code(match):
    code_values.append(match[1])
    return f'ZZCODE{len(code_values)-1}ZZ'
protected=re.sub(r'```[^\n]*\n(.*?)\n```',protect_code,md,flags=re.S)
paragraphs=[]
for paragraph in re.split(r'\n\s*\n',protected):
    if re.match(r'^(-|\d+\.)\s+',paragraph):paragraphs.extend(paragraph.splitlines())
    else:paragraphs.append(paragraph)
for paragraph in paragraphs:
    if paragraph.startswith('<!--'):
        continue
    paragraph=re.sub(r'<a id="[^"]+"></a>\s*','',paragraph)
    if paragraph.startswith('ZZCODE'):
        paragraph=code_values[int(re.fullmatch(r'ZZCODE(\d+)ZZ',paragraph)[1])]
    else:
        paragraph=re.sub(r'^#{1,3}\s+','',paragraph)
        paragraph=re.sub(r'^(-|\d+\.)\s+','',paragraph,flags=re.M)
    expected=clean(plain(paragraph))
    if not expected:continue
    checked+=1
    if expected not in html_clean:failures.append({'kind':'html-content','text':paragraph[:90]})
    if expected not in pdf_clean:failures.append({'kind':'pdf-content','text':paragraph[:90]})

anchors=re.findall(r'<a id="([^"]+)"',md)
toc=re.findall(r'\]\(#([^\)]+)\)',md)
assert set(toc)==set(anchors)==set(h.ids)
assert not h.external_assets
assert len(reader.pages)==md.count('<!-- page -->')+1
assert len(reader.outline)==len(anchors)

code_blocks=re.findall(r'```(\w+)\n(.*?)\n```',md,re.S)
syntax=[]
for language,source in code_blocks:
    if language=='sh':
        result=subprocess.run(['/bin/bash','-n'],input=source,text=True,capture_output=True)
        assert result.returncode==0,result.stderr
        syntax.append({'language':language,'passed':True})
    elif language=='python':ast.parse(source);syntax.append({'language':language,'passed':True})

overflow=[];page_bounds=[]
with pdfplumber.open(OUT/'City-Building-Guide.pdf') as pdf:
    for i,page in enumerate(pdf.pages):
        chars=[c for c in page.chars if c['text'].strip()]
        bad=[c for c in chars if c['x0'] < 47 or c['x1'] > 565 or c['top'] < 10 or c['bottom'] > 778]
        if bad:overflow.append({'page':i+1,'characters':[(c['text'],c['x0'],c['x1'],c['top'],c['bottom']) for c in bad[:10]]})
        page_bounds.append({'page':i+1,'textCharacters':len(chars),'minX':min(c['x0'] for c in chars),'maxX':max(c['x1'] for c in chars),'minTop':min(c['top'] for c in chars),'maxBottom':max(c['bottom'] for c in chars)})
assert not failures,failures
assert not overflow,overflow
report={'passed':True,'pages':len(reader.pages),'semanticParagraphsCheckedAcrossThreeFormats':checked,
 'linkedContentsEntries':len(toc),'pdfOutlineEntries':len(reader.outline),'htmlExternalAssets':h.external_assets,
 'syntaxChecks':syntax,'pageTextBounds':page_bounds,
 'limits':['Commands were inspected and syntax-checked, not executed to rebuild/render the app by the guide author.',
           'HTML content, links and offline dependency structure were checked; no browser screenshot review is claimed.',
           'PDF raster visual review is recorded separately after every final page is inspected.']}
(SCRATCH/'structural-proof.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='pageTextBounds'},indent=2))
