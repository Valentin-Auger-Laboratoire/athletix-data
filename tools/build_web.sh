#!/usr/bin/env bash
# Compile la version web et la copie dans docs/ (GitHub Pages).
# Ajoute un numéro de version aux fichiers pour que le navigateur ne garde pas l'ancienne version en cache.
# Usage : bash tools/build_web.sh   (depuis la racine du dépôt)
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"

MSYS_NO_PATHCONV=1 "$FLUTTER" build web --release --base-href /athletix-data/

VERSION="$(date +%Y%m%d%H%M%S)"
# index.html charge flutter_bootstrap.js?v=…, qui charge main.dart.js?v=…
sed -i "s/VERSION_BUILD/$VERSION/" build/web/index.html
sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VERSION\"/" build/web/flutter_bootstrap.js
grep -q "main.dart.js?v=$VERSION" build/web/flutter_bootstrap.js || { echo "Anti-cache non appliqué (format de flutter_bootstrap.js changé ?)"; exit 1; }

rm -rf docs
cp -r build/web docs
touch docs/.nojekyll
echo "docs/ mis à jour (version $VERSION)"
