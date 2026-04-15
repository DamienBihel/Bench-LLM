#!/usr/bin/env python3
"""Agrège runs/*/{_metrics.csv, _scores.csv, *.md} + prompts.json en docs/data.json."""
import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNS_DIR = ROOT / "runs"
PROMPTS = ROOT / "harness" / "prompts.json"
MODELS_META = ROOT / "harness" / "models.json"
OUT = ROOT / "docs" / "data.json"


def read_csv(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_prompts() -> list[dict]:
    if not PROMPTS.exists():
        return []
    return json.loads(PROMPTS.read_text(encoding="utf-8")).get("tests", [])


def label_to_id(prompts: list[dict]) -> dict[str, str]:
    return {p["label"]: p["id"] for p in prompts}


def parse_response_md(path: Path, label_map: dict[str, str]) -> tuple[str, list[dict]]:
    """Parse un fichier `<model>.md` : renvoie (model_name, [{test_id, test_label, response}])."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    model = ""
    for ln in lines:
        if ln.startswith("# "):
            model = ln[2:].strip()
            break

    responses = []
    sections = re.split(r"^## ", text, flags=re.MULTILINE)[1:]
    for sec in sections:
        sec_lines = sec.splitlines()
        if not sec_lines:
            continue
        label = sec_lines[0].strip()
        test_id = label_map.get(label, "")
        m = re.search(r"\*\*Reponse\*\*\s*:\s*\n+```(?:[a-zA-Z]*\n)?(.*?)```", sec, flags=re.DOTALL)
        if not m:
            m = re.search(r"\*\*Reponse\s*:\*\*\s*\n+```(?:[a-zA-Z]*\n)?(.*?)```", sec, flags=re.DOTALL)
        response = m.group(1).strip() if m else ""
        responses.append({"test_id": test_id, "test_label": label, "response": response})
    return model, responses


def load_models_meta() -> dict:
    if not MODELS_META.exists():
        return {}
    return json.loads(MODELS_META.read_text(encoding="utf-8"))


def build() -> dict:
    prompts = load_prompts()
    label_map = label_to_id(prompts)
    models_meta = load_models_meta()

    runs = []
    for run_dir in sorted(RUNS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        name = run_dir.name
        date = name[:10] if len(name) >= 10 and name[4] == "-" else ""

        metrics = read_csv(run_dir / "_metrics.csv")
        scores = read_csv(run_dir / "_scores.csv")
        for m in metrics:
            for k in ("duree_s", "eval_duration_s", "eval_count", "tokens_per_s", "thinking_chars", "response_chars"):
                if k not in m:
                    m[k] = None
                    continue
                try:
                    m[k] = float(m[k]) if m.get(k) not in (None, "") else None
                except ValueError:
                    m[k] = None

        responses = []
        for md in sorted(run_dir.glob("*.md")):
            if md.name.upper() == "SYNTHESE.MD":
                continue
            model, resps = parse_response_md(md, label_map)
            if not model:
                continue
            for r in resps:
                responses.append({"model": model, **r})

        runs.append({
            "name": name, "date": date,
            "metrics": metrics, "scores": scores, "responses": responses,
        })

    return {
        "prompts": prompts,
        "models": models_meta,
        "runs": runs,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def main() -> int:
    data = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {OUT}")
    print(f"  prompts: {len(data['prompts'])}")
    for r in data["runs"]:
        print(f"  run {r['name']}: {len(r['metrics'])} metrics, {len(r['scores'])} scores, {len(r['responses'])} responses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
