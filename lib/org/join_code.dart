import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Länge eines Beitrittscodes.
const int kJoinCodeLength = 24;

/// Zeichen für Beitrittscodes – ohne leicht verwechselbare Zeichen
/// (0/O, 1/I/L), damit man den Code auch abtippen kann.
const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Rolle, die man beim Beitritt per Code erhält. Berechtigte können sie
/// danach in der Mitgliederliste ändern.
const String kJoinCodeRoleId = 'viewer';

/// Adresse der Web-App; der Beitrittslink zeigt immer hierhin.
const String kWebAppUrl = 'https://stiasnymax-lang.github.io/wildnotes/';

/// Erzeugt einen zufälligen, nicht erratbaren Beitrittscode.
String generateJoinCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    kJoinCodeLength,
    (_) => _alphabet[r.nextInt(_alphabet.length)],
  ).join();
}

/// Großschreibung, Bindestriche/Leerzeichen entfernen.
String normalizeJoinCode(String input) =>
    input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

bool isValidJoinCode(String code) =>
    code.length == kJoinCodeLength &&
    code.split('').every((c) => _alphabet.contains(c));

/// Lesbare Darstellung in Vierergruppen: ABCD-EFGH-…
String formatJoinCode(String code) {
  final groups = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    groups.add(code.substring(i, min(i + 4, code.length)));
  }
  return groups.join('-');
}

/// Link, über den man der Organisation direkt beitreten kann.
String joinLink(String code) => '$kWebAppUrl?join=$code';

/// Akzeptiert sowohl den Code als auch den kompletten Beitrittslink.
String extractJoinCode(String input) {
  final trimmed = input.trim();
  final fromLink = Uri.tryParse(trimmed)?.queryParameters['join'];
  return normalizeJoinCode(fromLink ?? trimmed);
}

/// Beitrittscode aus dem Aufruf-Link (…/wildnotes/?join=CODE). Bleibt
/// gespeichert, bis man sich eingeloggt und beigetreten ist.
abstract final class PendingJoin {
  static String? code;

  static void readFromUrl() {
    if (!kIsWeb) return;
    final value = Uri.base.queryParameters['join'];
    if (value == null) return;
    final normalized = normalizeJoinCode(value);
    if (isValidJoinCode(normalized)) code = normalized;
  }
}
