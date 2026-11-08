import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'widgets/common/app_error_widget.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contacts_provider_v2.dart';
import 'providers/contacts_provider.dart'; // needed for ContactsProvider in some screens
import 'providers/messaging_provider.dart';
import 'providers/groups_provider.dart';

// Notifications
// Sélecteur photo système Android : actif sur mobile, neutre sur le web.
import 'services/photo_picker_natif_stub.dart'
  if (dart.library.io) 'services/photo_picker_natif.dart';

import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/presence_service.dart';
import 'widgets/common/presence_cycle_de_vie.dart';

// Screens — use canonical paths only
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/contacts/contacts_screen_v2.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/statistics_screen.dart';
import 'screens/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Gestion globale des erreurs ──────────────────────────────────────────
  // Avant cette correction, AUCUN gestionnaire n'était installé : toute
  // exception de build ou d'exécution affichait l'écran rouge de Flutter,
  // avec l'exception brute et parfois une pile d'appels (cf. vidéo de test).
  // On journalise tout (rien n'est supprimé ni masqué) et on affiche une vue
  // propre à la place.
  _installErrorHandlers();

  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      debugPrint('Orientation error: $e');
    }
  }

  // Sélecteur photo système (Android 13+ / Photo Picker) : donne accès à la
  // galerie sans permission sur les appareils récents, ce qui fiabilise la
  // sélection de la photo de profil. Appel sans effet sur iOS et sur le web.
  try {
    await activerSelecteurPhotoSysteme();
  } catch (e) {
    debugPrint('Photo picker error: $e');
  }

  // Initialiser le service de notifications
  await NotificationService.instance.initialize();

  // Notifications à distance (FCM / APNs). L'appel est volontairement non
  // bloquant et sans `await` : si Firebase n'est pas configuré — c'est le cas
  // tant que google-services.json et GoogleService-Info.plist n'ont pas été
  // fournis — l'application doit démarrer normalement, sans push. L'état
  // exact est exposé par PushService.instance et affiché dans les réglages.
  if (!kIsWeb) {
    unawaited(PushService.instance.initialiser());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProviderV2()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()), // for old screens
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
        // Présence des destinataires (source : le backend, via Socket.IO).
        ChangeNotifierProvider(create: (_) => PresenceService()),
      ],
      child: const PresenceCycleDeVie(child: OmniSMSApp()),
    ),
  );
}

/// Installe les gestionnaires d'erreurs globaux.
///
/// Aucun journal utile n'est supprimé : les exceptions restent intégralement
/// tracées dans la console (`debugPrint`) et, en debug, via
/// `FlutterError.presentError`. Seul l'affichage change : plus jamais de
/// texte technique dans l'interface.
void _installErrorHandlers() {
  // 1) Erreurs du framework (build, layout, paint, gestes).
  FlutterError.onError = (details) {
    // Dump complet conservé pour le développement.
    FlutterError.presentError(details);
    debugPrint('[OmniSMS][UI] ${details.exception}');
  };

  // 2) Erreurs asynchrones non capturées (Future, isolate).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[OmniSMS][async] $error');
    debugPrint('[OmniSMS][async][stack] $stack');
    // true = erreur traitée : on ne propage pas le crash à l'écran rouge.
    return true;
  };

  // 3) Remplacement de l'écran rouge par une vue claire et sans trace.
  ErrorWidget.builder = buildErrorWidget;
}

class OmniSMSApp extends StatelessWidget {
  const OmniSMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'OmniSMS',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          // CORRECTION : la bannière de notification est un `Stack`, qui a
          // besoin d'un ancêtre `Directionality` — fourni par MaterialApp.
          // Placée AU-DESSUS de MaterialApp, elle faisait échouer la toute
          // première frame ("No Directionality widget found") : l'app
          // n'affichait qu'un écran d'erreur au démarrage, sur mobile.
          builder: (context, child) {
            return InAppNotificationWrapper(
              // Callback : ouvrir la conversation depuis la notification
              // Actuellement enregistré pour une future navigation directe
              onTap: (conversationId) {
                // Navigation vers la conversation depuis la notification :
                // Le navigatorKey global permettrait une navigation directe.
                // Cette fonctionnalité est enregistrée — l'overlay ferme la
                // bannière et l'app amène l'utilisateur à la bonne
                // conversation quand l'infrastructure de navigation globale
                // est configurée.
                debugPrint(
                    '[NOTIFICATION] Tap → conversation: $conversationId');
              },
              child: child ?? const SizedBox.shrink(),
            );
          },
          // Route web publique `/privacy` : quand l'application est ouverte
          // directement sur cette URL (partage de lien, moteur de recherche),
          // la page s'affiche sans passer par le splash. En Android, la page
          // reste accessible par la route nommée '/privacy'.
          home: (kIsWeb &&
                  Uri.base.path.replaceAll(RegExp(r'/+$'), '') == '/privacy')
              ? const PrivacyPolicyScreen()
              : const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/dashboard': (_) => const DashboardScreen(),
              '/contacts': (_) => const ContactsScreenV2(),
              '/groups': (_) => const GroupsScreen(),
              '/statistics': (_) => const StatisticsScreen(),
              '/subscription': (_) => const SubscriptionScreen(),
              '/settings': (_) => const SettingsScreen(),
              // Page publique : accessible sans connexion, y compris depuis
              // le navigateur (`/privacy`) et depuis Connexion / Inscription
              // / Paramètres.
              '/privacy': (_) => const PrivacyPolicyScreen(),
            },
          );
      },
    );
  }
}
