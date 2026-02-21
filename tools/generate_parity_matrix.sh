#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="${VF_UPSTREAM_DIR:-$ROOT_DIR/../vexflow}"
UPSTREAM_INDEX="$UPSTREAM_DIR/src/index.ts"
UPSTREAM_TESTS_DIR="$UPSTREAM_DIR/tests"

CHECK_MODE=0
if [ "${1:-}" = "--check" ]; then
  CHECK_MODE=1
  shift
fi

OUT_FILE="${1:-$ROOT_DIR/docs/parity-matrix.md}"
TMP_OUT="$(mktemp)"
TMP_MODULES="$(mktemp)"
TMP_TOPICS="$(mktemp)"
TMP_SWIFT_INDEX="$(mktemp)"

cleanup() {
  rm -f "$TMP_OUT" "$TMP_MODULES" "$TMP_TOPICS" "$TMP_SWIFT_INDEX"
}
trap cleanup EXIT

if [ ! -f "$UPSTREAM_INDEX" ]; then
  echo "error: missing upstream index at $UPSTREAM_INDEX" >&2
  echo "set VF_UPSTREAM_DIR to your vexflow checkout" >&2
  exit 1
fi

if [ ! -d "$UPSTREAM_TESTS_DIR" ]; then
  echo "error: missing upstream tests directory at $UPSTREAM_TESTS_DIR" >&2
  echo "set VF_UPSTREAM_DIR to your vexflow checkout" >&2
  exit 1
fi

find "$ROOT_DIR/Sources/VexFoundation" -name '*.swift' -type f \
  | sed "s|^$ROOT_DIR/||" \
  | sort \
  | while IFS= read -r rel_path; do
      base_name="$(basename "$rel_path" .swift | tr '[:upper:]' '[:lower:]')"
      if ! grep -q "^${base_name}|" "$TMP_SWIFT_INDEX"; then
        printf '%s|%s\n' "$base_name" "$rel_path" >> "$TMP_SWIFT_INDEX"
      fi
    done

rg -o "from './[^']+'" "$UPSTREAM_INDEX" \
  | sed "s|from './||; s|'$||" \
  | sort -u > "$TMP_MODULES"

find "$UPSTREAM_TESTS_DIR" -name '*_tests.ts' -type f \
  | sed 's|.*/||' \
  | sed 's|_tests\.ts$||' \
  | sort > "$TMP_TOPICS"

module_path_for() {
  local module="$1"
  local path
  path="$(grep "^${module}|" "$TMP_SWIFT_INDEX" | head -n 1 | cut -d'|' -f2-)"
  printf '%s' "$path"
}

module_status_for() {
  local module="$1"
  local direct_path mapped_module mapped_path

  case "$module" in
    canvascontext|renderer|svgcontext|web)
      printf 'omitted|Intentional out-of-core browser runtime module'
      return
      ;;
  esac

  mapped_module=''
  case "$module" in
    font) mapped_module='vexfont' ;;
    stavebarline) mapped_module='barline' ;;
    stavevolta) mapped_module='volta' ;;
    strokes) mapped_module='stroke' ;;
    *) mapped_module='' ;;
  esac

  direct_path="$(module_path_for "$module")"
  if [ -n "$direct_path" ]; then
    printf 'implemented|`%s`' "$direct_path"
    return
  fi

  if [ -n "$mapped_module" ]; then
    mapped_path="$(module_path_for "$mapped_module")"
    if [ -n "$mapped_path" ]; then
      printf 'implemented|Mapped to `%s`' "$mapped_path"
      return
    fi
  fi

  printf 'missing|No first-class counterpart in current core package'
}

topic_status_for() {
  local topic="$1"

  case "$topic" in
    offscreencanvas|renderer)
      printf 'omitted|Intentional out-of-core browser runtime surface'
      return
      ;;
  esac

  case "$topic" in
    accidental|annotation|articulation|auto_beam_formatting|bach|barline|beam|bend|boundingbox|boundingboxcomputation|chordsymbol|clef|crossbeam|curve|dot|easyscore|factory|font|formatter|fraction|ghostnote|glyphnote|gracenote|gracetabnote|key_clef|keymanager|keysignature|modifier|multimeasurerest|music|notehead|notesubgroup|ornament|parser|pedalmarking|percussion|registry|rests|rhythm|stave|staveconnector|stavehairpin|staveline|stavemodifier|stavenote|stavetie|stringnumber|strokes|style|tabnote|tabslide|tabstave|tabtie|textbracket|textformatter|textnote|threevoice|tickcontext|timesignature|tremolo|tuning|tuplet|typeguard|unison|vf_prefix|vibrato|vibratobracket|voice)
      printf 'covered|Covered by category-based suites in `Tests/VexFoundationTests`'
      return
      ;;
  esac

  printf 'missing|No dedicated counterpart suite currently tracked'
}

