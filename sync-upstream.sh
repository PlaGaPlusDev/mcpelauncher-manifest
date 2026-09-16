#!/bin/bash
# sync-upstream.sh — Sincroniza con minecraft-linux/mcpelauncher-manifest (rama ng)
# manteniendo los pins/parches de tus forks.
#
# Uso: ./sync-upstream.sh [--push]
#   sin args : fetch + merge + re-pin de tus forks, deja todo staged sin commitear
#   --push   : además hace commit del merge y push a origin/ng
set -euo pipefail

UPSTREAM="https://github.com/minecraft-linux/mcpelauncher-manifest.git"
BRANCH="ng"

# Forks del usuario cuyos pins NO se dejan pisar por upstream
FORKS=("libc-shim" "mcpelauncher-client" "mcpelauncher-webview" "mcpelauncher-errorwindow")

# --- Auto-config: ignora ruido de permisos y auto-resuelve conflictos repetidos ---
git config core.fileMode false
git config rerere.enabled true
git config advice.submoduleMergeConflict false

echo "=== 1. Fetch upstream ==="
git fetch "$UPSTREAM" "$BRANCH"

if git merge-base --is-ancestor FETCH_HEAD HEAD; then
    echo "Ya estás al día con upstream/$BRANCH. Nada que hacer."
    exit 0
fi

echo "=== 2. Guardar pins de tus forks (desde el checkout actual) ==="
declare -A PIN
for mod in "${FORKS[@]}"; do
    hash=$(git -C "$mod" rev-parse HEAD 2>/dev/null || git ls-tree HEAD "$mod" | awk '{print $3}')
    PIN["$mod"]=$hash
    echo "   $mod  $hash"
done

echo "=== 3. Merge con upstream ==="
git merge --no-commit FETCH_HEAD || echo "   ⚠ hubo conflictos, los resuelve el re-pin"

echo "=== 4. Re-pin de forks (mantener tus parches) ==="
for mod in "${FORKS[@]}"; do
    hash="${PIN[$mod]}"
    git -C "$mod" fetch origin 2>/dev/null || true
    if git -C "$mod" checkout "$hash" 2>/dev/null; then
        git add "$mod"
        echo "   ✓ $mod -> $hash"
    else
        echo "   ⚠ $mod: no se encontró $hash"
    fi
done

echo "=== 5. Revisar conflictos restantes ==="
unmerged=$(git diff --name-only --diff-filter=U)
if [[ -n "$unmerged" ]]; then
    echo "   ⚠ Quedan conflictos sin resolver:"
    echo "$unmerged" | sed 's/^/      /'
    exit 1
fi

git diff --cached --stat

if [[ "${1:-}" == "--push" ]]; then
    echo "=== 6. Commit + push ==="
    git commit -m "sync: merge upstream ng"
    git push origin "$BRANCH"
else
    echo ""
    echo "Todo staged. Para commitear y pushear: ./sync-upstream.sh --push"
fi