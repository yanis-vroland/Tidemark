#!/usr/bin/env bash
# Prépare le dossier du moteur natif llama.cpp (ADR-004, option A) : télécharge les
# archives de la release v0.6.0-2 de leehack/llamadart-native, vérifie leur SHA-256
# contre scripts/llama-native.sha256, et les dépose dans .llamadart-native/, que
# pubspec.yaml donne au hook de llamadart (llamadart_native_path). Le hook ne
# télécharge alors plus rien : il extrait ces archives à chaque construction.
#
# Usage : scripts/fetch-llama-native.sh [bundle...]
#   Sans argument, les bundles de l'hôte : sur macOS, Android (arm64, x64), iOS
#   (appareil et simulateurs) et macos-arm64 (flutter test) ; sur Linux,
#   linux-x64 (flutter test en CI).
#
# À lancer après chaque clonage et avant flutter run, flutter build ou flutter test.
# Chaque archive déjà présente est revérifiée à chaque lancement : une archive
# altérée est effacée et le script échoue. Le dossier ne doit contenir que des
# archives épinglées : le hook utiliserait sans contrôle une bibliothèque ou un
# dossier déposé à côté.
#
# Variables, pour les tests : LLAMA_NATIVE_DIR, LLAMA_NATIVE_PINS,
# LLAMA_NATIVE_BASE_URL.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
dir="${LLAMA_NATIVE_DIR:-$root/.llamadart-native}"
pins="${LLAMA_NATIVE_PINS:-$root/scripts/llama-native.sha256}"
tag="v0.6.0-2"
base="${LLAMA_NATIVE_BASE_URL:-https://github.com/leehack/llamadart-native/releases/download/$tag}"

die() {
  echo "fetch-llama-native : $*" >&2
  exit 1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

archive_of() { echo "llamadart-native-$1-$tag.tar.gz"; }

# Empreinte épinglée de l'archive $1, ou rien.
pinned() {
  awk -v name="$1" '$0 !~ /^#/ && NF == 2 && $2 == name { print $1 }' "$pins"
}

[ -f "$pins" ] || die "fichier d'empreintes introuvable : $pins"

if [ "$#" -gt 0 ]; then
  bundles=("$@")
else
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)
      bundles=(android-arm64 android-x64 ios-arm64 ios-arm64-sim ios-x86_64-sim macos-arm64) ;;
    Linux-x86_64)
      bundles=(linux-x64) ;;
    *)
      die "hôte non pris en charge : $(uname -s)-$(uname -m) ; donner les bundles en argument" ;;
  esac
fi

for bundle in "${bundles[@]}"; do
  [ -n "$(pinned "$(archive_of "$bundle")")" ] ||
    die "aucune empreinte épinglée pour $bundle dans $pins"
done

mkdir -p "$dir"

# 1. Rien d'autre que des archives épinglées dans le dossier.
unexpected=()
for entry in "$dir"/* "$dir"/.[!.]*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  name="$(basename "$entry")"
  if [ ! -f "$entry" ] || [ -L "$entry" ] || [ -z "$(pinned "$name")" ]; then
    unexpected+=("$name")
  fi
done
if [ "${#unexpected[@]}" -gt 0 ]; then
  die "entrées inattendues dans $dir : ${unexpected[*]} ; le hook pourrait les utiliser sans contrôle. Effacer le dossier, puis relancer."
fi

# 2. Chaque archive présente est revérifiée, demandée ou non.
altered=0
for entry in "$dir"/*.tar.gz; do
  [ -f "$entry" ] || continue
  name="$(basename "$entry")"
  if [ "$(sha256_of "$entry")" != "$(pinned "$name")" ]; then
    echo "fetch-llama-native : empreinte fausse, archive effacée : $name" >&2
    rm -f "$entry"
    altered=1
  fi
done
[ "$altered" -eq 0 ] || die "archive altérée dans $dir ; relancer pour la télécharger de nouveau"

# 3. Téléchargement des archives manquantes, vérifiées avant d'entrer dans le dossier.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for bundle in "${bundles[@]}"; do
  name="$(archive_of "$bundle")"
  if [ -f "$dir/$name" ]; then
    echo "Vérifiée : $name"
    continue
  fi
  echo "Téléchargement : $name"
  curl -fsSL --proto '=https,file' --proto-redir '=https' --retry 3 \
    -o "$tmp/$name" "$base/$name" || die "téléchargement impossible : $base/$name"
  actual="$(sha256_of "$tmp/$name")"
  expected="$(pinned "$name")"
  [ "$actual" = "$expected" ] ||
    die "empreinte fausse pour $name : $actual au lieu de $expected ; archive refusée"
  mv "$tmp/$name" "$dir/$name"
  echo "Vérifiée : $name"
done

echo "Moteur natif prêt dans $dir"
