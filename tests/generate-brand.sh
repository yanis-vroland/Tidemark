#!/usr/bin/env bash
# Vérifie tool/generate_brand.py selon la spec 007 (CA2) : `--check` réussit sur le
# dépôt, échoue dès qu'un fichier généré diffère, et le script est déterministe.
# Travaille sur une copie temporaire du dépôt : le dépôt n'est jamais modifié.
# Codes : 0 tout est conforme, 1 au moins un échec.
set -u

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
fail=0

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

if [ ! -f "$repo/tool/generate_brand.py" ]; then
  failed "tool/generate_brand.py est absent" "toutes les vérifications vont échouer"
fi

# Copie du dépôt sans .git ni dossiers lourds, puis lancement du script dans la copie
fresh_copy() {
  local dest
  dest=$(mktemp -d "$work/copy.XXXXXX")
  (cd "$repo" && tar --exclude=.git --exclude=.dart_tool --exclude=build \
    --exclude=.llamadart-native --exclude=node_modules -cf - .) | (cd "$dest" && tar -xf -)
  echo "$dest"
}

gen() { (cd "$1" && python3 tool/generate_brand.py "${@:2}" 2>&1); }

# Fichiers générés (liste des chemins relatifs) : ceux que la spec cite pour CA1 et CA3
generated_files() {
  local root=$1
  (
    cd "$root" || exit 1
    ls docs/maquettes/000-charte/logo/tidemark-logo.svg \
      docs/maquettes/000-charte/logo/tidemark-mark.svg \
      docs/maquettes/000-charte/logo/tidemark-mark-mono.svg \
      ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png \
      ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png \
      ios/Runner/Base.lproj/LaunchScreen.storyboard \
      android/app/src/main/res/mipmap-*/ic_launcher.* \
      android/app/src/main/res/drawable/ic_launcher_foreground.xml \
      android/app/src/main/res/drawable/launch_logo.xml \
      android/app/src/main/res/drawable/launch_background.xml \
      android/app/src/main/res/drawable-v21/launch_background.xml \
      android/app/src/main/res/values/colors.xml \
      android/app/src/main/res/values-night/colors.xml \
      android/app/src/main/res/values/styles.xml \
      android/app/src/main/res/values-night/styles.xml \
      android/app/src/main/res/values-v31/styles.xml \
      android/app/src/main/res/values-night-v31/styles.xml 2>/dev/null
  )
}

# Empreinte de tous les fichiers générés (nom + contenu)
fingerprint() {
  local root=$1 f
  generated_files "$root" | sort | while read -r f; do
    printf '%s ' "$f"
    shasum -a 256 "$root/$f" | cut -d' ' -f1
  done
}

# --- CA2 : --check réussit sur le dépôt tel quel ------------------------------
copy=$(fresh_copy)
before=$(fingerprint "$copy")
if out=$(gen "$copy" --check); then
  pass "CA2 : --check réussit sur le dépôt"
else
  failed "CA2 : --check réussit sur le dépôt" "$(head -n 1 <<<"$out")"
fi
if [ -f "$copy/tool/generate_brand.py" ] && [ "$(fingerprint "$copy")" = "$before" ]; then
  pass "CA2 : --check n'écrit rien"
else
  failed "CA2 : --check n'écrit rien" "script absent, ou un fichier a changé"
fi

# --- CA2 : un octet modifié dans un fichier généré fait échouer --check -------
# corrupt <dépôt> <fichier> : change un octet au milieu du fichier
corrupt() {
  python3 - "$1/$2" <<'PY'
import sys
path = sys.argv[1]
data = bytearray(open(path, "rb").read())
i = len(data) // 2
data[i] = (data[i] + 1) % 256
open(path, "wb").write(data)
PY
}

