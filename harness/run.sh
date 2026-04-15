#!/bin/bash
# Bench LLM locaux — harness reproductible
# Usage : ./run.sh [run_name]
#   run_name : nom du sous-dossier dans ../runs/ (defaut = YYYY-MM-DD_HHhMM)

set -u

# Parametres — MODELS_OVERRIDE (env var, espaces) pour ne relancer que certains modeles
if [ -n "${MODELS_OVERRIDE:-}" ]; then
  read -ra MODELS <<< "$MODELS_OVERRIDE"
  APPEND_MODE=true
else
  MODELS=("gemma4:latest" "ministral-3:8b" "gpt-oss:20b")
  APPEND_MODE=false
fi
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_ROOT="$(dirname "$HARNESS_DIR")"
PROMPTS_FILE="$HARNESS_DIR/prompts.json"

# Nom du run
if [ $# -ge 1 ]; then
  RUN_NAME="$1"
else
  RUN_NAME="$(date '+%Y-%m-%d_%Hh%M')"
fi
RUN_DIR="$BENCH_ROOT/runs/$RUN_NAME"
mkdir -p "$RUN_DIR"

# Header console
echo "================================================"
echo "  BENCH LLM LOCAUX"
echo "  Run : $RUN_NAME"
echo "  Prompts : $PROMPTS_FILE"
echo "  Sortie : $RUN_DIR"
echo "================================================"
echo ""

TESTS_COUNT=$(jq '.tests | length' "$PROMPTS_FILE")
OVERALL_CSV="$RUN_DIR/_metrics.csv"
if [ "$APPEND_MODE" = "false" ] || [ ! -f "$OVERALL_CSV" ]; then
  echo "model,test_id,test_label,duree_s,eval_duration_s,eval_count,tokens_per_s,thinking_chars,response_chars" > "$OVERALL_CSV"
fi

for model in "${MODELS[@]}"; do
  MODEL_SAFE=$(echo "$model" | tr ':/' '__')
  OUT_FILE="$RUN_DIR/${MODEL_SAFE}.md"

  {
    echo "# $model"
    echo ""
    echo "Run : $RUN_NAME"
    echo ""
  } > "$OUT_FILE"

  echo "───────────────────────────────────────────"
  echo "  MODELE : $model"
  echo "───────────────────────────────────────────"

  # Detection support thinking (probe 1-token)
  PROBE=$(curl -s http://localhost:11434/api/generate \
    -d "$(jq -n --arg m "$model" '{model:$m, prompt:"hi", stream:false, think:true, options:{num_predict:1}}')")
  if echo "$PROBE" | jq -r '.error // ""' | grep -qi 'thinking'; then
    THINK_BOOL="false"
    echo "  (thinking non supporte par ce modele)"
  else
    THINK_BOOL="true"
  fi

  # Si on est en mode append, nettoyer les lignes existantes de ce modele du CSV
  if [ "$APPEND_MODE" = "true" ] && [ -f "$OVERALL_CSV" ]; then
    grep -v "^\"$model\"," "$OVERALL_CSV" > "$OVERALL_CSV.tmp"
    mv "$OVERALL_CSV.tmp" "$OVERALL_CSV"
  fi

  for i in $(seq 0 $((TESTS_COUNT - 1))); do
    ID=$(jq -r ".tests[$i].id" "$PROMPTS_FILE")
    LABEL=$(jq -r ".tests[$i].label" "$PROMPTS_FILE")
    PROMPT=$(jq -r ".tests[$i].prompt" "$PROMPTS_FILE")
    SOURCE=$(jq -r ".tests[$i].source // \"generique\"" "$PROMPTS_FILE")
    RUBRIQUE=$(jq -r ".tests[$i].rubrique // \"subjective\"" "$PROMPTS_FILE")

    echo ""
    echo "  [$((i+1))/$TESTS_COUNT] $LABEL..."

    START=$(date +%s)
    RESP=$(curl -s --max-time 600 http://localhost:11434/api/generate \
      -d "$(jq -n --arg m "$model" --arg p "$PROMPT" --argjson t "$THINK_BOOL" \
        '{model:$m, prompt:$p, stream:false, think:$t, options:{temperature:0.2, num_predict:4096}}')")
    END=$(date +%s)

    DUR=$((END - START))
    OUTPUT=$(echo "$RESP" | jq -r '.response // ""')
    THINKING=$(echo "$RESP" | jq -r '.thinking // ""')
    THINKING_CHARS=${#THINKING}
    RESPONSE_CHARS=${#OUTPUT}
    EVAL_COUNT=$(echo "$RESP" | jq -r '.eval_count // 0')
    EVAL_DUR_NS=$(echo "$RESP" | jq -r '.eval_duration // 0')
    EVAL_DUR_S=$(echo "scale=2; $EVAL_DUR_NS / 1000000000" | bc)
    if [ "$EVAL_DUR_NS" -gt 0 ]; then
      TOKS=$(echo "scale=1; $EVAL_COUNT / ($EVAL_DUR_NS / 1000000000)" | bc)
    else
      TOKS="0"
    fi

    echo "       duree=${DUR}s  eval=${EVAL_DUR_S}s  tokens=${EVAL_COUNT}  tps=${TOKS}t/s  thinking=${THINKING_CHARS}c  reponse=${RESPONSE_CHARS}c"

    # Log markdown
    {
      echo "## $LABEL"
      echo ""
      echo "- **Source** : $SOURCE"
      echo "- **Stats** : duree=${DUR}s | eval=${EVAL_DUR_S}s | tokens=${EVAL_COUNT} (total) | vitesse=${TOKS} t/s | thinking=${THINKING_CHARS}c | reponse=${RESPONSE_CHARS}c"
      echo "- **Rubrique** : $RUBRIQUE"
      echo ""
      if [ "$THINKING_CHARS" -gt 0 ]; then
        echo "**Thinking :**"
        echo ""
        echo '```'
        echo "$THINKING"
        echo '```'
        echo ""
      fi
      echo "**Reponse :**"
      echo ""
      echo '```'
      echo "$OUTPUT"
      echo '```'
      echo ""
      echo "---"
      echo ""
    } >> "$OUT_FILE"

    # Log CSV
    echo "\"$model\",\"$ID\",\"$LABEL\",$DUR,$EVAL_DUR_S,$EVAL_COUNT,$TOKS,$THINKING_CHARS,$RESPONSE_CHARS" >> "$OVERALL_CSV"
  done

  echo ""
done

echo ""
echo "================================================"
echo "  Resultats : $RUN_DIR/"
echo "  Metriques CSV : $OVERALL_CSV"
echo "================================================"
