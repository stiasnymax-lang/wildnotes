import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_tiergarto/auth/verify_email_screen.dart';
import 'package:flutter_application_tiergarto/org/join_code.dart';

void main() {
  group('Beitrittscode', () {
    test('ist 24 Zeichen lang und gültig', () {
      final code = generateJoinCode(Random(1));
      expect(code.length, 24);
      expect(isValidJoinCode(code), isTrue);
    });

    test('enthält keine verwechselbaren Zeichen', () {
      for (var i = 0; i < 50; i++) {
        expect(generateJoinCode(), isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('zwei Codes sind verschieden', () {
      expect(generateJoinCode(), isNot(generateJoinCode()));
    });

    test('Anzeige in Vierergruppen und zurück', () {
      final code = generateJoinCode(Random(2));
      final formatted = formatJoinCode(code);
      expect(formatted.split('-').length, 6);
      expect(normalizeJoinCode(formatted), code);
      expect(normalizeJoinCode(formatted.toLowerCase()), code);
    });

    test('Code wird auch aus dem Beitrittslink erkannt', () {
      final code = generateJoinCode(Random(3));
      expect(extractJoinCode(joinLink(code)), code);
      expect(extractJoinCode('  ${formatJoinCode(code)} '), code);
    });

    test('zu kurze oder falsche Codes sind ungültig', () {
      expect(isValidJoinCode('ABCD'), isFalse);
      expect(isValidJoinCode('0' * 24), isFalse);
    });
  });

  group('Bestätigungsmail erneut senden', () {
    final sent = DateTime(2026, 11, 25, 12);

    test('direkt nach dem Senden: 2 Minuten warten', () {
      expect(
        resendWaitTime(lastSent: sent, now: sent),
        const Duration(minutes: 2),
      );
    });

    test('nach 90 Sekunden: noch 30 Sekunden', () {
      expect(
        resendWaitTime(
          lastSent: sent,
          now: sent.add(const Duration(seconds: 90)),
        ),
        const Duration(seconds: 30),
      );
    });

    test('nach 2 Minuten oder später: sofort möglich', () {
      expect(
        resendWaitTime(
          lastSent: sent,
          now: sent.add(const Duration(minutes: 2)),
        ),
        Duration.zero,
      );
      expect(
        resendWaitTime(lastSent: sent, now: sent.add(const Duration(days: 3))),
        Duration.zero,
      );
    });
  });
}
