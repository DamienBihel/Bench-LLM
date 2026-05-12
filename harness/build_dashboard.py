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
    """Parse un fichier `<model>.md` : renvoie (model_name, [{test_id, test_label, response}]).

    Utilise un marker unique '## <label>\\n\\n- **Source** :' pour decouper les
    sections. Evite les faux positifs sur '## Titre' et '---' que les modeles
    utilisent dans leurs reponses markdown. Le fence de reponse est matche en
    greedy pour capturer les fences internes (blocs code dans la reponse).
    """
    text = path.read_text(encoding="utf-8")
    model = ""
    for ln in text.splitlines():
        if ln.startswith("# "):
            model = ln[2:].strip()
            break

    # Decoupage : chaque section reelle commence par "## <label>\n\n- **Source** :"
    section_starts = [
        (m.start(), m.group(1).strip())
        for m in re.finditer(r"^## ([^\n]+)\n\n- \*\*Source\*\* :", text, re.MULTILINE)
    ]

    responses = []
    for i, (start, label) in enumerate(section_starts):
        end = section_starts[i + 1][0] if i + 1 < len(section_starts) else len(text)
        sec = text[start:end]
        test_id = label_map.get(label, "")
        # Greedy pour capturer les fences internes eventuels
        m = re.search(
            r"\*\*Reponse\s*:\*\*\s*\n+```(?:[a-zA-Z]*\n)?(.*)\n```",
            sec, flags=re.DOTALL,
        )
        response = m.group(1).strip() if m else ""
        responses.append({"test_id": test_id, "test_label": label, "response": response})
    return model, responses


def load_models_meta() -> dict:
    if not MODELS_META.exists():
        return {}
    return json.loads(MODELS_META.read_text(encoding="utf-8"))


def build_synthesis(runs: list[dict]) -> dict | None:
    """Merge runs with identical test_id fingerprint. For each model, keep its latest run."""
    if not runs:
        return None
    groups: dict[tuple, list[dict]] = {}
    for r in runs:
        fp = tuple(sorted({m["test_id"] for m in r["metrics"]}))
        groups.setdefault(fp, []).append(r)
    largest = max(groups.values(), key=len)
    if len(largest) < 2:
        return None
    ordered = sorted(largest, key=lambda x: x["name"])
    model_source = {}
    for r in ordered:
        for m in r["metrics"]:
            model_source[m["model"]] = r["name"]
    metrics, scores, responses = [], [], []
    for model, source in model_source.items():
        r = next(x for x in ordered if x["name"] == source)
        metrics.extend([m for m in r["metrics"] if m["model"] == model])
        scores.extend([s for s in r["scores"] if s["model"] == model])
        responses.extend([x for x in r["responses"] if x["model"] == model])
    return {
        "name": "SYNTHESE (tous modeles)",
        "date": "",
        "metrics": metrics,
        "scores": scores,
        "responses": responses,
        "is_synthesis": True,
        "source_runs": [r["name"] for r in ordered],
        "model_source": model_source,
    }


def write_synthesis_dir(synthesis: dict) -> Path | None:
    """Ecrit physiquement la synthese dans runs/_SYNTHESE/ :
    - _metrics.csv et _scores.csv agreges
    - Copie des <model>.md depuis le run source de chaque modele
    - SYNTHESE.md : meta-info (date, runs source, mapping modele -> run)

    Le prefixe '_' exclut ce dossier du scan de build() (sinon boucle).
    """
    if not synthesis:
        return None
    import shutil
    syn_dir = RUNS_DIR / "_SYNTHESE"
    syn_dir.mkdir(parents=True, exist_ok=True)

    # Nettoyer les fichiers precedents (eviter stale)
    for f in syn_dir.iterdir():
        if f.is_file():
            f.unlink()

    # _metrics.csv
    metrics = synthesis.get("metrics", [])
    if metrics:
        # Recuperer l'union de toutes les colonnes (certaines manquent entre versions)
        all_keys = []
        seen = set()
        for m in metrics:
            for k in m.keys():
                if k not in seen:
                    seen.add(k)
                    all_keys.append(k)
        with (syn_dir / "_metrics.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=all_keys)
            w.writeheader()
            for m in metrics:
                w.writerow({k: m.get(k, "") for k in all_keys})

    # _scores.csv
    scores = synthesis.get("scores", [])
    if scores:
        all_keys = []
        seen = set()
        for s in scores:
            for k in s.keys():
                if k not in seen:
                    seen.add(k)
                    all_keys.append(k)
        with (syn_dir / "_scores.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=all_keys)
            w.writeheader()
            for s in scores:
                w.writerow({k: s.get(k, "") for k in all_keys})

    # Copie des .md sources
    model_source = synthesis.get("model_source", {})
    for model, source_run in model_source.items():
        safe = model.replace("/", "__").replace(":", "_")
        src = RUNS_DIR / source_run / f"{safe}.md"
        dst = syn_dir / f"{safe}.md"
        if src.exists():
            shutil.copy2(src, dst)

    # SYNTHESE.md : meta-info
    lines = [
        "# SYNTHESE (tous modeles)",
        "",
        f"Genere : {datetime.now(timezone.utc).isoformat(timespec='seconds')}",
        "",
        "## Runs sources",
        "",
    ]
    for r in synthesis.get("source_runs", []):
        lines.append(f"- {r}")
    lines.append("")
    lines.append("## Mapping modele -> run source")
    lines.append("")
    for model, source_run in sorted(model_source.items()):
        lines.append(f"- `{model}` -> {source_run}")
    (syn_dir / "SYNTHESE.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    return syn_dir


def build() -> dict:
    prompts = load_prompts()
    label_map = label_to_id(prompts)
    models_meta = load_models_meta()

    runs = []
    for run_dir in sorted(RUNS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        if run_dir.name.startswith("_") or run_dir.name.startswith("."):
            # Dossier _SYNTHESE ou caches : skip
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

    synthesis = build_synthesis(runs)
    if synthesis:
        # Ecrit physiquement runs/_SYNTHESE/ (CSV + MD agreges)
        syn_dir = write_synthesis_dir(synthesis)
        if syn_dir:
            print(f"  synthese ecrite dans : {syn_dir}")
    all_runs = ([synthesis] if synthesis else []) + runs

    return {
        "prompts": prompts,
        "models": models_meta,
        "runs": all_runs,
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