topic_correspondence_for() {
  local topic="$1"

  case "$topic" in
    accidental|articulation|beam|auto_beam_formatting|crossbeam)
      printf 'Accidental, Beam & Articulation|`AccidentalBeamArticulationTests.swift`'
      return
      ;;
    annotation|ghostnote)
      printf 'Note Types & Annotation|`NoteTypesAnnotationTests.swift`'
      return
      ;;
    bach)
      printf 'Bach Demo|`BachDemoParityTests.swift`'
      return
      ;;
    barline|stave|stavemodifier|timesignature)
      printf 'Stave System|`StaveTests.swift`'
      return
      ;;
    clef|keysignature)
      printf 'Key Signature & Clef Parity|`KeyClefParityTests.swift`'
      return
      ;;
    bend|stringnumber|strokes)
      printf 'Bend, StringNumber, Stroke Parity|`BendStringNumberStrokeParityTests.swift`'
      return
      ;;
    keymanager|music|tuning)
      printf 'Music, KeyManager, Tuning Parity|`MusicKeyManagerTuningParityTests.swift`'
      return
      ;;
    boundingbox|boundingboxcomputation)
      printf 'BoundingBox|`BoundingBoxTests.swift`'
      return
      ;;
    chordsymbol|gracetabnote|tabnote|tabslide|tabstave|tabtie)
      printf 'TabStave, TabNote, TabTie, TabSlide, GraceTabNote, ChordSymbol|`TablatureAndChordSymbolTests.swift`'
      return
      ;;
    curve|stavetie|tuplet)
      printf 'StaveTie, Curve & Tuplet|`StaveTieCurveTupletTests.swift`'
      return
      ;;
    dot|stavenote)
      printf 'StaveNote System|`StaveNoteTests.swift`'
      return
      ;;
    formatter|tickcontext|voice)
      printf 'Voice, Formatter, TickContext Parity|`VoiceFormatterTickContextParityTests.swift`'
      return
      ;;
    easyscore|factory|parser|registry|system)
      printf 'Parser, Factory, EasyScore, Registry, System Parity|`ParserFactoryEasyScoreRegistrySystemParityTests.swift`'
      return
      ;;
    font)
      printf 'VexFont|`VexFontTests.swift`'
      return
      ;;
    fraction)
      printf 'Fraction Parity|`FractionParityTests.swift`'
      return
      ;;
    frethandfinger)
      printf 'FretHandFinger Parity|`FretHandFingerParityTests.swift`'
      return
      ;;
    glyphnote)
      printf 'Glyph System|`GlyphTests.swift`'
      return
      ;;
    gracenote|pedalmarking|staveline|textbracket|textdynamics)
      printf 'GraceNote, Dynamics, Brackets & Lines|`GraceNoteDynamicsBracketsLinesTests.swift`'
      return
      ;;
    key_clef)
      printf 'Key Signature & Clef Parity|`KeyClefParityTests.swift`'
      return
      ;;
    modifier|multimeasurerest|notesubgroup|parenthesis|vibrato|vibratobracket)
      printf 'NoteSubGroup, BarNote, Vibrato, VibratoBracket, Parenthesis, Crescendo, MultiMeasureRest|`NoteSubGroupBarNoteVibratoParenthesisMMRTests.swift`'
      return
      ;;
    notehead)
      printf 'Note System|`NoteTests.swift`'
      return
      ;;
    offscreencanvas|renderer)
      printf '%s' '-|-'
      return
      ;;
    ornament|staveconnector|stavehairpin|tremolo)
      printf 'Ornament, Tremolo, Hairpin & Connector|`OrnamentTremoloHairpinConnectorTests.swift`'
      return
      ;;
    percussion)
      printf 'Percussion|`PercussionParityTests.swift`'
      return
      ;;
    rests|rhythm|threevoice|unison)
      printf 'Rests, Rhythm, Three-Voice & Unison|`RestsRhythmThreeVoiceUnisonTests.swift`'
      return
      ;;
    style)
      printf 'Style|`StyleParityTests.swift`'
      return
      ;;
    textformatter|textnote)
      printf 'Text Formatter|`TextFormatterParityTests.swift`'
      return
      ;;
    typeguard|vf_prefix)
      printf 'TypeGuard & vf_prefix|`TypeGuardVfPrefixParityTests.swift`'
      return
      ;;
  esac

  printf '%s' '-|-'
}

module_total="$(wc -l < "$TMP_MODULES" | tr -d ' ')"
topic_total="$(wc -l < "$TMP_TOPICS" | tr -d ' ')"
source_file_total="$(find "$ROOT_DIR/Sources/VexFoundation" -name '*.swift' -type f | wc -l | tr -d ' ')"
test_file_total="$(find "$ROOT_DIR/Tests/VexFoundationTests" -name '*.swift' -type f | wc -l | tr -d ' ')"

