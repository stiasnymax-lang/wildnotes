import 'package:material_ui/material_ui.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/responsive.dart';

/// Startseite für nicht eingeloggte Benutzer (früher MainActivity).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bigButton = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(64),
      textStyle: const TextStyle(fontSize: 26),
    );

    return Scaffold(
      body: ContentWidth.narrow(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Willkommen in der WildNotes App',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                Text('Bereits ein Account?', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                FilledButton(
                  style: bigButton,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 48),
                Text(
                  'Noch kein Account? Dann jetzt Registrieren!',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: bigButton,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
