"""Shared, vector UI-flow figure for Markdown and both PDF publications.

Coordinates use a top-left origin. Arrows show the live guided journey;
side notes describe navigation that is available across stages.
Run this module to regenerate docs/diagrams/user-interface-flow.svg.
"""
from pathlib import Path
from reportlab.graphics.shapes import Drawing, Rect, Line, String, Polygon, Circle
from reportlab.graphics import renderSVG
from reportlab.lib.colors import HexColor
import math

WIDTH, HEIGHT = 680, 790
INK = HexColor('#183d38')
GOLD = HexColor('#a87b39')
PALE = HexColor('#edf2ed')
WHITE = HexColor('#ffffff')


def interface_flow():
    d = Drawing(WIDTH, HEIGHT)
    def text(x,y,value,size=16,bold=False,anchor='middle'):
        d.add(String(x, HEIGHT-y, value, fontName='Helvetica-Bold' if bold else 'Helvetica', fontSize=size, fillColor=INK, textAnchor=anchor))
    def box(x,y,w,h,lines,fill=PALE):
        d.add(Rect(x,HEIGHT-y-h,w,h,rx=7,ry=7,strokeColor=INK,strokeWidth=1,fillColor=fill))
        first=y+h/2-(len(lines)-1)*10+5
        for i,label in enumerate(lines):text(x+w/2,first+20*i,label,16 if i==0 else 14,i==0)
    def arrow(points,dashed=False):
        for (x1,y1),(x2,y2) in zip(points,points[1:]):
            d.add(Line(x1,HEIGHT-y1,x2,HEIGHT-y2,strokeColor=GOLD,strokeWidth=1.6,strokeDashArray=[5,4] if dashed else None))
        (x1,y1),(x2,y2)=points[-2:]
        angle=math.atan2(y2-y1,x2-x1)
        pts=[x2,HEIGHT-y2]
        for delta in (-.48,.48):pts.extend([x2-9*math.cos(angle+delta),HEIGHT-(y2-9*math.sin(angle+delta))])
        d.add(Polygon(pts,strokeColor=GOLD,fillColor=GOLD))
    # Schematic screen artwork stays vector-sharp in both print formats.
    def stroke(x1,y1,x2,y2,color=INK,width=1):
        d.add(Line(x1,HEIGHT-y1,x2,HEIGHT-y2,strokeColor=color,strokeWidth=width))
    def board(x,y):
        text(x+59,y+12,'Leela board',14,True)
        for row in range(8):
            for col in range(9):
                bx,by=x+col*13,y+23+row*11
                d.add(Rect(bx,HEIGHT-by-11,13,11,strokeColor=GOLD,strokeWidth=.5,
                           fillColor=PALE if (row+col)%2 else WHITE))
        d.add(Circle(x+6.5,HEIGHT-(y+105.5),3.5,fillColor=INK,strokeColor=None))
        text(x+59,y+127,'Splash screen',13)
    board(12,0)
    stroke(130,40,152,40,GOLD)
    # Stalk bundles and a divided working pile evoke the casting ceremony.
    text(73,279,'Yarrow stalks',14,True)
    for i in range(9):
        stroke(19+i*4,299+(i%3)*3,23+i*4,360+(i%2)*3,GOLD,2)
    for i in range(8):
        stroke(82+i*4,299+(i%2)*3,75+i*4,363-(i%3)*3,GOLD,2)
    stroke(28,333,53,333,INK,2)
    stroke(79,333,107,333,INK,2)
    text(73,387,'Divide and count',13)
    stroke(124,342,152,342,GOLD)
    def hexagram(x,y,bits):
        for i,bit in enumerate(reversed(bits)):
            yy=y+i*10
            if bit:stroke(x,yy,x+49,yy,INK,4)
            else:
                stroke(x,yy,x+20,yy,INK,4)
                stroke(x+29,yy,x+49,yy,INK,4)
    text(593,320,'Six-line hexagrams',14,True)
    hexagram(530,341,[1,0,1,0,1,0])
    hexagram(609,341,[1,0,1,1,1,0])
    arrow([(585,365),(603,365)])
    text(555,413,'Primary',13)
    text(634,413,'Relating',13)
    text(593,435,'Illustrative casting',12)
    stroke(498,407,521,407,GOLD)
    # A notebook grounds the reflection step in the Player's own writing.
    d.add(Rect(22,HEIGHT-583,102,87,rx=4,ry=4,fillColor=WHITE,strokeColor=GOLD))
    stroke(73,502,73,578,GOLD)
    for yy in (514,527,540,553,566):
        stroke(30,yy,64,yy,INK,.8)
        stroke(82,yy,116,yy,INK,.8)
    text(73,605,'Your reflection',14,True)
    stroke(126,555,140,555,GOLD)
    rows=[
        ('Splash: Sign Up / Log In', 'Enter from the Leela board'),
        ('Choose a Persona', 'Select an active identity'),
        ('Resume selected Persona', 'Restore its saved stage'),
        ('Progress', 'Current state and possible moves'),
        ('Prepare the question', 'Write, edit or use a saved suggestion'),
        ('Begin Casting / Next', 'Question fixed; build six lines'),
        ('See the Hexagram', 'Completed casting is recorded'),
        ('Interpretation', 'Read saved output or request AI'),
        ('Reflection', 'Journal; Save / Continue'),
        ('Movement review', 'Continue the Journey: update position'),
    ]
    x,w,h=158,334,48
    ys=[16+65*i for i in range(len(rows))]
    for i,(title,sub) in enumerate(rows):
        box(x,ys[i],w,h,[title,sub])
        if i<len(rows)-1:
            arrow([(x+w/2,ys[i]+h),(x+w/2,ys[i+1])],dashed=i==2)
    # Creation returns to selection; Resume is a separate Player action.
    box(520,81,148,48,['Create Persona','Name and context'])
    arrow([(492,94),(520,94)])
    arrow([(520,118),(506,118),(506,139),(475,139),(475,129)])
    text(592,158,'Then select Resume',13)
    # A continuing encounter resumes at its accepted stage, not necessarily Progress.
    box(5,149,133,98,['Saved encounter','returns to its','current stage.','New: Progress.'],WHITE)
    # Optional assistance never gates reflection.
    box(520,461,148,78,['AI is optional','Reflect without AI','or continue after','reading.'],WHITE)
    arrow([(492,495),(520,495)],dashed=True)
    arrow([(520,525),(507,525),(507,557),(492,557)],dashed=True)
    # The live game has an ongoing cycle, not an implemented terminal screen.
    arrow([(158,625),(145,625),(145,235),(158,235)])
    text(135,433,'Next encounter',14,anchor='end')
    # Cross-stage navigation is explained without implying game-stage transitions.
    box(12,677,656,100,[
        'Available throughout the active journey',
        'Pause / Resume: return to the saved stage. History: inspect and return.',
        'Personas: save pending edits and switch independent journeys.',
        'Edit / inspect / archive on selection. Log out: sign in to return.',
    ],WHITE)
    return d


def write_svg():
    path=Path(__file__).resolve().parents[1]/'docs/diagrams/user-interface-flow.svg'
    path.parent.mkdir(parents=True,exist_ok=True)
    renderSVG.drawToFile(interface_flow(),str(path))
    print(path)


if __name__=='__main__':write_svg()
