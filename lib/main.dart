import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app_check.dart';
import 'auth/welcome_screen.dart';
import 'core/main_shell.dart';
import 'firebase_options.dart';
import 'org/org_session.dart';

/// Einstiegspunkt der WildNotes-App.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check vor allen anderen Firebase-Aufrufen aktivieren
  await activateAppCheck();
  await initializeDateFormatting('de');
  OrgSession.instance.init();
  runApp(const WildNotesApp());
}

class WildNotesApp extends StatelessWidget {
  const WildNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Entspricht MainActivity.onStart(): ist bereits ein Benutzer eingeloggt,
    // geht es direkt in die App, sonst zur Willkommensseite.
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    return MaterialApp(
      title: 'WildNotes',
      debugShowCheckedModeBanner: false,
      navigatorKey: OrgSession.navigatorKey,
      locale: const Locale('de'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      // OrgScope liegt über dem Navigator, damit alle Seiten und Dialoge
      // auf die aktive Organisation zugreifen können.
      builder: (context, child) =>
          OrgScope(session: OrgSession.instance, child: child!),
      home: loggedIn ? const OrgGate() : const WelcomeScreen(),
    );
  }
}
