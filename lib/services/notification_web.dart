/// OmniSMS — Implémentation Web des notifications via Browser Notification API
///
/// Ce fichier est chargé UNIQUEMENT sur la plateforme web (conditional import).
/// Il n'est PAS importé sur Android/iOS → aucun conflit de compilation.
///
/// Utilise dart:js_util pour appeler JavaScript depuis Dart sans dépendance externe.
///
/// Fonctionnement :
///   1. Vérifie 'Notification' dans window (Support API)
///   2. Vérifie Notification.permission ('granted'/'denied'/'default')
///   3. Notification.requestPermission() → Promise<string>
///   4. new Notification(title, {body, icon, data}) → affichage navigateur
///
/// Limitation connue :
///   Les notifications en arrière-plan (PWA fermée) nécessitent Push API +
///   service worker push handler. Sans serveur push, seules les notifications
///   lorsque la page/PWA est OUVERTE sont supportées.
///   → Le handler push dans sw.js est ajouté pour le futur (infra optionnelle).

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;

/// Affiche une notification via l'API Notification du navigateur.
void jsShowNotification(String title, String body, String conversationId) {
  try {
    final permission = html.Notification.permission;
    if (permission != 'granted') return;

    final notif = html.Notification(
      title,
      body   : body,
      icon   : '/icons/Icon-192.png',
      // La donnée conversationId est transmise pour la navigation au clic
      // (gérable via notificationclick dans le service worker)
      tag    : conversationId,
      // 'data' n'est pas supporté dans dart:html Notification directement
      // mais on encode dans le tag pour identifier la conversation
    );

    notif.onClick.listen((_) {
      html.window.focus();
      // Le service worker et l'app gèrent le focus sur la bonne conversation
      // via le tag / l'URL encodée dans les messages postMessage
      html.window.postMessage({
        'type'          : 'NOTIFICATION_CLICK',
        'conversationId': conversationId,
      }, '*');
      notif.close();
    });

    // Auto-fermeture après 6 secondes
    Future.delayed(const Duration(seconds: 6), () {
      try { notif.close(); } catch (_) {}
    });

    debugPrint('[NOTIFICATION] Web Notification affiché: $title');
  } catch (e) {
    debugPrint('[NOTIFICATION] Web Notification error: $e');
  }
}

/// Retourne l'état de la permission Notification ('granted'/'denied'/'default').
String jsGetNotificationPermission() {
  try {
    // Vérifier si l'API Notification est disponible
    if (!html.Notification.supported) return 'denied';
    return html.Notification.permission;
  } catch (_) {
    return 'default';
  }
}

/// Demande la permission Notification au navigateur.
/// Retourne 'granted', 'denied', ou 'default'.
Future<String?> jsRequestNotificationPermission() async {
  try {
    if (!html.Notification.supported) return 'denied';
    final result = await html.Notification.requestPermission();
    debugPrint('[NOTIFICATION] Permission demandée, résultat: $result');
    return result;
  } catch (e) {
    debugPrint('[NOTIFICATION] requestPermission error: $e');
    return 'denied';
  }
}
