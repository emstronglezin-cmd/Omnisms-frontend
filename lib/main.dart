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

// Screens — use canonical paths only
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/contacts/contacts_screen.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProviderV2()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
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
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/dashboard': (_) => const DashboardScreen(),
            '/contacts': (_) => const ContactsScreen(),
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
