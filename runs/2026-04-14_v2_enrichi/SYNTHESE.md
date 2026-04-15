# Run 2026-04-14_v2_enrichi

Second bench, 10 tests (5 du baseline + 5 nouveaux inspires de benchmarks publics adaptes cas Damien). Scoring automatique via `score.sh`.

## Parametres

- Date : 2026-04-14, 19h15 → 20h55 (duree totale ~1h40)
- Machine : MacBook Pro 16 Go RAM
- Temperature : 0.2
- Nombre de tests : 10
- Modeles : gemma4:latest, ministral-3:8b, gpt-oss:20b

## Score binaire automatique

| Modele | Score | Taux | Seul echec |
|---|---|---|---|
| **gemma4:latest** | **17/17** | **100%** | — |
| **gpt-oss:20b** | **17/17** | **100%** | — |
| ministral-3:8b | 16/17 | 94% | backticks JSON (test 03) |

Tous les modeles passent les criteres binaires. Le binaire ne suffit pas pour trancher. Analyse qualitative necessaire.

## Analyse qualitative des 5 nouveaux tests

### Test 06 — Hallucination Vectara

Le test cle. Prompt strict : "Resume en utilisant uniquement l'information du passage. N'infere rien. N'utilise aucune connaissance externe."

| Modele | Reponse | Hallucinations |
|---|---|---|
| gemma4 | 3 bullets fideles (40 PME, 2h/sem, tarif secondaire) | **0 outil externe** |
| ministral-3 | 3 bullets fideles | **0 outil externe** |
| gpt-oss | 3 bullets fideles | **0 outil externe** |

**Comparaison avec baseline (test 04_resume, meme brief sans prompt strict) :**

| Modele | Baseline 04_resume | V2 06_hallu_vectara |
|---|---|---|
| gemma4 | 0 outil halu | 0 outil halu |
| ministral-3 | **7 outils halu** (Calendly, Notion, HubSpot, ClickUp, Zapier, Google Workspace, Asana) | **0 outil halu** |
| gpt-oss | 3 outils halu (HubSpot, Streak, Zapier) | 0 outil halu |

**Enseignement :** le prompt Vectara **elimine l'hallucination** sur les 3 modeles. Le prompt compte plus que le choix du modele sur ce critere.

### Test 07 — IFEval (contraintes multiples)

Contraintes : <= 80 mots, 0 em-dash, 3 bullets exacts, verbes a l'infinitif.

| Modele | Mots | Em-dash | Bullets | Verbes infinitifs | Verdict |
|---|---|---|---|---|---|
| gemma4 | 65 | 0 | 3 | ✓ (Planifier/Personnaliser/Definir) | Conforme |
| ministral-3 | 48 | 0 | 3 | ✓ (Personnaliser/Espacer/Proposer) | Conforme, **le plus concis** |
| gpt-oss | 53 | 0 | 3 | ✓ (Planifier/Personnaliser/Suivre) | Conforme |

**Enseignement :** les 3 modeles respectent un stack de contraintes combinees quand elles sont explicites. Aucun gagnant objectif ici.

### Test 08 — Tool calling nocodb CLI

| Modele | Commande | Analyse |
|---|---|---|
| gemma4 | `titre="Devis site web pour Jean-Pierre Martin" projet="01-Commercial" priorite="3-haute" deadline="2026-04-30" energie="deep"` | Parfait. `priorite="3-haute"` respecte la nomenclature complete |
| ministral-3 | `priorite="3" energie="deep"` | Commande OK mais `priorite="3"` au lieu de `"3-haute"` |
| gpt-oss | `priorite="3-haute" energie="casual"` | Parfait. Seule difference : energie=casual (jugement discutable pour un devis site) |

**Enseignement :** les 3 generent une commande parsable. Differences sur les jugements (priorite format, energie). gemma4 le plus precis.

### Test 09 — Challenger une decision ("Je baisse mon TJM de 800 a 500")

| Modele | Verdict | Ton | Qualite |
|---|---|---|---|
| gemma4 | **"Non. C'est une mauvaise idee."** | Direct, structure en sections | **Excellent** : 3 risques + 3 alternatives concretes avec argumentaires distincts (perimetre, valeur non-monetaire, engagement duree) |
| ministral-3 | **"Non, ce n'est pas une bonne idee"** | Structure en 5 blocs analytiques | Tres bon : calculs de marge (9h vs 14.4h), signaux envoyes, alternatives TJM fixe + bonus |
| gpt-oss | **"Non. Vous perdez de l'argent."** | **Le plus concis (100 mots)** | Tres bon MAIS erreur unite : il parle de "500 € h" (heure) au lieu de TJM. Confusion terminologique |

**Enseignement :** **aucun modele ne valide mollement**. Les 3 disent non avec arguments. Surprise : j'aurais parie sur au moins un qui hesite. Gemma4 gagne qualitativement par la richesse des alternatives. gpt-oss perd 10% pour confusion unite.

### Test 10 — Post LinkedIn ton Damien

