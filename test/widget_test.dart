import 'package:flutter_test/flutter_test.dart';

import 'package:omnisms/main.dart';

void main() {
  testWidgets('OmniSMSApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OmniSMSApp());
    expect(find.byType(OmniSMSApp), findsOneWidget);
  });
}
