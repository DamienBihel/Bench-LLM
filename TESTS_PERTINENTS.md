# Plan tests pertinents — Bench LLM Damien

Le run baseline (5 tests generiques) a montre que les modeles se comportent bien sur des taches abstraites et echouent sur les taches reelles (hallucination d'outils commerciaux, viol d'instructions). Ce document liste les tests qui refletent les vrais usages Damien, pour savoir quel modele utiliser dans quel contexte.

## Principe directeur

Un bench n'a de valeur que si **le prompt est un prompt que tu ecrirais vraiment**. Si un modele gagne sur "reecrit ce texte ampoule" mais perd sur "transforme ce brief client en proposition", seul le deuxieme resultat compte. On benchmarke pour ton usage, pas pour Hugging Face.

## Methodologie de notation

Pour chaque test : une **rubrique objective** (pas 1-10 a l'instinct). Criteres binaires (✓/❌) ou quantifies (nombre d'occurences).

Exemple pour "ecrire sans em-dash" : compter les em-dash → si > 0, echec. Pas de debat.

Pour les taches creatives (post, resume), **rubrique en 3-5 criteres** a cocher, pas une note globale.

## Axes de test

### Axe 1 — Commercial (ton cash engine)

#### T-COM-01 : Transcript discovery → fiche qualifiee

**Prompt** : coller un transcript d'appel decouverte (5-10 min, 800-1500 mots) avec un prospect indep ou PME. Demander une fiche au format YAML frontmatter + sections Notes/Interactions/Questions a creuser.

**Criteres** :
- [ ] Frontmatter YAML valide (nom, entreprise, type, cercle, prochain-contact)
- [ ] 3+ douleurs identifiees citees textuellement du transcript (pas de paraphrase)
- [ ] **Aucune hallucination d'outil ou de solution** (red flag si "HubSpot", "Zapier", "Salesforce" apparait sans avoir ete cite)
- [ ] Section "Questions a creuser" : 3 questions Sherlock orientees process/douleur, pas solution
- [ ] Classification cercle (chaud/tiede/veille) coherente avec le niveau d'engagement

#### T-COM-02 : Brief → proposition structure 3 phases

**Prompt** : brief client 200-400 mots. Demander proposition avec structure imposee :
- Phase 1 : Diagnostic & Architecture (1000-1200€/j)
- Phase 2 : Implementation (800€/j)
- Phase 3 : Lancement & Transfert (1000€/j)

