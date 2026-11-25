import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../core/main_shell.dart';
import '../utils/messages.dart';
import 'password_field.dart';
import '../utils/responsive.dart';

/// Login mit E-Mail und Passwort (früher LoginActivity).
/// Nur Benutzer mit bestätigter E-Mail-Adresse dürfen sich anmelden.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty) {
      showMessage(context, 'Enter email');
      return;
    }
    if (password.isEmpty) {
      showMessage(context, 'Enter password');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final auth = FirebaseAuth.instance;

    setState(() => _busy = true);
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      final user = auth.currentUser;

      if (user != null && user.emailVerified) {
        // E-Mail bestätigt → Login erlauben
        messenger.showMessage('Login erfolgreich');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OrgGate()),
          (_) => false,
        );
        return;
      }

      // E-Mail noch nicht bestätigt → Bestätigungsseite (dort kann man
      // auch eine neue Bestätigungsmail anfordern)
      messenger.showMessage(
        'Bitte bestätige zuerst deine E-Mail-Adresse.',
        long: true,
      );
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OrgGate()),
        (_) => false,
      );
      return;
    } on FirebaseAuthException {
      messenger.showMessage('Login fehlgeschlagen.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ContentWidth.narrow(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _password,
              onSubmitted: (_) {
                if (!_busy) _login();
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
