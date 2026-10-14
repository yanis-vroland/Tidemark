#!/bin/bash
# Usage : run-iphone.sh <udid> <dossier projet> <dossier de sortie> <nom> <dart-defines…>
# Sans les logs de flutter run (iproxy exige Rosetta) : build, installation et lancement par
# devicectl, puis récupération de result.json écrit par l'app à côté du modèle.
UDID=$1; APP=$2; OUT=$3; NAME=$4; shift 4; mkdir -p "$OUT"; cd "$APP" || exit 1
BUNDLE=dev.tidemark.tidemarkSpike
flutter build ios --profile "$@" > "$OUT/$NAME.build.log" 2>&1 || { echo "$NAME BUILD ÉCHOUÉ" >> "$OUT/status.txt"; exit 1; }
xcrun devicectl device install app --device "$UDID" build/ios/iphoneos/Runner.app > /dev/null 2>&1
xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE" > /dev/null 2>&1
for i in $(seq 1 180); do
  sleep 5
  if xcrun devicectl device copy from --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
      --source Documents/result.json --destination "$OUT/$NAME.json" > /dev/null 2>&1; then
    echo "TIDEMARK_RESULT $(cat "$OUT/$NAME.json")" > "$OUT/$NAME.log"; echo "$NAME OK" >> "$OUT/status.txt"; exit 0
  fi
done
echo "$NAME SANS RESULTAT" >> "$OUT/status.txt"
