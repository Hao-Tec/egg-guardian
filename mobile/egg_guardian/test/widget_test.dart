// Basic smoke test for Egg Guardian app.

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_guardian/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EggGuardianApp());
    await tester.pumpAndSettle();

    // Verify that the login screen renders
    expect(find.text('Egg Guardian'), findsOneWidget);
  });
}
