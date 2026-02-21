#!/usr/bin/env bash
set -euo pipefail

REFERENCE_DIR="${VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR:-}"
FILTER="UpstreamSVGParityTests"
FONTS="${VEXFOUNDATION_UPSTREAM_SVG_FONTS:-}"
ARTIFACTS_DIR="${VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR:-.build/upstream-svg-parity/artifacts}"
MANIFEST_PATH="${VEXFOUNDATION_UPSTREAM_SVG_MANIFEST_PATH:-.build/upstream-svg-parity/upstream_svg_manifest.json}"

usage() {
  cat <<'EOF'
Usage:
  tools/upstream_svg_parity.sh [options]

Options:
  --reference-dir <path>   Override upstream SVG reference folder.
  --font <name[,name...]>  Restrict tested fonts (Bravura,Gonville,Petaluma,Leland).
  --filter <swift-filter>  Pass-through test filter (default: UpstreamSVGParityTests).
  --artifacts-dir <path>   Directory for mismatch artifacts.
  --no-manifest            Skip manifest generation.
  -h, --help               Show help.
EOF
}

GENERATE_MANIFEST=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reference-dir)
      REFERENCE_DIR="$2"
      shift 2
      ;;
    --font)
      FONTS="$2"
      shift 2
      ;;
    --filter)
      FILTER="$2"
      shift 2
      ;;
    --artifacts-dir)
      ARTIFACTS_DIR="$2"
      shift 2
      ;;
    --no-manifest)
      GENERATE_MANIFEST=0
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

mkdir -p "$ARTIFACTS_DIR"

if [[ "$GENERATE_MANIFEST" -eq 1 ]]; then
  tools/generate_upstream_svg_manifest.sh "$REFERENCE_DIR" "$MANIFEST_PATH"
fi

echo "Running upstream SVG parity tests"
echo "  reference: $REFERENCE_DIR"
echo "  filter:    $FILTER"
if [[ -n "$FONTS" ]]; then
  echo "  fonts:     $FONTS"
fi
echo "  artifacts: $ARTIFACTS_DIR"

VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 \
VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR="$REFERENCE_DIR" \
VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR="$ARTIFACTS_DIR" \
VEXFOUNDATION_UPSTREAM_SVG_FONTS="$FONTS" \
swift test --filter "$FILTER"
