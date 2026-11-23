#!/usr/bin/env python3
"""Extract the SMuFL metadata that EngravingProfile reads (VexFlow 5.3.0).

Usage:
  tools/extract_smufl_metadata.py [--fonts DIR] [--out DIR]

DIR defaults to ../vexflow-5.4.0/node_modules/@vexflow-fonts. For Bravura,
Petaluma and Leland, it keeps `fontName`, `fontVersion`, `engravingDefaults`
and `glyphsWithAnchors` from `metadata.json` and writes
`Sources/VexFoundation/Resources/smufl/<font>-metadata.json`.
The fonts and their metadata are licensed under the SIL Open Font License 1.1
(see Sources/VexFoundation/Resources/fonts/licenses).
"""
import argparse, json, os

here = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--fonts', default=os.path.join(here, '..', '..', 'vexflow-5.4.0', 'node_modules', '@vexflow-fonts'))
ap.add_argument('--out', default=os.path.join(here, '..', 'Sources', 'VexFoundation', 'Resources', 'smufl'))
args = ap.parse_args()

KEYS = ['fontName', 'fontVersion', 'engravingDefaults', 'glyphsWithAnchors']
for font in ['bravura', 'petaluma', 'leland']:
    with open(os.path.join(args.fonts, font, 'metadata.json'), encoding='utf-8') as f:
        data = json.load(f)
    reduced = {k: data[k] for k in KEYS if k in data}
    path = os.path.join(args.out, font + '-metadata.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(reduced, f, sort_keys=True, separators=(',', ':'))
        f.write('\n')
    print(path, os.path.getsize(path))