implemented_count=0
partial_count=0
omitted_count=0
missing_count=0

covered_topics=0
partial_topics=0
omitted_topics=0
missing_topics=0

{
  echo "# VexFlow -> VexFoundation Parity Matrix"
  echo
  echo 'Generated by: `tools/generate_parity_matrix.sh`'
  echo
  echo "## Snapshot"
  echo
  echo "| Metric | Value |"
  echo "|---|---:|"
  echo "| VexFlow exported modules (from \`src/index.ts\`) | $module_total |"
  echo "| VexFoundation Swift source files | $source_file_total |"
  echo "| VexFlow test topics (\`*_tests.ts\`) | $topic_total |"
  echo "| VexFoundation test files | $test_file_total |"
  echo
  echo "## Module Parity"
  echo
  echo "| Upstream Module | Status | Evidence / Note |"
  echo "|---|---|---|"

  while IFS= read -r module; do
    status_note="$(module_status_for "$module")"
    status="$(printf '%s' "$status_note" | cut -d'|' -f1)"
    note="$(printf '%s' "$status_note" | cut -d'|' -f2-)"

    case "$status" in
      implemented) implemented_count=$((implemented_count + 1)) ;;
      partial) partial_count=$((partial_count + 1)) ;;
      omitted) omitted_count=$((omitted_count + 1)) ;;
      missing) missing_count=$((missing_count + 1)) ;;
    esac

    case "$status" in
      implemented) status_label='implemented' ;;
      partial) status_label='partial' ;;
      omitted) status_label='omitted (intentional)' ;;
      missing) status_label='missing' ;;
      *) status_label="$status" ;;
    esac

    printf '| `%s` | %s | %s |\n' "$module" "$status_label" "$note"
  done < "$TMP_MODULES"

  echo
  echo "## Module Summary"
  echo
  echo "| Status | Count |"
  echo "|---|---:|"
  echo "| implemented | $implemented_count |"
  echo "| partial | $partial_count |"
  echo "| omitted (intentional) | $omitted_count |"
  echo "| missing | $missing_count |"

  echo
  echo "## Test Topic Parity"
  echo
  echo "| Upstream Topic | Status | Local Suite | Test File | Evidence / Note |"
  echo "|---|---|---|---|---|"

  while IFS= read -r topic; do
    status_note="$(topic_status_for "$topic")"
    status="$(printf '%s' "$status_note" | cut -d'|' -f1)"
    note="$(printf '%s' "$status_note" | cut -d'|' -f2-)"
    mapping="$(topic_correspondence_for "$topic")"
    local_suite="$(printf '%s' "$mapping" | cut -d'|' -f1)"
    test_file="$(printf '%s' "$mapping" | cut -d'|' -f2-)"

    case "$status" in
      covered) covered_topics=$((covered_topics + 1)) ;;
      partial) partial_topics=$((partial_topics + 1)) ;;
      omitted) omitted_topics=$((omitted_topics + 1)) ;;
      missing) missing_topics=$((missing_topics + 1)) ;;
    esac

    case "$status" in
      covered) status_label='covered' ;;
      partial) status_label='partial' ;;
      omitted) status_label='omitted (intentional)' ;;
      missing) status_label='missing' ;;
      *) status_label="$status" ;;
    esac

    printf '| `%s` | %s | %s | %s | %s |\n' "$topic" "$status_label" "$local_suite" "$test_file" "$note"
  done < "$TMP_TOPICS"

  echo
  echo "## Test Topic Summary"
  echo
  echo "| Status | Count |"
  echo "|---|---:|"
  echo "| covered | $covered_topics |"
  echo "| partial | $partial_topics |"
  echo "| omitted (intentional) | $omitted_topics |"
  echo "| missing | $missing_topics |"

  echo
  echo "## Notes"
  echo
  echo "- This matrix is intentionally conservative and uses curated status mapping for renamed/integrated modules and parity suites."
  echo '- Run `tools/generate_parity_matrix.sh` after parity-related changes.'
  echo '- CI freshness check can use `tools/generate_parity_matrix.sh --check`.'
} > "$TMP_OUT"

if [ "$CHECK_MODE" -eq 1 ]; then
  if [ ! -f "$OUT_FILE" ]; then
    echo "parity matrix missing: $OUT_FILE" >&2
    exit 1
  fi
  if ! cmp -s "$TMP_OUT" "$OUT_FILE"; then
    echo "parity matrix out of date: $OUT_FILE" >&2
    echo "run: tools/generate_parity_matrix.sh" >&2
    diff -u "$OUT_FILE" "$TMP_OUT" || true
    exit 1
  fi
  echo "parity matrix is up to date: $OUT_FILE"
  exit 0
fi

mkdir -p "$(dirname "$OUT_FILE")"
cp "$TMP_OUT" "$OUT_FILE"
echo "wrote $OUT_FILE"
