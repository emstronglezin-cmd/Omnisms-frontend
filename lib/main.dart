import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'conversation_provider.dart';
import 'conversation_screen.dart';
import 'contacts_provider.dart';
import 'screens/connection_test_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/transcription_screen.dart';
import 'ui/home_screen.dart';
import 'ui/dashboard_screen.dart';

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
          ChangeNotifierProvider(create: (_) => ConversationProvider()),
          ChangeNotifierProvider(create: (_) => ContactsProvider()),
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
    return MaterialApp(
      title: 'OmniSMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
      routes: {
        '/groups': (context) => const GroupsScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
        '/transcription': (context) => const TranscriptionScreen(),
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