| Modele | Mots | Opinion tranchee | Style | Note |
|---|---|---|---|---|
| gemma4 | 272 | Moderee ("il est temps de", "arretons de") | Academique, peu de "je" | Correct mais pas le plus Damien-compatible |
| ministral-3 | 242 | Presente ("vous arretiez", "changez les gens") | Equilibre | Bon |
| gpt-oss | 212 | **Forte** ("C'est une realite qui me frustre", "arretez de courir") | Plus personnel | **Le plus dans ton ton** |

**Enseignement :** gpt-oss gagne sur le ton quand on lui en laisse le temps. Mais 266s pour un post = pas viable en iteration rapide. gemma4 reste le compromis raisonnable.

## Verdict actualise par usage

| Usage | Modele recommande | Justification |
|---|---|---|
| Resume brief client | **gemma4 + prompt Vectara strict** | Prompt Vectara elimine l'hallu |
| Q/R rapide factuel | ministral-3 | Rapide, concis, direct |
| Contraintes strictes (IFEval-style) | N'importe lequel des 3 | Tous respectent |
| Tool calling (generer commandes) | gemma4 | Plus precis sur la nomenclature |
| Challenger decision business | gemma4 (qualite) ou gpt-oss (concision) | Les 2 sont bons, pas de validation molle |
| Redaction ton personnel | gpt-oss SI patience (266s), sinon ministral | gpt-oss plus "dans le ton", lent |

## Insights majeurs (matiere post LinkedIn)

### Insight 1 — Le prompt bat le modele sur l'hallucination

Meme brief client, prompt different :
- Prompt neutre ("resume en 3 bullets") → **7 outils halu** chez ministral, 3 chez gpt-oss
- Prompt Vectara strict ("n'utilise aucune connaissance externe") → **0 halu sur les 3 modeles**

Plus important que de choisir le modele : **choisir le prompt**. La methode Vectara (et son prompt de 3 lignes) est directement transposable. Tu peux l'integrer dans n'importe quel prompt de synthese.

### Insight 2 — Les modeles locaux ne validient pas mollement

Test : "Je baisse mon TJM de 800 a 500 pour signer Sandra." Reponse des 3 modeles : **Non, c'est une mauvaise idee**. Aucun n'a commence par "Excellente reflexion" ou "Tu as raison".

Angle post : les LLMs locaux **peuvent** etre des vrais conseillers, pas des assistants polis, si tu formules la question de maniere directe sans demander de validation.

### Insight 3 — Les contraintes combinees sont respectees quand explicites

3 bullets + verbes infinitifs + max 80 mots + 0 em-dash = les 3 modeles reussissent. Le retour d'experience : **il faut lister toutes les contraintes dans le prompt**. Pas de "fais un post LinkedIn propre" et esperer. Chaque regle = une ligne dans le prompt.

### Insight 4 — Le cout de la latence bouffe le gain qualite

gpt-oss:20b a le ton le plus personnel sur le post LinkedIn (212 mots avec "ca me frustre depuis des annees"). Mais il a mis **266s** pour le produire. gemma4 sort 272 mots plus academiques en 203s. Pour 3 iterations, tu perds 3 minutes a attendre gpt-oss. Sur un usage quotidien, ca tue l'outil.

**Regle :** sur 16 Go RAM, considerer qu'un modele qui prend plus de 2 min pour une tache n'est pas un outil — c'est un batch nocturne.

### Insight 5 — ministral-3 viole encore les instructions

Sur le test 03 JSON avec instruction explicite "sans backticks", ministral continue a envelopper son JSON dans ```json...```. Sur 2 runs consecutifs. **C'est un comportement systemique**, pas un aleas. Pour un pipeline automatise qui parse le JSON, il faut prevoir un post-process qui strip les backticks, ou exclure ministral.

## Differences V2 vs Baseline

| Dimension | Baseline | V2 enrichi |
|---|---|---|
| Nombre de tests | 5 | 10 |
| Scoring | Manuel subjectif | **Automatique binaire** sur 6 tests (53% auto) |
| Duree totale | ~30 min | ~1h40 (gpt-oss plus lent encore) |
| Hallucination detectee | 10 mentions sur les 3 modeles | 0 (grace au prompt Vectara) |
| Winner | gemma4 (par elimination) | gemma4 (par consensus, mais score egal avec gpt-oss) |

## Limites de ce run

1. **Score auto ne mesure pas la qualite, uniquement les contraintes.** Les 3 modeles ont 100% mais qualitativement gemma4 > gpt-oss > ministral-3 selon les cas.
2. **Pas de warmup** : le premier appel par modele paye le chargement (+10-30s).
3. **Un seul essai par prompt** : pas de moyenne, pas d'ecart-type. Un bon resultat peut etre chanceux.
4. **Tests hors commerciaux reels** (transcript discovery reel, article complet) a ajouter plus tard.
5. **Pas de test contexte long** : les 262k de ministral-3 ne sont toujours pas exerces.

## Suite

Cf. `TESTS_PERTINENTS.md` section "Ameliorations a venir" :
- Variations dynamiques (HalluLens-style)
- Warmup silencieux
- Tests multi-turn
- Tests sur vrais inputs anonymises