for target in \
  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" \
  "android/app/src/main/res/drawable/launch_logo.xml" \
  "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png" \
  "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" \
  "docs/maquettes/000-charte/logo/tidemark-logo.svg"; do
  copy=$(fresh_copy)
  if [ ! -f "$copy/$target" ]; then
    failed "CA2 : --check échoue après modification de $target" "fichier absent"
    continue
  fi
  # Précondition : sans script fonctionnel, un échec de --check ne prouverait rien
  if ! gen "$copy" --check >/dev/null; then
    failed "CA2 : --check échoue après modification de $target" "précondition : --check échoue déjà sur la copie intacte"
    continue
  fi
  corrupt "$copy" "$target"
  corrupted=$(fingerprint "$copy")
  if out=$(gen "$copy" --check); then
    failed "CA2 : --check échoue après modification de $target" "code 0"
  else
    pass "CA2 : --check échoue après modification de $target"
  fi
  if [ "$(fingerprint "$copy")" = "$corrupted" ]; then
    pass "CA2 : --check n'a pas réécrit $target"
  else
    failed "CA2 : --check n'a pas réécrit $target" "le fichier a été modifié par --check"
  fi
done

# --- CA2 : un fichier généré supprimé fait aussi échouer --check ---------------
copy=$(fresh_copy)
if ! gen "$copy" --check >/dev/null; then
  failed "CA2 : --check échoue si un fichier généré manque" "précondition : --check échoue déjà sur la copie intacte"
else
rm -f "$copy/android/app/src/main/res/drawable/launch_logo.xml"
if out=$(gen "$copy" --check); then
  failed "CA2 : --check échoue si un fichier généré manque" "code 0"
else
  pass "CA2 : --check échoue si un fichier généré manque"
fi
fi

# --- CA2 : sans argument, le script réécrit les fichiers (réparation) ---------
copy=$(fresh_copy)
good=$(fingerprint "$copy")
corrupt "$copy" "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
if gen "$copy" >/dev/null && [ "$(fingerprint "$copy")" = "$good" ]; then
  pass "CA2 : sans argument, le script restaure les fichiers générés"
else
  failed "CA2 : sans argument, le script restaure les fichiers générés"
fi

# --- CA2 : déterminisme ------------------------------------------------------
copy=$(fresh_copy)
gen_ok=1
gen "$copy" >/dev/null || gen_ok=0
first=$(fingerprint "$copy")
gen "$copy" >/dev/null || gen_ok=0
second=$(fingerprint "$copy")
if [ "$gen_ok" = 1 ] && [ -n "$first" ] && [ "$first" = "$second" ]; then
  pass "CA2 : deux exécutions successives donnent des fichiers identiques"
else
  failed "CA2 : deux exécutions successives donnent des fichiers identiques"
fi

# Une seconde copie, générée à part, doit aboutir aux mêmes octets
copy2=$(fresh_copy)
gen_ok2=1
gen "$copy2" >/dev/null || gen_ok2=0
if [ "$gen_ok" = 1 ] && [ "$gen_ok2" = 1 ] && [ -n "$first" ] && [ "$first" = "$(fingerprint "$copy2")" ]; then
  pass "CA2 : deux copies générées séparément sont identiques"
else
  failed "CA2 : deux copies générées séparément sont identiques"
fi

# --- Garde-fou : un nom d'icône de Contents.json n'écrit pas hors de son dossier ---
copy=$(fresh_copy)
contents="$copy/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
sed -i.bak 's#"Icon-App-20x20@1x.png"#"../../../../scripts/evil.png"#' "$contents" && rm -f "$contents.bak"
if gen "$copy" >/dev/null; then
  failed "Garde-fou : un nom d'icône qui sort du dossier est refusé" "le générateur a réussi"
elif [ -e "$copy/scripts/evil.png" ]; then
  failed "Garde-fou : un nom d'icône qui sort du dossier est refusé" "fichier écrit hors du dossier"
else
  pass "Garde-fou : un nom d'icône qui sort du dossier est refusé"
fi

exit "$fail"
