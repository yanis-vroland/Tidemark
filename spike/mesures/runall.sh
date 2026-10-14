#!/bin/bash
# Usage : GPU=<couches> MODE=<release|debug> [CONFIGS="..."] runall.sh <appareil> <dossier projet> <dossier de sortie>
# Lance chaque configuration l'une après l'autre ; un log par appareil et par configuration.
DEV=$1; APP=$2; OUT=$3; mkdir -p "$OUT"; cd "$APP" || exit 1
run() { name=$1; shift; log="$OUT/$name.log"
  flutter run --$MODE -d "$DEV" "$@" > "$log" 2>&1 &
  pid=$!
  for i in $(seq 1 360); do grep -aqE "TIDEMARK_RESULT|TIDEMARK ERREUR|FAILURE|BUILD FAILED" "$log" && break; sleep 5; done
  grep -aqE "TIDEMARK_RESULT|TIDEMARK ERREUR" "$log" && echo "$name OK" >> "$OUT/status.txt" || echo "$name SANS RESULTAT" >> "$OUT/status.txt"
  kill $pid 2>/dev/null; pkill -f "flutter_tools.*-d $DEV"; sleep 3; }
Q25G=qwen2.5-1.5b-instruct-q4_k_m.gguf
Q25L=Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm
Q3L=Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm
for c in ${CONFIGS:-llamadart-schema llamadart-libre edge-tools edge-libre}; do case $c in
  llamadart-schema) run $c --dart-define=ENGINE=llamadart --dart-define=MODEL=$Q25G --dart-define=CONSTRAINED=true --dart-define=GPU_LAYERS=$GPU ;;
  llamadart-libre) run $c --dart-define=ENGINE=llamadart --dart-define=MODEL=$Q25G --dart-define=CONSTRAINED=false --dart-define=GPU_LAYERS=$GPU ;;
  edge-tools) run $c --dart-define=ENGINE=edge --dart-define=MODEL=$Q3L --dart-define=CONSTRAINED=true ;;
  edge-libre) run $c --dart-define=ENGINE=edge --dart-define=MODEL=$Q3L --dart-define=CONSTRAINED=false ;;
  edge-q25-tools) run $c --dart-define=ENGINE=edge --dart-define=MODEL=$Q25L --dart-define=MODEL_TYPE=qwen --dart-define=CONSTRAINED=true ;;
  edge-q25-libre) run $c --dart-define=ENGINE=edge --dart-define=MODEL=$Q25L --dart-define=MODEL_TYPE=qwen --dart-define=CONSTRAINED=false ;;
esac; done
echo FIN >> "$OUT/status.txt"
