"""Presentation labels from Unicode, keyed by the existing binary lookup table.
Source: https://www.unicode.org/charts/nameslist/n_4DC0.html
Existing seed names take precedence in the renderer. No commentary is added.
"""
import json
import re
import unicodedata
from pathlib import Path
source = Path('src/Domain/HexagramIndex.hs').read_text().split('(0, 63)', 1)[1]
ordering = [int(value) for value in re.findall(r'\d+', source)]
assert len(ordering) == 64 and sorted(ordering) == list(range(1, 65))
labels = {str(binary): {'hexagramNumber': number, 'hexagramName': unicodedata.name(chr(0x4DC0 + number - 1)).removeprefix('HEXAGRAM FOR ').title()} for binary, number in enumerate(ordering)}
Path('app/public/journey/hexagram-labels.json').write_text(json.dumps(labels, indent=2) + '\n')
