#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p .build/tests
bash app/scripts/check-layers.sh app/tweak/Sources
python3 app/harness/tabbar/test_repack_ui.py -v
python3 -m unittest discover -s tests -p 'test_*.py' -v
