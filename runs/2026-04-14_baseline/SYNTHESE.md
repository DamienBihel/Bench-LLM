# Run 2026-04-14 — Baseline

Premier bench. 3 modeles, 5 tests generiques. Sert de reference pour les runs suivants.

## Parametres

- Date : 2026-04-14, 18h11
- Machine : MacBook Pro 16 Go RAM
- Temperature : 0.2
- Nombre de tests : 5
- Duree totale : ~30 min

## Resume qualite

| Test | gemma4 | ministral-3:8b | gpt-oss:20b |
|---|---|---|---|
| Francais pur (reecriture) | 8/10 — correct, 2 phrases | 9/10 — concis, 1 phrase | 8/10 — correct, verbeux |
| Raisonnement (ages) | ✓ 15 (378 tokens thinking) | ✓ 15 (**3 tokens, direct**) | ✓ 15 (132 tokens thinking) |
| JSON strict | ✓ pur, conforme | ❌ viole instruction (backticks) | ✓ pur, conforme |
| Resume business | ✓✓ fidele au brief | ❌ hallucine 7 outils | ⚠ hallu HubSpot/Streak/Zapier |
| Code Python | ⚠ type retour datetime au lieu de date | ❌ code casse (replace bizarres) | ✓ parfait |

## Resume performance

| Modele | Vitesse mediane | Duree totale | Verdict machine |
|---|---|---|---|
| gemma4:latest | 6.9 t/s | ~4 min | Confortable |
| ministral-3:8b | 5.2 t/s | ~2.5 min | Confortable |
| gpt-oss:20b | 2.2 t/s | **22 min** | **Swap — inutilisable en prod** |

## Verdict par usage

| Usage | Modele recommande | Raison |
|---|---|---|
| Resume brief client, synthese discovery | **gemma4** | Fidelite aux faits, pas d'hallu outils |
| Extraction JSON automatisee | gemma4 | Respect strict instructions |
| Code Python / scripts | gpt-oss si patient, sinon gemma4 | gpt-oss meilleur mais tres lent |
| Q/R rapide, conversationnel | ministral-3 | Concis, vitesse, pas de thinking inutile |
| Production generale | **gemma4** | Best balance qualite/vitesse/respect |

## Biais et limites de ce run

- Temperature 0.2 : pas teste a 0 (deterministe) ni 0.7 (creativite)
- Pas de warmup avant mesure : premier appel par modele inclut le chargement
- Prompts generiques, pas cas Damien specifiques : voir TESTS_PERTINENTS.md
- Un seul essai par prompt : pas de moyenne sur N=3 ou plus
- Pas de test contexte long (les 262k de ministral-3 ne sont pas exerces)
- Pas de test vision / tool calling / thinking mode explicite

## Insights non triviaux

Voir fichier separe (a extraire dans Connaissances/Tech/ si post LinkedIn ecrit) :

1. Un 8B calibre > un 20B qui swap. La taille ne compense pas le depassement RAM.
2. 2 modeles sur 3 hallucinent des outils commerciaux dans un resume business. Red flag pour usage discovery/proposition.
3. Le thinking mode depense 100-400 tokens pour repondre a une question simple. Cher et inutile hors problemes complexes.
4. La violation d'instructions (backticks, format) est un no-go pour pipelines automatises.

## Donnees

- Detail par modele : `gemma4_latest.md`, `ministral-3_8b.md`, `gpt-oss_20b.md`
- Metriques brutes : `_metrics.csv`
