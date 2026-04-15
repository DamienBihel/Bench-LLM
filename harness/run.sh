#!/bin/bash
# Bench LLM locaux — harness reproductible
# Usage : ./run.sh [run_name]
#   run_name : nom du sous-dossier dans ../runs/ (defaut = YYYY-MM-DD_HHhMM)

set -u

# Parametres
MODELS=("gemma4:latest" "ministral-3:8b" "gpt-oss:20b")
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
echo "model,test_id,test_label,duree_s,eval_duration_s,eval_count,tokens_per_s" > "$OVERALL_CSV"

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

  for i in $(seq 0 $((TESTS_COUNT - 1))); do
    ID=$(jq -r ".tests[$i].id" "$PROMPTS_FILE")
    LABEL=$(jq -r ".tests[$i].label" "$PROMPTS_FILE")
    PROMPT=$(jq -r ".tests[$i].prompt" "$PROMPTS_FILE")
    SOURCE=$(jq -r ".tests[$i].source // \"generique\"" "$PROMPTS_FILE")
    RUBRIQUE=$(jq -r ".tests[$i].rubrique // \"subjective\"" "$PROMPTS_FILE")

    echo ""
    echo "  [$((i+1))/$TESTS_COUNT] $LABEL..."

    START=$(date +%s)
    RESP=$(curl -s http://localhost:11434/api/generate \
      -d "$(jq -n --arg m "$model" --arg p "$PROMPT" \
        '{model:$m, prompt:$p, stream:false, options:{temperature:0.2}}')")
    END=$(date +%s)

    DUR=$((END - START))
    OUTPUT=$(echo "$RESP" | jq -r '.response')
    EVAL_COUNT=$(echo "$RESP" | jq -r '.eval_count // 0')
    EVAL_DUR_NS=$(echo "$RESP" | jq -r '.eval_duration // 0')
    EVAL_DUR_S=$(echo "scale=2; $EVAL_DUR_NS / 1000000000" | bc)
    if [ "$EVAL_DUR_NS" -gt 0 ]; then
      TOKS=$(echo "scale=1; $EVAL_COUNT / ($EVAL_DUR_NS / 1000000000)" | bc)
    else
      TOKS="0"
    fi

    echo "       duree=${DUR}s  eval=${EVAL_DUR_S}s  tokens=${EVAL_COUNT}  tps=${TOKS}t/s"

    # Log markdown
    {
      echo "## $LABEL"
      echo ""
      echo "- **Source** : $SOURCE"
      echo "- **Stats** : duree=${DUR}s | eval=${EVAL_DUR_S}s | tokens=${EVAL_COUNT} | vitesse=${TOKS} t/s"
      echo "- **Rubrique** : $RUBRIQUE"
      echo ""
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
    echo "\"$model\",\"$ID\",\"$LABEL\",$DUR,$EVAL_DUR_S,$EVAL_COUNT,$TOKS" >> "$OVERALL_CSV"
  done

  echo ""
done

echo ""
echo "================================================"
echo "  Resultats : $RUN_DIR/"
echo "  Metriques CSV : $OVERALL_CSV"
echo "================================================"
