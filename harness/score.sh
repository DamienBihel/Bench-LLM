#!/bin/bash
# Score automatique des reponses d'un run.
# Usage : ./score.sh <run_name>
#   run_name : sous-dossier dans ../runs/
#
# Applique des tests automatiques (binaires) sur les reponses de chaque modele
# pour les tests qui ont une rubrique verifiable par script.
#
# Output : ../runs/<run_name>/_scores.csv

set -u

if [ $# -lt 1 ]; then
  echo "Usage: $0 <run_name>"
  echo "Exemple: $0 2026-04-14_v2"
  exit 1
fi

RUN_NAME="$1"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_ROOT="$(dirname "$HARNESS_DIR")"
RUN_DIR="$BENCH_ROOT/runs/$RUN_NAME"
SCORES_CSV="$RUN_DIR/_scores.csv"

if [ ! -d "$RUN_DIR" ]; then
  echo "ERREUR: $RUN_DIR introuvable"
  exit 1
fi

# En-tete CSV
echo "model,test_id,critere,resultat,detail" > "$SCORES_CSV"

# Fonction : extraire la reponse d'un test dans un fichier markdown
# Usage : extract_response <model_file.md> <test_label>
# Retourne le contenu entre la ligne "## <label>" et le prochain "---"
extract_response() {
  local file="$1"
  local label="$2"
  awk -v lbl="$label" '
    $0 ~ "^## " lbl { inside = 1; capture = 0; next }
    inside && /^```$/ {
      if (capture == 0) { capture = 1 } else { capture = 0; inside = 0 }
      next
    }
    inside && capture { print }
    inside && /^---$/ { inside = 0 }
  ' "$file"
}

# Fonction score : log une ligne dans le CSV
log_score() {
  local model="$1" test_id="$2" critere="$3" resultat="$4" detail="$5"
  echo "\"$model\",\"$test_id\",\"$critere\",\"$resultat\",\"$detail\"" >> "$SCORES_CSV"
}

for model_file in "$RUN_DIR"/*.md; do
  # Skip SYNTHESE et autres fichiers non-modele
  basename=$(basename "$model_file")
  [[ "$basename" == "SYNTHESE.md" ]] && continue
  [[ "$basename" == "INSIGHTS.md" ]] && continue

  model=$(head -1 "$model_file" | sed 's/^# //')

  echo ""
  echo "── $model ─────────────────"

  # ─── Test 03_json : JSON parsable ───
  resp=$(extract_response "$model_file" "Extraction JSON structuree")
  # Retirer d'eventuels backticks markdown
  resp_clean=$(echo "$resp" | sed 's/^```json$//; s/^```$//')
  if echo "$resp_clean" | jq . >/dev/null 2>&1; then
    log_score "$model" "03_json" "json_parsable" "PASS" ""
    echo "  03_json json_parsable: PASS"
  else
    log_score "$model" "03_json" "json_parsable" "FAIL" "JSON invalide"
    echo "  03_json json_parsable: FAIL"
  fi
  # Check backticks violation
  if echo "$resp" | grep -q '```'; then
    log_score "$model" "03_json" "pas_de_backticks" "FAIL" "backticks presents"
    echo "  03_json pas_de_backticks: FAIL"
  else
    log_score "$model" "03_json" "pas_de_backticks" "PASS" ""
    echo "  03_json pas_de_backticks: PASS"
  fi

  # ─── Test 06_hallu_vectara : compter entites externes ───
  resp=$(extract_response "$model_file" "Hallucination — methode Vectara")
  FORBIDDEN_TOOLS="HubSpot Calendly Notion Zapier Salesforce Asana ClickUp Trello Monday Pipedrive Airtable Slack Make"
  violations=0
  viol_list=""
  for tool in $FORBIDDEN_TOOLS; do
    if echo "$resp" | grep -qi "$tool"; then
      violations=$((violations + 1))
      viol_list="$viol_list $tool"
    fi
  done
  if [ "$violations" -eq 0 ]; then
    log_score "$model" "06_hallu_vectara" "zero_outil_externe" "PASS" ""
    echo "  06_hallu zero_outil_externe: PASS"
  else
    log_score "$model" "06_hallu_vectara" "zero_outil_externe" "FAIL" "$violations outils halu:$viol_list"
    echo "  06_hallu zero_outil_externe: FAIL ($violations:$viol_list)"
  fi

  # ─── Test 07_ifeval_contraintes ───
  resp=$(extract_response "$model_file" "IFEval — contraintes multiples combinees")
  word_count=$(echo "$resp" | wc -w | tr -d ' ')
  emdash_count=$(echo "$resp" | grep -c '—' || true)
  bullet_count=$(echo "$resp" | grep -cE '^[[:space:]]*[-*•]' || true)

  if [ "$word_count" -le 80 ] && [ "$word_count" -gt 0 ]; then
    log_score "$model" "07_ifeval" "max_80_mots" "PASS" "$word_count mots"
    echo "  07_ifeval max_80_mots: PASS ($word_count)"
  else
    log_score "$model" "07_ifeval" "max_80_mots" "FAIL" "$word_count mots"
    echo "  07_ifeval max_80_mots: FAIL ($word_count)"
  fi
  if [ "$emdash_count" -eq 0 ]; then
    log_score "$model" "07_ifeval" "zero_emdash" "PASS" ""
    echo "  07_ifeval zero_emdash: PASS"
  else
    log_score "$model" "07_ifeval" "zero_emdash" "FAIL" "$emdash_count em-dash"
    echo "  07_ifeval zero_emdash: FAIL ($emdash_count)"
  fi
  if [ "$bullet_count" -eq 3 ]; then
    log_score "$model" "07_ifeval" "exactement_3_bullets" "PASS" ""
    echo "  07_ifeval exactement_3_bullets: PASS"
  else
    log_score "$model" "07_ifeval" "exactement_3_bullets" "FAIL" "$bullet_count bullets"
    echo "  07_ifeval exactement_3_bullets: FAIL ($bullet_count)"
  fi

  # ─── Test 08_tool_calling_nocodb ───
  resp=$(extract_response "$model_file" "Tool calling — nocodb CLI")
  # Pas de backticks
  if echo "$resp" | grep -q '```'; then
    log_score "$model" "08_tool_calling" "pas_de_backticks" "FAIL" ""
    echo "  08_tool pas_de_backticks: FAIL"
  else
    log_score "$model" "08_tool_calling" "pas_de_backticks" "PASS" ""
    echo "  08_tool pas_de_backticks: PASS"
  fi
  # Commence par nocodb tasks add
  if echo "$resp" | head -1 | grep -qE '^nocodb tasks add'; then
    log_score "$model" "08_tool_calling" "commande_correcte" "PASS" ""
    echo "  08_tool commande_correcte: PASS"
  else
    log_score "$model" "08_tool_calling" "commande_correcte" "FAIL" ""
    echo "  08_tool commande_correcte: FAIL"
  fi
  # Tous les champs presents
  champs_ok=1
  for champ in titre projet priorite deadline energie; do
    if ! echo "$resp" | grep -qE "${champ}="; then champs_ok=0; break; fi
  done
  if [ "$champs_ok" -eq 1 ]; then
    log_score "$model" "08_tool_calling" "tous_champs_presents" "PASS" ""
    echo "  08_tool tous_champs_presents: PASS"
  else
    log_score "$model" "08_tool_calling" "tous_champs_presents" "FAIL" ""
    echo "  08_tool tous_champs_presents: FAIL"
  fi
  # Projet valide
  if echo "$resp" | grep -qE 'projet="(01-Commercial|07-Reseau|06-Communication)"'; then
    log_score "$model" "08_tool_calling" "projet_valide" "PASS" ""
    echo "  08_tool projet_valide: PASS"
  else
    log_score "$model" "08_tool_calling" "projet_valide" "FAIL" ""
    echo "  08_tool projet_valide: FAIL"
  fi
  # Deadline format YYYY-MM-DD
  if echo "$resp" | grep -qE 'deadline="2026-04-[0-9]{2}"'; then
    log_score "$model" "08_tool_calling" "deadline_format" "PASS" ""
    echo "  08_tool deadline_format: PASS"
  else
    log_score "$model" "08_tool_calling" "deadline_format" "FAIL" ""
    echo "  08_tool deadline_format: FAIL"
  fi

  # ─── Test 09_challenger_decision ───
  resp=$(extract_response "$model_file" "Calibration — challenger une decision")
  # Ne commence pas par validation molle
  if echo "$resp" | head -c 100 | grep -qiE '^(excellente|tu as raison|bonne idee|c.est une bonne|super|parfait|bravo)'; then
    log_score "$model" "09_challenger" "pas_validation_molle" "FAIL" ""
    echo "  09_challenger pas_validation_molle: FAIL"
  else
    log_score "$model" "09_challenger" "pas_validation_molle" "PASS" ""
    echo "  09_challenger pas_validation_molle: PASS"
  fi
  # Contient mot-cle de refus / alerte
  if echo "$resp" | grep -qiE '(non|mauvaise|erreur|attention|risque|probleme|piege|dangereux)'; then
    log_score "$model" "09_challenger" "identifie_risque" "PASS" ""
    echo "  09_challenger identifie_risque: PASS"
  else
    log_score "$model" "09_challenger" "identifie_risque" "FAIL" ""
    echo "  09_challenger identifie_risque: FAIL"
  fi

  # ─── Test 10_post_linkedin_ton ───
  resp=$(extract_response "$model_file" "Redaction — post LinkedIn ton Damien")
  word_count=$(echo "$resp" | wc -w | tr -d ' ')
  emdash_count=$(echo "$resp" | grep -c '—' || true)
  emoji_count=$(echo "$resp" | python3 -c 'import sys, unicodedata; print(sum(1 for c in sys.stdin.read() if unicodedata.category(c) == "So"))' 2>/dev/null || echo 0)

  if [ "$word_count" -ge 200 ] && [ "$word_count" -le 350 ]; then
    log_score "$model" "10_linkedin" "mots_200_350" "PASS" "$word_count mots"
    echo "  10_linkedin mots_200_350: PASS ($word_count)"
  else
    log_score "$model" "10_linkedin" "mots_200_350" "FAIL" "$word_count mots"
    echo "  10_linkedin mots_200_350: FAIL ($word_count)"
  fi
  if [ "$emdash_count" -eq 0 ]; then
    log_score "$model" "10_linkedin" "zero_emdash" "PASS" ""
    echo "  10_linkedin zero_emdash: PASS"
  else
    log_score "$model" "10_linkedin" "zero_emdash" "FAIL" "$emdash_count em-dash"
    echo "  10_linkedin zero_emdash: FAIL ($emdash_count)"
  fi
  if [ "$emoji_count" -eq 0 ]; then
    log_score "$model" "10_linkedin" "zero_emoji" "PASS" ""
    echo "  10_linkedin zero_emoji: PASS"
  else
    log_score "$model" "10_linkedin" "zero_emoji" "FAIL" "$emoji_count emoji"
    echo "  10_linkedin zero_emoji: FAIL ($emoji_count)"
  fi
  # Corporate
  if echo "$resp" | grep -qiE '(decouvrez|nous serions|dans un monde|a l.ere de|ravi de|plaisir de vous)'; then
    log_score "$model" "10_linkedin" "pas_corporate" "FAIL" ""
    echo "  10_linkedin pas_corporate: FAIL"
  else
    log_score "$model" "10_linkedin" "pas_corporate" "PASS" ""
    echo "  10_linkedin pas_corporate: PASS"
  fi

done

echo ""
echo "═════════════════════════════════════════════════"
echo "  Scores sauves : $SCORES_CSV"
echo "═════════════════════════════════════════════════"
echo ""
echo "Resume par modele :"
awk -F'","' 'NR>1 {gsub(/"/, "", $1); gsub(/"/, "", $4); count[$1,$4]++; total[$1]++} END {
  for (key in count) {
    split(key, a, SUBSEP);
    if (a[2] == "PASS") passes[a[1]] = count[key]
  }
  for (m in total) {
    p = (m in passes) ? passes[m] : 0
    printf "  %-25s : %d/%d PASS (%.0f%%)\n", m, p, total[m], (p*100/total[m])
  }
}' "$SCORES_CSV"
