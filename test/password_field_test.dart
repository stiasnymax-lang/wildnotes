import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_application_tiergarto/auth/password_field.dart';

void main() {
  testWidgets('Augen-Symbol zeigt und verbirgt das Passwort', (tester) async {
    final controller = TextEditingController(text: 'geheim123');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );

    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText)).obscureText;

    // Standard: verborgen
    expect(obscured(), isTrue);
    expect(find.byTooltip('Passwort anzeigen'), findsOneWidget);

    // Antippen: sichtbar
    await tester.tap(find.byTooltip('Passwort anzeigen'));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('Passwort verbergen'), findsOneWidget);

    // Nochmal antippen: wieder verborgen
    await tester.tap(find.byTooltip('Passwort verbergen'));
    await tester.pump();
    expect(obscured(), isTrue);
  });
}
