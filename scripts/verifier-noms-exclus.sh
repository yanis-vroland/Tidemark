#!/usr/bin/env bash
# Refuse les noms exclus (clients et employeurs réels, CLAUDE.md de l'espace de
# travail) dans les fichiers suivis et dans les commits d'une plage.
#
# Usage : scripts/verifier-noms-exclus.sh [plage | --all]
#   plage   défaut origin/main..HEAD
#   --all   tout l'historique (toutes les références), avant le passage en public
#
# Liste : variable EXCLUDED_NAMES (noms séparés par des virgules ; secret de CI).
# Hors CI seulement, à défaut, fichier local non versionné .excluded-names à la
# racine du dépôt (un nom par ligne ou séparés par des virgules). Comparaison
# insensible à la casse, par sous-chaîne ; un nom fait au moins 3 caractères.
#
# Ce qui est cherché :
# - contenu et chemin des fichiers suivis ;
# - pour chaque commit de la plage : message, nom et e-mail d'auteur et de
#   committer, lignes ajoutées par son diff ;
# - titre, description et branche de la PR, s'ils sont fournis par PR_TITLE,
#   PR_BODY et PR_HEAD_REF.
#
# La sortie ne cite jamais un nom : seulement le fichier (ou son objet Git si le
# chemin contient lui-même un nom) et le SHA du commit. Les journaux de CI sont
# publics.
#
# Liste vide ou absente : échec en CI (secret manquant), simple avertissement en
# local.
#
# Codes : 0 rien trouvé, 1 nom trouvé ou liste absente en CI, 2 usage invalide
# ou erreur de Git (une erreur ne vaut jamais « rien trouvé »).
set -u -o pipefail

# Casse des lettres accentuées (É et é) ; sans effet si la locale manque
export LC_ALL=C.UTF-8

if [ $# -gt 1 ]; then
  echo "Usage : $0 [plage | --all]   (défaut : origin/main..HEAD)" >&2
  exit 2
fi
range=${1:-origin/main..HEAD}

if ! top=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "Erreur : à lancer dans un dépôt Git" >&2
  exit 2
fi
cd "$top" || exit 2

if ! tmp=$(mktemp -d); then
  echo "Erreur : mktemp a échoué" >&2
  exit 2
fi
trap 'rm -rf "$tmp"' EXIT
patterns="$tmp/patterns"

in_ci() {
  case ${CI:-} in
    "" | false | 0) return 1 ;;
    *) return 0 ;;
  esac
}

# Erreur de Git : jamais « rien trouvé »
git_error() {
  echo "Erreur : git $1 a échoué : vérification impossible." >&2
  exit 2
}

# Un nom par ligne, sans espaces autour ni entrée vide : une ligne vide dans le
# fichier de motifs ferait correspondre tout le dépôt.
normalize() {
  tr -d '\r' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | { grep -v '^$' || true; }
}

printf '%s' "${EXCLUDED_NAMES:-}" | normalize >"$patterns"
source_name="la variable EXCLUDED_NAMES"
# En CI, seul le secret compte : un fichier versionné ne doit pas en tenir lieu
if [ ! -s "$patterns" ] && ! in_ci && [ -f .excluded-names ]; then
  normalize <.excluded-names >"$patterns"
  source_name="le fichier .excluded-names"
fi

if [ ! -s "$patterns" ]; then
  if in_ci; then
    echo "Échec : la liste des noms exclus est vide. Le secret EXCLUDED_NAMES est absent ou vide : à créer avec « gh secret set EXCLUDED_NAMES »." >&2
    exit 1
  fi
  echo "Avertissement : aucune liste de noms exclus (variable EXCLUDED_NAMES ou fichier .excluded-names) : vérification sautée." >&2
  exit 0
fi

# Un motif trop court ferait échouer presque tout le dépôt ; le motif n'est pas cité
while IFS= read -r name; do
  if [ "${#name}" -lt 3 ]; then
    echo "Erreur : un nom de la liste ($source_name) fait moins de 3 caractères." >&2
    exit 2
  fi
done <"$patterns"

# --all est compris tel quel par git rev-list
if ! commits=$(git rev-list "$range" 2>/dev/null); then
  echo "Erreur : plage de commits invalide : $range" >&2
  exit 2
fi

found=0
report() {
  echo "$1"
  found=1
}

# matches : l'entrée standard contient-elle un nom de la liste ?
matches() {
  grep -qiF -f "$patterns"
}

g() {
  git -c core.quotePath=false "$@"
}

# Fichiers suivis, séparés par NUL
g ls-files -z >"$tmp/files" || git_error ls-files

# Un fichier .excluded-names suivi publierait la liste
if tr '\0' '\n' <"$tmp/files" | grep -qx '\.excluded-names'; then
  report "Fichier .excluded-names suivi par Git : à retirer de l'index (git rm --cached .excluded-names)"
fi

# Fichier à citer : son chemin, ou son objet si le chemin contient un nom
describe_file() {
  local blob
  if printf '%s\n' "$1" | matches; then
    blob=$(g ls-files -s -z -- ":(literal)$1" | tr '\0' '\n' | awk '{ print $2; exit }') || git_error ls-files
    echo "objet $blob (chemin masqué : il contient lui-même un nom exclu)"
  else
    echo "$1"
  fi
}

# Contenu des fichiers suivis (binaires compris) ; code 1 : rien trouvé
g grep -l -z -i -F -f "$patterns" >"$tmp/content"
case $? in
  0 | 1) ;;
  *) git_error grep ;;
esac
while IFS= read -r -d '' path; do
  report "Nom exclu dans le contenu de : $(describe_file "$path")"
done <"$tmp/content"

# Chemins des fichiers suivis
while IFS= read -r -d '' path; do
  if printf '%s\n' "$path" | matches; then
    report "Nom exclu dans le chemin du fichier : $(describe_file "$path")"
  fi
done <"$tmp/files"

# Commits de la plage
for sha in $commits; do
  g log -1 --format=%B "$sha" >"$tmp/message" || git_error log
  if matches <"$tmp/message"; then
    report "Nom exclu dans le message du commit : $sha"
  fi
  g log -1 --format='%an%n%ae%n%cn%n%ce' "$sha" >"$tmp/identity" || git_error log
  if matches <"$tmp/identity"; then
    report "Nom exclu dans l'auteur ou le committer du commit : $sha"
  fi
  # Lignes ajoutées seulement : une PR qui retire un nom doit passer
  g show --format= --no-color --no-ext-diff "$sha" >"$tmp/diff" || git_error show
  if grep '^+' "$tmp/diff" | matches; then
    report "Nom exclu dans les lignes ajoutées par le commit : $sha"
  fi
done

# Titre, description et branche de la PR (fournis par la CI)
check_text() {
  if [ -n "$2" ] && printf '%s\n' "$2" | matches; then
    report "Nom exclu dans $1"
  fi
}
check_text "le titre de la PR" "${PR_TITLE:-}"
check_text "la description de la PR" "${PR_BODY:-}"
check_text "le nom de la branche de la PR" "${PR_HEAD_REF:-}"

if [ "$found" -ne 0 ]; then
  echo "Échec : un nom exclu (liste lue dans $source_name) apparaît ci-dessus. Corrige le fichier, ou réécris le commit avant le merge (git rebase), sans jamais citer le nom dans la PR." >&2
  exit 1
fi
echo "Aucun nom exclu dans les fichiers suivis ni dans les commits de $range."
exit 0
