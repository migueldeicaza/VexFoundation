#!/usr/bin/env python3
"""Summarize upstream SVG parity mismatch artifacts.

Usage:
  tools/parity_report.py [--artifacts DIR] [--min DELTA] [--filter TEXT] [--rows]

For each mismatching case, prints the classification:
  ROWS a vs e   different number of drawing rows (actual vs expected)
  STRUCT        same rows, but a row differs in kind or text content
  <number>      same structure; the largest numeric difference (px)
With --rows, also prints the first differing row (or the max-delta row).
"""
import argparse, collections, glob, os, re

num = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')
ap = argparse.ArgumentParser()
ap.add_argument('--artifacts', default=os.path.join(os.path.dirname(__file__), '..', '.build', 'upstream-svg-parity', 'artifacts'))
ap.add_argument('--min', type=float, default=0.0)
ap.add_argument('--filter', default='')
ap.add_argument('--rows', action='store_true')
args = ap.parse_args()

buckets = collections.Counter()
results = []
for a in sorted(glob.glob(os.path.join(args.artifacts, '*.actual.signature.txt'))):
    name = os.path.basename(a).replace('.actual.signature.txt', '').replace('pptr-', '')
    if args.filter and args.filter not in name:
        continue
    A = open(a).read().split('\n')
    E = open(a.replace('.actual.', '.expected.')).read().split('\n')
    detail = None
    if len(A) != len(E):
        i = 0
        while i < min(len(A), len(E)) and A[i] == E[i]:
            i += 1
        kind, score = 'ROWS %d vs %d' % (len(A), len(E)), 1e9
        detail = (i, A[i] if i < len(A) else '<END>', E[i] if i < len(E) else '<END>')
        buckets['rows'] += 1
    else:
        mx, kind = 0.0, None
        for i, (x, y) in enumerate(zip(A, E)):
            if x == y:
                continue
            if num.sub('#', x) != num.sub('#', y):
                kind, score, detail = 'STRUCT', 1e8, (i, x, y)
                break
            d = max(abs(float(p) - float(q)) for p, q in zip(num.findall(x), num.findall(y)))
            if d > mx:
                mx, detail = d, (i, x, y)
        if kind is None:
            kind, score = '%.3f' % mx, mx
            buckets['<=0.01' if mx <= 0.01 else '<=0.1' if mx <= 0.1 else '<=1' if mx <= 1 else '>1'] += 1
        else:
            buckets['struct'] += 1
    if score >= args.min:
        results.append((score, name, kind, detail))

for score, name, kind, detail in sorted(results, key=lambda r: (-r[0], r[1])):
    print('%-90s %s' % (name, kind))
    if args.rows and detail:
        print('    row %d\n    A %s\n    E %s' % (detail[0], detail[1][:160], detail[2][:160]))
print(dict(buckets))
