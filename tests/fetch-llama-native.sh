#!/usr/bin/env bash
# Vérifie scripts/fetch-llama-native.sh (ADR-004, option A) sur des archives
# factices servies en file:// : aucun accès à Internet.
#
# Interface testée :
#   fetch-llama-native.sh [bundle...]   prépare le dossier du moteur natif pour les
#                                       bundles donnés (par défaut, ceux de l'hôte).
# Variables (pour les tests) : LLAMA_NATIVE_DIR (dossier préparé),
# LLAMA_NATIVE_PINS (fichier d'empreintes), LLAMA_NATIVE_BASE_URL (adresse des
# archives). Le dossier ne contient que des archives épinglées ; chaque archive
# présente est revérifiée à chaque lancement ; une archive téléchargée n'y entre
# qu'après vérification. Erreurs sur stderr, code non nul.
#
# Un échec attendu est un code entre 1 et 125 : 126 et 127 (script non exécutable
# ou absent) ne comptent pas comme un refus.
set -u

root="$(cd "$(dirname "$0")/.." && pwd -P)"
script="$root/scripts/fetch-llama-native.sh"
pins_real="$root/scripts/llama-native.sha256"
fail=0

if [ ! -f "$script" ]; then
  echo "ÉCHEC  $script est absent : toutes les vérifications vont échouer"
  fail=1
fi

if ! work=$(mktemp -d) || ! work=$(cd "$work" && pwd -P); then
  echo "Erreur : mktemp -d a échoué" >&2
  exit 1
fi
trap 'rm -rf "$work"' EXIT

pass() { echo "OK     $1"; }
failed() {
  echo "ÉCHEC  $1${2:+ ($2)}"
  fail=1
}

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Archives factices, servies depuis $work/release
mkdir -p "$work/release"
printf 'archive android factice\n' >"$work/release/llamadart-native-android-arm64-v0.6.0-2.tar.gz"
printf 'archive ios factice\n' >"$work/release/llamadart-native-ios-arm64-v0.6.0-2.tar.gz"
android_sha=$(sha "$work/release/llamadart-native-android-arm64-v0.6.0-2.tar.gz")
ios_sha=$(sha "$work/release/llamadart-native-ios-arm64-v0.6.0-2.tar.gz")
wrong_sha=0000000000000000000000000000000000000000000000000000000000000000

# write_pins <fichier> <empreinte android> <empreinte ios>
write_pins() {
  {
    echo "# Empreintes de test"
    echo "$2  llamadart-native-android-arm64-v0.6.0-2.tar.gz"
    echo "$3  llamadart-native-ios-arm64-v0.6.0-2.tar.gz"
  } >"$1"
}
write_pins "$work/pins" "$android_sha" "$ios_sha"

err=""
code=0

# run <dossier> <adresse> <pins> <arguments...>
run() {
  local dir=$1 base=$2 pins=$3
  shift 3
  LLAMA_NATIVE_DIR="$dir" LLAMA_NATIVE_BASE_URL="$base" \
    LLAMA_NATIVE_PINS="$pins" "$script" "$@" >/dev/null 2>"$work/stderr"
  code=$?
  err=$(cat "$work/stderr")
}

refused() { [ "$code" -ge 1 ] && [ "$code" -le 125 ]; }

base="file://$work/release"
nowhere="file://$work/absent"

# 1. Téléchargement de deux archives justes
dir="$work/d1"
run "$dir" "$base" "$work/pins" android-arm64 ios-arm64
if [ "$code" -eq 0 ] &&
  [ "$(sha "$dir/llamadart-native-android-arm64-v0.6.0-2.tar.gz")" = "$android_sha" ] &&
  [ "$(sha "$dir/llamadart-native-ios-arm64-v0.6.0-2.tar.gz")" = "$ios_sha" ]; then
  pass "archives téléchargées et vérifiées"
else
  failed "archives téléchargées et vérifiées" "code $code, $err"
fi

# 2. Relance sans réseau : les archives présentes sont revérifiées, rien n'est téléchargé
run "$dir" "$nowhere" "$work/pins" android-arm64 ios-arm64
if [ "$code" -eq 0 ]; then
  pass "archives présentes et justes : acceptées sans téléchargement"
else
  failed "archives présentes et justes : acceptées sans téléchargement" "code $code, $err"
fi

