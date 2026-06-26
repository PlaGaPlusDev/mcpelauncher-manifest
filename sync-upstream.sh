#!/bin/bash
# sync-upstream.sh — Sincroniza con minecraft-linux/mcpelauncher-manifest
# sin sobrescribir los pins de los submódulos fork.
#
# Uso: ./sync-upstream.sh
set -e

UPSTREAM="https://github.com/minecraft-linux/mcpelauncher-manifest.git"
BRANCH="ng"

# Lista de forks del usuario (NO se actualizan los pins)
FORKS=("libc-shim" "mcpelauncher-client" "mcpelauncher-webview" "mcpelauncher-errorwindow")

echo "=== 1. Fetch upstream ==="
git fetch "$UPSTREAM" "$BRANCH"

echo "=== 2. Guardar pins actuales de forks ==="
for mod in "${FORKS[@]}"; do
    hash=$(git ls-tree HEAD "$mod" | awk '{print $3}')
    echo "   $mod  $hash"
    echo "$hash" > "/tmp/sync-pin-$mod"
done

echo "=== 3. Merge con upstream ==="
git merge FETCH_HEAD --no-edit || echo "⚠ Conflictos resuelve manualmente"

echo "=== 4. Restaurar pins de forks ==="
for mod in "${FORKS[@]}"; do
    hash=$(cat "/tmp/sync-pin-$mod")
    # checkout al hash correcto en el submodulo y lo stagedea
    git -C "$mod" fetch origin 2>/dev/null || true
    if git -C "$mod" checkout "$hash" 2>/dev/null; then
        git add "$mod"
        echo "   $mod restaurado a $hash ✓"
    else
        echo "   ⚠ $mod: hash $hash no encontrado localmente"
    fi
    rm -f "/tmp/sync-pin-$mod"
done

echo "=== 5. Revisa el diff ==="
git diff --cached --stat
echo ""
echo "Si todo está bien: git commit -m 'sync: merge upstream ng' && git push origin ng"
