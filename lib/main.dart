import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import 'services/notification_service.dart';
import 'services/presence_service.dart';

// Screens — use canonical paths only
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/contacts/contacts_screen_v2.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/statistics_screen.dart';
import 'screens/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialiser le service de notifications
  await NotificationService.instance.initialize();

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
      child: const OmniSMSApp(),
    ),
  );
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
          home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/dashboard': (_) => const DashboardScreen(),
              '/contacts': (_) => const ContactsScreenV2(),
              '/groups': (_) => const GroupsScreen(),
              '/statistics': (_) => const StatisticsScreen(),
              '/subscription': (_) => const SubscriptionScreen(),
              '/settings': (_) => const SettingsScreen(),
            },
          );
      },
    );
  }
}
