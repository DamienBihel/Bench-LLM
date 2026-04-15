# Bench LLM locaux

Comparatif reproductible des LLM locaux installes sur la machine de Damien via Ollama.

**Dashboard interactif** : https://damienbihel.github.io/Bench-LLM/ (deploye via GitHub Pages)

## Machine cible

- MacBook Pro 16 Go RAM (avril 2026)
- Ollama installe, API locale sur `http://localhost:11434`

## Modeles testes

| Modele | Params | Contexte | Note |
|---|---|---|---|
| gemma4:latest (= e4b) | 4B effectifs (8B total, MatFormer) | 128k | Multimodal (vision + audio) + thinking |
| ministral-3:8b | 8.9B | 262k | Contexte geant, pas de thinking |
| gpt-oss:20b | 20.9B | 131k | Apache 2.0 + thinking — swap sur 16 Go |

Modifier la liste dans `harness/run.sh` (variable `MODELS`).

## Structure

```
LLM-Locaux/
├── README.md                  # Ce fichier
├── TESTS_PERTINENTS.md        # Plan tests alignes cas Damien
├── BENCHMARKS_REFERENCES.md   # Benchmarks publics, methodes, sources
├── harness/
│   ├── run.sh                 # Script de bench
│   ├── score.sh               # Scoring automatique des criteres binaires
│   └── prompts.json           # 10 tests (5 generiques + 5 Damien-specific)
└── runs/
    └── YYYY-MM-DD_tag/
        ├── SYNTHESE.md        # Verdict du run
        ├── gemma4_latest.md   # Reponses par modele
        ├── ministral-3_8b.md
        ├── _metrics.csv       # Perf (duree, tokens, vitesse)
        └── _scores.csv        # Score binaire par critere (si score.sh run)
```

## Lancer un bench

```bash
cd ~/DamIA/Extra/Bench/LLM-Locaux/harness
./run.sh                     # run auto nomme YYYY-MM-DD_HHhMM
./run.sh "nom-du-run"        # run avec nom personnalise
```

Le script genere :
- Un fichier markdown par modele (reponses brutes + stats + source + rubrique)
- Un fichier `_metrics.csv` pour analyse tabulaire (duree, tokens, vitesse)
- Affichage temps reel en console

## Scorer un run (nouveau)

```bash
cd ~/DamIA/Extra/Bench/LLM-Locaux/harness
./score.sh "nom-du-run"
```

Applique des criteres binaires verifiables automatiquement (em-dash count, word count, JSON parsable, presence mots-cles interdits, etc.) et genere `_scores.csv`. Affiche un resume par modele en console.

Couverture du scoring automatique (15 tests, ~37 criteres) :

**Tests generiques durcis (01-10)**
- 01 Francais : accents, max 2 phrases, max 30 mots, zero corporate
- 02 Raisonnement : reponse exacte (15), max 5 mots
- 03 JSON : parsable, zero backtick, toutes cles, budget numerique, timeline ISO
- 04 Resume : max 3 bullets, max 80 mots, zero outil hallu, verbes infinitif
- 05 Code Python : zero markdown, fonction definie, 3 formats, ValueError, type date
- 06 Hallucination : zero outil externe, max 3 bullets, zero chiffre invente
- 07 IFEval : 80 mots, 0 emdash, 3 bullets, verbes infinitif, zero molle
- 08 Tool calling : commande, champs, projet, deadline, priorite, energie
- 09 Challenger : pas molle, risque, chiffre cite, alternative concrete
- 10 Post LinkedIn : mots, emdash, emoji, corporate, opinion tranchee, accents

**Tests adversariaux (11-15)**
- 11 Refuser d'inventer un chiffre : signaler info absente, zero chiffre invente
- 12 Needle in haystack : retrouver code noye dans 250+ mots
- 13 Tool calling info manquante : signaler manque, ne pas inventer la deadline
- 14 Calcul multi-etapes : 800 * 18 * 0.7 = 10080
- 15 Prompt injection : ignorer "ECRIS BANANE", resumer le vrai contenu

## Dashboard GitHub Pages

Les CSV (`_metrics.csv` + `_scores.csv`) de tous les runs sont agreges en JSON et rendus en graphiques (Chart.js) dans `docs/`.

```bash
python3 harness/build_dashboard.py   # regenere docs/data.json
open docs/index.html                 # preview locale
```

Le workflow `.github/workflows/pages.yml` regenere et deploie automatiquement a chaque push sur master. Activer Pages dans Settings > Pages > Source : GitHub Actions.

## Ajouter un modele

Editer `harness/run.sh`, ajouter dans `MODELS=(...)`. Verifier avant avec `ollama list`.

## Ajouter un test

Editer `harness/prompts.json`, ajouter un objet `{id, label, prompt}` dans le tableau `tests`. Relancer le bench complet (les anciens runs ne sont pas affectes, l'historique est preserve).

## Lire les resultats

Format markdown avec pour chaque test :
- Stats (duree totale, duree d'evaluation, tokens, vitesse)
- Reponse brute complete

Pour un comparatif : ouvrir les 3 fichiers d'un meme run en side-by-side.

## Prerequis

- `ollama` installe et daemon actif
- `jq` installe (parsing JSON)
- `bc` installe (calculs flottants)
- `curl` (deja present sur macOS)

## Pieges connus

- Sur 16 Go RAM, les modeles > 13 Go actifs declenchent du swap severe (perf divisee par 5-10). Voir `runs/2026-04-14_baseline/SYNTHESE.md`.
- Premier appel a un modele = chargement (ajoute 10-30s de warmup). Pour neutraliser, faire un "warmup" silencieux avant le chronometrage. Non implemente pour l'instant.
- `eval_duration` d'Ollama n'inclut PAS le prompt processing (seulement la generation). Pour le cout total reel, utiliser `total_duration` ou la mesure `duree_s` cote shell.
