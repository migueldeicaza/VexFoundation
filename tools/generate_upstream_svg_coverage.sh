#!/usr/bin/env bash
set -euo pipefail

REFERENCE_DIR="${VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR:-}"
TESTS_INPUT="Tests/VexFoundationTests/UpstreamSVGParityTests*.swift"
OUT_MD="docs/upstream-svg-coverage.md"
OUT_JSON=".build/upstream-svg-parity/upstream_svg_coverage.json"
CHECK_MODE=0
PARITY_MODE="${VEXFOUNDATION_UPSTREAM_SVG_PARITY_MODE:-strict}"
SIGNATURE_EPSILON="${VEXFOUNDATION_UPSTREAM_SVG_SIGNATURE_EPSILON:-}"

usage() {
  cat <<'EOF'
Usage:
  tools/generate_upstream_svg_coverage.sh [options]

Options:
  --reference-dir <path>  Override upstream SVG reference folder.
  --tests-file <path|glob>
                          Swift parity test file(s) to scan.
                          Default: Tests/VexFoundationTests/UpstreamSVGParityTests*.swift
  --out-md <path>         Markdown report output path.
  --out-json <path>       JSON report output path.
  --parity-mode <mode>    strict|tolerant (for report metadata).
  --signature-epsilon <n> Numeric epsilon metadata for tolerant mode.
  --check                 Verify outputs are up to date (no writes).
  -h, --help              Show help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reference-dir)
      REFERENCE_DIR="$2"
      shift 2
      ;;
    --tests-file)
      TESTS_INPUT="$2"
      shift 2
      ;;
    --out-md)
      OUT_MD="$2"
      shift 2
      ;;
    --out-json)
      OUT_JSON="$2"
      shift 2
      ;;
    --parity-mode)
      PARITY_MODE="$2"
      shift 2
      ;;
    --signature-epsilon)
      SIGNATURE_EPSILON="$2"
      PARITY_MODE="tolerant"
      shift 2
      ;;
    --check)
      CHECK_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$PARITY_MODE" in
  strict|tolerant) ;;
  *)
    echo "Invalid --parity-mode value: $PARITY_MODE" >&2
    exit 1
    ;;
esac

