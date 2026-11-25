import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../core/main_shell.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';
import 'welcome_screen.dart';

/// Wartezeit, bevor eine weitere Bestätigungsmail angefordert werden kann.
const Duration kResendCooldown = Duration(minutes: 2);

/// Wie lange man noch warten muss, bis man eine neue Mail anfordern darf.
Duration resendWaitTime({required DateTime lastSent, required DateTime now}) {
  final remaining = lastSent.add(kResendCooldown).difference(now);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Merkt sich, wann zuletzt eine Bestätigungsmail verschickt wurde.
abstract final class VerificationMail {
  static final Map<String, DateTime> _lastSent = {};

  static void markSent(User user) => _lastSent[user.uid] = DateTime.now();

  /// Letzter Versand in dieser Sitzung, sonst der Zeitpunkt der
  /// Registrierung (da wurde die erste Mail verschickt).
  static DateTime lastSent(User user) =>
      _lastSent[user.uid] ??
      user.metadata.creationTime ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// Wird angezeigt, solange die E-Mail-Adresse noch nicht bestätigt ist.
/// Man kann den Status neu prüfen und – frühestens 2 Minuten nach der
/// letzten Mail – eine neue Bestätigungsmail anfordern, z. B. wenn der
/// Link abgelaufen ist.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _ticker;
  bool _checking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Countdown jede Sekunde aktualisieren
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _checking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        // Token erneuern, damit die Sicherheitsregeln die Bestätigung sehen
        await user.getIdToken(true);
        messenger.showMessage('E-Mail bestätigt – willkommen!');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OrgGate()),
          (_) => false,
        );
        return;
      }
      messenger.showMessage(
        'Noch nicht bestätigt. Bitte auf den Link in der E-Mail klicken.',
        long: true,
      );
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _resend(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await user.sendEmailVerification();
      VerificationMail.markSent(user);
      messenger.showMessage(
        'Neue Bestätigungsmail an ${user.email} gesendet.',
        long: true,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        VerificationMail.markSent(user);
        messenger.showMessage(
          'Zu viele Anfragen. Bitte etwas später erneut versuchen.',
          long: true,
        );
      } else {
        messenger.showMessage(e.message ?? e.code, long: true);
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    final wait = resendWaitTime(
      lastSent: VerificationMail.lastSent(user),
      now: DateTime.now(),
    );
    final minutes = wait.inMinutes;
    final seconds = (wait.inSeconds % 60).toString().padLeft(2, '0');
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: ContentWidth.narrow(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 72),
            const SizedBox(height: 16),
            Text(
              'Bitte bestätige deine E-Mail-Adresse',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Wir haben einen Bestätigungslink an ${user.email} geschickt. '
              'Klicke auf den Link in der E-Mail und tippe danach auf '
              '„Ich habe bestätigt“.\n\n'
              'Keine E-Mail bekommen oder ist der Link abgelaufen? Schau im '
              'Spam-Ordner nach oder fordere eine neue E-Mail an.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _checking ? null : _checkVerified,
              icon: const Icon(Icons.check),
              label: const Text('Ich habe bestätigt'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: wait > Duration.zero || _sending
                  ? null
                  : () => _resend(user),
              icon: const Icon(Icons.forward_to_inbox_outlined),
              label: Text(
                wait > Duration.zero
                    ? 'Neue E-Mail in $minutes:$seconds möglich'
                    : 'Neue Bestätigungsmail senden',
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _signOut,
              child: const Text('Abmelden / anderes Konto'),
            ),
          ],
        ),
      ),
    );
  }
}
