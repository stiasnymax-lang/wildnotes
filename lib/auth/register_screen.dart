import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/messages.dart';
import 'login_screen.dart';
import '../utils/responsive.dart';

/// Registrierung eines neuen Kontos (früher RegisterActivity).
/// Nach dem Anlegen wird eine Bestätigungsmail verschickt, der Benutzer
/// wieder abgemeldet und zum Login weitergeleitet.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-Mail eingeben';
    if (!_emailPattern.hasMatch(email)) return 'Ungültige E-Mail-Adresse';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) return 'Passwort eingeben';
    if (password.length < 6) return 'Passwort muss mindestens 6 Zeichen haben';
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final auth = FirebaseAuth.instance;

    setState(() => _busy = true);
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      final user = credential.user;

      if (user == null) {
        messenger.showMessage(
          'Benutzer konnte nach Registrierung nicht geladen werden.',
          long: true,
        );
        if (mounted) setState(() => _busy = false);
        return;
      }

      try {
        await user.sendEmailVerification();
        messenger.showMessage(
          'Konto erstellt! Bitte E-Mail bestätigen.',
          long: true,
        );
      } on FirebaseAuthException catch (e) {
        var fehler = 'Konto erstellt, aber Bestätigungsmail fehlgeschlagen.';
        if (e.message != null) fehler = '$fehler\n${e.message}';
        messenger.showMessage(fehler, long: true);
      }

      await auth.signOut();
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      messenger.showMessage(
        e.message ?? 'Registrierung fehlgeschlagen',
        long: true,
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: ContentWidth.narrow(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Password'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _register,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
