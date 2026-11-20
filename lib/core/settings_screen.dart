import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/welcome_screen.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';

/// Einstellungen (früher SettingsActivity): zeigt die E-Mail des
/// eingeloggten Benutzers und erlaubt Logout sowie Passwort-Reset per E-Mail.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _goToWelcome(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) _goToWelcome(context);
  }

  Future<void> _resetPassword(BuildContext context, String? email) async {
    final messenger = ScaffoldMessenger.of(context);
    if (email == null || email.isEmpty) {
      messenger.showMessage('Keine E-Mail verfügbar.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showMessage('Password-Reset-E-Mail gesendet.');
    } on FirebaseAuthException catch (e) {
      messenger.showMessage(
        e.message ?? 'Password-Reset-E-Mail fehlgeschlagen.',
        long: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Falls kein Benutzer eingeloggt ist → zurück zur Startseite
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _goToWelcome(context);
      });
      return const Scaffold(body: ContentWidth(child: SizedBox.shrink()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.account_circle_outlined, size: 72),
            const SizedBox(height: 12),
            Text(
              user.email ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _resetPassword(context, user.email),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}