# 3. Empreinte épinglée fausse : téléchargement refusé, rien n'entre dans le dossier
write_pins "$work/pins-wrong" "$wrong_sha" "$ios_sha"
dir="$work/d3"
run "$dir" "$base" "$work/pins-wrong" android-arm64
if refused && [ ! -e "$dir/llamadart-native-android-arm64-v0.6.0-2.tar.gz" ]; then
  pass "empreinte fausse au téléchargement : refus, archive absente"
else
  failed "empreinte fausse au téléchargement : refus, archive absente" "code $code"
fi
if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
  pass "empreinte fausse : aucun fichier temporaire laissé dans le dossier"
else
  failed "empreinte fausse : aucun fichier temporaire laissé dans le dossier" "$(ls -A "$dir")"
fi

# 4. Archive en cache altérée : revérifiée, refusée et effacée
dir="$work/d4"
mkdir -p "$dir"
cp "$work/release/llamadart-native-android-arm64-v0.6.0-2.tar.gz" "$dir/"
printf 'altération\n' >>"$dir/llamadart-native-android-arm64-v0.6.0-2.tar.gz"
run "$dir" "$base" "$work/pins" android-arm64
if refused && [ ! -e "$dir/llamadart-native-android-arm64-v0.6.0-2.tar.gz" ]; then
  pass "archive en cache altérée : refus et effacement"
else
  failed "archive en cache altérée : refus et effacement" "code $code"
fi

# 5. Une archive altérée d'un autre bundle que ceux demandés est aussi refusée
dir="$work/d5"
mkdir -p "$dir"
printf 'autre contenu\n' >"$dir/llamadart-native-ios-arm64-v0.6.0-2.tar.gz"
run "$dir" "$base" "$work/pins" android-arm64
if refused && [ ! -e "$dir/llamadart-native-ios-arm64-v0.6.0-2.tar.gz" ]; then
  pass "archive altérée d'un bundle non demandé : refus et effacement"
else
  failed "archive altérée d'un bundle non demandé : refus et effacement" "code $code"
fi

# 6. Bibliothèque ou dossier déposé à côté des archives : refus (le hook l'utiliserait sans contrôle)
for intrus in libllamadart.so libllamadart.dylib llama.framework extracted android-arm64 notes.txt; do
  dir="$work/d6-$intrus"
  mkdir -p "$dir"
  case "$intrus" in
    *.*) printf 'x' >"$dir/$intrus" ;;
    *) mkdir -p "$dir/$intrus" ;;
  esac
  run "$dir" "$base" "$work/pins" android-arm64
  if refused; then
    pass "entrée inattendue « $intrus » : refus"
  else
    failed "entrée inattendue « $intrus » : refus" "code $code"
  fi
done

# 7. Bundle absent du fichier d'empreintes : refus
dir="$work/d7"
run "$dir" "$base" "$work/pins" linux-x64
if refused && [ -n "$err" ]; then
  pass "bundle non épinglé : refus avec message"
else
  failed "bundle non épinglé : refus avec message" "code $code"
fi

# 8. Archive introuvable : refus
dir="$work/d8"
run "$dir" "$nowhere" "$work/pins" android-arm64
if refused; then
  pass "archive introuvable : refus"
else
  failed "archive introuvable : refus" "code $code"
fi

# 9. Fichier d'empreintes réel : une ligne par bundle utile, 64 caractères hexadécimaux,
# tag de llamadart 0.12.0 (v0.6.0-2)
expected="android-arm64 android-x64 ios-arm64 ios-arm64-sim ios-x86_64-sim linux-x64 macos-arm64"
for bundle in $expected; do
  name="llamadart-native-$bundle-v0.6.0-2.tar.gz"
  if grep -Eq "^[0-9a-f]{64}  $name\$" "$pins_real" 2>/dev/null; then
    pass "empreinte épinglée pour $bundle"
  else
    failed "empreinte épinglée pour $bundle"
  fi
done
lines=$(grep -Evc '^(#|$)' "$pins_real" 2>/dev/null || true)
if [ "${lines:-0}" -eq 7 ]; then
  pass "fichier d'empreintes : exactement 7 archives"
else
  failed "fichier d'empreintes : exactement 7 archives" "${lines:-0} lignes"
fi

if [ "$fail" -ne 0 ]; then
  echo "Des vérifications ont échoué."
  exit 1
fi
echo "Toutes les vérifications sont passées."
