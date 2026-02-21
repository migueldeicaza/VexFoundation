#!/usr/bin/env bash
set -euo pipefail

REFERENCE_DIR="${1:-${VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR:-../vexflow/build/images/reference}}"
OUTPUT_FILE="${2:-.build/upstream-svg-parity/upstream_svg_manifest.json}"

if [[ ! -d "$REFERENCE_DIR" ]]; then
  cat >&2 <<EOF
Missing reference directory: $REFERENCE_DIR
Pass a path explicitly:
  tools/generate_upstream_svg_manifest.sh /path/to/reference/dir [output.json]
or set:
  VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR=/path/to/reference/dir
EOF
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

node - "$REFERENCE_DIR" "$OUTPUT_FILE" <<'NODE'
const fs = require('fs');
const path = require('path');

const referenceDir = process.argv[2];
const outputFile = process.argv[3];
const fontNames = new Set(['Bravura', 'Gonville', 'Petaluma', 'Leland']);

const entries = fs
  .readdirSync(referenceDir)
  .filter((file) => file.startsWith('pptr-') && file.endsWith('.svg'))
  .sort()
  .map((file) => {
    const stem = file.slice('pptr-'.length, -'.svg'.length);
    const parts = stem.split('.');
    const moduleName = parts.shift() || '';

    let font = null;
    if (parts.length > 1 && fontNames.has(parts[parts.length - 1])) {
      font = parts.pop();
    }

    const testName = parts.join('.');
    return {
      module: moduleName,
      test: testName,
      font,
      filename: file,
    };
  });

const moduleCounts = {};
for (const entry of entries) {
  moduleCounts[entry.module] = (moduleCounts[entry.module] || 0) + 1;
}

const payload = {
  generatedAt: new Date().toISOString(),
  referenceDir: path.resolve(referenceDir),
  count: entries.length,
  moduleCount: Object.keys(moduleCounts).length,
  moduleCounts,
  entries,
};

fs.writeFileSync(outputFile, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
console.log(`Wrote ${entries.length} SVG reference entries to ${outputFile}`);
NODE
