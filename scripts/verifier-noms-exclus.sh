#!/usr/bin/env bash
# Refuse les noms exclus (clients et employeurs réels, CLAUDE.md de l'espace de
# travail) dans les fichiers suivis et dans les commits d'une plage.
#
# Usage : scripts/verifier-noms-exclus.sh [plage]   (défaut : origin/main..HEAD)
#
# Liste : variable EXCLUDED_NAMES (noms séparés par des virgules ; secret de CI),
# à défaut fichier local non versionné .excluded-names à la racine du dépôt (un nom
# par ligne ou séparés par des virgules). Comparaison insensible à la casse, par
# sous-chaîne.
#
# Ce qui est cherché : contenu et chemin des fichiers suivis ; message, nom et
# e-mail d'auteur et de committer de chaque commit de la plage.
#
# La sortie ne cite jamais un nom : seulement le fichier (ou son objet Git si le
# chemin contient lui-même un nom) et le SHA du commit. Les journaux de CI sont
# publics.
#
# Liste vide ou absente : échec en CI (secret manquant), simple avertissement en
# local.
#
# Codes : 0 rien trouvé, 1 nom trouvé ou liste absente en CI, 2 usage invalide.
set -u

if [ $# -gt 1 ]; then
  echo "Usage : $0 [plage]   (défaut : origin/main..HEAD)" >&2
  exit 2
fi
range=${1:-origin/main..HEAD}

if ! top=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "Erreur : à lancer dans un dépôt Git" >&2
  exit 2
fi
cd "$top" || exit 2

if ! patterns=$(mktemp); then
  echo "Erreur : mktemp a échoué" >&2
  exit 2
fi
trap 'rm -f "$patterns"' EXIT

# Un nom par ligne, sans espaces autour ni entrée vide : une ligne vide dans le
# fichier de motifs ferait correspondre tout le dépôt.
normalize() {
  tr -d '\r' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'
}

printf '%s' "${EXCLUDED_NAMES:-}" | normalize >"$patterns"
source_name="la variable EXCLUDED_NAMES"
if [ ! -s "$patterns" ] && [ -f .excluded-names ]; then
  normalize <.excluded-names >"$patterns"
  source_name="le fichier .excluded-names"
fi

if [ ! -s "$patterns" ]; then
  case ${CI:-} in
    "" | false | 0)
      echo "Avertissement : aucune liste de noms exclus (variable EXCLUDED_NAMES ou fichier .excluded-names) : vérification sautée." >&2
      exit 0
      ;;
    *)
      echo "Échec : la liste des noms exclus est vide. Le secret EXCLUDED_NAMES est absent ou vide : à créer avec « gh secret set EXCLUDED_NAMES »." >&2
      exit 1
      ;;
  esac
fi

if ! commits=$(git rev-list "$range" 2>/dev/null); then
  echo "Erreur : plage de commits invalide : $range" >&2
  exit 2
fi

found=0

# matches : l'entrée standard contient-elle un nom de la liste ?
matches() {
  grep -qiF -f "$patterns"
}

# Objet Git d'un fichier suivi, pour le désigner sans citer son chemin
blob_of() {
  git ls-files -s -- "$1" | awk '{ print $2; exit }'
}

# Fichier à citer : son chemin, ou son objet si le chemin contient un nom
describe_file() {
  if printf '%s\n' "$1" | matches; then
    echo "objet $(blob_of "$1") (chemin masqué : il contient lui-même un nom exclu)"
  else
    echo "$1"
  fi
}

# Contenu des fichiers suivis (binaires compris)
while IFS= read -r path; do
  [ -n "$path" ] || continue
  echo "Nom exclu dans le contenu de : $(describe_file "$path")"
  found=1
done < <(git grep -l -i -F -f "$patterns" 2>/dev/null)

# Chemins des fichiers suivis
while IFS= read -r path; do
  [ -n "$path" ] || continue
  echo "Nom exclu dans le chemin du fichier : $(describe_file "$path")"
  found=1
done < <(git ls-files | grep -iF -f "$patterns")

# Commits de la plage
for sha in $commits; do
  if git log -1 --format=%B "$sha" | matches; then
    echo "Nom exclu dans le message du commit : $sha"
    found=1
  fi
  if git log -1 --format='%an%n%ae%n%cn%n%ce' "$sha" | matches; then
    echo "Nom exclu dans l'auteur ou le committer du commit : $sha"
    found=1
  fi
done

if [ "$found" -ne 0 ]; then
  echo "Échec : un nom exclu (liste lue dans $source_name) apparaît ci-dessus. Corrige le fichier, ou réécris le message du commit avant le merge (git rebase), sans jamais citer le nom dans la PR." >&2
  exit 1
fi
echo "Aucun nom exclu dans les fichiers suivis ni dans les commits de $range."
exit 0
