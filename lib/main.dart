import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contacts_provider_v2.dart';
import 'providers/messaging_provider.dart';
import 'providers/groups_provider.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/splash_screen.dart';
import 'ui/dashboard_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/statistics_screen.dart';
import 'screens/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation on mobile only
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      debugPrint('⚠️ Orientation lock error: $e');
    }
  }

  // Firebase is completely disabled on web to avoid initialization crashes.
  // The app uses its own backend (omnisms-backend.onrender.com) for auth.
  // Firebase can be re-enabled once a valid web appId is configured.
  // To re-enable: uncomment the block below and add a real Firebase web appId.
  //
  // if (!kIsWeb) {
  //   try {
  //     await Firebase.initializeApp(...);
  //   } catch (e) {
  //     debugPrint('⚠️ Firebase init error: $e');
  //   }
  // }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProviderV2()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/contacts': (context) => const ContactsScreen(),
            '/groups': (context) => const GroupsScreen(),
            '/statistics': (context) => const StatisticsScreen(),
            '/subscription': (context) => const SubscriptionScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
