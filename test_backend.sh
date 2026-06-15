#!/bin/bash

echo "🔍 ==== TESTS BACKEND OMNISMS ===="
echo ""

BASE_URL="https://omnisms-backend.onrender.com"

echo "🌐 Test 1: Base URL Health Check"
echo "URL: $BASE_URL/health"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/health" || echo "❌ Échec"
echo ""

echo "📇 Test 2: Contacts Endpoint"
echo "URL: $BASE_URL/api/contacts"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/api/contacts" || echo "❌ Échec"
echo ""

echo "💬 Test 3: Messages Endpoint"
echo "URL: $BASE_URL/api/messages"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/api/messages" || echo "❌ Échec"
echo ""

echo "🎤 Test 4: Transcription Endpoint"
echo "URL: $BASE_URL/api/transcription"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL/api/transcription" || echo "❌ Échec"
echo ""

echo "🔌 Test 5: WebSocket URL (info only)"
echo "URL: wss://omnisms-backend.onrender.com/ws"
echo "ℹ️  WebSocket ne peut pas être testé avec curl"
echo ""

echo "✅ ==== TESTS TERMINÉS ===="
echo ""
echo "📊 Codes de statut:"
echo "  200 = OK ✅"
echo "  401 = Auth requise (normal) ⚠️"
echo "  404 = Route non trouvée ❌"
echo "  500+ = Erreur serveur ❌"
