#!/usr/bin/env node

// Convert VexFlow TypeScript font/metrics files to JSON for use in a Swift package.
// Usage: node convert_fonts.js

const fs = require('fs');
const path = require('path');

const VEXFLOW_FONTS_DIR = path.resolve(__dirname, '../../vexflow/src/fonts');
const OUTPUT_DIR = path.resolve(__dirname, '../Sources/VexFoundation/Resources');

// Map of input .ts filenames to output .json filenames
const FILES = {
  'bravura_glyphs.ts': 'bravura_glyphs.json',
  'gonville_glyphs.ts': 'gonville_glyphs.json',
  'leland_glyphs.ts': 'leland_glyphs.json',
  'petaluma_glyphs.ts': 'petaluma_glyphs.json',
  'custom_glyphs.ts': 'custom_glyphs.json',
  'common_metrics.ts': 'common_metrics.json',
};

// Ensure output directory exists
fs.mkdirSync(OUTPUT_DIR, { recursive: true });

for (const [tsFile, jsonFile] of Object.entries(FILES)) {
  const inputPath = path.join(VEXFLOW_FONTS_DIR, tsFile);
  const outputPath = path.join(OUTPUT_DIR, jsonFile);

  console.log(`Converting ${tsFile} -> ${jsonFile}`);

  const content = fs.readFileSync(inputPath, 'utf8');

  // Strip "export const <Identifier> = " from the beginning and trailing ";" + whitespace
  const objectLiteral = content
    .replace(/^export\s+const\s+\w+\s*=\s*/, '')
    .replace(/;\s*$/, '');

  // eval is safe here because we control the input files (they are from our own repo).
  const obj = eval('(' + objectLiteral + ')');

  const json = JSON.stringify(obj, null, 2);
  fs.writeFileSync(outputPath, json + '\n', 'utf8');

  // Quick validation: parse it back
  JSON.parse(json);

  const stats = fs.statSync(outputPath);
  console.log(`  -> ${outputPath} (${(stats.size / 1024).toFixed(1)} KB)`);
}

console.log('\nDone. All files converted successfully.');
