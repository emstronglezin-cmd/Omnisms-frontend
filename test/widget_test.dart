import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnisms/main.dart';
import 'package:omnisms/providers/auth_provider.dart';
import 'package:omnisms/providers/contacts_provider.dart';
import 'package:omnisms/providers/contacts_provider_v2.dart';
import 'package:omnisms/providers/groups_provider.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OmniSMSApp smoke test', (WidgetTester tester) async {
    // Les providers lisent SharedPreferences au démarrage (jeton, userId,
    // réglages) : sans valeurs simulées le premier frame lève une exception.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ContactsProviderV2()),
          ChangeNotifierProvider(create: (_) => ContactsProvider()),
          ChangeNotifierProvider(create: (_) => MessagingProvider()),
          ChangeNotifierProvider(create: (_) => GroupsProvider()),
        ],
        child: const OmniSMSApp(),
      ),
    );

    // Le splash et les providers démarrent des minuteries (Future.delayed,
    // polling) : on avance l'horloge simulée pour qu'elles se consomment.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(OmniSMSApp), findsOneWidget);
  });
}
