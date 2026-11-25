import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Websiteschlüssel (Site Key) von reCAPTCHA (Google Cloud Fraud Defense /
/// reCAPTCHA Enterprise) für die Web-App.
///
/// Der Websiteschlüssel ist öffentlich und darf im Code stehen. Der
/// Schlüssel muss in der Firebase Console unter App Check → Apps → Web-App
/// mit dem Anbieter „Fraud Defense“ registriert sein.
///
/// Solange hier nichts eingetragen ist, bleibt App Check im Web aus.
const String kRecaptchaSiteKey = '6Lf9gTEuAAAAAFFH71Bi7VaGIqHz5SbVt1_9Fb-4';

/// Aktiviert Firebase App Check: Jede Anfrage an Firebase (Login,
/// Firestore) trägt dann einen Nachweis, dass sie aus der echten App kommt.
/// Skripte mit kopiertem API-Key werden abgewiesen, sobald in der Firebase
/// Console die Erzwingung eingeschaltet ist.
///
/// - Web: reCAPTCHA Enterprise / Fraud Defense (unsichtbar, kein Klick)
/// - Android Debug-Builds: Debug-Provider. Beim ersten Start steht im Log
///   ein Debug-Token, das in der Firebase Console freigegeben werden muss.
/// - Android Release: Play Integrity
Future<void> activateAppCheck() async {
  if (kIsWeb && kRecaptchaSiteKey.isEmpty) {
    debugPrint('App Check: kein reCAPTCHA-Websiteschlüssel – App Check aus.');
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb
          ? ReCaptchaEnterpriseProvider(kRecaptchaSiteKey)
          : null,
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    // Ohne App Check läuft die App weiter; erst die Erzwingung in der
    // Firebase Console würde Anfragen dann ablehnen.
    debugPrint('App Check konnte nicht aktiviert werden: $e');
  }
}
