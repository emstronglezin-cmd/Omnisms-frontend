#!/bin/bash
# OmniSMS - Static PWA Build Script
# Copie public/ (PWA v5 — version fonctionnelle de référence) vers build/web/
# Aucun Flutter requis — site HTML/CSS/JS natif
set -e

echo "🌐 OmniSMS Static PWA Build (v5)"
echo "================================="

# Créer le répertoire de sortie que Vercel attend
mkdir -p build/web

# Copier les fichiers statiques (PWA complète : index.html, style.css, app.js, sw.js, manifest, icônes)
echo "📁 Copie des fichiers statiques depuis public/ vers build/web/..."
cp -r public/. build/web/

echo ""
echo "✅ Build terminé — sortie : build/web/"
ls -lh build/web/
