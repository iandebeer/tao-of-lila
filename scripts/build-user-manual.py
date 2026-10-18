"""Build the user manual PDF from Markdown; requires reportlab."""
from pathlib import Path
import re
from html import escape
from interface_flow import interface_flow, write_svg
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, KeepTogether

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/pdf/tao-of-leela-user-manual.pdf'
INK = colors.HexColor('#183d38')
GOLD = colors.HexColor('#a87b39')
WIDTH = A4[0] - 104
BODY = ParagraphStyle('Body', fontName='Helvetica', fontSize=10, leading=13.5, textColor=INK, spaceAfter=7)
H2 = ParagraphStyle('Heading', parent=BODY, fontName='Times-Roman', fontSize=23, leading=27, spaceBefore=15, spaceAfter=12, keepWithNext=True)
H3 = ParagraphStyle('Subheading', parent=BODY, fontName='Helvetica-Bold', fontSize=11.5, leading=16, spaceBefore=10, spaceAfter=6, keepWithNext=True)
CELL = ParagraphStyle('Cell', parent=BODY, fontSize=9.2, leading=12.2, spaceAfter=0)
QUOTE = ParagraphStyle('Quote', parent=BODY, leftIndent=15, rightIndent=12, fontName='Times-Italic', fontSize=12, leading=16, borderColor=GOLD, borderWidth=.5, borderPadding=10, spaceBefore=6, spaceAfter=15)


def slug(text):
    return re.sub(r'[^\w\- ]', '', text.lower()).replace(' ', '-')


def inline(text):
    text = escape(text.replace('\u2011','-').replace('\u2013','-').replace('\u2014','-'))
    def link(m):
        label, target = m.groups()
        if target.startswith('#'):
            return f'<link href="{target}" color="#183d38"><u>{label}</u></link>'
        if target.startswith('introduction-pamphlet.md'):
            target = 'tao-of-leela-pamphlet.pdf'
        elif not target.startswith('http'):
            target = '../../docs/' + target
        return f'<link href="{target}" color="#183d38"><u>{label}</u></link>'
    text = re.sub(r'\[([^]]+)\]\(([^)]+)\)', link, text)
    text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<i>\1</i>', text)
    return re.sub(r'`([^`]+)`', r'<font name="Courier" size="8.3">\1</font>', text)


class Manual(SimpleDocTemplate):
    def afterFlowable(self, flowable):
        if hasattr(flowable, 'section_title'):
            self.canv.bookmarkPage(flowable.section_id)
            self.canv.addOutlineEntry(flowable.section_title, flowable.section_id, 0)


def chrome(c, doc):
    c.saveState()
    c.setStrokeColor(GOLD)
    c.setLineWidth(.5)
    c.line(52, A4[1]-39, A4[0]-52, A4[1]-39)
    c.setFillColor(INK)
    c.setFont('Helvetica', 8)
    c.drawString(52, A4[1]-30, 'THE TAO OF LEELA')
    c.drawRightString(A4[0]-52, A4[1]-30, 'USER MANUAL')
    c.line(52, 39, A4[0]-52, 39)
    c.setFont('Helvetica', 7.5)
    c.drawString(52, 25, 'PROTOTYPE EDITION  /  SOURCE: docs/user-manual.md')
    c.drawRightString(A4[0]-52, 25, str(doc.page))
    c.restoreState()


def main():
    write_svg()
    source = (ROOT / 'docs/user-manual.md').read_text()
    lines = source.splitlines()
    story = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith('# '):
            story.extend([Spacer(1, 28), Paragraph('The Tao of Leela', ParagraphStyle('Cover', parent=H2, fontSize=37, leading=42)), Paragraph('User Manual', ParagraphStyle('Subtitle', parent=H2, fontSize=27, leading=33)), Spacer(1, 14)])
            i += 1
            continue
        if line.startswith('## '):
            title = line[3:]
            if title in ('The journey at a glance', '2. Choose the right entrance') or re.match(r'1\. ', title):
                story.append(PageBreak())
            item = Paragraph(f'<a name="{slug(title)}"/>' + inline(title), H2)
            item.section_title, item.section_id = title, slug(title)
            story.append(item)
            i += 1
            continue
        if line.startswith('!['):
            figure = interface_flow()
            scale = 540 / figure.height
            figure.scale(scale, scale)
            figure.width *= scale
            figure.height *= scale
            story.extend([figure, Spacer(1, 14)])
            i += 1
            continue
        if line.startswith('### '):
            story.append(Paragraph(inline(line[4:]), H3))
            i += 1
            continue
        if line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                cells = [x.strip() for x in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?', x) for x in cells):
                    rows.append(cells)
                i += 1
            n = len(rows[0])
            widths = [WIDTH*.31, WIDTH*.69] if n == 2 else [WIDTH*.29, WIDTH*.36, WIDTH*.35]
            if rows[0][0] == 'Line value': widths = [WIDTH*.20, WIDTH*.40, WIDTH*.40]
            data = [[Paragraph(inline('**'+x+'**' if r==0 else x), CELL) for x in row] for r,row in enumerate(rows)]
            table = Table(data, colWidths=widths, repeatRows=1, hAlign='LEFT')
            table.setStyle(TableStyle([
                ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e5ede7')),
                ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.HexColor('#faf8f2'),colors.white]),
                ('VALIGN',(0,0),(-1,-1),'TOP'),
                ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
                ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),
                ('LINEBELOW',(0,0),(-1,0),.6,GOLD),
                ('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#dce3dd')),
            ]))
            story.extend([table, Spacer(1,12)])
            continue
        quoted = line.startswith('>')
        numbered = bool(re.match(r'^\d+\. ', line))
        block = [line[2:] if quoted else line]
        i += 1
        while i < len(lines) and lines[i].strip() and not lines[i].startswith(('#','|')):
            if re.match(r'^\d+\. ', lines[i]): break
            if lines[i].startswith('>') != quoted: break
            block.append(lines[i][2:] if quoted else lines[i])
            i += 1
        # Preserve explicit Markdown line breaks in the Persona example.
        text = '\n'.join(block)
        parts = re.split(r'  \n', text)
        markup = '<br/>'.join(inline(' '.join(p.split())) for p in parts)
        style = QUOTE if quoted else BODY
        if text.strip() == 'For example:':
            style = ParagraphStyle('ExampleLead', parent=BODY, keepWithNext=True)
        item = Paragraph(markup, style)
        if quoted and story and isinstance(story[-1], Paragraph) and story[-1].getPlainText() == 'For example:':
            story.append(KeepTogether([story.pop(), item]))
        else:
            story.append(KeepTogether([item]) if quoted else item)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Manual(str(OUT), pagesize=A4, rightMargin=52, leftMargin=52, topMargin=57, bottomMargin=57,
           title='The Tao of Leela - User Manual', author='Tao of Leela').build(story, onFirstPage=chrome, onLaterPages=chrome)
    print(OUT)


if __name__ == '__main__': main()
