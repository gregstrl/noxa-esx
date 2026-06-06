#!/usr/bin/env bash
# =====================================================================
#  NOXA — update.sh  (Linux / macOS)
#  Met à jour le serveur depuis GitHub (gregstrl/noxa-esx) :
#    1) git fetch + reset --hard origin/main  (récupère la dernière version)
#    2) calcule le diff des ressources (ajoutées / modifiées / supprimées)
#    3) synchronise install.sql + sql/migrations/ dans noxa_updater
#       (seul emplacement lisible par le serveur FiveM, sandbox oblige)
#  Ensuite, dans la console serveur :  install noxa
#
#  Le Lua serveur FiveM est sandboxé (os.execute bloqué) : c'est CE script
#  qui fait le git. La partie base + reload se fait via `install noxa`.
# =====================================================================
set -euo pipefail

BRANCH="${NOXA_BRANCH:-main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

UPDATER="resources/noxa_updater"
SQL_DST="$UPDATER/sql"
MIG_DST="$SQL_DST/migrations"
STATE="$UPDATER/sync/state.txt"

say()  { printf '\033[36m[noxa update]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[noxa update]\033[0m %s\n' "$1"; }
err()  { printf '\033[31m[noxa update]\033[0m %s\n' "$1"; }

# Nom de ressource à partir d'un chemin resources/...  (gère les [catégories]).
resource_of() {
  local p="${1#resources/}"
  local first="${p%%/*}"
  if [[ "$first" == \[*\] ]]; then
    local rest="${p#*/}"; echo "${rest%%/*}"
  else
    echo "$first"
  fi
}

# Ne recharge que le périmètre Noxa + ESX (sécurité : on ne touche pas à
# oxmysql / menuv / noxa_updater lui-même via le state).
keep_resource() {
  case "$1" in
    noxa_updater) return 1 ;;
    noxa_*|es_extended) return 0 ;;
    *) return 1 ;;
  esac
}

# Le dossier d'une ressource existe-t-il encore ? (gère resources/X et
# resources/[categorie]/X). Renvoie 0 si présent.
resource_dir_exists() {
  local name="$1"
  [[ -d "resources/$name" ]] && return 0
  local d
  for d in resources/*/"$name"; do
    [[ -d "$d" ]] && return 0
  done
  return 1
}

# La ressource existait-elle dans le commit AVANT ? (recherche son fxmanifest)
resource_existed_before() {
  local before="$1" name="$2"
  git cat-file -e "$before:resources/$name/fxmanifest.lua" 2>/dev/null && return 0
  local p
  for p in $(git ls-tree -r --name-only "$before" -- resources/ 2>/dev/null \
      | grep -E "(^|/)$name/fxmanifest.lua$"); do
    return 0
  done
  return 1
}

# ---------------------------------------------------------------------
#  1) GIT
# ---------------------------------------------------------------------
BEFORE=""; AFTER=""
if [[ -d .git ]] && command -v git >/dev/null 2>&1; then
  BEFORE="$(git rev-parse HEAD 2>/dev/null || echo '')"
  say "git fetch origin $BRANCH ..."
  n=0
  until git fetch origin "$BRANCH"; do
    n=$((n+1)); [[ $n -ge 4 ]] && { err "git fetch a échoué (réseau ?)."; break; }
    warn "fetch échoué, nouvelle tentative dans $((2**n))s..."; sleep $((2**n))
  done
  say "git reset --hard origin/$BRANCH ..."
  git reset --hard "origin/$BRANCH"
  AFTER="$(git rev-parse HEAD 2>/dev/null || echo '')"
  if [[ "$BEFORE" == "$AFTER" ]]; then
    say "Déjà à jour (aucun nouveau commit)."
  else
    say "Mis à jour : ${BEFORE:0:7} -> ${AFTER:0:7}"
  fi
else
  warn "Pas de dépôt git (ou git absent) : synchro SQL seule, sans pull."
fi

# ---------------------------------------------------------------------
#  2) DIFF DES RESSOURCES -> state.txt
# ---------------------------------------------------------------------
mkdir -p "$UPDATER/sync"
: > "$STATE"
if [[ -n "$BEFORE" && -n "$AFTER" && "$BEFORE" != "$AFTER" ]]; then
  # liste unique des ressources touchées
  mapfile -t changed < <(git diff --name-only "$BEFORE" "$AFTER" -- resources/ \
    | while read -r f; do resource_of "$f"; done | sort -u)
  for name in "${changed[@]}"; do
    [[ -z "$name" ]] && continue
    keep_resource "$name" || continue
    if ! resource_dir_exists "$name"; then
      echo "D $name" >> "$STATE"          # dossier disparu -> ressource retirée
    elif resource_existed_before "$BEFORE" "$name"; then
      echo "M $name" >> "$STATE"          # existait avant + existe encore -> modifiée
    else
      echo "A $name" >> "$STATE"          # nouvelle ressource
    fi
  done
  if [[ -s "$STATE" ]]; then
    say "Ressources changées :"; sed 's/^/    /' "$STATE"
  else
    say "Aucune ressource Noxa/ESX impactée."
  fi
else
  say "Pas de diff ressources (le serveur rechargera tout le périmètre noxa_*)."
fi

# ---------------------------------------------------------------------
#  3) SYNCHRO SQL (racine -> noxa_updater/sql)
# ---------------------------------------------------------------------
say "Synchronisation du SQL dans $SQL_DST ..."
mkdir -p "$MIG_DST"
if [[ -f install.sql ]]; then
  cp -f install.sql "$SQL_DST/install.sql"
else
  err "install.sql introuvable à la racine !"
fi

rm -f "$MIG_DST"/*.sql 2>/dev/null || true
: > "$SQL_DST/migrations.index"
if [[ -d sql/migrations ]]; then
  for f in $(ls -1 sql/migrations/*.sql 2>/dev/null | sort); do
    base="$(basename "$f")"
    cp -f "$f" "$MIG_DST/$base"
    echo "$base" >> "$SQL_DST/migrations.index"
  done
fi
count="$(grep -c . "$SQL_DST/migrations.index" 2>/dev/null || echo 0)"
say "SQL synchronisé (install.sql + $count migration(s))."

echo
say "✅ Fichiers à jour. Dans la console serveur, tape maintenant :"
printf '\033[32m    install noxa\033[0m\n'
say "   (synchronise la base puis recharge les ressources modifiées)."
