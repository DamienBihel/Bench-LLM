#!/usr/bin/env python3
"""Agrège runs/*/_metrics.csv + _scores.csv en docs/data.json pour le dashboard."""
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNS_DIR = ROOT / "runs"
OUT = ROOT / "docs" / "data.json"


def read_csv(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def build() -> dict:
    runs = []
    for run_dir in sorted(RUNS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        name = run_dir.name
        date = name[:10] if len(name) >= 10 and name[4] == "-" else ""
        metrics = read_csv(run_dir / "_metrics.csv")
        scores = read_csv(run_dir / "_scores.csv")
        for m in metrics:
            for k in ("duree_s", "eval_duration_s", "eval_count", "tokens_per_s"):
                try:
                    m[k] = float(m[k]) if m.get(k) not in (None, "") else None
                except ValueError:
                    m[k] = None
        runs.append({"name": name, "date": date, "metrics": metrics, "scores": scores})
    return {"runs": runs, "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds")}


def main() -> int:
    data = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {OUT} ({len(data['runs'])} runs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
