#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---check}"

usage() {
  cat <<'EOF'
Usage:
  tools/svg_snapshot.sh --check   # Validate SVG snapshots
  tools/svg_snapshot.sh --regen   # Regenerate SVG snapshots, then validate
EOF
}

run_svg_tests() {
  swift test --filter SVGRenderContextTests
}

case "$MODE" in
  --check)
    run_svg_tests
    ;;
  --regen)
    VEXFOUNDATION_REGENERATE_SVG_SNAPSHOTS=1 run_svg_tests
    run_svg_tests
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