if [[ -n "$SIGNATURE_EPSILON" ]]; then
  if ! [[ "$SIGNATURE_EPSILON" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Invalid --signature-epsilon value: $SIGNATURE_EPSILON" >&2
    exit 1
  fi
fi

if [[ "$PARITY_MODE" == "tolerant" && -z "$SIGNATURE_EPSILON" ]]; then
  SIGNATURE_EPSILON="0.005"
fi

if [[ -z "$REFERENCE_DIR" ]]; then
  if [[ -d ../vexmotion/build/images/reference ]]; then
    REFERENCE_DIR="../vexmotion/build/images/reference"
  elif [[ -d ../vexflow/build/images/reference ]]; then
    REFERENCE_DIR="../vexflow/build/images/reference"
  else
    cat >&2 <<'EOF'
Unable to locate reference SVGs.
Expected one of:
  ../vexmotion/build/images/reference
  ../vexflow/build/images/reference
Pass --reference-dir explicitly.
EOF
    exit 1
  fi
fi

if [[ ! -d "$REFERENCE_DIR" ]]; then
  echo "Missing reference directory: $REFERENCE_DIR" >&2
  exit 1
fi

resolve_tests_files() {
  local input="$1"

  if [[ -f "$input" ]]; then
    printf '%s\n' "$input"
    return
  fi

  if [[ -d "$input" ]]; then
    find "$input" -maxdepth 1 -type f -name 'UpstreamSVGParityTests*.swift' -print
    return
  fi

  shopt -s nullglob
  local matches=($input)
  shopt -u nullglob
  printf '%s\n' "${matches[@]}"
}

TESTS_FILES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && TESTS_FILES+=("$line")
done < <(resolve_tests_files "$TESTS_INPUT" | LC_ALL=C sort)

if [[ "${#TESTS_FILES[@]}" -eq 0 ]]; then
  cat >&2 <<EOF
No parity test files matched: $TESTS_INPUT
Pass --tests-file explicitly with a file path or glob.
EOF
  exit 1
fi

tmp_md="$(mktemp)"
tmp_json="$(mktemp)"
tmp_tests="$(mktemp)"
cleanup() {
  rm -f "$tmp_md" "$tmp_json" "$tmp_tests"
}
trap cleanup EXIT

printf '%s\n' "${TESTS_FILES[@]}" > "$tmp_tests"

node - "$REFERENCE_DIR" "$tmp_tests" "$tmp_md" "$tmp_json" "$PARITY_MODE" "$SIGNATURE_EPSILON" <<'NODE'
const fs = require('fs');
const path = require('path');

const [referenceDir, testsListFile, outMd, outJson, parityMode, signatureEpsilonRaw] = process.argv.slice(2);
const knownFonts = new Set(['Bravura', 'Gonville', 'Petaluma', 'Leland']);
const signatureEpsilon = signatureEpsilonRaw ? Number(signatureEpsilonRaw) : 0;

const testsFiles = fs
  .readFileSync(testsListFile, 'utf8')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);
if (testsFiles.length === 0) {
  throw new Error(`No tests files listed in: ${testsListFile}`);
}
for (const file of testsFiles) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing tests file: ${file}`);
  }
}

function caseModule(caseName) {
  const i = caseName.indexOf('.');
  return i === -1 ? caseName : caseName.slice(0, i);
}

const referenceFiles = fs
  .readdirSync(referenceDir)
  .filter((file) => file.startsWith('pptr-') && file.endsWith('.svg'))
  .sort();

const referenceByCase = new Map();
for (const file of referenceFiles) {
  const stem = file.slice('pptr-'.length, -'.svg'.length);
  const parts = stem.split('.');
  const moduleName = parts.shift() || '';
  if (!moduleName || parts.length === 0) continue;

  let font = null;
  if (parts.length > 1 && knownFonts.has(parts[parts.length - 1])) {
    font = parts.pop();
  }

  const testName = parts.join('.');
  if (!testName) continue;

  const caseName = `${moduleName}.${testName}`;
  if (!referenceByCase.has(caseName)) {
    referenceByCase.set(caseName, {
      case: caseName,
      module: moduleName,
      test: testName,
      fonts: new Set(),
      files: 0,
    });
  }
  const entry = referenceByCase.get(caseName);
  if (font) entry.fonts.add(font);
  entry.files += 1;
}

const referenceCases = [...referenceByCase.values()]
  .map((entry) => ({
    case: entry.case,
    module: entry.module,
    test: entry.test,
    files: entry.files,
    fonts: [...entry.fonts].sort(),
  }))
  .sort((a, b) => a.case.localeCompare(b.case));

const testRegex = /@Test\("([^"]+)"\)/g;
const implementedSet = new Set();
for (const testsFile of testsFiles) {
  const swiftSource = fs.readFileSync(testsFile, 'utf8');
  for (const match of swiftSource.matchAll(testRegex)) {
    implementedSet.add(match[1]);
  }
}
const implementedCases = [...implementedSet].sort((a, b) => a.localeCompare(b));

const referenceCaseNames = referenceCases.map((entry) => entry.case);
const referenceSet = new Set(referenceCaseNames);

const coveredCases = implementedCases.filter((name) => referenceSet.has(name));
const missingCases = referenceCaseNames.filter((name) => !implementedSet.has(name));
const extraCases = implementedCases.filter((name) => !referenceSet.has(name));

const moduleStats = new Map();
for (const ref of referenceCases) {
  if (!moduleStats.has(ref.module)) {
    moduleStats.set(ref.module, {
      module: ref.module,
      referenceCases: 0,
      implementedCases: 0,
      coveredCases: 0,
      missingCases: 0,
    });
  }
  moduleStats.get(ref.module).referenceCases += 1;
}
for (const implemented of implementedCases) {
  const module = caseModule(implemented);
  if (!moduleStats.has(module)) {
    moduleStats.set(module, {
      module,
      referenceCases: 0,
      implementedCases: 0,
      coveredCases: 0,
      missingCases: 0,
    });
  }
  moduleStats.get(module).implementedCases += 1;
  if (referenceSet.has(implemented)) {
    moduleStats.get(module).coveredCases += 1;
  }
}
for (const stat of moduleStats.values()) {
  stat.missingCases = Math.max(0, stat.referenceCases - stat.coveredCases);
}

const moduleRows = [...moduleStats.values()].sort((a, b) => {
  if (b.referenceCases !== a.referenceCases) return b.referenceCases - a.referenceCases;
  return a.module.localeCompare(b.module);
});

const coveragePct = referenceCases.length === 0
  ? 100
  : (coveredCases.length / referenceCases.length) * 100;

const payload = {
  referenceDir: path.resolve(referenceDir),
  testsFile: path.resolve(testsFiles[0]),
  testsFiles: testsFiles.map((file) => path.resolve(file)),
  summary: {
    referenceSvgFiles: referenceFiles.length,
    referenceCases: referenceCases.length,
    implementedCases: implementedCases.length,
    coveredCases: coveredCases.length,
    missingCases: missingCases.length,
    extraCases: extraCases.length,
    coveragePercent: Number(coveragePct.toFixed(2)),
    parityComparisonMode: parityMode,
    signatureEpsilon: Number(signatureEpsilon.toFixed(6)),
  },
  moduleCoverage: moduleRows,
  implementedCases,
  coveredCases,
  missingCases,
  extraCases,
};

const lines = [];
lines.push('# Upstream SVG Reference Coverage');
lines.push('');
lines.push('Generated by: `tools/generate_upstream_svg_coverage.sh`');
lines.push('');
lines.push(`- Reference dir: \`${path.resolve(referenceDir)}\``);
lines.push(`- Parity test sources: \`${testsFiles.length}\` file(s)`);
lines.push(`- Comparison mode: \`${parityMode}\``);
if (parityMode === 'tolerant') {
  lines.push(`- Signature epsilon: \`${payload.summary.signatureEpsilon}\``);
}
for (const testsFile of testsFiles) {
  lines.push(`  - \`${path.resolve(testsFile)}\``);
}
lines.push('');
lines.push('## Snapshot');
lines.push('');
lines.push('| Metric | Value |');
lines.push('|---|---:|');
lines.push(`| Reference SVG files | ${payload.summary.referenceSvgFiles} |`);
lines.push(`| Reference cases (module.test) | ${payload.summary.referenceCases} |`);
lines.push(`| Implemented parity tests | ${payload.summary.implementedCases} |`);
lines.push(`| Covered reference cases | ${payload.summary.coveredCases} |`);
lines.push(`| Missing reference cases | ${payload.summary.missingCases} |`);
lines.push(`| Extra implemented cases (no reference SVG) | ${payload.summary.extraCases} |`);
lines.push(`| Coverage | ${payload.summary.coveragePercent.toFixed(2)}% |`);
lines.push(`| Comparison mode | ${payload.summary.parityComparisonMode} |`);
lines.push(`| Signature epsilon | ${payload.summary.signatureEpsilon} |`);
lines.push('');
lines.push('## Coverage By Module');
lines.push('');
lines.push('| Module | Reference | Implemented | Covered | Missing |');
lines.push('|---|---:|---:|---:|---:|');
for (const row of moduleRows) {
  lines.push(
    `| \`${row.module}\` | ${row.referenceCases} | ${row.implementedCases} | ${row.coveredCases} | ${row.missingCases} |`
  );
}
lines.push('');
lines.push('## Missing Reference Cases');
lines.push('');
if (missingCases.length === 0) {
  lines.push('None.');
} else {
  lines.push('```text');
  lines.push(...missingCases);
  lines.push('```');
}
lines.push('');
lines.push('## Extra Implemented Cases (No Matching Reference)');
lines.push('');
if (extraCases.length === 0) {
  lines.push('None.');
} else {
  lines.push('```text');
  lines.push(...extraCases);
  lines.push('```');
}
lines.push('');

