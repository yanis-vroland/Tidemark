#!/usr/bin/env bash
# Vérifie scripts/check-llama-hook-cache.sh (ADR-004, option B) sur un cache de
# pub factice.
#
# Interface testée :
#   check-llama-hook-cache.sh           échoue si le hook de llamadart a gardé dans
#                                       le cache de pub un moteur qu'il a téléchargé
#                                       lui-même (tout dossier de native_bundles/
#                                       autre que local/), si aucun paquet llamadart
#                                       n'est trouvé, ou si aucune extraction sous
#                                       local/ n'existe ;
#   check-llama-hook-cache.sh --purge   efface ces dossiers (cache restauré par la
#                                       CI), puis réussit.
# Variable : PUB_CACHE (par défaut ~/.pub-cache) ; tous les hôtes (hosted/*).
set -u

root="$(cd "$(dirname "$0")/.." && pwd -P)"
script="$root/scripts/check-llama-hook-cache.sh"
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

code=0
err=""
run() {
  local cache=$1
  shift
  PUB_CACHE="$cache" "$script" "$@" >/dev/null 2>"$work/stderr"
  code=$?
  err=$(cat "$work/stderr")
}
refused() { [ "$code" -ge 1 ] && [ "$code" -le 125 ]; }

bundles() { echo "$1/hosted/pub.dev/llamadart-0.12.0/.dart_tool/llamadart/native_bundles"; }

# 1. Cache sans llamadart : rien n'a été contrôlé, refus ; --purge passe quand même
# (attente changée après la revue de sécurité : le contrôle réussissait sans rien voir)
mkdir -p "$work/c1/hosted/pub.dev"
run "$work/c1"
if refused && [[ "$err" == *"aucun paquet llamadart"* ]]; then pass "cache sans llamadart : refus"; else failed "cache sans llamadart : refus" "code $code"; fi
run "$work/c1" --purge
if [ "$code" -eq 0 ]; then pass "cache sans llamadart, --purge : accepté"; else failed "cache sans llamadart, --purge : accepté" "code $code"; fi

# Paquet llamadart sans aucune extraction du dossier local : le hook ne l'a pas pris
mkdir -p "$(bundles "$work/c1b")"
run "$work/c1b"
if refused; then pass "aucune extraction sous local/ : refus"; else failed "aucune extraction sous local/ : refus" "code $code"; fi

mkdir -p "$(bundles "$work/c2")/local/abc/v0.6.0-2/macos-arm64/extracted"
run "$work/c2"
if [ "$code" -eq 0 ]; then pass "extraction du dossier local seule : acceptée"; else failed "extraction du dossier local seule : acceptée" "code $code"; fi

# 2. Moteur téléchargé par le hook (dossier du tag) : refus
mkdir -p "$(bundles "$work/c3")/v0.6.0-2/linux-x64"
printf 'x' >"$(bundles "$work/c3")/v0.6.0-2/linux-x64/llamadart-native-linux-x64-v0.6.0-2.tar.gz"
run "$work/c3"
if refused; then pass "moteur téléchargé par le hook : refus"; else failed "moteur téléchargé par le hook : refus" "code $code"; fi

# 2 bis. Nom caché ou miroir de pub : vus aussi
mkdir -p "$(bundles "$work/c5")/local/abc" "$(bundles "$work/c5")/..x"
run "$work/c5"
if refused; then pass "dossier caché « ..x » : refus"; else failed "dossier caché « ..x » : refus" "code $code"; fi
mirror="$work/c6/hosted/mirror.example.com/llamadart-0.12.0/.dart_tool/llamadart/native_bundles"
mkdir -p "$mirror/local/abc"
run "$work/c6"
if [ "$code" -eq 0 ]; then pass "miroir de pub, extraction locale seule : accepté"; else failed "miroir de pub, extraction locale seule : accepté" "code $code"; fi
mkdir -p "$mirror/v0.6.0-2/linux-x64"
run "$work/c6"
if refused; then pass "miroir de pub, moteur téléchargé : refus"; else failed "miroir de pub, moteur téléchargé : refus" "code $code"; fi

# 3. Autre dépôt (github/…) : refus
mkdir -p "$(bundles "$work/c4")/local/abc" "$(bundles "$work/c4")/github/autre/depot/v1/linux-x64"
run "$work/c4"
if refused; then pass "moteur d'un autre dépôt : refus"; else failed "moteur d'un autre dépôt : refus" "code $code"; fi

# 4. --purge efface les téléchargements du hook, garde local/, puis le contrôle passe
mkdir -p "$(bundles "$work/c3")/local/abc"
run "$work/c3" --purge
if [ "$code" -eq 0 ] && [ ! -e "$(bundles "$work/c3")/v0.6.0-2" ] && [ -d "$(bundles "$work/c3")/local/abc" ]; then
  pass "--purge : téléchargements du hook effacés, local/ gardé"
else
  failed "--purge : téléchargements du hook effacés, local/ gardé" "code $code"
fi
run "$work/c3"
if [ "$code" -eq 0 ]; then pass "après --purge : contrôle accepté"; else failed "après --purge : contrôle accepté" "code $code"; fi

if [ "$fail" -ne 0 ]; then
  echo "Des vérifications ont échoué."
  exit 1
fi
echo "Toutes les vérifications sont passées."
