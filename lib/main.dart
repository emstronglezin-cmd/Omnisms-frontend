import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

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
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Firebase (non-blocking - app works without it)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ',
          appId: '1:948236796279:web:omnisms-webapp-2024',
          messagingSenderId: '948236796279',
          projectId: 'omnisms-b98c5',
          storageBucket: 'omnisms-b98c5.firebasestorage.app',
          authDomain: 'omnisms-b98c5.firebaseapp.com',
        ),
      );
      debugPrint('✅ Firebase initialized');
    }
  } catch (e) {
    // Firebase error is non-blocking
    debugPrint('⚠️ Firebase init (non-blocking): $e');
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
