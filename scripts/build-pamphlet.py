"""Render docs/introduction-pamphlet.md as a five-page A5 PDF.

Requires reportlab. Run from any directory with Python 3.
The Markdown is the copy source; explicit page groups keep the pamphlet concise.
"""
from pathlib import Path
import html
import re
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A5
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
from reportlab.graphics import renderPDF
from interface_flow import interface_flow, write_svg

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/introduction-pamphlet.md'
OUTPUT = ROOT / 'output/pdf/tao-of-leela-pamphlet.pdf'
W, H = A5
MARGIN = 35
INK = HexColor('#183d38')
MUTED = HexColor('#52655e')
GOLD = HexColor('#a87b39')
PAPER = HexColor('#faf7ef')
STYLE = ParagraphStyle('body', fontName='Helvetica', fontSize=10,
                       leading=13.8, textColor=INK, spaceAfter=8)
QUOTE = ParagraphStyle('quote', parent=STYLE, fontName='Times-Italic',
                       fontSize=15, leading=19, textColor=INK)
REFERENCE = ParagraphStyle('reference', parent=STYLE, fontSize=7.7,
                           leading=10, textColor=MUTED, spaceAfter=6)
TITLE = ParagraphStyle('title', parent=STYLE, fontName='Times-Roman',
                       fontSize=23, leading=26, spaceAfter=11)


def markup(text):
    text = ' '.join(text.split())
    text = html.escape(text)
    text = re.sub(r'\[([^]]+)\]\((https?://[^)]+)\)',
                  r'<link href="\2" color="#52655e"><u>\1</u></link>', text)
    text = re.sub(r'\[([^]]+)\]\(([^)]+)\)', r'\1', text)
    text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<i>\1</i>', text)
    text = re.sub(r'`([^`]+)`', r'<font name="Courier" size="8.6">\1</font>', text)
    return text


def blocks(text):
    for block in text.strip().split('\n\n'):
        if re.match(r'^\d+\. ', block):
            yield from re.split(r'\n(?=\d+\. )', block)
        else:
            yield block


def paragraph(c, text, y, style=STYLE, inset=0):
    item = Paragraph(markup(text.lstrip('> ')), style)
    _, height = item.wrap(W - 2 * MARGIN - inset, H)
    if y - height < 52:
        raise ValueError(f'Page overflow: {text[:60]}')
    item.drawOn(c, MARGIN + inset, y - height)
    return y - height - style.spaceAfter


def frame(c, number, label):
    c.setFillColor(PAPER)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    c.setFillColor(GOLD)
    c.rect(MARGIN, H-36, 25, 2, fill=1, stroke=0)
    c.setFont('Helvetica', 8)
    c.setFillColor(MUTED)
    c.drawString(MARGIN+34, H-37, label.upper())
    c.setStrokeColor(GOLD)
    c.setLineWidth(.4)
    c.line(MARGIN, 37, W-MARGIN, 37)
    c.setFont('Helvetica', 7.5)
    c.drawString(MARGIN, 23, 'THE TAO OF LEELA  /  PROTOTYPE EDITION')
    c.drawRightString(W-MARGIN, 23, f'{number} / 5')


def section(c, title, content, y):
    y = paragraph(c, title, y, TITLE)
    for block in blocks(content):
        y = paragraph(c, block, y, QUOTE if block.startswith('>') else REFERENCE if block.startswith('Background:') else STYLE,
                      10 if block.startswith('>') else 0)
    return y - (14 if "Background:" in content else 8)


def main():
    write_svg()
    source = SOURCE.read_text()
    sections = {}
    for part in source.split('\n## ')[1:]:
        heading, body = part.split('\n', 1)
        sections[heading] = body.strip()
    expected = ['A question opens a path', 'Leela: life as a journey',
                'I Ching: the Book of Changes', 'Dao: the Way',
                'Whose journey will you imagine?', 'One encounter, at your own pace',
                'The journey at a glance', 'AI proposes; the Player chooses', 'Begin a journey']
    if list(sections) != expected:
        raise ValueError('Review page groups after changing pamphlet headings')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=A5)
    c.setTitle('The Tao of Leela - A question opens a path')
    c.setAuthor('Tao of Leela')
    c.setSubject('An introduction to Leela, the I Ching, and contemplation of the Way')

    frame(c, 1, 'An invitation to play')
    c.setFillColor(INK)
    c.setFont('Times-Roman', 43)
    c.drawString(MARGIN, H-108, 'The Tao')
    c.drawString(MARGIN, H-152, 'of Leela')
    y = paragraph(c, 'A question opens a path', H-180, QUOTE)
    for block in blocks(sections[expected[0]]):
        y = paragraph(c, block, y)
    # Decorative circles suggest a shared field; they encode no gameplay rule.
    cy = 116
    c.setStrokeColor(GOLD)
    for radius in (36, 49, 62):
        c.setLineWidth(.5)
        c.circle(W/2, cy, radius, stroke=1, fill=0)
    c.setFillColor(INK)
    c.circle(W/2, cy, 3, stroke=0, fill=1)
    c.showPage()

    frame(c, 2, 'The foundations of the game')
    y = H-65
    for heading in expected[1:4]:
        y = section(c, heading, sections[heading], y)
    c.showPage()

    frame(c, 3, 'The Player and the Persona')
    y = section(c, expected[4], sections[expected[4]], H-65)
    section(c, expected[5], sections[expected[5]], y)
    c.showPage()

    frame(c, 4, 'The live interface flow')
    y = paragraph(c, expected[6], H-65, TITLE)
    figure = interface_flow()
    scale = 360 / figure.height
    figure.scale(scale, scale)
    renderPDF.draw(figure, c, (W - 680*scale)/2, y-360)
    caption = re.sub(r'!\[[^]]*\]\([^)]+\)', '', sections[expected[6]]).strip()
    paragraph(c, caption, y-373, ParagraphStyle('caption', parent=STYLE, fontSize=9, leading=12))
    c.showPage()

    frame(c, 5, 'Begin with curiosity')
    y = section(c, expected[7], sections[expected[7]], H-65)
    y = section(c, expected[8], sections[expected[8]], y)
    y = paragraph(c, 'User Manual: docs/user-manual.md', y, REFERENCE)
    paragraph(c, 'Developer Manual: docs/developer-manual.md', y, REFERENCE)
    c.showPage()
    c.save()
    print(OUTPUT)


if __name__ == '__main__':
    main()
