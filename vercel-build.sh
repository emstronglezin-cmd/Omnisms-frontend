#!/bin/bash
# OmniSMS - Static PWA Build Script
# Aucun Flutter requis — copie simplement les fichiers public/ vers build/web/
set -e

echo "🌐 OmniSMS Static PWA Build"
echo "=========================="
echo "Pas de Flutter — site HTML/CSS/JS natif"
echo ""

# Créer le répertoire de sortie que Vercel attend
mkdir -p build/web

# Copier les fichiers statiques
echo "📁 Copie des fichiers statiques depuis public/ vers build/web/..."
cp -r public/* build/web/

echo ""
echo "✅ Build terminé!"
echo "📦 Contenu de build/web/:"
ls -lh build/web/

echo ""
echo "🚀 Prêt pour déploiement sur Vercel"
