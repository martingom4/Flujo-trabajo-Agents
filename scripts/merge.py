#!/usr/bin/env python3
"""Fusiona el kit global en ~/.claude sin pisar lo que ya existe.

- settings.json: une permisos, hooks (sin duplicar comandos), marketplaces y plugins.
- CLAUDE.md: reemplaza solo el bloque entre marcadores martin-global; el resto
  (p. ej. la sección que agrega graphify) queda intacto.
Deja respaldo *.bak-<fecha> de cada archivo que modifica.
"""
import json
import shutil
import sys
import time
from pathlib import Path

START, END = "<!-- martin-global:start", "<!-- martin-global:end -->"


def backup(p: Path) -> None:
    if p.exists():
        shutil.copy2(p, p.with_name(p.name + ".bak-" + time.strftime("%Y%m%d-%H%M%S")))


def merge_hooks(dst: dict, src: dict) -> None:
    for event, groups in src.items():
        have = dst.setdefault(event, [])
        cmds = {h.get("command") for g in have for h in g.get("hooks", [])}
        for g in groups:
            if not any(h.get("command") in cmds for h in g.get("hooks", [])):
                have.append(g)


def merge_settings(dst_path: Path, src_path: Path) -> None:
    src = json.loads(src_path.read_text(encoding="utf-8"))
    dst = json.loads(dst_path.read_text(encoding="utf-8")) if dst_path.exists() else {}
    perms = dst.setdefault("permissions", {})
    allow = perms.setdefault("allow", [])
    allow += [r for r in src.get("permissions", {}).get("allow", []) if r not in allow]
    merge_hooks(dst.setdefault("hooks", {}), src.get("hooks", {}))
    for key in ("extraKnownMarketplaces", "enabledPlugins"):
        dst.setdefault(key, {}).update(src.get(key, {}))
    backup(dst_path)
    dst_path.write_text(json.dumps(dst, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def merge_claude_md(dst_path: Path, block_path: Path) -> None:
    block = block_path.read_text(encoding="utf-8").strip() + "\n"
    text = dst_path.read_text(encoding="utf-8") if dst_path.exists() else ""
    if START in text and END in text:
        head, rest = text.split(START, 1)
        tail = rest.split(END, 1)[1]
        new = head + block.rstrip("\n") + tail
    else:
        new = block + ("\n" + text if text.strip() else "")
    if new != text:
        backup(dst_path)
        dst_path.write_text(new, encoding="utf-8")


if __name__ == "__main__":
    kit_home, claude_home = Path(sys.argv[1]), Path(sys.argv[2])
    claude_home.mkdir(parents=True, exist_ok=True)
    merge_settings(claude_home / "settings.json", kit_home / "settings.json")
    merge_claude_md(claude_home / "CLAUDE.md", kit_home / "CLAUDE.md.block")
    print("settings.json y CLAUDE.md fusionados en", claude_home)
