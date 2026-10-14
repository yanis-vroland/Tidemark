#!/bin/bash
# Usage : GPU=<couches> MODE=<release|debug> runall.sh <appareil> <dossier projet> <dossier de sortie>
# Lance chaque configuration l'une après l'autre ; un log par appareil et par configuration.
DEV=$1; APP=$2; OUT=$3; mkdir -p "$OUT"; cd "$APP" || exit 1
run() { name=$1; shift; log="$OUT/$name.log"
  flutter run --$MODE -d "$DEV" "$@" > "$log" 2>&1 &
  pid=$!
  for i in $(seq 1 360); do grep -aqE "TIDEMARK_RESULT|TIDEMARK ERREUR|FAILURE|BUILD FAILED" "$log" && break; sleep 5; done
  grep -aqE "TIDEMARK_RESULT|TIDEMARK ERREUR" "$log" && echo "$name OK" >> "$OUT/status.txt" || echo "$name SANS RESULTAT" >> "$OUT/status.txt"
  kill $pid 2>/dev/null; pkill -f "flutter_tools.*-d $DEV"; sleep 3; }
run llamadart-schema --dart-define=ENGINE=llamadart --dart-define=MODEL=qwen2.5-1.5b-instruct-q4_k_m.gguf --dart-define=CONSTRAINED=true --dart-define=GPU_LAYERS=$GPU
run llamadart-libre --dart-define=ENGINE=llamadart --dart-define=MODEL=qwen2.5-1.5b-instruct-q4_k_m.gguf --dart-define=CONSTRAINED=false --dart-define=GPU_LAYERS=$GPU
run edge-tools --dart-define=ENGINE=edge --dart-define=MODEL=Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm --dart-define=CONSTRAINED=true
run edge-libre --dart-define=ENGINE=edge --dart-define=MODEL=Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm --dart-define=CONSTRAINED=false
echo FIN >> "$OUT/status.txt"
