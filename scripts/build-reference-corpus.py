#!/usr/bin/env python3
"""Offline, reproducible packaging of the attributed source texts in data/references.
No network or model calls. Hexagrams are keyed by bottom-line-first binary value.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'data/references'
def read(path): return json.loads((ROOT / path).read_text())
def write(path, value): (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
def source(text, ref, author='James Legge', title='The Yî King', year=1882):
    return dict(translationTranslator=author, translationTitle=title, translationYear=year,
                translationCopyrightStatus='public_domain', translationSourceReference=ref, translationText=text)

def build():
    english = read('data/references/sources/legge-judgments-lines.json')['hexagrams']
    images = read('data/references/sources/legge-images.json')
    chinese = (BASE / 'sources/yijing-chinese.txt').read_text()
    sections = re.split(r'第[^\n]+卦', chinese)[1:]
    metadata = read('data/state-view-metadata.json')
    by_number = {h['kingWenNumber']: h for h in metadata['hexagramViews']}
    trigrams = {t['trigramBinary']: t for t in metadata['trigramViews']}
    assert len(sections) == len(english) == len(images) == 64
    hexagrams = []
    for h, section in zip(english, sections):
        n = h['n']; view = by_number[n]; binary = view['binaryValue']
        assert int(h['bits'][::-1], 2) == binary, n
        paragraphs = [re.sub(r'\s+', '', p) for p in re.split(r'\n\s*\n', section) if p.strip()]
        judgment = next(p for p in paragraphs if p.startswith(h['char'] + '：'))
        image = next(p for p in paragraphs if p.startswith('象曰：')).split('。')[0] + '。'
        lines = []
        for pattern in [r'初[九六]', r'[九六]二', r'[九六]三', r'[九六]四', r'[九六]五', r'上[九六]']:
            match = re.search(r'^(' + pattern + r'：[^^\n]*(?:\n[　 ][^\n]+)*)', section, re.M)
            assert match, (n, pattern)
            lines.append(re.sub(r'\s+', '', match[1]))
        assert len(h['lines']) == 6 and all(h['lines']) and h['judgement']
        text = dict(textHexagramNumber=n, textChineseName=h['char'], textPinyin=h['pinyin'],
            textUnicodeSymbol=view['glyph'], textLowerTrigram=trigrams[binary % 8]['naturalImage'],
            textUpperTrigram=trigrams[binary // 8]['naturalImage'], textJudgmentChinese=judgment,
            textImageChinese=image, textLineChinese=lines, textLexicalNotes=[],
            textWorkingTranslation='', textLineWorkingTranslations=[''] * 6,
            textLeggeJudgment=source(h['judgement'],h['ref']),
            textLeggeLines=[source(line, h['ref'] + '#line-' + str(i)) for i,line in enumerate(h['lines'],1)],
            textLeggeImage=source(images[str(n)], 'https://archive.sacred-texts.com/ich/icap2-' + ('1' if n<=30 else '2') + '.htm'),
            textAdditionalChinese=re.search(r'^用[九六]：[^\n]+', section, re.M)[0] if n<=2 else None,
            textAdditionalLegge=source(h['extra'],h['ref']) if h.get('extra') else None)
        hexagrams.append(dict(referenceBinary=binary, referenceText=text))
    gita = (BASE / 'sources/gita-arnold.txt').read_text()
    parts = re.split(r'^\s*CHAPTER [IVXL]+\s*$', gita, flags=re.M)[1:]
    assert len(parts)==18
    chapters=[]
    for n,part in enumerate(parts,1):
        body=part.split('*** END OF')[0].strip()
        # A bounded thematic excerpt is sent to the model; full chapters stay in DB.
        excerpt=body[:2400].rsplit('\n',1)[0].strip()
        chapters.append(dict(chapterNumber=n, chapterSource=source(excerpt,
            f'https://www.gutenberg.org/ebooks/2388 — chapter {n}; opening excerpt; thematic background, not a commentary on numbered Leela squares',
            'Edwin Arnold','The Song Celestial; or Bhagavad-Gîtâ',1885), chapterBody=body))
    states=read('data/leela.json')
    extension=read('data/references/leela-editorial.json')
    combined={s['stateId']:s for s in states}
    for e in extension:
        combined[e['stateId']] = dict(stateId=e['stateId'],stateName=e['name'],stateDescription=e['description'],stateSeed=e['theme'])
    assert sorted(combined)==list(range(1,73))
    entries=[]
    extra={e['stateId']:e for e in extension}
    for s in metadata['stateMetadata']:
        n=s['stateId']; e=extra.get(n)
        entries.append(dict(referenceState=combined[n], referenceCommentary=e['commentary'], referenceCommentarySource='Tao of Leela original editorial commentary (MIT), not a quotation from Harish Johari',
                            referenceChapter=e['chapter'] if e else {1:2,2:4,3:6,4:12,5:16,6:2,7:18,8:18,9:3,10:15}[n]))
    documents=[]
    for ident,file,title,author,year,url,rights in [
      ('yijing-chinese','yijing-chinese.txt','易經','Anonymous',0,'https://www.gutenberg.org/ebooks/25501','public_domain'),
      ('yijing-legge','legge-judgments-lines.json','The Yî King: judgments and line texts','James Legge',1882,'https://scarletbeast.com/lab/oracle/codex/iching.json','public_domain'),
      ('yijing-legge-images','legge-images.json','The Yî King: Appendix II, Great Images','James Legge',1882,'https://archive.sacred-texts.com/ich/icap2-1.htm','public_domain'),
      ('gita-arnold','gita-arnold.txt','The Song Celestial; or Bhagavad-Gîtâ','Edwin Arnold',1885,'https://www.gutenberg.org/ebooks/2388','public_domain')]:
        body=(BASE/'sources'/file).read_text()
        documents.append(dict(documentId=ident,documentTitle=title,documentAuthor=author,documentYear=year,
            documentSource=url,documentRights=rights,documentDigest=hashlib.sha256(body.encode()).hexdigest(),documentBody=body))
    library=dict(referenceVersion='pending',referenceDocuments=documents,
                 referenceHexagrams=sorted(hexagrams,key=lambda h:h['referenceBinary']), referenceLeela=entries, referenceChapters=chapters)
    library['referenceVersion'] = 'public-domain-' + hashlib.sha256(json.dumps(library,ensure_ascii=False,sort_keys=True).encode()).hexdigest()[:16]
    write('data/references/library.json',library)
    write('data/hexagrams.json', [dict(hexagramNumber=h['referenceText']['textHexagramNumber'],
        hexagramName=by_number[h['referenceText']['textHexagramNumber']]['translatedName'],
        judgment=h['referenceText']['textJudgmentChinese'] + '\n' + h['referenceText']['textLeggeJudgment']['translationText'],
        image=h['referenceText']['textImageChinese'] + '\n' + h['referenceText']['textLeggeImage']['translationText'],
        upperTrigram=h['referenceText']['textUpperTrigram'], lowerTrigram=h['referenceText']['textLowerTrigram'])
        for h in sorted(hexagrams,key=lambda h:h['referenceText']['textHexagramNumber'])])
    write('data/leela.json',[combined[n] for n in range(1,73)])
    write('app/public/journey/hexagrams.json', read('data/hexagrams.json'))
    preview = read('app/public/journey/preview.json')
    def refresh(value):
        if isinstance(value, list): return [refresh(item) for item in value]
        if isinstance(value, dict):
            if 'stateName' in value and value.get('stateId') in combined:
                return {**value, **combined[value['stateId']]}
            return {key:refresh(item) for key,item in value.items()}
        return value
    preview = refresh(preview)
    preview['states'] = [combined[n] for n in range(1,73)]
    write('app/public/journey/preview.json', preview)
    return library
if __name__ == '__main__':
    lib=build(); print('Packaged 72 Leela entries, 64 bilingual hexagrams, 384 lines and 18 Gita chapters.')