fs.mkdirSync(path.dirname(outMd), { recursive: true });
fs.mkdirSync(path.dirname(outJson), { recursive: true });
fs.writeFileSync(outMd, `${lines.join('\n')}\n`, 'utf8');
fs.writeFileSync(outJson, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
NODE

if [[ "$CHECK_MODE" -eq 1 ]]; then
  stale=0
  if [[ ! -f "$OUT_MD" ]] || ! cmp -s "$tmp_md" "$OUT_MD"; then
    echo "Coverage markdown is out of date: $OUT_MD" >&2
    stale=1
  fi
  if [[ ! -f "$OUT_JSON" ]] || ! cmp -s "$tmp_json" "$OUT_JSON"; then
    echo "Coverage JSON is out of date: $OUT_JSON" >&2
    stale=1
  fi
  if [[ "$stale" -ne 0 ]]; then
    exit 1
  fi
  echo "Upstream SVG coverage report is up to date."
  exit 0
fi

mkdir -p "$(dirname "$OUT_MD")" "$(dirname "$OUT_JSON")"
mv "$tmp_md" "$OUT_MD"
mv "$tmp_json" "$OUT_JSON"
echo "Wrote markdown coverage report to $OUT_MD"
echo "Wrote JSON coverage report to $OUT_JSON"
