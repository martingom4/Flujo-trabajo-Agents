#!/usr/bin/env python3
"""Resumen de consumo de tokens de una sesion de Claude Code.

Lee el transcript JSONL (por defecto el mas reciente del proyecto actual)
y emite JSON con totales, costo estimado y los tool results mas pesados.
"""
import argparse
import json
import os
import sys
from pathlib import Path

# Precios por MTok (USD). Ajustar si cambia el modelo/precio.
PRICES = {
    "opus": {"input": 15.0, "output": 75.0, "cache_read": 1.5, "cache_write": 18.75},
    "sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.3, "cache_write": 3.75},
    "haiku": {"input": 1.0, "output": 5.0, "cache_read": 0.1, "cache_write": 1.25},
    "default": {"input": 15.0, "output": 75.0, "cache_read": 1.5, "cache_write": 18.75},
}


def project_dir_for_cwd() -> Path:
    slug = os.getcwd().replace(":", "-").replace("\\", "-").replace("/", "-").replace(".", "-").replace(" ", "-")
    return Path.home() / ".claude" / "projects" / slug


def latest_transcript(directory: Path) -> Path | None:
    files = sorted(directory.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


def price_table(model: str) -> dict:
    m = (model or "").lower()
    for key in ("opus", "sonnet", "haiku"):
        if key in m:
            return PRICES[key]
    return PRICES["default"]


def content_size(content) -> int:
    if isinstance(content, str):
        return len(content)
    if isinstance(content, list):
        return sum(len(json.dumps(b, ensure_ascii=False)) for b in content)
    return len(json.dumps(content, ensure_ascii=False)) if content else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript", help="Ruta a un .jsonl especifico")
    ap.add_argument("--top", type=int, default=10, help="Cuantos tool results pesados listar")
    args = ap.parse_args()

    if args.transcript:
        path = Path(args.transcript)
    else:
        pdir = project_dir_for_cwd()
        if not pdir.is_dir():
            print(json.dumps({"error": f"No existe {pdir}; pasa --transcript"}), file=sys.stderr)
            return 1
        path = latest_transcript(pdir)
        if not path:
            print(json.dumps({"error": f"Sin transcripts en {pdir}"}), file=sys.stderr)
            return 1

    totals = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
    turns = 0
    model = ""
    tool_use_names = {}   # tool_use id -> nombre de herramienta
    heavy = []            # (chars, tool, snippet)

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = rec.get("message") or {}
            usage = msg.get("usage") or {}
            if usage:
                turns += 1
                model = msg.get("model") or model
                totals["input"] += usage.get("input_tokens", 0)
                totals["output"] += usage.get("output_tokens", 0)
                totals["cache_read"] += usage.get("cache_read_input_tokens", 0)
                totals["cache_write"] += usage.get("cache_creation_input_tokens", 0)
            content = msg.get("content")
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "tool_use":
                        tool_use_names[block.get("id")] = block.get("name", "?")
                    elif block.get("type") == "tool_result":
                        size = content_size(block.get("content"))
                        tool = tool_use_names.get(block.get("tool_use_id"), "?")
                        heavy.append((size, tool))

    heavy.sort(reverse=True)
    prices = price_table(model)
    cost = (
        totals["input"] * prices["input"]
        + totals["output"] * prices["output"]
        + totals["cache_read"] * prices["cache_read"]
        + totals["cache_write"] * prices["cache_write"]
    ) / 1_000_000

    total_tokens = sum(totals.values())
    cache_eligible = totals["input"] + totals["cache_read"] + totals["cache_write"]
    out = {
        "transcript": str(path),
        "model": model,
        "turns": turns,
        "tokens": {**totals, "total": total_tokens},
        "cost_usd_estimado": round(cost, 4),
        "cache_hit_pct": round(100 * totals["cache_read"] / cache_eligible, 1) if cache_eligible else 0,
        "tool_results_pesados": [
            {"chars": c, "tokens_aprox": c // 4, "tool": t} for c, t in heavy[: args.top]
        ],
    }
    print(json.dumps(out, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
