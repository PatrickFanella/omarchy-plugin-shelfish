#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "$plugin_dir/tests/model.test.js"
node "$plugin_dir/tests/i18n.test.js"
node "$plugin_dir/tests/release.test.js"

if command -v omarchy >/dev/null 2>&1; then
  (cd "$plugin_dir" && omarchy plugin validate .)
else
  printf '%s\n' "omarchy not found; skipped plugin validation"
fi
