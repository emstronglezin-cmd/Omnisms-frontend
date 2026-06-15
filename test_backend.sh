#!/bin/bash

echo "🔍 ==== OMNISMS BACKEND CONNECTIVITY TEST ===="
echo ""

BASE_URL="https://omnisms-backend.onrender.com"

echo "1️⃣ Testing Health Endpoint..."
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
echo "   Health Check: $HEALTH $([ $HEALTH -eq 200 ] && echo '✅' || echo '❌')"
echo ""

echo "2️⃣ Testing Contacts Endpoint..."
CONTACTS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/contacts")
echo "   Contacts API: $CONTACTS $([ $CONTACTS -eq 401 ] && echo '⚠️ (auth required - normal)' || echo '')"
echo ""

echo "3️⃣ Testing Messages Endpoint..."
MESSAGES=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/messages")
echo "   Messages GET: $MESSAGES $([ $MESSAGES -eq 200 ] || [ $MESSAGES -eq 401 ] && echo '✅' || echo '❌')"
echo ""

echo "4️⃣ Testing Send Message Endpoint..."
SEND=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/messages/send" -H "Content-Type: application/json" -d '{}')
echo "   Send Message POST: $SEND $([ $SEND -eq 400 ] || [ $SEND -eq 401 ] && echo '⚠️ (validation error - normal)' || echo '')"
echo ""

echo "5️⃣ Testing Transcription Endpoint..."
TRANSCRIBE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/transcription" -H "Content-Type: application/json" -d '{}')
echo "   Transcription POST: $TRANSCRIBE $([ $TRANSCRIBE -eq 400 ] || [ $TRANSCRIBE -eq 401 ] && echo '⚠️ (validation error - normal)' || echo '')"
echo ""

echo "6️⃣ WebSocket Endpoint..."
echo "   WebSocket URL: wss://omnisms-backend.onrender.com/ws"
echo "   ℹ️  WebSocket cannot be tested via curl (requires runtime connection)"
echo ""

echo "✅ ==== BACKEND CONNECTIVITY TEST COMPLETE ===="
