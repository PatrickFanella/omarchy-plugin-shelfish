#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "$plugin_dir/tests/model.test.js"
node "$plugin_dir/tests/release.test.js"

if command -v qmllint >/dev/null 2>&1; then
  qmllint "$plugin_dir/BarWidget.qml" "$plugin_dir/GroupButton.qml" \
    "$plugin_dir/ManagePanel.qml" "$plugin_dir/Service.qml"
else
  printf '%s\n' "qmllint not found; skipped QML validation"
fi

if command -v omarchy >/dev/null 2>&1; then
  (cd "$plugin_dir" && omarchy plugin validate .)
else
  printf '%s\n' "omarchy not found; skipped plugin validation"
fi
