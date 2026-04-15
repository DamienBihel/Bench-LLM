# Extra/Bench

Dossier de benchmarks reproductibles. Chaque bench = un sous-dossier autonome avec harness (scripts + prompts), runs dates, et synthese.

## Benches actifs

| Nom | Objectif | Dernier run |
|---|---|---|
| [LLM-Locaux](LLM-Locaux/README.md) | Comparer les LLM locaux installes via Ollama sur des taches reelles | 2026-04-14 |

## Structure type

```
NomDuBench/
├── README.md              # Cas d'usage, comment relancer
├── harness/               # Code + prompts (reproductible)
│   ├── run.sh
│   └── prompts.json
├── runs/                  # Resultats dates
│   └── YYYY-MM-DD_tag/
│       ├── gemma4.md
│       ├── modele2.md
│       ├── _metrics.csv
│       └── SYNTHESE.md
└── TESTS_PERTINENTS.md    # Plan tests futurs a ajouter
```

## Regle

Les synthese (connaissances extraites) peuvent aussi etre copiees dans `Connaissances/Tech/` quand elles dependent de NP. Les donnees brutes et le harness restent ici.
