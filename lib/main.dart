import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contacts_provider.dart';
import 'providers/messaging_provider.dart';
import 'providers/groups_provider.dart';

// Services
import 'services/ads_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/statistics_screen.dart';
import 'screens/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation (mobile only, not web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ',
        appId: '1:948236796279:android:747ba8ba81710da2ade172',
        messagingSenderId: '948236796279',
        projectId: 'omnisms-b98c5',
        storageBucket: 'omnisms-b98c5.firebasestorage.app',
      ),
    );
    
    // 🔥 Initialize Crashlytics (production only)
    await _initCrashlytics();
    
  } catch (e) {
    debugPrint('⚠️ Firebase init error (non-blocking): $e');
  }
  
  // 📱 Initialize Start.io Ads (mobile only)
  if (!kIsWeb) {
    try {
      await AdsService().initialize();
      debugPrint('✅ Ads service initialized');
    } catch (e) {
      debugPrint('⚠️ Ads init error (non-blocking): $e');
    }
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// 🔥 Initialize Firebase Crashlytics
Future<void> _initCrashlytics() async {
  // Enable Crashlytics collection (production only)
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(isProduction);
  
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  debugPrint('🔥 Crashlytics initialized (production mode: $isProduction)');
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
