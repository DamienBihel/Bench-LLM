# Benchmarks LLM — references externes

Ce document recense les benchmarks LLM publics (2025-2026) qui peuvent inspirer les tests pertinents pour Damien. Il sert de matiere premiere pour enrichir `TESTS_PERTINENTS.md` et `harness/prompts.json`.

## Tendance 2026 : du leaderboard au test proprietaire

Le shift majeur de 2026 : les benchmarks publics sont satures (les modeles frontier atteignent 85-95% sur MMLU, GPQA). **L'evaluation utile est maintenant proprietaire** — on teste sur les taches exactes que le modele va faire en prod. C'est exactement l'approche Damien. Les benchmarks publics servent de referentiel, pas de verdict.

Sources :
- [LLM Evaluation Frameworks & Metrics Guide for 2026](https://www.mlaidigital.com/blogs/llm-model-evaluation-frameworks-a-complete-guide-for-2026)
- [Vals AI — evaluations sur taches metier reelles](https://www.vals.ai/benchmarks)
- [SEAL Leaderboards (Scale AI) — evaluations expert](https://scale.com/leaderboard)

## Benchmarks generalistes reconnus

| Nom | Mesure | Utilite pour Damien |
|---|---|---|
| **MMLU** | Connaissances multi-domaines (questions type QCM) | Faible. Ne teste pas tes cas d'usage. |
| **HumanEval** | Code Python (164 fonctions a ecrire) | Moyen. Pertinent pour T-TECH-01. |
| **GPQA** | Questions niveau graduate (physique, bio, chimie) | Nul pour toi. |
| **AIME 2025** | Math olympiade | Nul pour toi. |
| **LiveCodeBench** | Code continu, prevent contamination | Moyen. Meilleur que HumanEval (plus recent). |
| **TAU-bench Retail** | Agent customer service avec tools | **Interessant** pour tester tool calling. |
| **MMMU** | Multimodal (image + texte) | Pertinent si tu utilises la vision (factures, screenshots). |
| **MT-Bench** | Conversation multi-tours juge par GPT-4 | Moyen. Tu fais du single-turn principalement. |
| **IFEval** | Instruction following strict | **Tres pertinent** (cf. T-REG-01, T-REG-02, T-REG-03). |
| **BFCL** (Berkeley Function Calling Leaderboard) | Tool/function calling | **Tres pertinent** si tu exposes nocodb CLI ou similar. |

## Benchmarks hallucination (le plus critique pour toi)

### Vectara Hallucination Leaderboard

Le plus actionnable, directement reutilisable.

**Methodologie :**
1. Fournir au LLM le texte complet d'un article
2. Lui demander un resume avec un prompt strict
3. Utiliser un modele detecteur (HHEM) pour scorer 0-1
4. Score < 0.5 = hallucination

**Prompt exact qu'ils utilisent** (a reutiliser tel quel dans tes tests) :
> "Summarize using only the information in the given passage. Do not infer. Do not use your internal knowledge."

Version francaise recommandee pour tes tests :
> "Resume en utilisant uniquement l'information du texte ci-dessous. N'infere rien. N'utilise aucune connaissance externe."

**Dataset :** 7 700+ articles multi-domaines (tech, finance, droit, medical, science, education), longueurs jusqu'a 32k tokens.

**Implications pour Damien :** tu peux repliquer cette approche en prenant 10 articles de `Connaissances/_Sources/` ou `Extra/Transcriptions/`, demander un resume avec ce prompt, puis verifier manuellement qu'aucune info externe n'a ete injectee.

Source : [Vectara Hallucination Leaderboard v2](https://www.vectara.com/blog/introducing-the-next-generation-of-vectaras-hallucination-leaderboard)

### HalluLens (arXiv 2504.17550)

Benchmark academique recent. Distingue :
- **Extrinsic** : contenu genere incoherent avec les donnees d'entrainement
- **Intrinsic** : contradiction interne au contenu genere

Nouveaute importante : **dynamic test set generation** pour eviter le data leakage (les benchmarks fixes finissent par etre dans les corpus d'entrainement des nouveaux modeles).

**Implication Damien :** si tu veux que ton bench reste valide dans le temps, **varie tes prompts** entre les runs (ou genere de nouveaux prompts a partir d'un template). Un prompt fige 2 ans finit par etre memorise.

Source : [HalluLens paper](https://arxiv.org/abs/2504.17550)

### Chiffres 2026

- Taux d'hallucination moyens selon 37 modeles : **15-52%**
- Certaines combinaisons modele + prompting methode montent a 50-82%
- Les outils de detection automatique atteignent 85-92% de precision

Source : [LLM Hallucination Statistics 2026](https://sqmagazine.co.uk/llm-hallucination-statistics/)

## L'approche "15 LLMs sur 38 vraies taches" (ianlpaterson 2026)

Article de reference pour l'approche "je teste sur mes vrais cas". Methodologie remarquable.

**10 categories testees** (sur base d'usages reels du PDG) :

| Code | Categorie | Nb tests | Exemples taches |
|---|---|---|---|
| E | Extraction | 5 | Recuperer donnees structurees de rapports |
| C | Code | 7 | Bash, Python, Rust, TypeScript |
| R | Raisonnement | 5 | Chaines causales, analyse de cause racine |
| W | Rediger | 5 | Texte avec contraintes de style specifiques |
| P | Planification | 4 | Decomposition de taches, specs |
| I | Investissements | 4 | Extraction marches de prediction, options |
| D | Donnees | 4 | CSV/JSON, transformations, normalisation |
| H | Operations | 2 | Parsing logs cron, detection derives schema |
| L | Lettres | 1 | Traitement au niveau caractere |
| M | Maths | 1 | Arithmetique modulaire |

**Methodologie de scoring :**
- 570 appels API au total (15 modeles × 38 taches)
- **Scoring deterministe** : 11 types de scoreurs (json_object, code_exec, writing_constraints)
- **Pas de juge LLM principal** (Opus utilise seulement pour QA)
- **Pass/fail binaire**, pas d'interpretation subjective

**Enseignements transposables :**

1. Organiser les tests par **groupes de cas d'usage reels** (pas par "capacite academique")
2. **Scoring binaire** ou quantifie (pas de note 7/10 a l'instinct)
3. Utiliser un **LLM juge seulement pour QA**, pas pour le score principal
4. Un test unique par groupe ne suffit pas (minimum 3-5 par categorie)

**Verdict principal de l'auteur :**
- Meilleur rapport qualite/prix : Claude Sonnet 4.6 (100%, $0.20/appel)
- Raisonnement complexe : Sonnet et Opus dominent
- Extraction + vitesse : Gemini Flash (97% en 1s a $0.003)
- JSON strict : MiniMax M2.5 (zero wrapper)
- Local gratuit : **gpt-oss-20b 98.3%** (mais attention, lui tourne sur machine puissante)
- Latence critique : Kimi K2.5 et DeepSeek R1 = 5-9x plus lents sans gain

Source : [I Tested 15 LLMs on 38 Real Coding Tasks](https://ianlpaterson.com/blog/llm-benchmark-2026-38-actual-tasks-15-models-for-2-29/)

## Techniques de scoring objectif (a reutiliser)

### 1. JSON validation

```python
import json
try:
    json.loads(response)
    # verifier cles attendues
    score = 1
except json.JSONDecodeError:
    score = 0
```

### 2. Execution code

```python
# Pour Python
import subprocess
result = subprocess.run(["python", "-c", response], capture_output=True, timeout=5)
if result.returncode == 0:
    # verifier output
    score = 1
```

### 3. Comptage interdictions

```bash
# Compter em-dash dans une reponse
echo "$RESPONSE" | grep -c "—"  # doit etre 0
# Compter mots
echo "$RESPONSE" | wc -w  # doit etre <= 150
```

### 4. Detection hallucination manuelle (pour resume)

Extraire toutes les entites nommees / chiffres du resume genere. Verifier que chacune figure **textuellement** dans la source. Toute entite non-presente = hallucination.

### 5. Judge LLM (derniere option, pour tache subjective)

A utiliser **uniquement pour Quality Assurance** des scoreurs automatiques, pas comme score principal. Un LLM juge est biaise (prefere les reponses verboses, bien structurees).

## Outils open source pour bencher en local

- **DeepEval** : framework d'evaluation avec metriques predefinies ([deepeval.com](https://deepeval.com/docs/metrics-hallucination))
- **GuideLLM** (Red Hat) : simule des workloads, mesure latence + throughput ([red hat](https://developers.redhat.com/articles/2025/06/20/guidellm-evaluate-llm-deployments-real-world-inference))
- **promptfoo** : YAML-first, comparaison multi-modeles, scoring pluggable
- **HaluEval dataset** : dataset d'hallucinations open source ([GitHub](https://github.com/RUCAIBox/HaluEval))

## Ce qu'on ne va PAS tester (et pourquoi)

| Benchmark public | Pourquoi pas pertinent pour toi |
|---|---|
| MMLU | Saturated, QCM academique, ne reflete aucun de tes usages |
| GPQA | Questions graduate en sciences dures, aucun rapport avec ton metier |
| AIME | Olympiades math, non pertinent |
| MMLU-Pro | Idem MMLU, plus dur, toujours QCM |
| BigCodeBench | Si tu fais rarement du code en prod, limite |
| AGIEval | Examens type SAT, non pertinent |
| GSM8K | Math word problems primaire, non pertinent |

## Plan : comment enrichir nos tests a partir de ces references

1. **Hallucination avec prompt Vectara** : integrer un test "summarize from passage only" avec le prompt exact Vectara, sur un article de `Extra/Transcriptions/`. Scoring : count d'entites/chiffres non-presents dans la source.

2. **Instruction following (IFEval-style)** : tests de contraintes multiples combinees ("reponds en JSON, max 50 mots, sans em-dash, en francais"). Scoring binaire sur chaque contrainte.

3. **Tool calling (BFCL-style)** : simuler un appel a `nocodb tasks add` avec les bons champs en fonction d'un input textuel. Scoring : parsing correct de la commande.

4. **Variation dynamique (HalluLens-style)** : plutot qu'un prompt fige pour le bench, avoir 3-5 variantes interchangeables par test, pour eviter que les modeles memorisent.

5. **Multi-turn** : ajouter 1-2 tests conversationnels (besoin clarifie en 2 tours) pour tester les modeles sur le **maintien de contexte**.

## Sources

- [LLM Evaluation Frameworks 2025 vs 2026](https://www.mlaidigital.com/blogs/llm-evaluation-frameworks-2025-vs-2026-what-matters-now-2026)
- [LLM Benchmarks 2026 — llm-stats.com](https://llm-stats.com/benchmarks)
- [Vellum AI LLM Leaderboard](https://www.vellum.ai/llm-leaderboard)
- [8 LLM evaluation tools you should know in 2026](https://techhq.com/news/8-llm-evaluation-tools-you-should-know-in-2026/)
- [HalluLens paper (arXiv 2504.17550)](https://arxiv.org/abs/2504.17550)
- [Vectara Hallucination Leaderboard v2](https://www.vectara.com/blog/introducing-the-next-generation-of-vectaras-hallucination-leaderboard)
- [Vectara Hallucination Leaderboard repo](https://github.com/vectara/hallucination-leaderboard/)
- [HaluEval GitHub](https://github.com/RUCAIBox/HaluEval)
- [Ian Paterson — 15 LLMs 38 Real Tasks](https://ianlpaterson.com/blog/llm-benchmark-2026-38-actual-tasks-15-models-for-2-29/)
- [GuideLLM Red Hat](https://developers.redhat.com/articles/2025/06/20/guidellm-evaluate-llm-deployments-real-world-inference)
- [DeepEval hallucination metric](https://deepeval.com/docs/metrics-hallucination)
- [Evaluation LLM (FR) — Ayi Nedjimi Consultants](https://www.ayinedjimi-consultants.fr/ia-evaluation-llm-benchmarks.html)
- [LLM Hallucination Statistics 2026](https://sqmagazine.co.uk/llm-hallucination-statistics/)
