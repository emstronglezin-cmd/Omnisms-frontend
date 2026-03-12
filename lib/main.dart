import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

// Legacy imports
import 'conversation_provider.dart';
import 'conversation_screen.dart';
import 'contacts_provider.dart';
import 'screens/connection_test_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/transcription_screen.dart';
import 'ui/home_screen.dart';
import 'ui/dashboard_screen.dart';

// Phase 2 - Providers
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

// Phase 2 - Auth Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/profile_screen.dart';

// Phase 2 - Settings Screens
import 'screens/settings/settings_screen.dart';
import 'screens/settings/notifications_settings_screen.dart';
import 'screens/settings/theme_settings_screen.dart';
import 'screens/settings/statistics_screen.dart';

// Phase 2 - Contacts Screen
import 'screens/contacts/contacts_screen.dart' as phase2_contacts;

// Phase 2 - Messaging Screens
import 'screens/messaging/conversation_screen.dart' as phase2_messaging;

// Phase 2 - Groups Screens
import 'screens/groups/groups_screen.dart' as phase2_groups;
import 'screens/groups/create_group_screen.dart';
import 'screens/groups/group_conversation_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Verrouiller l'orientation en portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Initialiser Firebase avec gestion d'erreurs
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
      debugPrint('✅ Firebase initialisé avec succès');
    } catch (e) {
      debugPrint('⚠️ Erreur Firebase (non bloquant): $e');
    }
    
    // Gestionnaire d'erreurs global
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('❌ Erreur Flutter: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    };
    
    runApp(
      MultiProvider(
        providers: [
          // Legacy providers
          ChangeNotifierProvider(create: (_) => ConversationProvider()),
          ChangeNotifierProvider(create: (_) => ContactsProvider()),
          // Phase 2 providers
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('❌ Erreur Zone: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'OmniSMS',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const DashboardScreen(),
          routes: {
            // Legacy routes
            '/subscription': (context) => const SubscriptionScreen(),
            '/transcription': (context) => const TranscriptionScreen(),
            '/connection-test': (context) => const ConnectionTestScreen(),
            
            // Phase 2 - Auth routes
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/profile': (context) => const ProfileScreen(),
            
            // Phase 2 - Settings routes
            '/settings': (context) => const SettingsScreen(),
            '/settings/notifications': (context) =>
                const NotificationsSettingsScreen(),
            '/settings/theme': (context) => const ThemeSettingsScreen(),
            '/settings/statistics': (context) => const StatisticsScreen(),
            
            // Phase 2 - Contacts route
            '/contacts': (context) => const phase2_contacts.ContactsScreen(),
            
            // Phase 2 - Messaging routes
            '/conversation': (context) => const phase2_messaging.ConversationScreen(),
            
            // Phase 2 - Groups routes
            '/groups/new': (context) => const phase2_groups.GroupsScreen(),
            '/groups/create': (context) => const CreateGroupScreen(),
            '/groups/conversation': (context) => const GroupConversationScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/groups/conversation') {
              final groupName = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) {
                  return GroupConversationScreen(groupName: groupName);
                },
              );
            }
            if (settings.name == '/conversation') {
              final contactName = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) {
                  return phase2_messaging.ConversationScreen(contactName: contactName);
                },
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OmniSMS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [Text('Bienvenue sur OmniSMS')],
        ),
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  final void Function(String contactName)? onContactTap;
  const ContactsScreen({super.key, this.onContactTap});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les contacts après le rendu, avec protection contre les erreurs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Provider.of<ContactsProvider>(context, listen: false).fetchContacts();
        } catch (e) {
          // Ignorer les erreurs asynchrones - elles sont gérées par le provider
          debugPrint('Erreur lors du chargement des contacts: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactsProvider = context.watch<ContactsProvider>();
    final contacts = contactsProvider.contacts;
    final isLoading = contactsProvider.isLoading;
    final error = contactsProvider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.network_check),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionTestScreen()),
              );
            },
            tooltip: 'Tester la connexion backend',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<ContactsProvider>(
                context,
                listen: false,
              ).fetchContacts();
            },
            tooltip: 'Actualiser les contacts',
          ),
        ],
      ),
      body: Column(
        children: [
          // Affichage des erreurs
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.1),
              child: Text(
                error,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        title: Text(contact),
                        onTap: () {
                          if (widget.onContactTap != null) {
                            widget.onContactTap!(contact);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
