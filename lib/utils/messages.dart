import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:material_ui/material_ui.dart';

/// Ersatz für Android-Toasts: zeigt eine kurze Meldung als SnackBar.
extension MessageExtension on ScaffoldMessengerState {
  void showMessage(String text, {bool long = false}) {
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: long ? 4 : 2),
      ),
    );
  }
}

/// Kurzform für [MessageExtension.showMessage] mit einem BuildContext.
void showMessage(BuildContext context, String text, {bool long = false}) {
  ScaffoldMessenger.of(context).showMessage(text, long: long);
}

/// Lesbare Fehlermeldung für Firebase- und App-Fehler.
String errorText(Object error) {
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Keine Berechtigung für diese Aktion.';
    }
    return error.message ?? error.code;
  }
  return error.toString();
}

/// Sicherheitsabfrage vor einer Aktion; liefert `true` bei Bestätigung.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Löschen',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