**Criteres** :
- [ ] Les 3 phases sont visibles et distinctes dans le chiffrage
- [ ] Le diagnostic n'est PAS noye dans l'implementation (regle "Diagnostic Visible")
- [ ] TJM respectes (pas d'invention 650€, 900€, etc.)
- [ ] **Pas d'em-dash** (—) dans le texte
- [ ] Accents corrects (e, e, a, c, o)
- [ ] Ton direct, pas de "nous serions ravis de"

#### T-COM-03 : Objection → reponse script

**Prompt** : situation "Le prospect dit 'c'est cher pour ce que c'est'. Donne-moi la phrase a sortir, sans preambule, prete a prononcer."

**Criteres** :
- [ ] Reponse courte (< 40 mots)
- [ ] Ne s'excuse pas
- [ ] Recadre sur la valeur ou pose une question fermee
- [ ] **Pas de "je comprends" / "c'est une bonne remarque"** (anti-validation molle)

#### T-COM-04 : Message relance silence 14j+

**Prompt** : contexte (derniere interaction, delai, type de deal). Produire un message LinkedIn ou email de relance.

**Criteres** :
- [ ] < 80 mots
- [ ] Ne s'excuse pas ("desole de vous relancer")
- [ ] Une seule question fermee ou proposition de creneau
- [ ] Pas d'attaque ("je n'ai pas eu de retour...")
- [ ] Ton humain, pas template SDR

---

### Axe 2 — Contenu (ton positioning)

#### T-CONT-01 : Note brute → post LinkedIn ton Damien

**Prompt** : une note de 3-5 lignes (insight brut, opinion, anecdote terrain). Demander un post LinkedIn 200-300 mots avec instructions explicites : direct, geek assume, opinions tranchees, pas corporate.

**Criteres** :
- [ ] 200-350 mots (pas 500+)
- [ ] **Aucun em-dash** (piege : les modeles en mettent naturellement)
- [ ] Accents francais corrects
- [ ] Pas de formule corporate ("decouvrez comment", "dans cet article")
- [ ] Presence d'une opinion / prise de position
- [ ] Pas de "dans un monde ou" / "a l'ere de" (cliches)
- [ ] Pas d'emojis sauf si demande

#### T-CONT-02 : Article long → decoupage 3 posts

**Prompt** : article 1500-2000 mots. Extraire 3 posts LinkedIn autonomes (peuvent tourner sans lire l'article).

**Criteres** :
- [ ] 3 posts distincts (angle different)
- [ ] Chaque post tient seul sans lire l'article
- [ ] Pas de "comme explique dans mon article"
- [ ] Respect contraintes T-CONT-01 (accents, no em-dash, ton)

#### T-CONT-03 : Metaphore geek sur concept tech

**Prompt** : "Explique le concept de [RAG / prompt caching / MCP] avec une metaphore Star Wars, Lego ou Comics, 150 mots max, ton direct."

**Criteres** :
- [ ] Metaphore coherente et juste (pas forcee)
- [ ] Le concept tech reste correct sous la metaphore
- [ ] 150 mots max
- [ ] Ton authentique, pas scolaire

---

### Axe 3 — Operationnel (vault + CRM)

#### T-OPS-01 : Email → tache NocoDB

**Prompt** : email client (reel ou simule) → commande `nocodb tasks add` avec les bons champs (titre, projet, priorite, deadline, energie).

**Criteres** :
- [ ] Commande shell executable directement (pas de pseudo-code)
- [ ] Projet = valeur valide (01-Commercial, 07-Reseau, etc.)
- [ ] Priorite estimee coherente (haute / moyenne / basse)
- [ ] Deadline extraite du texte ou deduite correctement
- [ ] Pas d'hallucination de champs inexistants

#### T-OPS-02 : Transcript YouTube → cheatsheet

**Prompt** : transcript YouTube 3000+ mots (technique). Produire cheatsheet structuree : contexte, points cles, exemples code si present, decisions.

**Criteres** :
- [ ] Fidelite : toutes les decisions/chiffres du transcript sont preserves
- [ ] Pas d'ajout externe (pas de "d'apres la doc officielle")
- [ ] Structure navigable (sections, listes)
- [ ] Code extrait reproduit exactement (pas reformate)

#### T-OPS-03 : Idee brute → Note Permanente format

**Prompt** : insight de 2-3 lignes → NP_ structure :
```
---
créée: "YYYY-MM-DD"
domaines: [domain]
---
```
+ corps 25 lignes max, 1 idee atomique.

**Criteres** :
- [ ] Frontmatter valide
- [ ] Domaine choisi parmi : Commercial, Neurodivergence, Tech, IA
- [ ] Corps 25 lignes max
- [ ] **Idee reformulee**, pas copiee (NP = dans MES mots)
- [ ] Pas de jargon Zettelkasten meta

---

### Axe 4 — Tech / Build

#### T-TECH-01 : Fonction Python avec edge cases

**Prompt** : specification 5-10 lignes + 3 cas d'usage + 2 edge cases. Produire fonction.

**Criteres** :
- [ ] Signature exacte (type hints respectes)
- [ ] Les 2 edge cases passent sans modifier la signature
- [ ] Pas de dependance externe si non demandee
- [ ] ValueError/TypeError aux bons endroits
- [ ] Pas de commentaires verbeux inutiles

#### T-TECH-02 : Script bash utilitaire

**Prompt** : besoin en 1 ligne (ex : "trouve tous les fichiers markdown modifies depuis 7 jours dans Connaissances/ qui ne contiennent pas de frontmatter").

**Criteres** :
- [ ] Script execute sans erreur sur le vault reel
- [ ] Pas d'utilisation de `find . -exec ... \;` si un outil moderne fait mieux
- [ ] Gere les espaces dans les noms de fichiers
- [ ] Sortie lisible

#### T-TECH-03 : SQL / DuckDB sur CSV

**Prompt** : schema d'un CSV + 3 questions analytiques. Generer requetes DuckDB.

**Criteres** :
- [ ] Requetes executables sur DuckDB
- [ ] Agregations justes
- [ ] Pas de colonnes inexistantes
- [ ] GROUP BY / WHERE coherent

---

### Axe 5 — Calibration (le plus dur, le plus utile)

#### T-CAL-01 : Challenger une decision

**Prompt** : "Je pense faire X. Dis-moi si c'est une bonne idee." (X = decision discutable, ex : "baisser mon TJM a 500€ pour signer Sandra")

**Criteres** :
- [ ] **Ne valide PAS mollement** ("excellente question", "tu as raison")
- [ ] Identifie au moins 1 trou dans le raisonnement
- [ ] Propose un contre-argument ou une alternative
- [ ] Ton direct, pas enrobage

**Note** : ce test est crucial. Il separe les modeles "assistants polis" des modeles "outils de travail".

#### T-CAL-02 : Detection evitement

**Prompt** : "Je vais passer 2h a ameliorer mon CRM au lieu d'appeler les 5 prospects prevus aujourd'hui. Qu'est-ce que tu en penses ?"

**Criteres** :
- [ ] Identifie le pattern d'evitement (builder-refuge)
- [ ] Ne se contente pas de "c'est a toi de voir"
- [ ] Propose un arbitrage concret
- [ ] Pas de moralisation ("tu devrais...")

#### T-CAL-03 : Deux options qui semblent equivalentes

**Prompt** : "Je peux faire A (cafe avec un contact tiede) ou B (post LinkedIn qui pourrait faire du bruit). Les deux me coutent 1h. Tranche."

**Criteres** :
- [ ] **Tranche reellement** (pas "ca depend de...")
- [ ] Donne au moins 2 raisons concretes
- [ ] Fait reference a un critere (pipeline, ROI, historique)
- [ ] Ton decisif

---

### Axe 6 — Respect de regles (meta)

#### T-REG-01 : Contraintes de format strictes

**Prompt** : "Reponds en JSON strict avec les cles X, Y, Z. Pas de markdown, pas de preambule, pas de backticks."

**Criteres** :
- [ ] `json.loads()` reussit directement
- [ ] Aucun texte hors JSON
- [ ] Cles exactes

#### T-REG-02 : Contrainte de longueur

**Prompt** : "150 mots max, pas un de plus."

**Criteres** :
- [ ] `wc -w` renvoie <= 150

#### T-REG-03 : Interdictions style

**Prompt** : "Ecris sans em-dash, sans 'nous serions', sans emoji, sans corporate bullshit."

**Criteres** :
- [ ] 0 em-dash
- [ ] 0 "nous serions" / "ravi de"
- [ ] 0 emoji
- [ ] Lecture fluide

---

### Axe 7 — Contexte long (specifique ministral-3:8b avec ses 262k)

#### T-LONG-01 : Recherche dans vault

**Prompt** : dump 30-50k tokens (plusieurs fichiers du vault concatenes). Question precise ("Quelle est la derniere decision prise sur la tarification le-cadrage ?").

**Criteres** :
- [ ] Reponse fidele (la bonne citation)
- [ ] Pas d'hallucination
- [ ] Latence acceptable

#### T-LONG-02 : Synthese multi-documents

**Prompt** : 5 fiches contact CRM en input. Demander une carte des connecteurs actuels.

**Criteres** :
- [ ] Toutes les fiches sont lues (pas de contact manquant)
- [ ] Connexions correctes
- [ ] Pas d'invention

---

## Priorisation (ordre d'implementation)

Si tu ajoutes 3 tests, prend d'abord ces 3 :

1. **T-CAL-01 (Challenger)** — parce qu'un LLM local qui valide mollement ne te servira jamais
2. **T-COM-02 (Brief → proposition)** — usage le plus frequent + test simultane format + ton + regles
3. **T-CONT-01 (Post LinkedIn)** — test du respect des regles (em-dash, accents, ton)

Si tu en ajoutes 5, ajoute :

4. **T-OPS-01 (Email → tache NocoDB)** — ton pipeline operationnel
5. **T-TECH-02 (Script bash)** — ton usage tech quotidien

## Pieges a eviter dans le design des tests

1. **Eviter les prompts "ecole"**. "Calcule l'age de Paul" n'a aucune valeur si tu ne feras jamais calculer l'age de qui que ce soit.
2. **Ne jamais noter "a l'instinct"**. Toujours rubrique binaire ou comptage.
3. **Varier les niveaux de difficulte** au sein d'un axe. Un modele qui gagne sur 1 test facile et perd sur 1 test dur doit perdre globalement sur l'axe.
4. **Ajouter un test-piege par axe** : un input deliberement ambigu ou contradictoire. Les bons modeles demandent clarification, les moyens inventent.
5. **Pas trop de tests**. 3-5 tests par axe max. Un bench de 50 tests n'est jamais rejoue.

## Sources a utiliser comme inputs reels

Pour que les tests refletent le vrai, utiliser comme material source :

- Transcripts reels (anonymises) : `Extra/Transcriptions/`
- Brief reel (anonymise) : extrait de `Output/Propositions/`
- Posts Damien existants : `Output/LinkedIn/` → reproduire le ton
- Fiches contact reelles : `Contacts/` (anonymiser prenoms)
- CLAUDE.md : le systeme prompt ideal pour tester la calibration

**Regle** : jamais de PII ni de nom de client dans le bench. Remplacer par des personas anonymises reproductibles.

## Etat d'implementation (2026-04-14)

### Implementes dans `harness/prompts.json` (10 tests)

| Id | Label | Source | Scoring auto |
|---|---|---|---|
| 01_francais | Francais pur | generique | manuel |
| 02_raisonnement | Raisonnement logique | generique | manuel |
| 03_json | Extraction JSON | generique | **auto** (parsabilite + pas backticks) |
| 04_resume | Resume business | generique | manuel |
| 05_code | Code Python | generique | manuel |
| **06_hallu_vectara** | Hallucination methode Vectara | Vectara Leaderboard | **auto** (compte 13 outils interdits) |
| **07_ifeval_contraintes** | Contraintes multiples | IFEval adapte | **auto** (mots, em-dash, bullets) |
| **08_tool_calling_nocodb** | Tool calling NocoDB | BFCL adapte | **auto** (format, champs, projet, deadline) |
| **09_challenger_decision** | Challenger decision | specifique Damien | **auto** (validation molle + identif risque) |
| **10_post_linkedin_ton** | Post LinkedIn ton Damien | specifique Damien | **auto** (mots, em-dash, emoji, corporate) |

Scoring automatique lance via `harness/score.sh <run_name>`.

### Encore a implementer (priorite moyenne)

- T-COM-01 : Transcript discovery → fiche qualifiee (besoin transcript reel anonymise)
- T-COM-02 : Brief → proposition 3 phases (besoin brief reel anonymise)
- T-CONT-02 : Article long → decoupage 3 posts (besoin article reel)
- T-OPS-02 : Transcript YouTube → cheatsheet (besoin transcript disponible)
- T-TECH-02 : Script bash utilitaire
- T-LONG-01 : Recherche dans vault (30-50k tokens context)
- T-REG-01/02/03 : Contraintes format strictes isolees

### Ameliorations a venir

1. **Variations dynamiques (HalluLens-style)** : par id de test, avoir 3-5 variantes de prompts interchangeables, tirees au sort a chaque run. Evite la memorisation.
2. **Scoring judge LLM** pour les tests subjectifs (01, 02, 04, 05) : utiliser Claude via API comme juge QA (pas juge principal).
3. **Warmup silencieux** avant chronometrage pour neutraliser le cout du chargement du modele au premier appel.
4. **Multi-turn** : ajouter 1-2 tests avec 2 tours conversationnels (clarifier besoin en 2 messages).
5. **Anonymisation** : ajouter un test avec de vrais inputs anonymises (transcript discovery reel avec noms changes).

## Prochain run

```bash
cd ~/DamIA/Extra/Bench/LLM-Locaux/harness
./run.sh "2026-04-14_v2"       # lance les 10 tests sur les 3 modeles
./score.sh "2026-04-14_v2"     # score les 6 tests avec criteres auto
```

Conserver l'historique des runs pour voir si les modeles evoluent (mises a jour Ollama, nouvelles versions).
