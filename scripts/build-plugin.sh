#!/usr/bin/env bash
# Regenera dist/flujo-martin.plugin (el archivo que se instala en la app de Claude).
# Si cambiaste skills, subí antes "version" en plugins/flujo-martin/.claude-plugin/plugin.json.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"; rm -f "$ROOT/dist/flujo-martin.plugin"
cd "$ROOT/plugins/flujo-martin"
if command -v zip >/dev/null 2>&1; then
  zip -qr "$ROOT/dist/flujo-martin.plugin" . -x "*.DS_Store"
else
  python3 -c "import shutil;shutil.make_archive('$ROOT/dist/flujo-martin','zip','.')" && mv "$ROOT/dist/flujo-martin.zip" "$ROOT/dist/flujo-martin.plugin"
fi
echo "==> dist/flujo-martin.plugin listo — abrilo/subilo en la app de Claude para actualizar el plugin."
